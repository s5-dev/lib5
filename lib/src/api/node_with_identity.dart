import 'dart:convert';
import 'dart:typed_data';

import 'package:lib5/src/api/key_value_db.dart';
import 'package:lib5/src/api/node.dart';
import 'package:lib5/src/hidden_db/api.dart';
import 'package:lib5/src/hidden_db/classes.dart';
import 'package:lib5/src/identifier/blob.dart';
import 'package:lib5/src/identity/identity.dart';
import 'package:lib5/src/model/multihash.dart';
import 'package:lib5/src/model/node_id.dart';
import 'package:lib5/storage_service.dart';
import 'package:lib5/util.dart';

class S5NodeAPIWithIdentity extends S5NodeAPI {
  final S5UserIdentity identity;

  S5NodeAPIWithIdentity(
    super.node, {
    required this.identity,
    required this.authDB,
  });

  final _storageServiceAccountsPath = 'accounts.json';

  HiddenJSONResponse? _accountsRes;

  final KeyValueDB authDB;

  late Map accounts;

  final accountConfigs = <String, StorageServiceConfig>{};

  Future<void> initStorageServices() async {
    node.logger.verbose('initStorageServices');
    final hiddenDB = TrustedHiddenDBProvider(identity.hiddenDBKey, this);
    final res = await hiddenDB.getJSON(_storageServiceAccountsPath);
    _accountsRes = res;
    accounts = res.data ??
        {
          'accounts': {},
          'active': <String>[],
          'uploadOrder': {'default': []}
        };

    for (final id in accounts['active']) {
      if (!accountConfigs.containsKey(id)) {
        await setupAccount(id);
      }
    }
  }

  Future<void> setupAccount(String id) async {
    node.logger.info('[account] setup $id');

    final config = accounts['accounts'][id]!;
    final uri = Uri.parse(config['url']);

    final authTokenKey = _getAuthTokenKey(id);

    if (!authDB.contains(authTokenKey)) {
      // TODO Check if the auth token is valid/expired

      try {
        final pc = StorageServiceConfig(
          scheme: uri.scheme,
          authority: uri.authority,
          headers: {},
        );
        final seed = base64UrlNoPaddingDecode(
          config['seed'],
        );

        final authToken = await login(
          serviceConfig: pc,
          httpClient: httpClient,
          identity: identity,
          seed: seed,
          label: 's5-dart',
          crypto: crypto,
        );
        authDB.set(authTokenKey, utf8.encode(authToken));
      } catch (e, st) {
        node.logger.catched(e, st);
      }
    }

    final authToken = utf8.decode(authDB.get(authTokenKey)!);

    final sc = StorageServiceConfig(
      scheme: uri.scheme,
      authority: uri.authority,
      headers: {
        'authorization': 'Bearer $authToken',
      },
    );

    accountConfigs[id] = sc;

    connectToPortalNodes(sc);
  }

  void connectToPortalNodes(StorageServiceConfig sc) async {
    try {
      final res = await httpClient.get(
        Uri.parse(
          '${sc.scheme}://${sc.authority}/s5/p2p/nodes',
        ),
      );
      final data = json.decode(res.body);
      for (final n in data['nodes']) {
        final id = NodeID.decode(n['id']);
        final uris = <Uri>[];
        for (final uri in n['uris']) {
          uris.add(Uri.parse(uri).replace(userInfo: id.toBase58()));
        }
        if (uris.isNotEmpty) {
          if (!node.p2p.reconnectDelay.containsKey(id)) {
            node.p2p.connectToNode(uris);
          }
        }
      }
    } catch (e, st) {
      node.logger.catched(e, st);
    }
  }

  Future<void> _saveStorageServices() async {
    final hiddenDB = TrustedHiddenDBProvider(identity.hiddenDBKey, this);
    await hiddenDB.setJSON(
      _storageServiceAccountsPath,
      accounts,
      revision: (_accountsRes?.revision ?? 0) + 1,
    );
  }

  Future<void> registerAccount(String url, {String? inviteCode}) async {
    await initStorageServices();

    final uri = Uri.parse(url);

    for (final id in accountConfigs.keys) {
      if (id.startsWith('${uri.authority}:')) {
        throw 'User already has an account on this service!';
      }
    }

    final portalConfig = StorageServiceConfig(
      authority: uri.authority,
      scheme: uri.scheme,
      headers: {},
    );

    final seed = crypto.generateSecureRandomBytes(32);

    final authToken = await register(
      serviceConfig: portalConfig,
      httpClient: httpClient,
      identity: identity,
      email: null,
      seed: seed,
      label: 's5-dart',
      authToken: inviteCode,
      crypto: crypto,
    );

    final id =
        '${uri.authority}:${base64UrlNoPaddingEncode(seed.sublist(0, 12))}';

    accounts['accounts'][id] = {
      'url': '${uri.scheme}://${uri.authority}',
      'seed': base64UrlNoPaddingEncode(seed),
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };

    accounts['active'].add(id);
    accounts['uploadOrder']['default'].add(id);

    await setupAccount(id);

    authDB.set(
      _getAuthTokenKey(id),
      utf8.encode(authToken),
    );
    await _saveStorageServices();

    // TODO updateQuota();
  }

  Uint8List _getAuthTokenKey(String id) {
    return utf8.encode('identity_main_account_${id}_auth_token');
  }

  @override
  Future<BlobIdentifier> uploadBlobAsBytes(Uint8List data) async {

    final List<String> services = accountConfigs.keys.toList();
    // TODO Differentiate by type
    /*  if (data[0] == 0x8d && data[1] == 0x01) {
      services = metadataUploadServiceOrder;
    } else {
      services = thumbnailUploadServiceOrder;
    } */
    final expectedHash = await crypto.hashBlake3(data);
    final blobId = BlobIdentifier(Multihash.blake3(expectedHash), data.length);

    final results = await Future.wait(
      [
        for (final service in services)
          _uploadRawFileInternal(blobId, service, data)
      ],
    );
    for (final result in results) {
      if (result) return blobId;
    }
    throw 'Could not upload raw file $services $results';
  }

  Future<bool> _uploadRawFileInternal(
    BlobIdentifier expectedBlobId,
    String id,
    Uint8List data,
  ) async {
    node.logger.verbose('_uploadRawFileInternal $id');
    try {
      final sc = accountConfigs[id]!;
      final res = await httpClient.post(
        sc.getAPIUrl(
          '/s5/upload',
        ),
        headers: sc.headers,
        body: data,
      );
      if (res.statusCode != 200) {
        throw 'HTTP ${res.statusCode}: ${res.body}';
      }

      final cidStr = jsonDecode(res.body)['cid'];
      if (!expectedBlobId.matchesCidStr(cidStr)) {
        // TODO Use HashMismatchException here
        throw 'Integrity check for file uploaded to $id failed ($cidStr != $expectedBlobId)';
      }
      return true;
    } catch (e, st) {
      node.logger.catched(e, st);
      return false;
    }
  }
}
