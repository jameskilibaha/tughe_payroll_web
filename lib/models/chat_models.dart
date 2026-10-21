enum ChatSendState { sending, sent, failed }

/// One message of a conversation between an employee and the staff.
class ChatMessage {
  ChatMessage({
    this.id,
    required this.employeeId,
    required this.fromEmployee,
    required this.senderName,
    required this.text,
    required this.createdAt,
    this.localId,
    this.state = ChatSendState.sent,
  });

  /// The server's number - null while the message is only on this screen (being sent).
  int? id;
  final int employeeId;
  final bool fromEmployee;
  String senderName;
  final String text;
  DateTime createdAt;
  final String? localId;
  ChatSendState state;

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: (j['id'] as num).toInt(),
        employeeId: (j['employeeId'] as num).toInt(),
        fromEmployee: j['senderRole'] == 'EMPLOYEE',
        senderName: (j['senderName'] as String?) ?? '',
        text: (j['text'] as String?) ?? '',
        createdAt: DateTime.tryParse((j['createdAt'] as String?) ?? '')?.toLocal() ?? DateTime.now(),
      );
}

/// One conversation in the list on the left: an employee with the latest message.
class ChatThread {
  ChatThread({
    required this.employeeId,
    required this.employeeName,
    required this.employeeNumber,
    this.isBlocked = false,
    this.unread = 0,
    this.lastText = '',
    this.lastFromEmployee = true,
    this.lastAt,
    this.online = false,
  });

  final int employeeId;
  String employeeName;
  String employeeNumber;
  bool isBlocked;
  int unread;
  String lastText;
  bool lastFromEmployee;
  DateTime? lastAt;
  bool online;

  String get initials {
    final parts = employeeName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  factory ChatThread.fromJson(Map<String, dynamic> j) {
    final last = j['lastMessage'] is Map ? Map<String, dynamic>.from(j['lastMessage'] as Map) : null;
    return ChatThread(
      employeeId: (j['employeeId'] as num).toInt(),
      employeeName: (j['employeeName'] as String?) ?? '',
      employeeNumber: (j['employeeNumber'] as String?) ?? '',
      isBlocked: j['isBlocked'] == true,
      unread: ((j['unread'] as num?) ?? 0).toInt(),
      lastText: (last?['text'] as String?) ?? '',
      lastFromEmployee: last?['senderRole'] != 'STAFF',
      lastAt: DateTime.tryParse((j['lastMessageAt'] as String?) ?? '')?.toLocal(),
      online: j['online'] == true,
    );
  }
}
