import 'package:base_codecs/base_codecs.dart';
import 'package:lib5/constants.dart';
import 'package:lib5/lib5.dart';

void main() {
  final mediaCID =
      CID.decode('z5TTp1umafoRLvi8VHEU6fXtUxkpjas2N5KPKhZyaLff9ZZ5');
  print(mediaCID.type == cidTypeMetadataMedia);

  final rawCID =
      CID.decode('uJh9HlpMAkwc3YGnUflReWWPwj6Vtg3ihGyXFYNe_KvJbGl_fj1s');
  print(rawCID.type == cidTypeRaw);
  print('${rawCID.size! / 1000 / 1000} MB');

  print(rawCID.hash.functionType == mhashBlake3Default);
  print('BLAKE3 hash: ${hex.encode(rawCID.hash.hashBytes).toLowerCase()}');

  print(rawCID.toBase32());
  print(rawCID.toBase58());
}
