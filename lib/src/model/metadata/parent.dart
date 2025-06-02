import 'package:lib5/src/constants.dart';
import 'package:lib5/src/model/cid.dart';

@Deprecated(
    'this should be handled on the application layer, use directories instead')
class MetadataParentLink {
  // Can be a (user) identity or a resolver CID
  final CID cid;
  final int type;
  final String? role;
  final bool signed;

  MetadataParentLink({
    required this.cid,
    this.type = parentLinkTypeUserIdentity,
    this.role,
    this.signed = false,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    void addNotNull(String key, dynamic value) {
      if (value != null) {
        map[key] = value;
      }
    }

    addNotNull('cid', cid.toString());
    addNotNull('type', type);
    addNotNull('role', role);
    addNotNull('signed', signed);

    return map;
  }
}
