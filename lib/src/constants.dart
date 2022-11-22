// ! CID types
// These bytes are carefully selected to make the base58 and base32 representations of different CID types
// easy to distinguish and not collide with anything on https://github.com/multiformats/multicodec
const cidTypeRaw = 0x26;
const cidTypeMetadataMedia = 0xc5;
// const cidTypeMetadataFile = 0xc6;
const cidTypeMetadataDirectory = 0x59;
const cidTypeResolver = 0x25;

// ! indicates that the registry entry contains a S5 CID
const registryS5MagicByte = 0x5a;

// ! some multicodec bytes
// BLAKE3 with default output size of 256 bits
const mhashBlake3Default = 0x1f;

const mkeyEd25519 = 0xed;

// ! metadata files

// used as the first byte of metadata files
const metadataMagicByte = 0x5f;

// types for metadata files
const metadataTypeMedia = 0x02;
const metadataTypeDirectory = 0x03;

const registryMaxDataSize = 48;

// ! p2p protocol message types

const protocolMethodHandshakeOpen = 1;
const protocolMethodHandshakeDone = 2;

const protocolMethodSignedMessage = 10;

const protocolMethodHashQueryResponse = 5;
const protocolMethodHashQuery = 4;

const protocolMethodAnnouncePeers = 7;

const protocolMethodRegistryUpdate = 12;
const protocolMethodRegistryQuery = 13;

// ! Some optional metadata extensions (same for files, media files and directories)

// List<SpecialObject> (with CIDs)
const metadataExtensionChildren = 1;

// List<String>, license identifier from https://spdx.org/licenses/
const metadataExtensionLicenses = 11;

// List<Uint8List>, multicoded pubkey that references a registry entry that contains donation links and addresses
const metadataExtensionDonationKeys = 12;

// map string->map, external ids of this object by their wikidata property id. Can be used to for example internet archive identifiers
const metadataExtensionWikidataClaims = 13;

// List<String>, for example [en, de, de-DE]
const metadataExtensionLanguages = 14;

// List<String>,
const metadataExtensionSourceUris = 15;

// Resolver CID, can be used to update this post. can also be used to "delete" a post.
const metadataExtensionUpdateCID = 16;

// List<CID>, lists previous versions of this post
const metadataExtensionPreviousVersions = 17;

// unix timestamp in milliseconds
const metadataExtensionTimestamp = 18;

const metadataExtensionTags = 19;
const metadataExtensionCategories = 20;

// video, podcast, book, audio, music, ...
const metadataExtensionViewTypes = 21;

const metadataExtensionBasicMediaMetadata = 22;

// TODO comment to / reply to
// TODO mentions
// TODO Reposts (just link the original item)

// ! media details
const metadataMediaDetailsDuration = 10;

// ! metadata proofs
const metadataProofTypeSignature = 1;
const metadataProofTypeTimestamp = 2;