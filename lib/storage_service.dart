/// provides acces to the storage service.
///
/// With these functions S5 nodes can be registered on, logged into,
/// and worked with (for things like remote uploads).
///
/// ```dart
/// final httpClient = http.Client();
/// final storageServiceConfig = StorageServiceConfig(
///   scheme: 'https',
///   authority: 'example.com', // replace with node
///   headers: {},
/// );
/// final apiProvider = S5APIProviderWithRemoteUpload(s5.api
///   ..storageServiceConfigs.add(storageServiceConfig)
///   ..httpClient = httpClient;
///
/// final fileData = Uint8List.fromList([/* Your file data */]);
///
/// try {
///   final cid = await apiProvider.uploadBlob(fileData);
///   print('File uploaded with CID: $cid');
/// } catch (e) {
///   print('File upload failed: $e');
/// }

library lib5.storage_service;

export 'src/storage_service/config.dart';
export 'src/storage_service/login.dart';
export 'src/storage_service/register.dart';
export 'src/api/remote_upload.dart';
