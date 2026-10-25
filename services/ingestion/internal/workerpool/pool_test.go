package workerpool

import (
	"context"
	"fmt"
	"sync"
	"testing"
	"time"

	"cl.uautonoma.acceso/ingestion/internal/crypto"
	"cl.uautonoma.acceso/ingestion/internal/models"
	"cl.uautonoma.acceso/ingestion/internal/repository"
)

func TestWorkerPool_ReconnectionStormSimulation(t *testing.T) {
	// 1. Inicializar repositorio en memoria
	repo := repository.NewInMemoryRepository()

	// 2. Crear Worker Pool con 8 goroutines y buffer de 100
	wp := NewWorkerPool(8, 100, repo)
	wp.Start()
	defer wp.Stop()

	// 3. Simular Tormenta de Reconexión: 15 torniquetes despachando concurrentemente
	torniquetesCount := 15
	eventsPerTurnstile := 10
	var wg sync.WaitGroup

	startTime := time.Now()

	for trn := 1; trn <= torniquetesCount; trn++ {
		wg.Add(1)
		go func(trnID int) {
			defer wg.Done()

			batch := models.BatchRequest{
				TurnstileID:       fmt.Sprintf("TRN-TEST-%02d", trnID),
				CampusID:          "CAMPUS_PROVIDENCIA",
				DispatchTimestamp: time.Now().UTC().Format(time.RFC3339),
				EventsCount:       eventsPerTurnstile,
				Events:            make([]models.OutboxEvent, 0, eventsPerTurnstile),
			}

			for ev := 1; ev <= eventsPerTurnstile; ev++ {
				uuid := fmt.Sprintf("evt-trn%d-ev%d", trnID, ev)
				batch.Events = append(batch.Events, models.OutboxEvent{
					EventUUID:       uuid,
					TurnstileID:     batch.TurnstileID,
					CampusID:        batch.CampusID,
					StudentID:       "ua-stu-2026-001",
					StudentRUT:      "20.456.789-K",
					AccessTimestamp: time.Now().UTC().Format(time.RFC3339),
					AccessResult:    "GRANTED",
					LatencyMs:       92,
					PayloadHash:     "hash-payload-simulated",
					Status:          "PENDING",
				})
			}

			resp, err := wp.Submit(batch)
			if err != nil {
				t.Errorf("Error al procesar lote del torniquete %d: %v", trnID, err)
				return
			}

			if resp.Status != "ACK_CONFIRMED" {
				t.Errorf("Estado inesperado: %s", resp.Status)
			}

			if len(resp.AckMap) != eventsPerTurnstile {
				t.Errorf("Cantidad de ACKs incorrecta: esperada %d, obtenida %d",
					eventsPerTurnstile, len(resp.AckMap))
			}
		}(trn)
	}

	wg.Wait()
	elapsed := time.Since(startTime)

	totalExpectedEvents := torniquetesCount * eventsPerTurnstile
	logs, err := repo.GetRecentAuditLogs(context.Background(), totalExpectedEvents+10)
	if err != nil {
		t.Fatalf("Error al consultar logs: %v", err)
	}

	if len(logs) != totalExpectedEvents {
		t.Fatalf("Total de registros en BD incorrecto: esperado %d, obtenido %d",
			totalExpectedEvents, len(logs))
	}

	t.Logf("✓ Tormenta de Reconexión absorbida exitosamente: %d eventos procesados en %v",
		totalExpectedEvents, elapsed)
}

func TestForensicHashChainIntegrity(t *testing.T) {
	prev := crypto.GenesisHash
	evUUID := "evt-audit-check-001"
	ts := time.Now().UTC().Format(time.RFC3339)
	res := "GRANTED"
	lat := 94
	pHash := "sha256-payload"

	curr := crypto.ComputeCurrentHash(prev, evUUID, ts, res, lat, pHash)
	if curr == "" || len(curr) != 64 {
		t.Fatalf("Hash SHA-256 inválido: %s", curr)
	}

	ack := crypto.ComputeAckHash(evUUID, curr)
	if ack == "" || len(ack) != 64 {
		t.Fatalf("ACK Hash SHA-256 inválido: %s", ack)
	}

	valid := crypto.VerifyChainIntegrity(prev, evUUID, ts, res, lat, pHash, curr)
	if !valid {
		t.Fatalf("Integridad forense de la cadena corrupta")
	}
}

func TestQdrantCosineSimilarity(t *testing.T) {
	v1 := make([]float32, 512)
	v2 := make([]float32, 512)
	for i := 0; i < 512; i++ {
		v1[i] = float32(i) / 512.0
		v2[i] = float32(i) / 512.0
	}

	sim := repository.CosineSimilarity(v1, v2)
	if sim < 0.9999 {
		t.Fatalf("Similitud Coseno de vectores idénticos debe ser 1.0, obtenida: %f", sim)
	}
}
