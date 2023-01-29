import 'dart:convert';
import 'dart:typed_data';

import 'package:lib5/src/api/base.dart';
import 'package:lib5/src/util/derive_hash.dart';

import 'classes.dart';
import 'constants.dart';
import 'hidden.dart';

abstract class HiddenDBProvider {
  Future<void> setRawData(
    String path,
    Uint8List data, {
    required int revision,
  });
  Future<HiddenRawDataResponse> getRawData(
    String path,
  );

  Future<void> setJSON(
    String path,
    dynamic data, {
    required int revision,
  });
  Future<HiddenJSONResponse> getJSON(
    String path,
  );
}

class TrustedHiddenDBProvider extends HiddenDBProvider {
  final Uint8List _hiddenRootKey;
  final S5APIProvider _api;

  TrustedHiddenDBProvider(this._hiddenRootKey, this._api);

  @override
  Future<HiddenRawDataResponse> getRawData(String path) async {
    final pathKey = _derivePathKeyForPath(path);

    return getHiddenRawDataImplementation(
      pathKey: pathKey,
      api: _api,
    );
  }

  @override
  Future<void> setRawData(String path, Uint8List data,
      {required int revision}) async {
    final pathKey = _derivePathKeyForPath(path);
    return setHiddenRawDataImplementation(
      pathKey: pathKey,
      data: data,
      revision: revision,
      api: _api,
    );
  }

  Uint8List _derivePathKeyForPath(String path) {
    final pathSegments = path
        .split('/')
        .map((e) => e.trim())
        .where((element) => element.isNotEmpty)
        .toList();

    final key = deriveKeyForPathSegments(pathSegments);
    return deriveHashBlake3Int(
      key,
      pathKeyDerivationTweak,
      crypto: _api.crypto,
    );
  }

  Uint8List deriveKeyForPathSegments(List<String> pathSegments) {
    if (pathSegments.isEmpty) {
      return _hiddenRootKey;
    }
    return deriveHashBlake3(
      deriveKeyForPathSegments(
        pathSegments.sublist(0, pathSegments.length - 1),
      ),
      utf8.encode(pathSegments.last),
      crypto: _api.crypto,
    );
  }

  @override
  Future<HiddenJSONResponse> getJSON(String path) async {
    final res = await getRawData(
      path,
    );
    if (res.data == null) {
      return HiddenJSONResponse(cid: res.cid);
    }

    return HiddenJSONResponse(
      data: json.decode(utf8.decode(res.data!)),
      revision: res.revision,
      cid: res.cid,
    );
  }

  @override
  Future<void> setJSON(String path, data, {required int revision}) {
    return setRawData(
      path,
      Uint8List.fromList(utf8.encode(json.encode(data))),
      revision: revision,
    );
  }
}
