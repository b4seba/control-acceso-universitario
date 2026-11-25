package crypto

import "golang.org/x/crypto/bcrypt"

// HashPassword genera un hash bcrypt seguro de la contraseña del usuario.
func HashPassword(password string) (string, error) {
	bytes, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return "", err
	}
	return string(bytes), nil
}

// VerifyPassword compara una contraseña en texto plano contra su hash bcrypt almacenado.
func VerifyPassword(password, hash string) bool {
	if hash == "" || password == "" {
		return false
	}
	return bcrypt.CompareHashAndPassword([]byte(hash), []byte(password)) == nil
}
