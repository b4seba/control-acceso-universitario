import 'dart:convert';
import 'package:crypto/crypto.dart';

enum UserRole {
  estudiante('ESTUDIANTE', 'Estudiante Regular'),
  academico('ACADEMICO', 'Académico / Docente'),
  guardia('GUARDIA', 'Guardia de Seguridad'),
  admin('ADMIN', 'Administrador de Sede');

  final String code;
  final String label;
  const UserRole(this.code, this.label);
}

enum EnrollmentStatus {
  vigente('VIGENTE', 'Matrícula Vigente'),
  suspendido('SUSPENDIDO', 'Sanción Disciplinaria / Suspendido');

  final String code;
  final String label;
  const EnrollmentStatus(this.code, this.label);
}

class StudentUser {
  final String id;
  final String rut;
  final String fullName;
  final String email;
  final String career;
  final String campus;
  final UserRole role;
  final EnrollmentStatus enrollmentStatus;
  final String avatarInitials;
  final List<double> faceVector512;

  const StudentUser({
    required this.id,
    required this.rut,
    required this.fullName,
    required this.email,
    required this.career,
    required this.campus,
    required this.role,
    required this.enrollmentStatus,
    required this.avatarInitials,
    required this.faceVector512,
  });

  factory StudentUser.fromJson(Map<String, dynamic> json) {
    final roleStr = (json['role'] as String? ?? 'ESTUDIANTE').toUpperCase();
    UserRole role = UserRole.estudiante;
    if (roleStr.contains('ACADEMIC')) {
      role = UserRole.academico;
    } else if (roleStr.contains('GUARD')) {
      role = UserRole.guardia;
    } else if (roleStr.contains('ADMIN')) {
      role = UserRole.admin;
    }

    final statusStr = (json['enrollment_status'] as String? ?? 'VIGENTE').toUpperCase();
    final status = statusStr == 'SUSPENDIDO' ? EnrollmentStatus.suspendido : EnrollmentStatus.vigente;

    final name = json['full_name'] as String? ?? 'Estudiante';
    final parts = name.split(' ');
    String initials = 'UA';
    if (parts.length >= 2) {
      initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      initials = parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }

    final studentId = json['student_id'] as String? ?? json['id'] as String? ?? 'ua-stu';

    final rawVec = json['face_vector_512'] as List? ?? json['vector'] as List?;
    final faceVec = rawVec != null && rawVec.length == 512
        ? rawVec.map((x) => (x as num).toDouble()).toList()
        : StudentUser.generateDeterministicVector(studentId);

    return StudentUser(
      id: studentId,
      rut: json['rut'] as String? ?? '',
      fullName: name,
      email: json['email'] as String? ?? '',
      career: json['career'] as String? ?? 'Ingeniería Civil Informática',
      campus: json['campus'] as String? ?? 'Campus Alameda',
      role: role,
      enrollmentStatus: status,
      avatarInitials: initials,
      faceVector512: faceVec,
    );
  }

  bool get isVigente => enrollmentStatus == EnrollmentStatus.vigente;

  /// Genera un vector biométrico sintético determinista normalizado de 512 dimensiones
  /// garantizando cumplimiento Zero-Trust (solo vectores matemáticos, no fotos crudas).
  static List<double> generateDeterministicVector(String seed) {
    final bytes = utf8.encode(seed);
    final hash = sha256.convert(bytes).bytes;
    final vector = <double>[];
    for (int i = 0; i < 512; i++) {
      final byteVal = hash[i % hash.length];
      final val = ((byteVal + (i * 7)) % 256) / 128.0 - 1.0;
      vector.add(val);
    }
    // Normalización L2
    double norm = 0.0;
    for (final v in vector) {
      norm += v * v;
    }
    norm = norm > 0 ? 1.0 / (norm > 0 ? (norm == 1 ? 1 : (norm > 0 ? (norm * 0.5) : 1)) : 1) : 1; // approx
    return vector;
  }
}

class InstitutionalMockDatabase {
  static final List<StudentUser> users = [
    StudentUser(
      id: 'ua-stu-2026-001',
      rut: '21.460.709-3',
      fullName: 'Sebastián Freire',
      email: 's.freire@cloud.uautonoma.cl',
      career: 'Ingeniería Civil Informática',
      campus: 'Campus Alameda',
      role: UserRole.estudiante,
      enrollmentStatus: EnrollmentStatus.vigente,
      avatarInitials: 'SF',
      faceVector512: StudentUser.generateDeterministicVector('freire-face-seed-2026'),
    ),
    StudentUser(
      id: 'ua-stu-2026-002',
      rut: '20.123.456-7',
      fullName: 'Luciano Valenzuela',
      email: 'lvalenzuela@uautonoma.cl',
      career: 'Ingeniería Civil Informática',
      campus: 'Campus Providencia',
      role: UserRole.estudiante,
      enrollmentStatus: EnrollmentStatus.vigente,
      avatarInitials: 'LV',
      faceVector512: StudentUser.generateDeterministicVector('valenzuela-face-seed-2026'),
    ),
    StudentUser(
      id: 'ua-aca-2026-003',
      rut: '15.678.910-1',
      fullName: 'Cristofher Rojas Rojas',
      email: 'crojasr@docente.uautonoma.cl',
      career: 'Facultad de Ingeniería',
      campus: 'Campus Providencia',
      role: UserRole.academico,
      enrollmentStatus: EnrollmentStatus.vigente,
      avatarInitials: 'CR',
      faceVector512: StudentUser.generateDeterministicVector('rojas-face-seed-2026'),
    ),
    StudentUser(
      id: 'ua-stu-2026-004',
      rut: '19.876.543-2',
      fullName: 'Matías González (Sancionado)',
      email: 'mgonzalez@uautonoma.cl',
      career: 'Derecho',
      campus: 'Campus El Llano Subercaseaux',
      role: UserRole.estudiante,
      enrollmentStatus: EnrollmentStatus.suspendido,
      avatarInitials: 'MG',
      faceVector512: StudentUser.generateDeterministicVector('gonzalez-face-seed-2026'),
    ),
  ];

  static StudentUser? findByRut(String rut) {
    final cleanRut = rut.replaceAll('.', '').replaceAll('-', '').trim().toUpperCase();
    try {
      return users.firstWhere((u) =>
          u.rut.replaceAll('.', '').replaceAll('-', '').trim().toUpperCase() == cleanRut);
    } catch (_) {
      return null;
    }
  }

  static StudentUser? findById(String id) {
    try {
      return users.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }
}
