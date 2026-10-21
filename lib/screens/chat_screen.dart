import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../controllers/chat_controller.dart';
import '../core/theme.dart';
import '../core/tr_text.dart';
import '../core/translations.dart';
import '../models/chat_models.dart';

/// "Mazungumzo (Chat)": live conversations with the employees. Left: the conversations; right:
/// the open one. On a narrow window one of the two is shown at a time.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatController _chat = Get.find<ChatController>();
  final _search = TextEditingController();
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();

  static const _maxChars = 2000;

  @override
  void initState() {
    super.initState();
    _chat.screenOpen.value = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chat.activeId.value != null) _chat.markRead();
    });
    // the list is reversed (newest at the bottom): its far end is the OLDEST message
    _scroll.addListener(() {
      if (_scroll.hasClients && _scroll.position.pixels >= _scroll.position.maxScrollExtent - 240) _chat.loadOlder();
    });
  }

  @override
  void dispose() {
    _chat.screenOpen.value = false;
    _search.dispose();
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _open(int employeeId) async {
    _input.clear();
    await _chat.openThread(employeeId);
    if (mounted) _focus.requestFocus();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _chat.send(text);
    _input.clear();
    setState(() {});
    if (_scroll.hasClients) _scroll.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final height = c.maxHeight.isFinite ? c.maxHeight : MediaQuery.of(context).size.height * 0.8;
      final wide = c.maxWidth >= 820;
      return SizedBox(
        height: height,
        child: Obx(() {
          final hasActive = _chat.activeId.value != null;
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 340, child: _listPane()),
                const SizedBox(width: 14),
                Expanded(child: _conversationPane(showBack: false)),
              ],
            );
          }
          return hasActive ? _conversationPane(showBack: true) : _listPane();
        }),
      );
    });
  }

  BoxDecoration get _card => BoxDecoration(color: Pal.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: Pal.border));

  // ---------------------------------------------------------------------------------------
  // left: the conversations
  // ---------------------------------------------------------------------------------------

  Widget _listPane() {
    final live = _chat.connection.value;
    final dotColor = live == 'live' ? Pal.success : (live == 'connecting' ? AppColors.gold : Pal.danger);
    final status = live == 'live'
        ? 'Moja kwa moja'
        : (live == 'connecting' ? 'Inaunganisha...' : 'Hakuna muunganisho wa moja kwa moja');
    final q = _search.text.trim().toLowerCase();
    final onlineNow = _chat.online.toSet(); // read here so the list redraws when somebody comes or leaves
    final activeNow = _chat.activeId.value;
    final all = _chat.threads.toList();
    final shown = q.isEmpty
        ? all
        : all.where((t) => t.employeeName.toLowerCase().contains(q) || t.employeeNumber.toLowerCase().contains(q)).toList();

    return Container(
      decoration: _card,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Mazungumzo (Chat)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Pal.brandText))),
                    if (_chat.totalUnread.value > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(10)),
                        child: Text('${_chat.totalUnread.value}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.slate900)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(status, style: TextStyle(fontSize: 10.5, color: Pal.textMuted))),
                ]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 18),
                hintText: tr('Tafuta mfanyakazi au namba...'),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: OutlinedButton.icon(
              onPressed: _newChatDialog,
              icon: const Icon(Icons.add_comment_outlined, size: 17),
              label: const Text('Mazungumzo Mapya'),
            ),
          ),
          Divider(height: 1, color: Pal.border),
          Expanded(
            child: _chat.loadingThreads.value && all.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : shown.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.forum_outlined, size: 40, color: Pal.textMuted),
                              const SizedBox(height: 10),
                              Text(
                                _chat.error.value ?? (q.isEmpty ? 'Hakuna mazungumzo bado. Mfanyakazi akikuandikia, ujumbe wake utaonekana hapa.' : 'Hakuna mfanyakazi anayelingana.'),
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, height: 1.35, color: Pal.textMuted),
                              ),
                              if (_chat.error.value != null) TextButton(onPressed: _chat.refreshThreads, child: const Text('Jaribu Tena')),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: shown.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: Pal.border),
                        itemBuilder: (_, i) => _threadTile(shown[i], onlineNow, activeNow),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _threadTile(ChatThread t, Set<int> onlineNow, int? activeNow) {
    final active = activeNow == t.employeeId;
    final isOnline = onlineNow.contains(t.employeeId);
    final unread = t.unread > 0;
    return Material(
      color: active ? Pal.tint(Colors.blue) : Colors.transparent,
      child: InkWell(
        onTap: () => _open(t.employeeId),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: AppColors.brandBlue,
                    child: Text(t.initials, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  if (isOnline)
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(color: Pal.success, shape: BoxShape.circle, border: Border.all(color: Pal.surface, width: 2)),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(t.employeeName.isEmpty ? '...' : t.employeeName,
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: unread ? FontWeight.w800 : FontWeight.w600)),
                        ),
                        if (t.lastAt != null) Text(_shortTime(t.lastAt!), style: TextStyle(fontSize: 10, color: unread ? Pal.primary : Pal.textMuted, fontWeight: unread ? FontWeight.bold : FontWeight.normal)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.lastText.isEmpty ? t.employeeNumber : '${t.lastFromEmployee ? '' : '${tr('Wewe')}: '}${t.lastText}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11.5, color: unread ? Pal.text : Pal.textMuted, fontWeight: unread ? FontWeight.w600 : FontWeight.normal),
                          ),
                        ),
                        if (unread)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(10)),
                            child: Text('${t.unread}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: AppColors.slate900)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------------------
  // right: the open conversation
  // ---------------------------------------------------------------------------------------

  Widget _conversationPane({required bool showBack}) {
    final id = _chat.activeId.value;
    if (id == null) {
      return Container(
        decoration: _card,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat_bubble_outline_rounded, size: 54, color: Pal.textMuted),
                const SizedBox(height: 12),
                Text('Chagua mazungumzo upande wa kushoto', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Pal.text)),
                const SizedBox(height: 6),
                Text('au bonyeza "Mazungumzo Mapya" kumwandikia mfanyakazi.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Pal.textMuted)),
              ],
            ),
          ),
        ),
      );
    }

    final thread = _chat.threads.firstWhereOrNull((t) => t.employeeId == id);
    final name = thread?.employeeName ?? '';
    final isOnline = _chat.online.contains(id);
    final isTyping = _chat.typing.contains(id);
    final readUpTo = _chat.employeeReadId.value;

    // newest first, with a day heading above the first message of each day
    final msgs = _chat.messages.toList();
    final rows = <Widget>[];
    for (var i = msgs.length - 1; i >= 0; i--) {
      final m = msgs[i];
      rows.add(_bubble(m, read: !m.fromEmployee && m.id != null && m.id! <= readUpTo));
      final day = DateTime(m.createdAt.year, m.createdAt.month, m.createdAt.day);
      final prev = i > 0 ? msgs[i - 1].createdAt : null;
      final prevDay = prev == null ? null : DateTime(prev.year, prev.month, prev.day);
      if (prevDay == null || prevDay != day) rows.add(_dayHeading(day));
    }
    if (isTyping) rows.insert(0, _typingRow(name));
    if (_chat.loadingOlder.value) {
      rows.add(const Padding(padding: EdgeInsets.all(12), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))));
    }

    return Container(
      decoration: _card,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // header
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Pal.border))),
            child: Row(
              children: [
                if (showBack)
                  IconButton(tooltip: tr('Rudi'), icon: const Icon(Icons.arrow_back), onPressed: _chat.closeThread),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.brandBlue,
                  child: Text(thread?.initials ?? '?', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name.isEmpty ? '...' : name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                      Row(children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: isOnline ? Pal.success : Pal.textMuted, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isTyping
                                ? 'anaandika...'
                                : (isOnline ? 'Yuko mtandaoni' : 'Hayuko mtandaoni - ataona ujumbe atakaporudi'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: isTyping ? Pal.primary : Pal.textMuted, fontWeight: isTyping ? FontWeight.w700 : FontWeight.normal),
                          ),
                        ),
                        if (thread?.employeeNumber.isNotEmpty ?? false)
                          Text('  ${thread!.employeeNumber}', style: TextStyle(fontSize: 10.5, color: Pal.textMuted)),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // messages
          Expanded(
            child: Container(
              color: Pal.surfaceAlt.withOpacity(Pal.dark ? 0.35 : 0.6),
              child: _chat.loadingMessages.value
                  ? const Center(child: CircularProgressIndicator())
                  : msgs.isEmpty
                      ? Center(
                          child: Text('Hakuna ujumbe bado. Andika ujumbe wa kwanza hapa chini.',
                              textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: Pal.textMuted)))
                      : ListView.builder(
                          controller: _scroll,
                          reverse: true,
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                          itemCount: rows.length,
                          itemBuilder: (_, i) => rows[i],
                        ),
            ),
          ),
          // composer
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: Pal.border))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Focus(
                    onKeyEvent: (node, event) {
                      // Enter sends; Shift+Enter starts a new line
                      if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter && !HardwareKeyboard.instance.isShiftPressed) {
                        _send();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TextField(
                      controller: _input,
                      focusNode: _focus,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: _maxChars,
                      onChanged: (_) {
                        setState(() {});
                        _chat.notifyTyping();
                      },
                      style: const TextStyle(fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: tr('Andika ujumbe... (Enter = tuma, Shift+Enter = mstari mpya)'),
                        counterText: _input.text.length > _maxChars - 200 ? '${_input.text.length}/$_maxChars' : '',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: EdgeInsets.only(bottom: _input.text.length > _maxChars - 200 ? 20 : 2),
                  child: ElevatedButton.icon(
                    onPressed: _input.text.trim().isEmpty ? null : _send,
                    icon: const Icon(Icons.send_rounded, size: 17),
                    label: const Text('Tuma'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayHeading(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    final label = diff == 0
        ? tr('Leo')
        : diff == 1
            ? tr('Jana')
            : '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}/${day.year}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          decoration: BoxDecoration(color: Pal.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: Pal.border)),
          child: Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Pal.textMuted)),
        ),
      ),
    );
  }

  Widget _typingRow(String name) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(color: Pal.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: Pal.border)),
            child: Text('${name.isEmpty ? '' : '$name '}${tr('anaandika...')}', style: TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: Pal.textMuted)),
          ),
        ),
      );

  Widget _bubble(ChatMessage m, {required bool read}) {
    final mine = !m.fromEmployee; // sent from the staff side (by me or by another accountant)
    final failed = m.state == ChatSendState.failed;
    final bg = mine ? Pal.primary : Pal.surface;
    final fg = mine ? Pal.onPrimary : Pal.text;
    final sub = mine ? Pal.onPrimary.withOpacity(0.72) : Pal.textMuted;

    Widget status() {
      if (!mine) return const SizedBox.shrink();
      if (failed) return Icon(Icons.error_outline, size: 14, color: Pal.dark ? const Color(0xFFB91C1C) : const Color(0xFFFECACA));
      if (m.state == ChatSendState.sending) return Icon(Icons.schedule, size: 13, color: sub);
      return Icon(read ? Icons.done_all : Icons.done, size: 15, color: read ? AppColors.gold : sub);
    }

    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.fromLTRB(13, 9, 13, 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(14),
          topRight: const Radius.circular(14),
          bottomLeft: Radius.circular(mine ? 14 : 3),
          bottomRight: Radius.circular(mine ? 3 : 14),
        ),
        border: mine ? null : Border.all(color: Pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (mine && m.senderName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(m.senderName, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Pal.dark ? const Color(0xFF1E3A8A) : const Color(0xFFFCD34D))),
            ),
          SelectableText(m.text, style: TextStyle(fontSize: 13.5, height: 1.35, color: fg)),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (failed)
                Text(tr('Haijatumwa - bonyeza'), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Pal.dark ? const Color(0xFFB91C1C) : const Color(0xFFFECACA)))
              else
                Text(_clock(m.createdAt), style: TextStyle(fontSize: 10, color: sub)),
              const SizedBox(width: 4),
              status(),
            ],
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: failed
            ? PopupMenuButton<String>(
                tooltip: '',
                onSelected: (v) => v == 'retry' ? _chat.retry(m) : _chat.discard(m),
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'retry', child: Text('Tuma tena')),
                  PopupMenuItem(value: 'discard', child: Text('Futa ujumbe huu')),
                ],
                child: bubble,
              )
            : bubble,
      ),
    );
  }

  // ---------------------------------------------------------------------------------------
  // start a conversation with any employee
  // ---------------------------------------------------------------------------------------

  Future<void> _newChatDialog() async {
    final ctrl = TextEditingController();
    Timer? debounce;
    var results = <Map<String, dynamic>>[];
    var loading = false;
    var closed = false; // the dialog is gone: a late answer must not touch it
    var firstLoadDone = false;
    String? failure;

    Future<void> search(StateSetter set, String q) async {
      if (closed) return;
      set(() => loading = true);
      try {
        final found = await _chat.findEmployees(q);
        if (closed) return;
        set(() {
          results = found;
          failure = null;
        });
      } catch (e) {
        if (!closed) set(() => failure = e.toString());
      } finally {
        if (!closed) set(() => loading = false);
      }
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, set) {
        if (!firstLoadDone) {
          firstLoadDone = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => search(set, ''));
        }
        return AlertDialog(
          title: const Text('Mazungumzo Mapya'),
          content: SizedBox(
            width: 420,
            height: 420,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  decoration: InputDecoration(isDense: true, prefixIcon: const Icon(Icons.search, size: 18), hintText: tr('Tafuta mfanyakazi kwa jina au namba...')),
                  onChanged: (v) {
                    debounce?.cancel();
                    debounce = Timer(const Duration(milliseconds: 300), () => search(set, v));
                  },
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: loading && results.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : failure != null
                          ? Center(child: Text(failure!, style: TextStyle(color: Pal.danger)))
                          : results.isEmpty
                              ? Center(child: Text('Hakuna mfanyakazi anayelingana.', style: TextStyle(color: Pal.textMuted)))
                              : ListView.separated(
                                  itemCount: results.length,
                                  separatorBuilder: (_, __) => Divider(height: 1, color: Pal.border),
                                  itemBuilder: (_, i) {
                                    final e = results[i];
                                    final name = (e['employeeName'] as String?) ?? '';
                                    return ListTile(
                                      dense: true,
                                      leading: CircleAvatar(radius: 16, backgroundColor: AppColors.brandBlue, child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12))),
                                      title: Text(name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                                      subtitle: Text((e['employeeNumber'] as String?) ?? '', style: const TextStyle(fontSize: 11)),
                                      onTap: () {
                                        Navigator.of(dialogContext).pop();
                                        _input.clear();
                                        _chat.startConversation(employeeId: (e['employeeId'] as num).toInt(), name: name, number: (e['employeeNumber'] as String?) ?? '');
                                        _focus.requestFocus();
                                      },
                                    );
                                  },
                                ),
                ),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Funga'))],
        );
      }),
    );
    closed = true;
    debounce?.cancel();
    // (the controller is not disposed here: the dialog is still fading out and its field still uses it)
  }

  String _clock(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// Today: the time; earlier: the date.
  String _shortTime(DateTime t) {
    final now = DateTime.now();
    final sameDay = t.year == now.year && t.month == now.month && t.day == now.day;
    return sameDay ? _clock(t) : '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}';
  }
}
