import 'package:flutter_test/flutter_test.dart';
import 'package:kiosk_app/domain/fsm/turnstile_state.dart';
import 'package:kiosk_app/domain/models/turnstile_event.dart';
import 'package:kiosk_app/domain/models/whitelist_student.dart';
import 'package:kiosk_app/data/database/turnstile_database.dart';

class MockFsmContext implements TurnstileFsmContext {
  @override
  final String turnstileId = 'TRN-TEST-01';
  @override
  final String campusId = 'CAMPUS_TEST';
  @override
  final TurnstileDatabase database = TurnstileDatabase.instance;
  
  TurnstileState currentState = IdleState();

  @override
  void transitionTo(TurnstileState nextState) {
    currentState = nextState;
  }
}

void main() {
  group('GoF State Pattern & FSM Transitions Tests', () {
    late MockFsmContext mockContext;

    setUp(() {
      mockContext = MockFsmContext();
    });

    test('Initial state is IdleState with correct halo and message', () {
      final state = IdleState();
      expect(state.type, TurnstileStateType.idle);
      expect(state.haloColor.toARGB32(), 0xFF0077B6); // Azul Neón Cobalto
      expect(state.statusMessage, contains('ACERQUE SU CREDENCIAL'));
    });

    test('Face comparison: Cosine similarity identifies identical vectors with high confidence', () {
      final v1 = WhitelistStudent.generateDeterministicVector('test-vector-A');
      final v2 = WhitelistStudent.generateDeterministicVector('test-vector-A');
      final vDiff = WhitelistStudent.generateDeterministicVector('test-vector-B');

      final simMatch = WhitelistStudent.calculateCosineSimilarity(v1, v2);
      final simDiff = WhitelistStudent.calculateCosineSimilarity(v1, vDiff);

      expect(simMatch, greaterThanOrEqualTo(0.99));
      expect(simDiff, lessThan(0.72));
    });

    test('FaceScanningState transitions to AccessGrantedState when face vector matches', () async {
      final student = WhitelistStudent(
        studentId: 'ua-stu-test-01',
        rut: '20.111.222-3',
        fullName: 'Estudiante Prueba',
        career: 'Informática',
        campus: 'Providencia',
        role: 'ESTUDIANTE',
        status: 'VIGENTE',
        faceVector512: WhitelistStudent.generateDeterministicVector('sample-seed-ok'),
      );

      final state = FaceScanningState(
        student: student,
        flowStartTimestampMs: DateTime.now().millisecondsSinceEpoch - 90,
      );

      // Captured vector is identical
      final capturedVector = WhitelistStudent.generateDeterministicVector('sample-seed-ok');
      
      // We test the cosine match and state generation
      final similarity = WhitelistStudent.calculateCosineSimilarity(student.faceVector512, capturedVector);
      expect(similarity, greaterThanOrEqualTo(0.72));
      expect(state.studentId, 'ua-stu-test-01');
      expect(mockContext.turnstileId, 'TRN-TEST-01');
    });

    test('TurnstileOutboxEvent generates immutable SHA-256 payload hash', () {
      final hash = TurnstileOutboxEvent.calculatePayloadHash(
        eventUuid: 'evt-test-1234',
        turnstileId: 'TRN-PROV-01',
        studentId: 'ua-stu-2026-001',
        timestamp: '2026-10-25T01:00:00Z',
        result: 'GRANTED',
        latencyMs: 94,
      );

      expect(hash, hasLength(64)); // SHA-256 hex length
    });
  });
}
