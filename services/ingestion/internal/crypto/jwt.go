package crypto

import (
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

const InstitutionalJWTSecret = "UA_CENTRAL_SECRET_JWT_KEY_2026_PROV"

// UAClaims representa el payload estándar RFC 7519 para sesiones institucionales
type UAClaims struct {
	StudentID string `json:"student_id"`
	RUT       string `json:"rut"`
	FullName  string `json:"full_name"`
	Role      string `json:"role"`
	Campus    string `json:"campus"`
	jwt.RegisteredClaims
}

// GenerateJWT firma un token criptográfico HMAC-SHA256 válido por 24 horas
func GenerateJWT(studentID, rut, fullName, role, campus string) (string, error) {
	now := time.Now().UTC()
	claims := UAClaims{
		StudentID: studentID,
		RUT:       rut,
		FullName:  fullName,
		Role:      role,
		Campus:    campus,
		RegisteredClaims: jwt.RegisteredClaims{
			Issuer:    "Universidad",
			Subject:   studentID,
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(now.Add(24 * time.Hour)),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(InstitutionalJWTSecret))
}

// ValidateJWT verifica la firma criptográfica y expiración del token
func ValidateJWT(tokenString string) (*UAClaims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &UAClaims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("método de firma no permitido")
		}
		return []byte(InstitutionalJWTSecret), nil
	})

	if err != nil {
		return nil, err
	}

	if claims, ok := token.Claims.(*UAClaims); ok && token.Valid {
		return claims, nil
	}

	return nil, errors.New("token JWT inválido o expirado")
}
