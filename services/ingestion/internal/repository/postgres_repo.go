package repository

import (
	"context"
	"fmt"
	"strings"
	"sync"
	"time"

	"cl.uautonoma.acceso/ingestion/internal/crypto"
	"cl.uautonoma.acceso/ingestion/internal/models"
	"github.com/jackc/pgx/v5/pgxpool"
)

// RepositoryInterface define el contrato de persistencia para el microservicio
type RepositoryInterface interface {
	GetLatestHash(ctx context.Context) (string, error)
	PersistBatch(ctx context.Context, records []models.AccessAuditRecord) error
	GetRecentAuditLogs(ctx context.Context, limit int) ([]models.AccessAuditRecord, error)
	CreateUser(ctx context.Context, user models.UserRBAC) error
	GetUserByRUT(ctx context.Context, rut string) (*models.UserRBAC, error)
	GetAllUsers(ctx context.Context) ([]models.UserRBAC, error)
	UpdateUserStatus(ctx context.Context, rut string, status string) error
	DeleteUser(ctx context.Context, rut string) error
}

// PostgresRepository implementa RepositoryInterface sobre PostgreSQL 16
type PostgresRepository struct {
	pool *pgxpool.Pool
}

func NewPostgresRepository(connString string) (*PostgresRepository, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	config, err := pgxpool.ParseConfig(connString)
	if err != nil {
		return nil, fmt.Errorf("error al parsear config de PostgreSQL: %w", err)
	}

	config.MaxConns = 25
	config.MinConns = 5
	config.MaxConnLifetime = 30 * time.Minute

	pool, err := pgxpool.NewWithConfig(ctx, config)
	if err != nil {
		return nil, fmt.Errorf("error al conectar con pool de PostgreSQL 16: %w", err)
	}

	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("fallo ping a PostgreSQL 16: %w", err)
	}

	return &PostgresRepository{pool: pool}, nil
}

func (r *PostgresRepository) GetLatestHash(ctx context.Context) (string, error) {
	query := `SELECT current_hash FROM access_audit_log ORDER BY id DESC LIMIT 1`
	var hash string
	err := r.pool.QueryRow(ctx, query).Scan(&hash)
	if err != nil {
		// Si la tabla está vacía, retornar hash Génesis
		return crypto.GenesisHash, nil
	}
	return hash, nil
}

func (r *PostgresRepository) PersistBatch(ctx context.Context, records []models.AccessAuditRecord) error {
	if len(records) == 0 {
		return nil
	}

	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("error al iniciar transacción PostgreSQL: %w", err)
	}
	defer tx.Rollback(ctx)

	insertQuery := `
		INSERT INTO access_audit_log (
			event_uuid, turnstile_id, campus_id, student_id, student_rut,
			access_timestamp, access_result, denial_reason, latency_ms,
			payload_hash, previous_hash, current_hash, ingested_at
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
		ON CONFLICT (event_uuid) DO NOTHING;
	`

	for _, rec := range records {
		_, err := tx.Exec(ctx, insertQuery,
			rec.EventUUID,
			rec.TurnstileID,
			rec.CampusID,
			rec.StudentID,
			rec.StudentRUT,
			rec.AccessTimestamp,
			rec.AccessResult,
			rec.DenialReason,
			rec.LatencyMs,
			rec.PayloadHash,
			rec.PreviousHash,
			rec.CurrentHash,
			rec.IngestedAt,
		)
		if err != nil {
			return fmt.Errorf("error al insertar registro en lote: %w", err)
		}
	}

	return tx.Commit(ctx)
}

func (r *PostgresRepository) GetRecentAuditLogs(ctx context.Context, limit int) ([]models.AccessAuditRecord, error) {
	query := `
		SELECT id, event_uuid, turnstile_id, campus_id, student_id, student_rut,
		       access_timestamp, access_result, denial_reason, latency_ms,
		       payload_hash, previous_hash, current_hash, ingested_at
		FROM access_audit_log
		ORDER BY id DESC LIMIT $1
	`
	rows, err := r.pool.Query(ctx, query, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var logs []models.AccessAuditRecord
	for rows.Next() {
		var rec models.AccessAuditRecord
		err := rows.Scan(
			&rec.ID, &rec.EventUUID, &rec.TurnstileID, &rec.CampusID,
			&rec.StudentID, &rec.StudentRUT, &rec.AccessTimestamp,
			&rec.AccessResult, &rec.DenialReason, &rec.LatencyMs,
			&rec.PayloadHash, &rec.PreviousHash, &rec.CurrentHash,
			&rec.IngestedAt,
		)
		if err != nil {
			return nil, err
		}
		logs = append(logs, rec)
	}
	return logs, nil
}

func (r *PostgresRepository) CreateUser(ctx context.Context, user models.UserRBAC) error {
	query := `
		INSERT INTO users_rbac (student_id, rut, full_name, email, role, career, campus_id, enrollment_status)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		ON CONFLICT (rut) DO UPDATE SET 
			full_name = EXCLUDED.full_name, 
			career = EXCLUDED.career,
			campus_id = EXCLUDED.campus_id,
			enrollment_status = EXCLUDED.enrollment_status;
	`
	_, err := r.pool.Exec(ctx, query, user.StudentID, user.RUT, user.FullName, user.Email, user.Role, user.Career, user.Campus, user.EnrollmentStatus)
	return err
}

func (r *PostgresRepository) GetUserByRUT(ctx context.Context, rut string) (*models.UserRBAC, error) {
	clean := cleanRUT(rut)
	query := `
		SELECT student_id, rut, full_name, email, role, career, campus_id, enrollment_status, created_at
		FROM users_rbac
		WHERE REPLACE(REPLACE(rut, '.', ''), '-', '') = $1
		LIMIT 1;
	`
	var u models.UserRBAC
	err := r.pool.QueryRow(ctx, query, clean).Scan(&u.StudentID, &u.RUT, &u.FullName, &u.Email, &u.Role, &u.Career, &u.Campus, &u.EnrollmentStatus, &u.CreatedAt)
	if err != nil {
		return nil, err
	}
	return &u, nil
}

func (r *PostgresRepository) GetAllUsers(ctx context.Context) ([]models.UserRBAC, error) {
	query := `SELECT student_id, rut, full_name, email, role, career, campus_id, enrollment_status, created_at FROM users_rbac`
	rows, err := r.pool.Query(ctx, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var users []models.UserRBAC
	for rows.Next() {
		var u models.UserRBAC
		if err := rows.Scan(&u.StudentID, &u.RUT, &u.FullName, &u.Email, &u.Role, &u.Career, &u.Campus, &u.EnrollmentStatus, &u.CreatedAt); err == nil {
			users = append(users, u)
		}
	}
	return users, nil
}

func (r *PostgresRepository) UpdateUserStatus(ctx context.Context, rut string, status string) error {
	clean := cleanRUT(rut)
	query := "UPDATE users_rbac SET enrollment_status = $1 WHERE REPLACE(REPLACE(rut, '.', ''), '-', '') = $2;"
	_, err := r.pool.Exec(ctx, query, status, clean)
	return err
}

func (r *PostgresRepository) DeleteUser(ctx context.Context, rut string) error {
	clean := cleanRUT(rut)
	query := "DELETE FROM users_rbac WHERE REPLACE(REPLACE(rut, '.', ''), '-', '') = $1;"
	_, err := r.pool.Exec(ctx, query, clean)
	return err
}

// ============================================================================
// InMemoryRepository: Implementación en memoria para pruebas y contingencia
// ============================================================================
type InMemoryRepository struct {
	mu      sync.RWMutex
	records []models.AccessAuditRecord
	users   map[string]models.UserRBAC
}

func NewInMemoryRepository() *InMemoryRepository {
	repo := &InMemoryRepository{
		records: make([]models.AccessAuditRecord, 0),
		users:   make(map[string]models.UserRBAC),
	}
	// Seed Sebastián Freire como usuario real institucional
	freire := models.UserRBAC{
		StudentID:        "ua-stu-2026-001",
		RUT:              "21.460.709-3",
		FullName:         "Sebastián Freire",
		Email:            "s.freire@cloud.uautonoma.cl",
		Role:             "ESTUDIANTE",
		Career:           "Ingeniería Civil Informática",
		Campus:           "Campus Alameda",
		EnrollmentStatus: "VIGENTE",
		CreatedAt:        time.Now().UTC(),
	}
	repo.users[cleanRUT(freire.RUT)] = freire
	return repo
}

func (m *InMemoryRepository) CreateUser(ctx context.Context, user models.UserRBAC) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.users[cleanRUT(user.RUT)] = user
	return nil
}

func (m *InMemoryRepository) GetUserByRUT(ctx context.Context, rut string) (*models.UserRBAC, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	clean := cleanRUT(rut)
	if u, ok := m.users[clean]; ok {
		return &u, nil
	}
	return nil, fmt.Errorf("usuario con RUT %s no encontrado", rut)
}

func (m *InMemoryRepository) GetAllUsers(ctx context.Context) ([]models.UserRBAC, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	list := make([]models.UserRBAC, 0, len(m.users))
	for _, u := range m.users {
		list = append(list, u)
	}
	return list, nil
}

func (m *InMemoryRepository) UpdateUserStatus(ctx context.Context, rut string, status string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	clean := cleanRUT(rut)
	if u, ok := m.users[clean]; ok {
		u.EnrollmentStatus = status
		m.users[clean] = u
		return nil
	}
	return fmt.Errorf("usuario no encontrado")
}

func (m *InMemoryRepository) DeleteUser(ctx context.Context, rut string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	clean := cleanRUT(rut)
	delete(m.users, clean)
	return nil
}

func cleanRUT(rut string) string {
	r := strings.ReplaceAll(rut, ".", "")
	r = strings.ReplaceAll(r, "-", "")
	r = strings.TrimSpace(r)
	return strings.ToUpper(r)
}

func (m *InMemoryRepository) GetLatestHash(ctx context.Context) (string, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	if len(m.records) == 0 {
		return crypto.GenesisHash, nil
	}
	return m.records[len(m.records)-1].CurrentHash, nil
}

func (m *InMemoryRepository) PersistBatch(ctx context.Context, records []models.AccessAuditRecord) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	for _, rec := range records {
		rec.ID = int64(len(m.records) + 1)
		m.records = append(m.records, rec)
	}
	return nil
}

func (m *InMemoryRepository) GetRecentAuditLogs(ctx context.Context, limit int) ([]models.AccessAuditRecord, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()

	n := len(m.records)
	if n == 0 {
		return []models.AccessAuditRecord{}, nil
	}

	start := n - limit
	if start < 0 {
		start = 0
	}

	result := make([]models.AccessAuditRecord, n-start)
	copy(result, m.records[start:n])

	// Invertir para orden descendente
	for i, j := 0, len(result)-1; i < j; i, j = i+1, j-1 {
		result[i], result[j] = result[j], result[i]
	}
	return result, nil
}
