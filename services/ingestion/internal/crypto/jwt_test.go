package crypto

import (
	"testing"
)

func TestGenerateAndValidateJWT(t *testing.T) {
	studentID := "ua-stu-2026-001"
	rut := "21.460.709-3"
	name := "Sebastián Freire"
	role := "ESTUDIANTE"
	campus := "Campus Alameda"

	token, err := GenerateJWT(studentID, rut, name, role, campus)
	if err != nil {
		t.Fatalf("Error al generar JWT: %v", err)
	}

	if token == "" {
		t.Fatal("Token JWT generado no debe ser vacío")
	}

	claims, err := ValidateJWT(token)
	if err != nil {
		t.Fatalf("Error al validar JWT: %v", err)
	}

	if claims.StudentID != studentID {
		t.Errorf("StudentID esperado %s, obtenido %s", studentID, claims.StudentID)
	}
	if claims.RUT != rut {
		t.Errorf("RUT esperado %s, obtenido %s", rut, claims.RUT)
	}
	if claims.Role != role {
		t.Errorf("Role esperado %s, obtenido %s", role, claims.Role)
	}
}

func TestValidateTamperedJWT(t *testing.T) {
	studentID := "ua-stu-2026-001"
	token, _ := GenerateJWT(studentID, "21.460.709-3", "Sebastián", "ESTUDIANTE", "Alameda")

	// Alterar la firma
	tampered := token + "tampered"
	_, err := ValidateJWT(tampered)
	if err == nil {
		t.Fatal("Se esperaba error al validar token JWT adulterado")
	}
}
