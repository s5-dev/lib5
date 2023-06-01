import 'package:lib5/lib5.dart';
import 'package:lib5/src/constants.dart';

class ExtraMetadata {
  final Map<int, dynamic> data;
  ExtraMetadata(this.data);

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    final names = {
      metadataExtensionLicenses: 'licenses',
      metadataExtensionDonationKeys: 'donationKeys',
      metadataExtensionWikidataClaims: 'wikidataClaims',
      metadataExtensionLanguages: 'languages',
      metadataExtensionSourceUris: 'sourceUris',
      // metadataExtensionUpdateCID: 'updateCID',
      metadataExtensionPreviousVersions: 'previousVersions',
      metadataExtensionTimestamp: 'timestamp',
      metadataExtensionOriginalTimestamp: 'originalTimestamp',
      metadataExtensionTags: 'tags',
      metadataExtensionCategories: 'categories',
      metadataExtensionBasicMediaMetadata: 'basicMediaMetadata',
      metadataExtensionViewTypes: 'viewTypes',
      metadataExtensionBridge: 'bridge',
      metadataExtensionRoutingHints: 'routingHints',
    };
    for (final e in data.entries) {
      if (e.key == metadataExtensionUpdateCID) {
        map['updateCID'] = CID.fromBytes(e.value).toString();
      } else {
        map[names[e.key]!] = e.value;
      }
    }

    return map;
  }
}
