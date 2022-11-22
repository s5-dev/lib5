import 'package:base_codecs/base_codecs.dart';
import 'package:lib5/constants.dart';
import 'package:lib5/lib5.dart';
import 'package:test/test.dart';

void main() {
  group('CID tests', () {
    test('all', () {
      final mediaCID =
          CID.decode('z5TTp1umafoRLvi8VHEU6fXtUxkpjas2N5KPKhZyaLff9ZZ5');
      expect(mediaCID.type, cidTypeMetadataMedia);
      expect(
        mediaCID.toBase32(),
        'byupzcidv4npfep5cnsmkrhi3irjiabixvh77tvixkjswrua2cxn7yza',
      );

      final rawCID =
          CID.decode('uJh9HlpMAkwc3YGnUflReWWPwj6Vtg3ihGyXFYNe_KvJbGl_fj1s');
      expect(rawCID.type, cidTypeRaw);
      expect(rawCID.size, 1536155487);

      expect(rawCID.hash.functionType, mhashBlake3Default);
      expect(
        hex.encode(rawCID.hash.hashBytes).toLowerCase(),
        '479693009307376069d47e545e5963f08fa56d8378a11b25c560d7bf2af25b1a',
      );

      expect(
        rawCID.toBase32(),
        'beypupfutacjqon3anhkh4vc6lfr7bd5fnwbxrii3excwbv57flzfwgs736hvw',
      );
      expect(
        rawCID.toBase58(),
        'z6e5mLE5CqXdaPxWaD1h4tCMibSH1adYGAyGrWn5xpNNf4CMVxDxW',
      );
    });
  });
}
