import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:lib5/src/identity/identity.dart';
import 'package:lib5/src/storage_service/config.dart';
import 'package:lib5/src/storage_service/sign_challenge.dart';
import 'package:lib5/src/util/base64.dart';

const endpointLogin = "/api/login";

Future<String> login({
  required http.Client httpClient,
  required StorageServiceConfig serviceConfig,
  required S5UserIdentity identity,
  required Uint8List seed,
  required String label,
}) async {
  final crypto = identity.api.crypto;

  final portalAccountRootSeed = identity.subSeeds[storageServiceAccountTweak]!;

  final portalAccountSeed = await crypto.hashBlake3(
    Uint8List.fromList(
      portalAccountRootSeed + seed,
    ),
  );

  final keyPair = await crypto.newKeyPairEd25519(seed: portalAccountSeed);

  final pubKeyStr = base64UrlNoPaddingEncode(keyPair.publicKey);

  final loginRequestResponse = await httpClient.get(
    Uri.parse('${serviceConfig.scheme}://account.${serviceConfig.authority}')
        .replace(
      path: endpointLogin,
      queryParameters: {
        'pubKey': pubKeyStr,
      },
    ),
  );
  if (loginRequestResponse.statusCode != 200) {
    throw 'HTTP ${loginRequestResponse.statusCode}: ${loginRequestResponse.body}';
  }

  final loginRequestResponseData = json.decode(loginRequestResponse.body);

  final challenge =
      base64UrlNoPaddingDecode(loginRequestResponseData['challenge']);

  final challengeResponse = await signChallenge(
    keyPair: keyPair,
    challenge: challenge,
    challengeType: challengeTypeLogin,
    crypto: crypto,
    serviceAuthority: serviceConfig.authority,
  );

  final data = {
    'pubKey': pubKeyStr,
    'response': base64UrlNoPaddingEncode(challengeResponse.response),
    'signature': base64UrlNoPaddingEncode(challengeResponse.signature),
    'label': label,
  };

  final loginResponse = await httpClient.post(
    Uri.parse(
        '${serviceConfig.scheme}://account.${serviceConfig.authority}$endpointLogin'),
    headers: {'content-type': 'application/json'},
    body: json.encode(data),
  );

  if (loginResponse.statusCode != 200) {
    throw 'HTTP ${loginResponse.statusCode}: ${loginResponse.body}';
  }

  return loginResponse.headers['set-cookie']!.split(';').first.split('=').last;
}
