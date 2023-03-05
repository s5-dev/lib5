import 'dart:typed_data';

class StorageLocation {
  final int type;
  final List<String> parts;
  final List<Uint8List> binaryParts = [];
  // unix timestamp when this location expires, in seconds
  final int expiry;

  late final Uint8List providerMessage;

  StorageLocation(this.type, this.parts, this.expiry);

  String get bytesUrl => parts[0];

  String get outboardBytesUrl {
    if (parts.length == 1) {
      return '${parts[0]}.obao';
    }
    return parts[1];
  }

  @override
  toString() =>
      'StorageLocation($type, $parts, expiry: ${DateTime.fromMillisecondsSinceEpoch(expiry * 1000)})';
}
