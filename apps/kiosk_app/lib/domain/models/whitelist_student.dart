import 'dart:convert';
import 'package:crypto/crypto.dart';

class WhitelistStudent {
  final String studentId;
  final String rut;
  final String fullName;
  final String career;
  final String campus;
  final String role;
  final String status; // 'VIGENTE', 'SUSPENDIDO'
  final List<double> faceVector512;

  const WhitelistStudent({
    required this.studentId,
    required this.rut,
    required this.fullName,
    required this.career,
    required this.campus,
    required this.role,
    required this.status,
    required this.faceVector512,
  });

  bool get isVigente => status.toUpperCase() == 'VIGENTE';

  Map<String, dynamic> toMap() {
    return {
      'student_id': studentId,
      'rut': rut,
      'full_name': fullName,
      'career': career,
      'campus': campus,
      'role': role,
      'status': status,
      'face_vector_json': jsonEncode(faceVector512),
    };
  }

  factory WhitelistStudent.fromMap(Map<String, dynamic> map) {
    List<double> vector = [];
    if (map['face_vector_json'] != null) {
      final List<dynamic> raw = jsonDecode(map['face_vector_json'] as String);
      vector = raw.map((e) => (e as num).toDouble()).toList();
    }
    return WhitelistStudent(
      studentId: map['student_id'] as String,
      rut: map['rut'] as String,
      fullName: map['full_name'] as String,
      career: map['career'] as String,
      campus: map['campus'] as String,
      role: map['role'] as String,
      status: map['status'] as String,
      faceVector512: vector,
    );
  }

  /// Calcula la Similitud Coseno entre dos vectores biométricos de 512 dimensiones
  /// Fórmula: cos(theta) = (u . v) / (||u|| * ||v||)
  static double calculateCosineSimilarity(List<double> v1, List<double> v2) {
    if (v1.length != v2.length || v1.isEmpty) return 0.0;
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    for (int i = 0; i < v1.length; i++) {
      dotProduct += v1[i] * v2[i];
      normA += v1[i] * v1[i];
      normB += v2[i] * v2[i];
    }
    if (normA <= 0.0 || normB <= 0.0) return 0.0;
    return dotProduct / (mathSqrt(normA) * mathSqrt(normB));
  }

  static double mathSqrt(double x) {
    if (x <= 0) return 0;
    double guess = x / 2.0;
    for (int i = 0; i < 10; i++) {
      guess = (guess + x / guess) / 2.0;
    }
    return guess;
  }

  static List<double> generateDeterministicVector(String seed) {
    final bytes = utf8.encode(seed);
    final hash = sha256.convert(bytes).bytes;
    final vector = <double>[];
    for (int i = 0; i < 512; i++) {
      final byteVal = hash[i % hash.length];
      final val = ((byteVal + (i * 7)) % 256) / 128.0 - 1.0;
      vector.add(val);
    }
    return vector;
  }
}
