/// Plain immutable model (no code generation required).
/// role: 'Admin' | 'Accountant' | 'User'
/// status: 'Active' | 'Blocked'
class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.designation,
    required this.avatarInitials,
    required this.status,
    this.password,
    this.permissions,
    this.lastLogin,
    this.backendId,
    this.username,
    this.firstName,
    this.lastName,
    this.phoneNumber,
    this.photoFileName,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final String designation;
  final String avatarInitials;
  final String status;
  final String? password;
  final List<String>? permissions;
  final String? lastLogin;

  /// Real numeric primary key from the backend (`tughe/user/models.py`).
  /// Null for users that only exist locally / haven't been synced yet.
  final int? backendId;

  /// The following four mirror the backend's actual User fields
  /// (firstName/lastName/phoneNumber/username) which don't exist on the
  /// original mock model. They are optional so nothing about the existing
  /// UI (which reads name/email/role/etc.) has to change.
  final String? username;
  final String? firstName;
  final String? lastName;
  final String? phoneNumber;

  /// Filename of the user's profile picture on disk (see
  /// tughe/fileStorage.py) - fetch its bytes via
  /// ApiService.fetchUserPhotoBytes(photoFileName).
  final String? photoFileName;

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    String? designation,
    String? avatarInitials,
    String? status,
    String? password,
    List<String>? permissions,
    String? lastLogin,
    int? backendId,
    String? username,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? photoFileName,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      designation: designation ?? this.designation,
      avatarInitials: avatarInitials ?? this.avatarInitials,
      status: status ?? this.status,
      password: password ?? this.password,
      permissions: permissions ?? this.permissions,
      lastLogin: lastLogin ?? this.lastLogin,
      backendId: backendId ?? this.backendId,
      username: username ?? this.username,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoFileName: photoFileName ?? this.photoFileName,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        role: json['role'] as String? ?? '',
        designation: json['designation'] as String? ?? '',
        avatarInitials: json['avatarInitials'] as String? ?? '',
        status: json['status'] as String? ?? 'Active',
        password: json['password'] as String?,
        permissions: (json['permissions'] as List<dynamic>?)?.map((e) => e as String).toList(),
        lastLogin: json['lastLogin'] as String?,
        backendId: (json['backendId'] as num?)?.toInt(),
        username: json['username'] as String?,
        firstName: json['firstName'] as String?,
        lastName: json['lastName'] as String?,
        phoneNumber: json['phoneNumber'] as String?,
        photoFileName: json['photoFileName'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'designation': designation,
        'avatarInitials': avatarInitials,
        'status': status,
        'password': password,
        'permissions': permissions,
        'lastLogin': lastLogin,
        'backendId': backendId,
        'username': username,
        'firstName': firstName,
        'lastName': lastName,
        'phoneNumber': phoneNumber,
        'photoFileName': photoFileName,
      };

  /// Maps the backend's `AuthUser`/`DisplayUser` JSON shape
  /// (firstName/lastName/phoneNumber/username/active/isBlocked) onto this
  /// model, preserving any locally-only cosmetic fields (email, role,
  /// designation, avatarInitials, permissions) passed in [previous].
  factory User.fromBackendJson(Map<String, dynamic> json, {User? previous}) {
    final firstName = json['firstName'] as String? ?? previous?.firstName ?? '';
    final lastName = json['lastName'] as String? ?? previous?.lastName ?? '';
    final id = json['id'];
    final active = json['active'];
    final isBlocked = json['isBlocked'] == true || active == 1;
    final fullName = '$firstName $lastName'.trim();
    final initials = fullName.isEmpty
        ? '?'
        : fullName.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).map((s) => s[0]).take(2).join().toUpperCase();
    return User(
      id: 'USR-$id',
      name: fullName.isEmpty ? (previous?.name ?? '') : fullName,
      email: previous?.email ?? '',
      // The server decides the role from the user's permissions.
      // Empty = the server did not say (an older server): the screens then do not hide anything,
      // the server itself still enforces every permission.
      role: (json['role'] as String?) ?? previous?.role ?? '',
      designation: previous?.designation ?? '',
      avatarInitials: previous?.avatarInitials ?? initials,
      status: isBlocked ? 'Blocked' : 'Active',
      permissions: previous?.permissions,
      lastLogin: previous?.lastLogin,
      backendId: (id as num?)?.toInt(),
      username: json['username'] as String? ?? previous?.username,
      firstName: firstName,
      lastName: lastName,
      phoneNumber: json['phoneNumber'] as String? ?? previous?.phoneNumber,
      photoFileName: json['photoFileName'] as String? ?? previous?.photoFileName,
    );
  }
}
