library openid_client.io;

import 'openid_client.dart';
import 'dart:async';
import 'dart:io';

export 'openid_client.dart';

class Authenticator {
  final Flow flow;

  final Function(String url) urlLancher;

  Authenticator(Client client,
      {int port: 3000,
      this.urlLancher: _runBrowser,
      Iterable<String> scopes: const []})
      : flow = new Flow.authorizationCode(client)
          ..scopes.addAll(scopes)
          ..redirectUri = Uri.parse("http://localhost:$port/cb");

  Future<Credential> authorize() async {
    var state = flow.authenticationUri.queryParameters["state"];

    _requestsByState[state] = new Completer();
    await _startServer(flow.redirectUri.port);
    urlLancher(flow.authenticationUri.toString());

    var response = await _requestsByState[state].future;

    return flow.callback(response);
  }

  static Map<int, Future<HttpServer>> _requestServers = {};
  static Map<String, Completer<Map<String, String>>> _requestsByState = {};

  static Future<HttpServer> _startServer(int port) async {
    return _requestServers[port] ??=
        (HttpServer.bind(InternetAddress.loopbackIPv4, port)
          ..then((requestServer) async {
            await for (var request in requestServer) {
              request.response.statusCode = 200;
              request.response.headers.set("Content-type", "text/html");
              request.response.writeln("<html>"
                  "<h1>You can now close this window</h1>"
                  "<script>window.close();</script>"
                  "</html>");
              request.response.close();
              var result = request.requestedUri.queryParameters;

              if (!result.containsKey("state")) continue;
              var r = _requestsByState.remove(result["state"]);
              r.complete(result);
              if (_requestsByState.isEmpty) {
                for (var s in _requestServers.values) {
                  (await s).close();
                }
                _requestServers.clear();
              }
            }

            _requestServers.remove(port);
          }));
  }
}

void _runBrowser(String url) {
  switch (Platform.operatingSystem) {
    case "linux":
      Process.run("x-www-browser", [url]);
      break;
    case "macos":
      Process.run("open", [url]);
      break;
    case "windows":
      Process.run("explorer", [url]);
      break;
    default:
      throw new UnsupportedError(
          "Unsupported platform: ${Platform.operatingSystem}");
      break;
  }
}
