// ! CID types
// These bytes are carefully selected to make the base58 and base32 representations of different CID types
// easy to distinguish and not collide with anything on https://github.com/multiformats/multicodec

const cidTypeBlob = 0x5b;
const blobTypeRaw = 0x82;

@Deprecated('use blob identifiers instead')
const cidTypeRaw = 0x26;
@Deprecated('use directories instead')
const cidTypeMetadataMedia = 0xc5;
// const cidTypeMetadataFile = 0xc6;
const cidTypeDirectory = 0x5d;
@Deprecated('use `cidTypeDirectory` instead')
const cidTypeMetadataDirectory = cidTypeDirectory;

@Deprecated('use directories instead')
const cidTypeMetadataWebApp = 0x59;


const cidTypeBridge = 0x3a;

// format for dynamic encrypted CID
// type algo key resolver_type mkey_ed255 pubkey
// in entry: encrypt(RAW CID or MEDIA or SOMETHING)

/// Used for immutable encrypted files and metadata formats, key can never be re-used
///
/// Used for file versions in Vup
@Deprecated('use directories instead')
const cidTypeEncryptedStatic = 0xae;

/// Used for encrypted files with update support
///
/// can point to resolver CID, Stream CID, Directory Metadata or Media Metadata object
// const cidTypeEncryptedDynamic = 0xad;
const cidTypeEncryptedMutable = 0x5e;

// ! some multicodec bytes
// BLAKE3 with default output size of 256 bits
@Deprecated('use mhashBlake3 instead')
const mhashBlake3Default = 0x1f;

const mhashBlake3 = 0x1e;
const mhashSha256 = 0x12;

const mkeyEd25519 = 0xed;

const encryptionAlgorithmXChaCha20Poly1305 = 0xa6;
const encryptionAlgorithmXChaCha20Poly1305NonceSize = 24;
const encryptionAlgorithmXChaCha20Poly1305KeySize = 32;

// ! metadata files

// used as the first byte of metadata files
@Deprecated('use directories instead')
const metadataMagicByte = 0x5f;

// types for metadata files
@Deprecated('use directories instead')
const metadataTypeMedia = 0x02;
@Deprecated('use directories instead')
const metadataTypeWebApp = 0x03;
const metadataTypeDirectory = 0x04;
@Deprecated('s5 no longer uses a custom data structure for public identity data')
const metadataTypeUserIdentity = 0x07;


@Deprecated('this should be on the application layer, use directories instead')
const parentLinkTypeUserIdentity = 1;
@Deprecated('this should be on the application layer, use directories instead')
const parentLinkTypeBoard = 5;
@Deprecated('this should be on the application layer, use directories instead')
const parentLinkTypeBridgeUser = 10;

const registryMaxDataSize = 64;

// ! user identity

const authPayloadVersion1 = 0x01;

// const userIdentityLinkFollowingList = 0x02;

// ! p2p protocol message types

const protocolMethodHandshakeOpen = 1;
const protocolMethodHandshakeDone = 2;

const protocolMethodSignedMessage = 10;

const protocolMethodHashQuery = 4;
const protocolMethodAnnouncePeers = 8;
const protocolMethodRegistryQuery = 13; // 0x0d

const recordTypeStorageLocation = 0x05; // cache until TTL
const recordTypeRegistryEntry = 0x07; // permanent
const recordTypeStreamMessage = 0x08; // temporary?
const protocolMethodMessageQuery = 0x49; // 0x0e

// ! Some optional metadata extensions (same for files, media files and directories)

// List<String>, license identifier from https://spdx.org/licenses/
@Deprecated('this should be on the application layer, use directories instead')
const metadataExtensionLicenses = 11;

// List<Uint8List>, multicoded pubkey that references a registry entry that contains donation links and addresses
@Deprecated('this should be on the application layer, use directories instead')
const metadataExtensionDonationKeys = 12;

// map string->map, external ids of this object by their wikidata property id.
@Deprecated('this should be on the application layer, use directories instead')
const metadataExtensionWikidataClaims = 13;

// List<String>, for example [en, de, de-DE]
@Deprecated('this should be on the application layer, use directories instead')
const metadataExtensionLanguages = 14;

// List<String>,
@Deprecated('this should be on the application layer, use directories instead')
const metadataExtensionSourceUris = 15;

// Resolver CID, can be used to update this post. can also be used to "delete" a post.
@Deprecated('this should be on the application layer, use directories instead')
const metadataExtensionUpdateCID = 16;

// List<CID>, lists previous versions of this post
@Deprecated('this should be on the application layer, use directories instead')
const metadataExtensionPreviousVersions = 17;

// unix timestamp in milliseconds
@Deprecated('this should be on the application layer, use directories instead')
const metadataExtensionTimestamp = 18;

@Deprecated('this should be on the application layer, use directories instead')
const metadataExtensionTags = 19;
@Deprecated('this should be on the application layer, use directories instead')
const metadataExtensionCategories = 20;

// video, podcast, book, audio, music, ...
@Deprecated('this should be on the application layer, use directories instead')
const metadataExtensionViewTypes = 21;
@Deprecated('this should be on the application layer, use directories instead')

const metadataExtensionBasicMediaMetadata = 22;

@Deprecated('this should be on the application layer, use directories instead')
const metadataExtensionBridge = 23;

@Deprecated('this should be on the application layer, use directories instead')
const metadataExtensionOriginalTimestamp = 24;

// List<Uint8List>
@Deprecated('this should be on the application layer, use directories instead')
const metadataExtensionRoutingHints = 25;

// TODO comment to / reply to (use parents)
// TODO mentions (use new extension field)
// TODO Reposts (just link the original item)

// ! media details
const metadataMediaDetailsDuration = 10;
const metadataMediaDetailsIsLive = 11;
const metadataMediaDetailsWasLive = 12;

// ! storage locations
const storageLocationTypeArchive = 0;
const storageLocationTypeFile = 3;
const storageLocationTypeFull = 5;
const storageLocationTypeBridge = 7;
