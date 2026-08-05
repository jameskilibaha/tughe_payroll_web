import 'salary_status.dart';
import 'assigned_arrear.dart';
import 'assigned_allowance.dart';

/// Plain immutable model (no code generation required).
/// Gender: 'Male' | 'Female'
/// MaritalStatus: 'Single' | 'Married' | 'Divorced' | 'Widowed'
/// EmployeeStatus: 'Active' | 'Blocked'
class Employee {
  const Employee({
    required this.id,
    required this.employeeIdNumber,
    required this.firstName,
    required this.middleName,
    required this.lastName,
    required this.gender,
    required this.maritalStatus,
    required this.nationality,
    required this.residentialDistrict,
    required this.mobileNumber,
    required this.email,
    required this.dateOfBirth,
    required this.dateOfEmployment,
    required this.status,
    this.salaryStatus,
    this.arrearsList,
    this.allowancesList,
    this.backendId,
    this.photoFileName,
  });

  final String id; // e.g. TGH-001 (display/local-lookup key)

  /// The backend's actual `employeeIdNumber` column
  /// (`tughe/employee/model.py`). Kept as its own explicit field - never
  /// mix this (a business ID string) up with [backendId] (the numeric
  /// database primary key) when calling the API.
  final String employeeIdNumber;

  final String firstName;
  final String middleName;
  final String lastName;
  final String gender;
  final String maritalStatus;
  final String nationality;
  final String residentialDistrict;
  final String mobileNumber;
  final String email;
  final String dateOfBirth; // YYYY-MM-DD
  final String dateOfEmployment; // YYYY-MM-DD
  final String status;

  final SalaryStatus? salaryStatus;
  final List<AssignedArrear>? arrearsList;
  final List<AssignedAllowance>? allowancesList;

  /// Real numeric primary key from the backend (`tughe/employee/model.py`).
  /// Null until the employee has been synced to/from the server (e.g. a
  /// record only just created locally and not yet confirmed by the API).
  final int? backendId;

  /// Filename of the employee's profile picture on disk (see
  /// tughe/fileStorage.py) - fetch its bytes via
  /// ApiService.fetchEmployeePhotoBytes(photoFileName).
  final String? photoFileName;

  String get fullName =>
      '$firstName $middleName $lastName'.replaceAll(RegExp(r'\s+'), ' ').trim();

  Employee copyWith({
    String? id,
    String? employeeIdNumber,
    String? firstName,
    String? middleName,
    String? lastName,
    String? gender,
    String? maritalStatus,
    String? nationality,
    String? residentialDistrict,
    String? mobileNumber,
    String? email,
    String? dateOfBirth,
    String? dateOfEmployment,
    String? status,
    SalaryStatus? salaryStatus,
    List<AssignedArrear>? arrearsList,
    List<AssignedAllowance>? allowancesList,
    int? backendId,
    String? photoFileName,
  }) {
    return Employee(
      id: id ?? this.id,
      employeeIdNumber: employeeIdNumber ?? this.employeeIdNumber,
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      lastName: lastName ?? this.lastName,
      gender: gender ?? this.gender,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      nationality: nationality ?? this.nationality,
      residentialDistrict: residentialDistrict ?? this.residentialDistrict,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      email: email ?? this.email,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      dateOfEmployment: dateOfEmployment ?? this.dateOfEmployment,
      status: status ?? this.status,
      salaryStatus: salaryStatus ?? this.salaryStatus,
      arrearsList: arrearsList ?? this.arrearsList,
      allowancesList: allowancesList ?? this.allowancesList,
      backendId: backendId ?? this.backendId,
      photoFileName: photoFileName ?? this.photoFileName,
    );
  }

  factory Employee.fromJson(Map<String, dynamic> json) => Employee(
        id: json['id'] as String,
        employeeIdNumber: json['employeeIdNumber'] as String? ?? json['id'] as String,
        firstName: json['firstName'] as String? ?? '',
        middleName: json['middleName'] as String? ?? '',
        lastName: json['lastName'] as String? ?? '',
        gender: json['gender'] as String? ?? 'Male',
        maritalStatus: json['maritalStatus'] as String? ?? 'Single',
        nationality: json['nationality'] as String? ?? '',
        residentialDistrict: json['residentialDistrict'] as String? ?? '',
        mobileNumber: json['mobileNumber'] as String? ?? '',
        email: json['email'] as String? ?? '',
        dateOfBirth: json['dateOfBirth'] as String? ?? '',
        dateOfEmployment: json['dateOfEmployment'] as String? ?? '',
        status: json['status'] as String? ?? 'Active',
        salaryStatus: json['salaryStatus'] != null
            ? SalaryStatus.fromJson(json['salaryStatus'] as Map<String, dynamic>)
            : null,
        arrearsList: (json['arrearsList'] as List<dynamic>?)
            ?.map((e) => AssignedArrear.fromJson(e as Map<String, dynamic>))
            .toList(),
        allowancesList: (json['allowancesList'] as List<dynamic>?)
            ?.map((e) => AssignedAllowance.fromJson(e as Map<String, dynamic>))
            .toList(),
        backendId: (json['backendId'] as num?)?.toInt(),
        photoFileName: json['photoFileName'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'employeeIdNumber': employeeIdNumber,
        'firstName': firstName,
        'middleName': middleName,
        'lastName': lastName,
        'gender': gender,
        'maritalStatus': maritalStatus,
        'nationality': nationality,
        'residentialDistrict': residentialDistrict,
        'mobileNumber': mobileNumber,
        'email': email,
        'dateOfBirth': dateOfBirth,
        'dateOfEmployment': dateOfEmployment,
        'status': status,
        'salaryStatus': salaryStatus?.toJson(),
        'arrearsList': arrearsList?.map((e) => e.toJson()).toList(),
        'allowancesList': allowancesList?.map((e) => e.toJson()).toList(),
        'backendId': backendId,
        'photoFileName': photoFileName,
      };

  /// Builds an [Employee] from the backend's `Employee` schema
  /// (`tughe/employee/schema.py`), optionally merging in [status]/
  /// [arrears]/[allowances] fetched from the companion endpoints, since the
  /// backend keeps those in separate tables (`employees_status`,
  /// `emp_arrears`, `emp_allowances`).
  factory Employee.fromBackendJson(
    Map<String, dynamic> json, {
    SalaryStatus? status,
    List<AssignedArrear>? arrears,
    List<AssignedAllowance>? allowances,
  }) {
    String isoDate(dynamic v) {
      if (v == null) return '';
      final s = v.toString();
      return s.length >= 10 ? s.substring(0, 10) : s;
    }

    final sex = (json['sex'] as String? ?? 'MALE').toUpperCase();
    final employeeIdNumber = json['employeeIdNumber'] as String? ?? 'TGH-${json['id']}';
    return Employee(
      id: employeeIdNumber,
      employeeIdNumber: employeeIdNumber,
      backendId: (json['id'] as num?)?.toInt(),
      photoFileName: json['photoFileName'] as String?,
      firstName: json['firstName'] as String? ?? '',
      middleName: json['middleName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      gender: sex == 'FEMALE' ? 'Female' : 'Male',
      maritalStatus: _titleCase(json['maritalStatus'] as String? ?? 'Single'),
      nationality: json['nationality'] as String? ?? '',
      residentialDistrict: json['residentDistrict'] as String? ?? '',
      mobileNumber: json['mobileNo'] as String? ?? '',
      email: json['email'] as String? ?? '',
      dateOfBirth: isoDate(json['dateOfBirth']),
      dateOfEmployment: isoDate(json['dateOfEmployment']),
      status: json['isBlocked'] == true ? 'Blocked' : 'Active',
      salaryStatus: status,
      arrearsList: arrears,
      allowancesList: allowances,
    );
  }
}

String _titleCase(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1).toLowerCase();
}
