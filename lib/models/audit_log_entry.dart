/// Plain immutable model (no code generation required).
/// category: 'Security' | 'User Management' | 'Payroll Settings' | 'Employee Management' | 'Reports' | 'System'
class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.timestamp,
    required this.userName,
    required this.userRole,
    required this.action,
    required this.details,
    required this.category,
    this.ipAddress,
    this.endpoint,
    this.method,
    this.statusCode,
    this.durationMs,
    this.backendId,
  });

  final String id;
  final String timestamp;
  final String userName;
  final String userRole;
  final String action;
  final String details;
  final String category;
  final String? ipAddress;

  /// The following four are populated automatically by the backend's
  /// request-auditing middleware (`tughe/auditMiddleware.py`) - every API
  /// call, not just the explicit UI-triggered ones.
  final String? endpoint;
  final String? method;
  final int? statusCode;
  final int? durationMs;

  /// Real numeric primary key from the backend (`tughe/auditTail/model.py`).
  final int? backendId;

  bool get isSuccess => statusCode == null || (statusCode! >= 200 && statusCode! < 400);

  AuditLogEntry copyWith({
    String? id,
    String? timestamp,
    String? userName,
    String? userRole,
    String? action,
    String? details,
    String? category,
    String? ipAddress,
    String? endpoint,
    String? method,
    int? statusCode,
    int? durationMs,
    int? backendId,
  }) {
    return AuditLogEntry(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      userName: userName ?? this.userName,
      userRole: userRole ?? this.userRole,
      action: action ?? this.action,
      details: details ?? this.details,
      category: category ?? this.category,
      ipAddress: ipAddress ?? this.ipAddress,
      endpoint: endpoint ?? this.endpoint,
      method: method ?? this.method,
      statusCode: statusCode ?? this.statusCode,
      durationMs: durationMs ?? this.durationMs,
      backendId: backendId ?? this.backendId,
    );
  }

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) => AuditLogEntry(
        id: json['id'] as String,
        timestamp: json['timestamp'] as String? ?? '',
        userName: json['userName'] as String? ?? '',
        userRole: json['userRole'] as String? ?? '',
        action: json['action'] as String? ?? '',
        details: json['details'] as String? ?? '',
        category: json['category'] as String? ?? '',
        ipAddress: json['ipAddress'] as String?,
        endpoint: json['endpoint'] as String?,
        method: json['method'] as String?,
        statusCode: (json['statusCode'] as num?)?.toInt(),
        durationMs: (json['durationMs'] as num?)?.toInt(),
        backendId: (json['backendId'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp,
        'userName': userName,
        'userRole': userRole,
        'action': action,
        'details': details,
        'category': category,
        'ipAddress': ipAddress,
        'endpoint': endpoint,
        'method': method,
        'statusCode': statusCode,
        'durationMs': durationMs,
        'backendId': backendId,
      };

  /// Maps the backend's `AuditTail` JSON onto this model. Every API call is
  /// now recorded automatically (see `tughe/auditMiddleware.py`), which
  /// also stamps `username`/`ipAddress`/`endpoint`/`method`/`statusCode`/
  /// `durationMs` directly - no client-side user lookup needed anymore.
  factory AuditLogEntry.fromBackendJson(Map<String, dynamic> json, {String userName = '', String userRole = ''}) {
    final backendUsername = json['username'] as String?;
    final tableName = json['tableName'] as String? ?? '';
    final endpoint = json['endpoint'] as String?;
    final method = json['method'] as String?;
    final statusCode = (json['statusCode'] as num?)?.toInt();
    return AuditLogEntry(
      id: 'AUD-${json['id']}',
      backendId: (json['id'] as num?)?.toInt(),
      timestamp: (json['created_at'] as String?)?.replaceFirst('T', ' ').split('.').first ?? '',
      userName: (backendUsername != null && backendUsername.isNotEmpty)
          ? backendUsername
          : (userName.isEmpty ? 'Haijulikani (Mtumiaji #${json['user_id'] ?? '-'})' : userName),
      userRole: userRole,
      action: json['actionType'] as String? ?? '',
      details: endpoint != null && method != null
          ? '$method $endpoint${statusCode != null ? ' → $statusCode' : ''}'
          : '$tableName: ${json['newData'] ?? ''}',
      category: _categoryForTable(tableName),
      ipAddress: json['ipAddress'] as String?,
      endpoint: endpoint,
      method: method,
      statusCode: statusCode,
      durationMs: (json['durationMs'] as num?)?.toInt(),
    );
  }
}

String _categoryForTable(String tableName) {
  switch (tableName.toUpperCase()) {
    case 'LOGIN':
    case 'USER':
    case 'PERMISSION':
      return 'Security';
    case 'EMPLOYEE':
    case 'EMP_ARREARS':
    case 'EMP_ALLOWANCES':
      return 'Employee Management';
    case 'ARREARS':
    case 'ALLOWANCES':
    case 'SALARY_TERMS':
    case 'PAYROLLS':
      return 'Payroll Settings';
    case 'REPORTS':
      return 'Reports';
    case 'AUDIT_TAILS':
      return 'System';
    default:
      return 'User Management';
  }
}
