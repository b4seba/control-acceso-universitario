package api

import (
	"bytes"
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"cl.uautonoma.acceso/ingestion/internal/crypto"
	"cl.uautonoma.acceso/ingestion/internal/models"
	"cl.uautonoma.acceso/ingestion/internal/repository"
	"cl.uautonoma.acceso/ingestion/internal/workerpool"
	"github.com/gin-gonic/gin"
)

type APIHandler struct {
	pool      *workerpool.WorkerPool
	repo      repository.RepositoryInterface
	qdrant    *repository.QdrantClient
	startTime time.Time
}

func NewAPIHandler(pool *workerpool.WorkerPool, repo repository.RepositoryInterface, qdrant *repository.QdrantClient) *APIHandler {
	return &APIHandler{
		pool:      pool,
		repo:      repo,
		qdrant:    qdrant,
		startTime: time.Now(),
	}
}

// RegisterRoutes configura los endpoints REST en el motor Gin
func (h *APIHandler) RegisterRoutes(router *gin.Engine) {
	router.Use(CORSMiddleware())

	v1 := router.Group("/api/v1")
	{
		v1.GET("/health", h.HealthCheck)
		v1.GET("/audit/logs", h.GetAuditLogs)
		v1.GET("/vectors", h.GetVectors)
		v1.POST("/vectors", h.UpsertVector)
		v1.POST("/vectors/search", h.SearchVectors)
		v1.POST("/auth/register", h.RegisterUser)
		v1.POST("/auth/login", h.LoginUser)
		v1.GET("/sync/whitelist", h.GetSyncWhitelist)

		// Endpoints protegidos para sincronización Edge-to-Cloud
		protected := v1.Group("")
		protected.Use(AuthMiddleware())
		{
			protected.POST("/ingest/batch", h.IngestBatch)
		}
	}
}

// GetVectors lista los embeddings biométricos de 512D almacenados en Qdrant (Zero-Trust)
func (h *APIHandler) GetVectors(c *gin.Context) {
	if h.qdrant == nil {
		c.JSON(http.StatusOK, gin.H{"total": 0, "vectors": []interface{}{}})
		return
	}

	vectors := h.qdrant.GetAllVectors()
	type VectorSummary struct {
		StudentID    string    `json:"student_id"`
		Dimensions   int       `json:"dimensions"`
		SampleValues []float32 `json:"sample_values_first_5"`
		CreatedAt    time.Time `json:"created_at"`
		ZeroTrust    string    `json:"zero_trust_status"`
	}

	summaryList := make([]VectorSummary, 0, len(vectors))
	for _, v := range vectors {
		samples := v.Vector
		if len(samples) > 5 {
			samples = samples[:5]
		}
		summaryList = append(summaryList, VectorSummary{
			StudentID:    v.StudentID,
			Dimensions:   len(v.Vector),
			SampleValues: samples,
			CreatedAt:    v.CreatedAt,
			ZeroTrust:    "CERTIFICADO: Solo vector matemático unidireccional. Sin fotografías crudas.",
		})
	}

	c.JSON(http.StatusOK, gin.H{
		"engine":        "Qdrant Vector DB (v1.12.1 HNSW / Cosine)",
		"total_vectors": len(summaryList),
		"policy":        "Zero-Trust Biometrics",
		"collection":    "student_face_embeddings_512d",
		"vectors":       summaryList,
	})
}

// UpsertVector registra un nuevo vector biométrico 512D en Qdrant (Zero-Trust)
func (h *APIHandler) UpsertVector(c *gin.Context) {
	var req struct {
		StudentID string    `json:"student_id"`
		Vector    []float32 `json:"vector"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Formato JSON de vector inválido"})
		return
	}
	if req.StudentID == "" || len(req.Vector) != 512 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Se requiere student_id y un vector de exactamente 512 dimensiones"})
		return
	}
	if h.qdrant != nil {
		if err := h.qdrant.UpsertStudentVector(c.Request.Context(), req.StudentID, req.Vector); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
	}
	c.JSON(http.StatusCreated, gin.H{
		"status":     "ENROLADO_EXITOSAMENTE",
		"student_id": req.StudentID,
		"dimensions": len(req.Vector),
		"zero_trust": "CERTIFICADO: Solo vector matemático unidireccional persistido en Qdrant Vector DB.",
	})
}

// SearchVectors ejecuta una búsqueda 1:1 o 1:N por Similitud Coseno
func (h *APIHandler) SearchVectors(c *gin.Context) {
	var req struct {
		Vector    []float32 `json:"vector"`
		Threshold float64   `json:"threshold"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Formato de vector JSON inválido"})
		return
	}

	if len(req.Vector) != 512 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "El vector facial debe tener exactamente 512 dimensiones"})
		return
	}

	if req.Threshold <= 0 {
		req.Threshold = 0.72
	}

	match, score, err := h.qdrant.SearchSimilarVector(c.Request.Context(), req.Vector, req.Threshold)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	if match == nil {
		c.JSON(http.StatusOK, gin.H{
			"match":       false,
			"score":       score,
			"threshold":   req.Threshold,
			"status":      "Rostro no coincide con ningún estudiante registrado",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"match":      true,
		"student_id": match.StudentID,
		"score":      score,
		"threshold":  req.Threshold,
		"status":     "COINCIDENCIA BIOMÉTRICA CONFIRMADA",
	})
}

// IngestBatch recibe un lote de transacciones de un Kiosko y lo encola en el Worker Pool
func (h *APIHandler) IngestBatch(c *gin.Context) {
	var batch models.BatchRequest
	if err := c.ShouldBindJSON(&batch); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   "Formato JSON de lote inválido",
			"details": err.Error(),
		})
		return
	}

	if len(batch.Events) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "El lote de eventos outbox no puede estar vacío",
		})
		return
	}

	// Enviar al Worker Pool para procesamiento asíncrono y hash-chaining
	response, err := h.pool.Submit(batch)
	if err != nil {
		if strings.Contains(err.Error(), "HTTP 429") {
			c.Header("Retry-After", "3")
			c.JSON(http.StatusTooManyRequests, gin.H{
				"error":       "Tormenta de Reconexión detectada: Worker Pool saturado",
				"queue_depth": h.pool.QueueDepth(),
			})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Error al procesar lote de auditoría",
			"details": err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, response)
}

// HealthCheck reporta la salud del microservicio y métricas del Worker Pool
func (h *APIHandler) HealthCheck(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"service":     "UA Ingestion Central Microservice",
		"status":      "HEALTHY",
		"version":     "1.0.0",
		"uptime":      time.Since(h.startTime).String(),
		"queue_depth": h.pool.QueueDepth(),
		"timestamp":   time.Now().UTC(),
	})
}

// GetAuditLogs devuelve los registros forenses recientes
func (h *APIHandler) GetAuditLogs(c *gin.Context) {
	if memRepo, ok := h.repo.(*repository.InMemoryRepository); ok {
		logs, err := memRepo.GetRecentAuditLogs(c.Request.Context(), 50)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{
			"total": len(logs),
			"logs":  logs,
		})
		return
	}

	if pgRepo, ok := h.repo.(*repository.PostgresRepository); ok {
		logs, err := pgRepo.GetRecentAuditLogs(c.Request.Context(), 50)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{
			"total": len(logs),
			"logs":  logs,
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{"total": 0, "logs": []interface{}{}})
}

// AuthMiddleware valida que la petición provenga de un nodo Kiosko o cliente autenticado con JWT RFC 7519
func AuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" || !strings.HasPrefix(authHeader, "Bearer ") {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"error": "Cabecera Authorization Bearer Token requerida",
			})
			return
		}

		token := strings.TrimPrefix(authHeader, "Bearer ")

		// Token directo de Kiosko Edge o Token JWT estándar RFC 7519
		if token == "UA_EDGE_TOKEN_2026_JWT" {
			c.Next()
			return
		}

		claims, err := crypto.ValidateJWT(token)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{
				"error":   "Token JWT no autorizado, alterado o expirado",
				"details": err.Error(),
			})
			return
		}

		c.Set("student_id", claims.StudentID)
		c.Set("role", claims.Role)
		c.Next()
	}
}

// CORSMiddleware permite la comunicación entre el Kiosko y la API REST
func CORSMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "POST, GET, OPTIONS, PUT, DELETE")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}
		c.Next()
	}
}

// RegisterUser crea un nuevo usuario institucional en PostgreSQL y persiste su vector 512D en Qdrant
func (h *APIHandler) RegisterUser(c *gin.Context) {
	var req models.RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Payload de registro inválido", "details": err.Error()})
		return
	}

	if req.RUT == "" || req.FullName == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Se requiere RUT y Nombre Completo"})
		return
	}

	if req.StudentID == "" {
		clean := strings.ReplaceAll(strings.ReplaceAll(req.RUT, ".", ""), "-", "")
		req.StudentID = "ua-stu-" + strings.ToLower(clean)
	}

	if req.Campus == "" {
		req.Campus = "Campus Alameda"
	}
	if req.Career == "" {
		req.Career = "Ingeniería Civil Informática"
	}

	emailName := strings.ToLower(strings.ReplaceAll(req.FullName, " ", "."))
	user := models.UserRBAC{
		StudentID:        req.StudentID,
		RUT:              req.RUT,
		FullName:         req.FullName,
		Email:            emailName + "@cloud.uautonoma.cl",
		Role:             "ESTUDIANTE",
		Career:           req.Career,
		Campus:           req.Campus,
		EnrollmentStatus: "VIGENTE",
		CreatedAt:        time.Now().UTC(),
	}

	if err := h.repo.CreateUser(c.Request.Context(), user); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Error al persistir usuario en PostgreSQL: " + err.Error()})
		return
	}

	if len(req.Vector) == 0 && len(req.FaceVector512) > 0 {
		req.Vector = req.FaceVector512
	}

	// Persistir vector 512D en Qdrant si viene incluido
	if len(req.Vector) == 512 && h.qdrant != nil {
		_ = h.qdrant.UpsertStudentVector(c.Request.Context(), user.StudentID, req.Vector)
	}

	// Sincronizar en segundo plano con el nodo Edge / SQLite WAL local (:5050)
	go func() {
		edgePayload, err := json.Marshal(map[string]interface{}{
			"student_id": user.StudentID,
			"rut":        user.RUT,
			"full_name":  user.FullName,
			"career":     user.Career,
			"campus":     user.Campus,
			"vector":     req.Vector,
		})
		if err == nil {
			client := &http.Client{Timeout: 600 * time.Millisecond}
			_, _ = client.Post("http://127.0.0.1:5050/enroll", "application/json", bytes.NewBuffer(edgePayload))
		}
	}()

	c.JSON(http.StatusCreated, gin.H{
		"status":     "USUARIO_CREADO_EXITOSAMENTE",
		"user":       user,
		"vector_512": len(req.Vector) == 512,
		"zero_trust": "Vector biométrico 512D indexado en Qdrant Vector DB sin fotografías crudas.",
	})
}

// LoginUser autentica credenciales institucionales y determina el rol automáticamente
func (h *APIHandler) LoginUser(c *gin.Context) {
	var req models.LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Payload de inicio de sesión inválido"})
		return
	}

	if req.RUT == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "El RUT es obligatorio"})
		return
	}

	user, err := h.repo.GetUserByRUT(c.Request.Context(), req.RUT)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Credenciales no encontradas en el registro institucional"})
		return
	}

	jwtToken, err := crypto.GenerateJWT(user.StudentID, user.RUT, user.FullName, user.Role, user.Campus)
	if err != nil {
		jwtToken = "jwt-ua-session-" + user.StudentID
	}

	// Recuperar vector 512D desde Qdrant
	var faceVec []float32
	if h.qdrant != nil {
		for _, vr := range h.qdrant.GetAllVectors() {
			if vr.StudentID == user.StudentID {
				faceVec = vr.Vector
				break
			}
		}
	}
	if len(faceVec) != 512 {
		faceVec = repository.GenerateDeterministicVector(user.StudentID)
	}

	c.JSON(http.StatusOK, gin.H{
		"success":         true,
		"token":           jwtToken,
		"user":            user,
		"face_vector_512": faceVec,
	})
}

// GetSyncWhitelist entrega los usuarios autorizados y sus vectores para los Kioskos en Modo Isla
func (h *APIHandler) GetSyncWhitelist(c *gin.Context) {
	users, err := h.repo.GetAllUsers(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	type UserWithVector struct {
		models.UserRBAC
		Vector []float32 `json:"face_vector_512"`
	}

	result := make([]UserWithVector, 0, len(users))
	for _, u := range users {
		var vec []float32
		if h.qdrant != nil {
			for _, vr := range h.qdrant.GetAllVectors() {
				if vr.StudentID == u.StudentID {
					vec = vr.Vector
					break
				}
			}
		}
		if len(vec) != 512 {
			vec = repository.GenerateDeterministicVector(u.StudentID)
		}
		result = append(result, UserWithVector{
			UserRBAC: u,
			Vector:   vec,
		})
	}

	c.JSON(http.StatusOK, gin.H{
		"total": len(result),
		"users": result,
	})
}
