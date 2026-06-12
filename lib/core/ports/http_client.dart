/// A minimal HTTP response — just what the price providers need.
class HttpResponse {
  final int statusCode;
  final String body;

  const HttpResponse(this.statusCode, this.body);

  bool get isOk => statusCode >= 200 && statusCode < 300;
}

/// A tiny HTTP GET abstraction. Keeps `lib/core` free of any concrete HTTP
/// package and lets provider tests run offline against canned responses.
abstract interface class HttpClient {
  Future<HttpResponse> get(Uri url, {Map<String, String>? headers});
}
