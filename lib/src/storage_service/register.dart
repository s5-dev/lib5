import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:lib5/src/identity/constants.dart';
import 'package:lib5/src/identity/identity.dart';
import 'package:lib5/src/storage_service/config.dart';
import 'package:lib5/src/storage_service/sign_challenge.dart';
import 'package:lib5/src/util/base64.dart';

const endpointRegister = "/api/register";

Future<String> register({
  required http.Client httpClient,
  required StorageServiceConfig serviceConfig,
  required S5UserIdentity identity,
  required Uint8List seed,
  required String? email,
  required String label,
}) async {
  final crypto = identity.api.crypto;

  final portalAccountRootSeed = identity.subSeeds[storageServiceAccountsTweak]!;

  final portalAccountSeed = await crypto.hashBlake3(
    Uint8List.fromList(
      portalAccountRootSeed + seed,
    ),
  );

  final keyPair = await crypto.newKeyPairEd25519(seed: portalAccountSeed);

  final pubKeyStr = base64UrlNoPaddingEncode(keyPair.publicKey);

  final registerRequestResponse = await httpClient.get(
    Uri.parse('${serviceConfig.scheme}://account.${serviceConfig.authority}')
        .replace(
      path: endpointRegister,
      queryParameters: {
        'pubKey': pubKeyStr,
      },
    ),
  );
  if (registerRequestResponse.statusCode != 200) {
    throw 'HTTP ${registerRequestResponse.statusCode}: ${registerRequestResponse.body}';
  }

  final registerRequestResponseData = json.decode(registerRequestResponse.body);

  final challenge =
      base64UrlNoPaddingDecode(registerRequestResponseData['challenge']);

  final challengeResponse = await signChallenge(
    keyPair: keyPair,
    challenge: challenge,
    challengeType: challengeTypeRegister,
    crypto: crypto,
    serviceAuthority: serviceConfig.authority,
  );

  final data = {
    'pubKey': pubKeyStr,
    'response': base64UrlNoPaddingEncode(challengeResponse.response),
    'signature': base64UrlNoPaddingEncode(challengeResponse.signature),
    'email': email,
    'label': label,
  };

  final registerResponse = await httpClient.post(
    Uri.parse(
        '${serviceConfig.scheme}://account.${serviceConfig.authority}$endpointRegister'),
    headers: {'content-type': 'application/json'},
    body: json.encode(data),
  );

  if (registerResponse.statusCode != 200) {
    throw 'HTTP ${registerResponse.statusCode}: ${registerResponse.body}';
  }

  // TODO Maybe not use set-cookie header name

  final authToken =
      registerResponse.headers['set-cookie']!.split(';').first.split('=').last;

  return authToken;
}
