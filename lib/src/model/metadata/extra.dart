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
      metadataExtensionUpdateCID: 'updateCID',
      metadataExtensionPreviousVersions: 'previousVersions',
      metadataExtensionTimestamp: 'timestamp',
      metadataExtensionTags: 'tags',
      metadataExtensionCategories: 'categories',
      metadataExtensionBasicMediaMetadata: 'basicMediaMetadata',
      metadataExtensionViewTypes: 'viewTypes',
      metadataExtensionBridge: 'bridge',
    };
    for (final e in data.entries) {
      if (e.key == metadataExtensionWikidataClaims) {
        map['wikidataClaims'] = {};
        for (final e in e.value.entries) {
          map['wikidataClaims'][e.key] =
              e.value.map((v) => {'value': v[1]}).toList();
        }
      } else {
        map[names[e.key]!] = e.value;
      }
    }

    return map;
  }
}
