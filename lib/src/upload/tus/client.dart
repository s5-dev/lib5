/// The MIT License (MIT)
///
/// Copyright (c) 2020 Joseph N. Mutumi
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in all
/// copies or substantial portions of the Software.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
/// SOFTWARE.

/// Modified by redsolver, 2022

import 'dart:async';
import 'dart:convert' show base64, utf8;
import 'dart:math' show pow;

import 'package:http/http.dart' as http;
import 'package:lib5/src/model/multihash.dart';

typedef OpenReadFunction = Stream<List<int>> Function(int start);

/// This class is used for creating or resuming uploads.
class S5TusClient {
  /// Version of the tus protocol used by the client. The remote server needs to
  /// support this version, too.
  static final tusVersion = "1.0.0";

  /// The tus server Uri
  final Uri url;

  /// Storage used to save and retrieve upload URLs by its fingerprint.
  final TusStore? store;

  final int fileLength;
  final OpenReadFunction openRead;

  /// Any additional headers
  final Map<String, String>? headers;

  int? _fileSize;

  String _fingerprint = "";

  String? _uploadMetadata;

  final Multihash hash;

  Uri? _uploadUrl;

  late int _offset;

  int uploadedOffset = 0;

  bool _pauseUpload = false;

  final Stream<void>? onCancel;

  S5TusClient({
    required this.url,
    required this.httpClient,
    required this.fileLength,
    required this.openRead,
    required this.hash,
    this.onCancel,
    this.store,
    this.headers,
    // this.metadata = const {},
  }) {
    _uploadMetadata = _generateMetadata();
  }

  /// Whether the client supports resuming
  bool get resumingEnabled => store != null;

  /// The URI on the server for the file
  Uri? get uploadUrl => _uploadUrl;

  /// The fingerprint of the file being uploaded
  String get fingerprint => _fingerprint;

  /// The 'Upload-Metadata' header sent to server
  String get uploadMetadata => _uploadMetadata ?? "";

  final http.Client httpClient;

  /// Create a new [upload] throwing [ProtocolException] on server error
  Future<void> create() async {
    _fileSize = fileLength;

    final client = httpClient;
    final createHeaders = Map<String, String>.from(headers ?? {})
      ..addAll({
        "Tus-Resumable": tusVersion,
        "Upload-Metadata": _uploadMetadata ?? "",
        "Upload-Length": "$_fileSize",
      });

    final response = await client.post(url, headers: createHeaders);
    if (!(response.statusCode >= 200 && response.statusCode < 300) &&
        response.statusCode != 404) {
      throw ProtocolException(
          "unexpected status code (${response.statusCode}) while creating upload: ${response.body}");
    }

    String urlStr = response.headers["location"] ?? "";
    if (urlStr.isEmpty) {
      throw ProtocolException(
          "missing upload Uri in response for creating upload");
    }

    _uploadUrl = _parseUrl(urlStr);

    store?.set(_fingerprint, _uploadUrl as Uri);
  }

  /// Check if possible to resume an already started upload
  Future<bool> _resume() async {
    _fileSize = fileLength;
    _pauseUpload = false;

    if (!resumingEnabled) {
      return false;
    }

    _uploadUrl = await store?.get(_fingerprint);

    if (_uploadUrl == null) {
      return false;
    }
    return true;
  }

  /// Start or resume an upload in chunks of [maxChunkSize] throwing
  /// [ProtocolException] on server error
  Future<String> upload({
    Function(double)? onProgress,
    Function()? onComplete,
  }) async {
    if (!await _resume()) {
      await create();
    }

    // get offset from server
    _offset = 0; // await _getOffset();

    bool isFirstUploadRequest = true;

    int totalBytes = _fileSize as int;

    // start upload
    final client = httpClient;

    bool isCanceled = false;
    EventSink<List<int>>? eventSink;

    final cancelSub = onCancel?.listen((_) {
      isCanceled = true;
      eventSink?.close();
    });

    int retryCount = 0;

    while (!_pauseUpload && _offset < totalBytes) {
      StreamSubscription? sub;
      try {
        if (!isFirstUploadRequest) {
          _offset = await _getOffset();
        }
        isFirstUploadRequest = false;

        final uploadHeaders = Map<String, String>.from(headers ?? {})
          ..addAll({
            "Tus-Resumable": tusVersion,
            "Upload-Offset": "$_offset",
            "Content-Type": "application/offset+octet-stream"
          });

        var uploadedLength = 0;

        var stream = http.ByteStream(openRead(_offset).transform(
          StreamTransformer.fromHandlers(
            handleData: (data, sink) {
              uploadedLength += data.length;
              sink.add(data);
              if (eventSink == null) {
                eventSink = sink;
              }
            },
            handleError: (error, stack, sink) {
              // TODO Proper error handling
              print(error.toString());
            },
            handleDone: (sink) {
              sink.close();
            },
          ),
        ));

        final req = CustomStreamedRequest('PATCH', _uploadUrl as Uri, stream);

        req.headers.addAll(uploadHeaders);

        if (onProgress != null) {
          sub = Stream.periodic(Duration(milliseconds: 100)).listen((event) {
            onProgress((uploadedOffset + uploadedLength) / totalBytes);
          });
        }

        final response = await client.send(req);

        sub?.cancel();

        if (!(response.statusCode >= 200 && response.statusCode < 300)) {
          throw ProtocolException(
              "unexpected status code (${response.statusCode}) while uploading: ${await utf8.decodeStream(response.stream)}");
        }

        int? serverOffset = _parseOffset(response.headers["upload-offset"]);
        if (serverOffset == null) {
          throw ProtocolException(
              "response to PATCH request contains no or invalid Upload-Offset header");
        }

        _offset = serverOffset;

        retryCount = 0;

        if (_offset == totalBytes) {
          if (onComplete != null) {
            onComplete();
          }
        }
      } catch (e, st) {
        // TODO Proper error handling

        sub?.cancel();

        if (isCanceled) {
          cancelSub?.cancel();
          throw S5TusClientCancelException();
        }

        _offset = _offsetBackup;

        retryCount++;
        if (retryCount > 10) {
          cancelSub?.cancel();
          throw 'Too many retries. ($e $st)';
        }

        print('Chunk upload error (try #$retryCount): $e $st');
        await Future.delayed(Duration(seconds: pow(2, retryCount).round()));
      }
    }
    cancelSub?.cancel();
    store?.remove(_fingerprint);
    return '';
  }

  /// Override this to customize creating 'Upload-Metadata'
  String _generateMetadata() {
    return 'hash ${base64.encode(utf8.encode(hash.toBase64Url()))}';
  }

  /// Get offset from server throwing [ProtocolException] on error
  Future<int> _getOffset() async {
    final offsetHeaders = Map<String, String>.from(headers ?? {})
      ..addAll({
        "Tus-Resumable": tusVersion,
      });

    final response =
        await httpClient.head(_uploadUrl as Uri, headers: offsetHeaders);

    if (!(response.statusCode >= 200 && response.statusCode < 300)) {
      throw ProtocolException(
          "unexpected status code (${response.statusCode}) while resuming upload");
    }

    int? serverOffset = _parseOffset(response.headers["upload-offset"]);
    if (serverOffset == null) {
      throw ProtocolException(
          "missing upload offset in response for resuming upload");
    }
    return serverOffset;
  }

  int _offsetBackup = 0;

  int? _parseOffset(String? offset) {
    if (offset == null || offset.isEmpty) {
      return null;
    }
    if (offset.contains(",")) {
      offset = offset.substring(0, offset.indexOf(","));
    }
    return int.tryParse(offset);
  }

  Uri _parseUrl(String urlStr) {
    if (urlStr.contains(",")) {
      urlStr = urlStr.substring(0, urlStr.indexOf(","));
    }
    Uri uploadUrl = Uri.parse(urlStr);
    if (uploadUrl.host.isEmpty) {
      uploadUrl = uploadUrl.replace(host: url.host);
    }
    if (uploadUrl.scheme.isEmpty) {
      uploadUrl = uploadUrl.replace(scheme: url.scheme);
    }
    return uploadUrl;
  }
}

class CustomStreamedRequest extends http.BaseRequest {
  final http.ByteStream byteStream;

  CustomStreamedRequest(String method, Uri url, this.byteStream)
      : super(method, url);

  @override
  http.ByteStream finalize() {
    super.finalize();
    return byteStream;
  }
}

class ProtocolException implements Exception {
  final String message;

  ProtocolException(this.message);

  @override
  String toString() => "ProtocolException: $message";
}

/// Implementations of this interface are used to lookup a
/// [fingerprint] with the corresponding [file].
///
/// This functionality is used to allow resuming uploads.
///
/// See [TusMemoryStore] or [TusFileStore]
abstract class TusStore {
  /// Store a new [fingerprint] and its upload [url].
  Future<void> set(String fingerprint, Uri url);

  /// Retrieve an upload's Uri for a [fingerprint].
  /// If no matching entry is found this method will return `null`.
  Future<Uri?> get(String fingerprint);

  /// Remove an entry from the store using an upload's [fingerprint].
  Future<void> remove(String fingerprint);
}

/// This class is used to lookup a [fingerprint] with the
/// corresponding [file] entries in a [Map].
///
/// This functionality is used to allow resuming uploads.
///
/// This store **will not** keep the values after your application crashes or
/// restarts.
class TusMemoryStore implements TusStore {
  Map<String, Uri> store = {};

  @override
  Future<void> set(String fingerprint, Uri url) async {
    store[fingerprint] = url;
  }

  @override
  Future<Uri?> get(String fingerprint) async {
    return store[fingerprint];
  }

  @override
  Future<void> remove(String fingerprint) async {
    store.remove(fingerprint);
  }
}

class S5TusClientCancelException implements Exception {}
