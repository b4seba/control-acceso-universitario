package models

import "time"

// OutboxEvent representa un evento individual de acceso emitido por un torniquete Edge
type OutboxEvent struct {
	ID              int64     `json:"id"`
	EventUUID       string    `json:"event_uuid"`
	TurnstileID     string    `json:"turnstile_id"`
	CampusID        string    `json:"campus_id"`
	StudentID       string    `json:"student_id"`
	StudentRUT      string    `json:"student_rut"`
	AccessTimestamp string    `json:"access_timestamp"`
	AccessResult    string    `json:"access_result"` // "GRANTED" | "DENIED"
	DenialReason    *string   `json:"denial_reason,omitempty"`
	LatencyMs       int       `json:"latency_ms"`
	PayloadHash     string    `json:"payload_hash"`
	Status          string    `json:"status"`
	RetryCount      int       `json:"retry_count"`
	SyncedAt        *string   `json:"synced_at,omitempty"`
	AckHash         *string   `json:"ack_hash,omitempty"`
}

// BatchRequest representa el paquete de sincronización enviado por el OutboxWorker
type BatchRequest struct {
	TurnstileID       string        `json:"turnstile_id"`
	CampusID          string        `json:"campus_id"`
	DispatchTimestamp string        `json:"dispatch_timestamp"`
	EventsCount       int           `json:"events_count"`
	Events            []OutboxEvent `json:"events"`
}

// BatchResponse es la respuesta criptográfica ACK entregada al Kiosko Edge
type BatchResponse struct {
	Status        string            `json:"status"` // "ACK_CONFIRMED"
	ProcessedAt   time.Time         `json:"processed_at"`
	BatchSize     int               `json:"batch_size"`
	AckMap        map[string]string `json:"ack_map"` // map[event_uuid]ack_hash
	ExecutionTime string            `json:"execution_time"`
}

// AccessAuditRecord representa el registro forense consolidado en PostgreSQL 16
type AccessAuditRecord struct {
	ID              int64     `json:"id"`
	EventUUID       string    `json:"event_uuid"`
	TurnstileID     string    `json:"turnstile_id"`
	CampusID        string    `json:"campus_id"`
	StudentID       string    `json:"student_id"`
	StudentRUT      string    `json:"student_rut"`
	AccessTimestamp time.Time `json:"access_timestamp"`
	AccessResult    string    `json:"access_result"`
	DenialReason    string    `json:"denial_reason"`
	LatencyMs       int       `json:"latency_ms"`
	PayloadHash     string    `json:"payload_hash"`
	PreviousHash    string    `json:"previous_hash"`
	CurrentHash     string    `json:"current_hash"`
	IngestedAt      time.Time `json:"ingested_at"`
}

// VectorRecord representa la entidad en Qdrant Vector DB (Zero-Trust: solo floats de 512D)
type VectorRecord struct {
	ID        string    `json:"id"`
	StudentID string    `json:"student_id"`
	Vector    []float32 `json:"vector"` // 512 dimensiones
	CreatedAt time.Time `json:"created_at"`
}

// UserRBAC representa un usuario en el sistema central RBAC (PostgreSQL 16)
type UserRBAC struct {
	StudentID        string    `json:"student_id"`
	RUT              string    `json:"rut"`
	FullName         string    `json:"full_name"`
	Email            string    `json:"email"`
	Role             string    `json:"role"` // ESTUDIANTE, ACADEMICO, GUARDIA
	Career           string    `json:"career"`
	Campus           string    `json:"campus"`
	EnrollmentStatus string    `json:"enrollment_status"` // VIGENTE, SUSPENDIDO
	PasswordHash     string    `json:"-"`
	CreatedAt        time.Time `json:"created_at"`
}

// RegisterRequest representa el payload de registro y enrolamiento de usuario
type RegisterRequest struct {
	StudentID     string    `json:"student_id"`
	RUT           string    `json:"rut"`
	FullName      string    `json:"full_name"`
	Career        string    `json:"career"`
	Campus        string    `json:"campus"`
	Password      string    `json:"password"`
	Vector        []float32 `json:"vector"`          // 512 dimensiones
	FaceVector512 []float32 `json:"face_vector_512"` // Compatibilidad 512D
}

// LoginRequest representa las credenciales de ingreso
type LoginRequest struct {
	RUT      string `json:"rut"`
	Password string `json:"password"`
}
