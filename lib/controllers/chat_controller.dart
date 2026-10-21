import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:collection/collection.dart';
import 'package:get/get.dart';

import '../core/tr_snack.dart';
import '../models/chat_models.dart';
import '../network/api_exception.dart';
import '../network/api_service.dart';
import '../network/payroll_live_socket.dart';
import 'auth_controller.dart';

/// The live chat of the staff with the employees.
///
/// History and every action also work over plain HTTP; the WebSocket (`/api/chat/ws`) makes the
/// messages arrive at once and carries "is typing", "seen" and who is online. It starts when
/// somebody is signed in and reconnects by itself after a drop.
class ChatController extends GetxController {
  ChatController({ApiService? apiService}) : _api = apiService ?? ApiService();

  final ApiService _api;

  /// The conversations, newest first.
  final RxList<ChatThread> threads = <ChatThread>[].obs;

  /// Messages of employees nobody has seen yet, over all conversations (the sidebar badge).
  final RxInt totalUnread = 0.obs;

  /// The employee whose conversation is open, and its messages (oldest first).
  final RxnInt activeId = RxnInt();
  final RxList<ChatMessage> messages = <ChatMessage>[].obs;
  final RxBool loadingThreads = false.obs;
  final RxBool loadingMessages = false.obs;
  final RxBool loadingOlder = false.obs;
  final RxBool hasMore = false.obs;

  /// offline | connecting | live
  final RxString connection = 'offline'.obs;

  /// Employees connected right now.
  final RxSet<int> online = <int>{}.obs;

  /// Employees who are typing right now.
  final RxSet<int> typing = <int>{}.obs;

  /// In the open conversation: the employee has seen everything up to this message id.
  final RxInt employeeReadId = 0.obs;
  final RxnString error = RxnString();

  /// True while the chat page is on screen (no pop-up for a message of the conversation being read).
  final RxBool screenOpen = false.obs;

  bool _started = false;
  Worker? _authWorker;
  PayrollLiveSocket? _socket;
  StreamSubscription<Map<String, dynamic>>? _sub;
  Timer? _ping;
  Timer? _reconnect;
  Timer? _poll;
  int _attempt = 0;
  DateTime _lastTypingSent = DateTime.fromMillisecondsSinceEpoch(0);
  final Map<int, Timer> _typingTimers = {};
  final Map<String, Timer> _ackTimers = {};
  String _baseTitle = '';

  bool get isLive => connection.value == 'live';

  // ---------------------------------------------------------------------------------------
  // life cycle
  // ---------------------------------------------------------------------------------------

  @override
  void onInit() {
    super.onInit();
    final auth = Get.find<AuthController>();
    _authWorker = ever(auth.currentUser, (_) => _syncWithLogin());
    _syncWithLogin();
  }

  @override
  void onClose() {
    _authWorker?.dispose();
    stop();
    super.onClose();
  }

  void _syncWithLogin() {
    final signedIn = Get.find<AuthController>().currentUser.value != null;
    if (signedIn && !_started) {
      start();
    } else if (!signedIn && _started) {
      stop();
    }
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;
    if (_baseTitle.isEmpty) _baseTitle = html.document.title;
    await refreshThreads();
    if (_started) unawaited(_connect());
  }

  void stop() {
    _started = false;
    _closeSocket();
    _reconnect?.cancel();
    _poll?.cancel();
    _poll = null;
    for (final t in _typingTimers.values) {
      t.cancel();
    }
    _typingTimers.clear();
    for (final t in _ackTimers.values) {
      t.cancel();
    }
    _ackTimers.clear();
    threads.clear();
    messages.clear();
    online.clear();
    typing.clear();
    activeId.value = null;
    totalUnread.value = 0;
    connection.value = 'offline';
    _attempt = 0;
    _updateTitle();
  }

  String _msg(Object e) => e is ApiException ? e.message : e.toString();

  // ---------------------------------------------------------------------------------------
  // conversations and history (HTTP)
  // ---------------------------------------------------------------------------------------

  Future<void> refreshThreads() async {
    loadingThreads.value = true;
    try {
      final r = await _api.chatThreads();
      if (!_started) return;
      final list = (r['threads'] as List? ?? const []).map((t) => ChatThread.fromJson(Map<String, dynamic>.from(t as Map))).toList();
      // a conversation that is open but still has no message on the server stays in the list
      for (final stub in threads.where((t) => t.lastAt == null && !list.any((x) => x.employeeId == t.employeeId))) {
        list.insert(0, stub);
      }
      threads.assignAll(list);
      online.addAll((r['onlineEmployees'] as List? ?? const []).map((e) => (e as num).toInt()));
      _recount();
      error.value = null;
    } catch (e) {
      error.value = _msg(e);
    } finally {
      loadingThreads.value = false;
    }
  }

  ChatThread? _thread(int employeeId) => threads.firstWhereOrNull((t) => t.employeeId == employeeId);

  void _recount() {
    totalUnread.value = threads.fold<int>(0, (sum, t) => sum + t.unread);
    _updateTitle();
  }

  void _sortThreads() {
    threads.sort((a, b) => (b.lastAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(a.lastAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
    threads.refresh();
  }

  void _updateTitle() {
    if (_baseTitle.isEmpty) return;
    final n = totalUnread.value;
    html.document.title = n > 0 ? '($n) $_baseTitle' : _baseTitle;
  }

  /// Opens the conversation with [employeeId] and marks it as read.
  Future<void> openThread(int employeeId) async {
    activeId.value = employeeId;
    messages.clear();
    hasMore.value = false;
    employeeReadId.value = 0;
    loadingMessages.value = true;
    try {
      final r = await _api.chatMessages(employeeId, limit: 50);
      if (activeId.value != employeeId) return;
      messages.assignAll((r['messages'] as List? ?? const []).map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m as Map))));
      hasMore.value = r['hasMore'] == true;
      employeeReadId.value = ((r['employeeReadId'] as num?) ?? 0).toInt();
      error.value = null;
    } catch (e) {
      error.value = _msg(e);
    } finally {
      if (activeId.value == employeeId) loadingMessages.value = false;
    }
    await markRead();
  }

  /// Starts (or opens) a conversation with an employee who may have no messages yet.
  Future<void> startConversation({required int employeeId, required String name, required String number}) async {
    if (_thread(employeeId) == null) {
      threads.insert(0, ChatThread(employeeId: employeeId, employeeName: name, employeeNumber: number));
    }
    await openThread(employeeId);
  }

  void closeThread() {
    activeId.value = null;
    messages.clear();
  }

  Future<void> loadOlder() async {
    final id = activeId.value;
    if (id == null || loadingOlder.value || !hasMore.value) return;
    final first = messages.firstWhereOrNull((m) => m.id != null);
    if (first == null) return;
    loadingOlder.value = true;
    try {
      final r = await _api.chatMessages(id, beforeId: first.id, limit: 50);
      if (activeId.value != id) return;
      final older = (r['messages'] as List? ?? const []).map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m as Map))).toList();
      messages.insertAll(0, older);
      hasMore.value = r['hasMore'] == true;
    } catch (e) {
      error.value = _msg(e);
    } finally {
      loadingOlder.value = false;
    }
  }

  /// Employees to start a conversation with (by name or number).
  Future<List<Map<String, dynamic>>> findEmployees(String q) async {
    final list = await _api.chatFindEmployees(q);
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // ---------------------------------------------------------------------------------------
  // the live connection
  // ---------------------------------------------------------------------------------------

  Future<void> _connect() async {
    if (!_started || connection.value != 'offline') return;
    connection.value = 'connecting';
    try {
      final r = await _api.chatTicket();
      final socket = PayrollLiveSocket(_api.chatWebSocketUrl(r['ticket'] as String));
      _socket = socket;
      _sub = socket.events.listen(_onEvent);
      socket.connect();
    } catch (_) {
      connection.value = 'offline';
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_started) return;
    _reconnect?.cancel();
    const delays = [1, 2, 4, 8, 15, 30];
    final seconds = delays[_attempt < delays.length ? _attempt : delays.length - 1];
    _attempt++;
    _reconnect = Timer(Duration(seconds: seconds), _connect);
    // meanwhile the screen stays fresh over plain HTTP
    _poll ??= Timer.periodic(const Duration(seconds: 10), (_) {
      if (_started && !isLive) {
        refreshThreads();
        final id = activeId.value;
        if (id != null) _syncOpen(id);
      }
    });
  }

  void _closeSocket() {
    _ping?.cancel();
    _sub?.cancel();
    _sub = null;
    _socket?.dispose();
    _socket = null;
  }

  void _send(Map<String, dynamic> frame) => _socket?.send(jsonEncode(frame));

  /// Catches up the open conversation with whatever arrived while the line was down.
  Future<void> _syncOpen(int id) async {
    try {
      final r = await _api.chatMessages(id, limit: 50);
      if (activeId.value != id) return;
      final known = messages.where((m) => m.id != null).map((m) => m.id!).toSet();
      for (final raw in (r['messages'] as List? ?? const [])) {
        final m = ChatMessage.fromJson(Map<String, dynamic>.from(raw as Map));
        if (known.add(m.id!)) messages.add(m);
      }
      _sortMessages();
      employeeReadId.value = ((r['employeeReadId'] as num?) ?? employeeReadId.value).toInt();
    } catch (_) {}
  }

  void _sortMessages() {
    messages.sort((a, b) {
      if (a.id != null && b.id != null) return a.id!.compareTo(b.id!);
      if (a.id == null && b.id == null) return a.createdAt.compareTo(b.createdAt);
      return a.id == null ? 1 : -1;
    });
    messages.refresh();
  }

  void _onEvent(Map<String, dynamic> e) {
    switch (e['type']) {
      case '_closed':
        _ping?.cancel();
        _sub?.cancel();
        _sub = null;
        _socket?.dispose();
        _socket = null;
        connection.value = 'offline';
        typing.clear();
        _scheduleReconnect();
        break;
      case 'ready':
        connection.value = 'live';
        _attempt = 0;
        _poll?.cancel();
        _poll = null;
        online
          ..clear()
          ..addAll((e['onlineEmployees'] as List? ?? const []).map((x) => (x as num).toInt()));
        _ping?.cancel();
        _ping = Timer.periodic(const Duration(seconds: 25), (_) => _send({'type': 'ping'}));
        refreshThreads(); // whatever arrived while the line was down
        final id = activeId.value;
        if (id != null) _syncOpen(id);
        break;
      case 'presence':
        final id = (e['employeeId'] as num).toInt();
        if (e['online'] == true) {
          online.add(id);
        } else {
          online.remove(id);
          typing.remove(id);
        }
        break;
      case 'message':
        _onMessage(ChatMessage.fromJson(Map<String, dynamic>.from(e['message'] as Map)));
        break;
      case 'ack':
        {
          final local = messages.firstWhereOrNull((m) => m.localId != null && m.localId == e['clientId']);
          if (local != null) _confirm(local, ChatMessage.fromJson(Map<String, dynamic>.from(e['message'] as Map)));
          break;
        }
      case 'read':
        {
          final id = (e['employeeId'] as num).toInt();
          final upTo = ((e['upTo'] as num?) ?? 0).toInt();
          if (e['by'] == 'employee') {
            if (activeId.value == id && upTo > employeeReadId.value) employeeReadId.value = upTo;
          } else {
            // another staff screen has read it: clear the badge here too
            final t = _thread(id);
            if (t != null && t.unread != 0) {
              t.unread = 0;
              threads.refresh();
              _recount();
            }
          }
          break;
        }
      case 'typing':
        {
          if (e['from'] != 'employee') break;
          final id = (e['employeeId'] as num).toInt();
          typing.add(id);
          _typingTimers[id]?.cancel();
          _typingTimers[id] = Timer(const Duration(seconds: 4), () => typing.remove(id));
          break;
        }
      case 'error':
        {
          final local = messages.firstWhereOrNull((m) => m.localId != null && m.localId == e['clientId']);
          if (local != null) {
            _ackTimers.remove(local.localId)?.cancel();
            local.state = ChatSendState.failed;
            messages.refresh();
          }
          trSnack('Ujumbe haukutumwa', (e['detail'] as String?) ?? 'Hitilafu isiyojulikana.');
          break;
        }
    }
  }

  void _onMessage(ChatMessage m) {
    var thread = _thread(m.employeeId);
    if (thread == null) {
      // a conversation we do not know yet: add a placeholder now, fill the name from the server
      thread = ChatThread(employeeId: m.employeeId, employeeName: m.fromEmployee ? m.senderName : '', employeeNumber: '');
      threads.insert(0, thread);
      refreshThreads();
    }
    thread
      ..lastText = m.text
      ..lastFromEmployee = m.fromEmployee
      ..lastAt = m.createdAt;

    final isOpenNow = activeId.value == m.employeeId;
    if (isOpenNow && !messages.any((x) => x.id == m.id)) {
      messages.add(m);
      _sortMessages();
    }
    if (m.fromEmployee) {
      typing.remove(m.employeeId);
      if (isOpenNow && screenOpen.value) {
        markRead();
      } else {
        thread.unread++;
        trSnack('Ujumbe mpya', '${thread.employeeName.isEmpty ? m.senderName : thread.employeeName}: ${m.text}');
      }
    }
    _sortThreads();
    _recount();
  }

  // ---------------------------------------------------------------------------------------
  // sending, typing, reading
  // ---------------------------------------------------------------------------------------

  Future<void> send(String raw) async {
    final id = activeId.value;
    final text = raw.trim();
    if (id == null || text.isEmpty) return;
    final local = ChatMessage(
      employeeId: id,
      fromEmployee: false,
      senderName: Get.find<AuthController>().currentUser.value?.name ?? '',
      text: text,
      createdAt: DateTime.now(),
      localId: DateTime.now().microsecondsSinceEpoch.toString(),
      state: ChatSendState.sending,
    );
    messages.add(local);
    final thread = _thread(id);
    if (thread != null) {
      thread
        ..lastText = text
        ..lastFromEmployee = false
        ..lastAt = local.createdAt;
      _sortThreads();
    }
    await _transmit(local);
  }

  Future<void> _transmit(ChatMessage m) async {
    m.state = ChatSendState.sending;
    messages.refresh();
    if (isLive) {
      _send({'type': 'message', 'employeeId': m.employeeId, 'text': m.text, 'clientId': m.localId});
      // no answer in 10 s: when the line has dropped meanwhile, send it the plain way
      _ackTimers[m.localId!] = Timer(const Duration(seconds: 10), () {
        if (m.state != ChatSendState.sending) return;
        if (!isLive) {
          _viaHttp(m);
        } else {
          m.state = ChatSendState.failed;
          messages.refresh();
        }
      });
    } else {
      await _viaHttp(m);
    }
  }

  Future<void> _viaHttp(ChatMessage m) async {
    if (m.state == ChatSendState.sent) return;
    try {
      final r = await _api.chatSend(m.employeeId, m.text);
      _confirm(m, ChatMessage.fromJson(Map<String, dynamic>.from(r['message'] as Map)));
    } catch (e) {
      m.state = ChatSendState.failed;
      messages.refresh();
      trSnack('Ujumbe haukutumwa', _msg(e));
    }
  }

  void _confirm(ChatMessage local, ChatMessage server) {
    _ackTimers.remove(local.localId)?.cancel();
    local.id = server.id;
    local.createdAt = server.createdAt;
    local.senderName = server.senderName;
    local.state = ChatSendState.sent;
    messages.removeWhere((x) => !identical(x, local) && x.id != null && x.id == local.id);
    _sortMessages();
  }

  Future<void> retry(ChatMessage m) async {
    if (m.state == ChatSendState.failed) await _transmit(m);
  }

  void discard(ChatMessage m) {
    if (m.id != null) return;
    _ackTimers.remove(m.localId)?.cancel();
    messages.remove(m);
  }

  /// "Is typing..." for the employee (at most every 2.5 s while the accountant types).
  void notifyTyping() {
    final id = activeId.value;
    if (id == null || !isLive) return;
    final now = DateTime.now();
    if (now.difference(_lastTypingSent) < const Duration(milliseconds: 2500)) return;
    _lastTypingSent = now;
    _send({'type': 'typing', 'employeeId': id});
  }

  /// Everything in the open conversation has been seen (clears its badge here and on the other
  /// staff screens, and lets the employee see the "seen" ticks).
  Future<void> markRead() async {
    final id = activeId.value;
    if (id == null) return;
    final thread = _thread(id);
    final hadUnread = (thread?.unread ?? 0) > 0;
    if (thread != null && thread.unread != 0) {
      thread.unread = 0;
      threads.refresh();
      _recount();
    }
    if (!hadUnread) return;
    if (isLive) {
      _send({'type': 'read', 'employeeId': id});
    } else {
      try {
        await _api.chatMarkRead(id);
      } catch (_) {}
    }
  }
}
