import 'dart:convert';
import 'dart:typed_data';

import 'package:lib5/src/api/base.dart';
import 'package:lib5/src/constants.dart';
import 'package:lib5/src/model/cid.dart';
import 'package:lib5/src/model/multihash.dart';
import 'package:lib5/src/storage_service/config.dart';

import 'package:http/http.dart' as http;

abstract class S5APIProviderWithRemoteUpload extends S5APIProvider {
  final List<StorageServiceConfig> storageServiceConfigs = [];

  http.Client get httpClient;

  @override
  Future<CID> uploadRawFile(Uint8List data) async {
    final expectedHash = await crypto.hashBlake3(data);
    final expectedCID = CID(
      cidTypeRaw,
      Multihash(Uint8List.fromList(
        [mhashBlake3Default] + expectedHash,
      )),
      size: data.length,
    );

    for (final sc in storageServiceConfigs) {
      try {
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
        final cid = CID.decode(json.decode(res.body)['cid']);
        if (cid != expectedCID) {
          throw 'Integrity check for file uploaded to $sc failed ($cid != $expectedCID)';
        }
        return cid;
      } catch (e, st) {
        // TODO Proper logging
        print(e);
        print(st);
      }
    }
    throw 'Could not upload raw file';
  }
}
