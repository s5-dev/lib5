import 'package:lib5/src/model/cid.dart';

import 'base.dart';
import 'extra.dart';

class WebAppMetadata extends Metadata {
  final String? name;

  final List<String> tryFiles;
  final Map<int, String> errorPages;

  final ExtraMetadata extraMetadata;

  final Map<String, WebAppMetadataFileReference> paths;

  WebAppMetadata({
    required this.name,
    required this.tryFiles,
    required this.extraMetadata,
    required this.errorPages,
    required this.paths,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': 'web_app',
        'name': name,
        'tryFiles': tryFiles,
        'errorPages':
            errorPages.map((key, value) => MapEntry(key.toString(), value)),
        'paths': paths,
        'extraMetadata': extraMetadata,
      };
}

class WebAppMetadataFileReference {
  final String? contentType;
  int get size => cid.size ?? 0;
  final CID cid;

  WebAppMetadataFileReference({
    required this.cid,
    required this.contentType,
  });

  Map<String, dynamic> toJson() => {
        'cid': cid.toBase64Url(),
        'contentType': contentType,
      };
}
