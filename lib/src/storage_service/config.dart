class StorageServiceConfig {
  final String scheme;
  final String authority;
  final Map<String, String> headers;

  StorageServiceConfig({
    required this.scheme,
    required this.authority,
    required this.headers,
  });

  Uri getAPIUrl(String path) {
    return Uri.parse('$scheme://$authority$path');
  }

  Uri getAccountsAPIUrl(String path) {
    return Uri.parse('$scheme://account.$authority$path');
  }

  @override
  toString() => getAPIUrl('').toString();
}
