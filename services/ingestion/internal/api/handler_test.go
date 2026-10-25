package api

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"cl.uautonoma.acceso/ingestion/internal/models"
	"cl.uautonoma.acceso/ingestion/internal/repository"
	"cl.uautonoma.acceso/ingestion/internal/workerpool"
	"github.com/gin-gonic/gin"
)

func TestAPIHandler_HealthAndBatchEndpoints(t *testing.T) {
	gin.SetMode(gin.TestMode)

	repo := repository.NewInMemoryRepository()
	qdrant := repository.NewQdrantClient("localhost:6333")
	qdrant.SeedInitialVectors()

	pool := workerpool.NewWorkerPool(4, 50, repo)
	pool.Start()
	defer pool.Stop()

	handler := NewAPIHandler(pool, repo, qdrant)
	router := gin.New()
	handler.RegisterRoutes(router)

	// 1. Probar GET /api/v1/health
	reqHealth, _ := http.NewRequest("GET", "/api/v1/health", nil)
	wHealth := httptest.NewRecorder()
	router.ServeHTTP(wHealth, reqHealth)

	if wHealth.Code != http.StatusOK {
		t.Fatalf("Healthcheck fallo con código: %d", wHealth.Code)
	}

	// 2. Probar POST /api/v1/ingest/batch sin autenticación (Debe dar 401)
	batchPayload := models.BatchRequest{
		TurnstileID:       "TRN-PROV-01",
		CampusID:          "CAMPUS_PROVIDENCIA",
		DispatchTimestamp: time.Now().UTC().Format(time.RFC3339),
		EventsCount:       1,
		Events: []models.OutboxEvent{
			{
				EventUUID:       "evt-e2e-001",
				TurnstileID:     "TRN-PROV-01",
				CampusID:        "CAMPUS_PROVIDENCIA",
				StudentID:       "ua-stu-2026-001",
				StudentRUT:      "20.456.789-K",
				AccessTimestamp: time.Now().UTC().Format(time.RFC3339),
				AccessResult:    "GRANTED",
				LatencyMs:       94,
				PayloadHash:     "hash-sha256-test",
				Status:          "PENDING",
			},
		},
	}

	bodyBytes, _ := json.Marshal(batchPayload)

	reqUnauth, _ := http.NewRequest("POST", "/api/v1/ingest/batch", bytes.NewBuffer(bodyBytes))
	reqUnauth.Header.Set("Content-Type", "application/json")
	wUnauth := httptest.NewRecorder()
	router.ServeHTTP(wUnauth, reqUnauth)

	if wUnauth.Code != http.StatusUnauthorized {
		t.Fatalf("Esperado 401 Unauthorized sin Bearer token, obtenido: %d", wUnauth.Code)
	}

	// 3. Probar POST /api/v1/ingest/batch con Bearer Token legítimo (Debe dar 200 OK)
	reqAuth, _ := http.NewRequest("POST", "/api/v1/ingest/batch", bytes.NewBuffer(bodyBytes))
	reqAuth.Header.Set("Content-Type", "application/json")
	reqAuth.Header.Set("Authorization", "Bearer UA_EDGE_TOKEN_2026_JWT")
	wAuth := httptest.NewRecorder()
	router.ServeHTTP(wAuth, reqAuth)

	if wAuth.Code != http.StatusOK {
		t.Fatalf("Esperado 200 OK con token válido, obtenido: %d, body: %s", wAuth.Code, wAuth.Body.String())
	}

	var batchResp models.BatchResponse
	if err := json.Unmarshal(wAuth.Body.Bytes(), &batchResp); err != nil {
		t.Fatalf("Error al deserializar respuesta de lote: %v", err)
	}

	if batchResp.Status != "ACK_CONFIRMED" {
		t.Fatalf("Status esperado ACK_CONFIRMED, obtenido: %s", batchResp.Status)
	}

	if batchResp.AckMap["evt-e2e-001"] == "" {
		t.Fatalf("ACK hash no encontrado para evt-e2e-001")
	}

	// 4. Probar GET /api/v1/vectors (Qdrant Zero-Trust)
	reqVec, _ := http.NewRequest("GET", "/api/v1/vectors", nil)
	wVec := httptest.NewRecorder()
	router.ServeHTTP(wVec, reqVec)

	if wVec.Code != http.StatusOK {
		t.Fatalf("Esperado 200 OK para GET /api/v1/vectors, obtenido: %d", wVec.Code)
	}

	t.Logf("✓ API Handler validado: Healthcheck OK, Auth 401 OK, Batch Ingestion ACK 200 OK, Qdrant Vectors 200 OK")
}
