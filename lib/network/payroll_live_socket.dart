// ignore: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

/// Minimal browser WebSocket for the live payroll run (this project targets
/// Flutter Web, and `dart:html` needs no extra package).
///
/// Emits every JSON message of the server as a `Map`. Two synthetic events tell
/// the caller what happened to the connection itself:
///   {'type': '_open'}                      the socket is connected
///   {'type': '_closed', 'code': int}       the socket closed (or failed to open)
class PayrollLiveSocket {
  PayrollLiveSocket(this.url);

  final String url;
  html.WebSocket? _ws;
  final StreamController<Map<String, dynamic>> _events = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get events => _events.stream;
  bool get isOpen => _ws?.readyState == html.WebSocket.OPEN;

  void connect() {
    final ws = html.WebSocket(url);
    _ws = ws;
    ws.onOpen.listen((_) => _emit({'type': '_open'}));
    ws.onMessage.listen((message) {
      try {
        final decoded = jsonDecode(message.data as String);
        if (decoded is Map) _emit(Map<String, dynamic>.from(decoded));
      } catch (_) {
        // ignore a malformed frame
      }
    });
    ws.onClose.listen((e) => _emit({'type': '_closed', 'code': e.code ?? 0}));
    ws.onError.listen((_) => _emit({'type': '_closed', 'code': 0}));
  }

  /// Sends a text command to the server (the only one it understands is `cancel`).
  void send(String text) {
    if (isOpen) _ws!.sendString(text);
  }

  void close() {
    try {
      _ws?.close();
    } catch (_) {}
    _ws = null;
  }

  void dispose() {
    close();
    _events.close();
  }

  void _emit(Map<String, dynamic> event) {
    if (!_events.isClosed) _events.add(event);
  }
}
