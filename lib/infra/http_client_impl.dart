import 'package:http/http.dart' as http;

import '../core/ports/http_client.dart';

/// [HttpClient] backed by `package:http`.
class HttpClientImpl implements HttpClient {
  final http.Client _client;

  HttpClientImpl([http.Client? client]) : _client = client ?? http.Client();

  @override
  Future<HttpResponse> get(Uri url, {Map<String, String>? headers}) async {
    final response = await _client.get(url, headers: headers);
    return HttpResponse(response.statusCode, response.body);
  }
}
