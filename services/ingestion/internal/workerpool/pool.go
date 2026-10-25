package workerpool

import (
	"context"
	"fmt"
	"log"
	"sync"
	"time"

	"cl.uautonoma.acceso/ingestion/internal/crypto"
	"cl.uautonoma.acceso/ingestion/internal/models"
	"cl.uautonoma.acceso/ingestion/internal/repository"
)

// IngestJob representa un lote de trabajo encolado en el Worker Pool
type IngestJob struct {
	Batch      models.BatchRequest
	RespChan   chan JobResult
	EnqueuedAt time.Time
}

// JobResult contiene el resultado del procesamiento del lote
type JobResult struct {
	Response models.BatchResponse
	Err      error
}

// WorkerPool gestiona un grupo de goroutines concurrentes para mitigar la Tormenta de Reconexión
type WorkerPool struct {
	workerCount int
	jobQueue    chan IngestJob
	repo        repository.RepositoryInterface
	wg          sync.WaitGroup
	ctx         context.Context
	cancel      context.CancelFunc
	mu          sync.Mutex
	lastHash    string
}

// NewWorkerPool inicializa el Worker Pool con N goroutines y un canal buffered
func NewWorkerPool(workerCount int, queueCapacity int, repo repository.RepositoryInterface) *WorkerPool {
	ctx, cancel := context.WithCancel(context.Background())
	return &WorkerPool{
		workerCount: workerCount,
		jobQueue:    make(chan IngestJob, queueCapacity),
		repo:        repo,
		ctx:         ctx,
		cancel:      cancel,
		lastHash:    crypto.GenesisHash,
	}
}

// Start arranca las N goroutines de procesamiento concurrente
func (wp *WorkerPool) Start() {
	// Inicializar último hash conocido desde la base de datos
	if wp.repo != nil {
		h, err := wp.repo.GetLatestHash(wp.ctx)
		if err == nil && h != "" {
			wp.lastHash = h
		}
	}

	log.Printf("[WorkerPool] Iniciando %d goroutines de ingesta (Buffer capacidad: %d)...",
		wp.workerCount, cap(wp.jobQueue))

	for i := 1; i <= wp.workerCount; i++ {
		wp.wg.Add(1)
		go wp.worker(i)
	}
}

// Submit envía un lote a la cola con control de Backpressure
func (wp *WorkerPool) Submit(batch models.BatchRequest) (models.BatchResponse, error) {
	respChan := make(chan JobResult, 1)
	job := IngestJob{
		Batch:      batch,
		RespChan:   respChan,
		EnqueuedAt: time.Now(),
	}

	select {
	case wp.jobQueue <- job:
		// Encolado exitosamente
		res := <-respChan
		return res.Response, res.Err
	case <-time.After(1500 * time.Millisecond):
		// Backpressure: Cola saturada ante Tormenta de Reconexión masiva
		return models.BatchResponse{}, fmt.Errorf("HTTP 429: Worker Pool saturado por Tormenta de Reconexión. Reintente con backoff")
	}
}

// worker ejecuta el ciclo de vida de cada goroutine individual
func (wp *WorkerPool) worker(id int) {
	defer wp.wg.Done()

	for {
		select {
		case <-wp.ctx.Done():
			return
		case job, ok := <-wp.jobQueue:
			if !ok {
				return
			}
			wp.processJob(id, job)
		}
	}
}

// processJob realiza el hash-chaining forense y la persistencia
func (wp *WorkerPool) processJob(workerID int, job IngestJob) {
	startTime := time.Now()
	batch := job.Batch
	ackMap := make(map[string]string)
	records := make([]models.AccessAuditRecord, 0, len(batch.Events))

	wp.mu.Lock()
	for _, ev := range batch.Events {
		// Encadenamiento criptográfico con el hash previo
		currHash := crypto.ComputeCurrentHash(
			wp.lastHash,
			ev.EventUUID,
			ev.AccessTimestamp,
			ev.AccessResult,
			ev.LatencyMs,
			ev.PayloadHash,
		)

		ackHash := crypto.ComputeAckHash(ev.EventUUID, currHash)
		ackMap[ev.EventUUID] = ackHash

		t, err := time.Parse(time.RFC3339, ev.AccessTimestamp)
		if err != nil {
			t = time.Now().UTC()
		}

		denialReason := ""
		if ev.DenialReason != nil {
			denialReason = *ev.DenialReason
		}

		records = append(records, models.AccessAuditRecord{
			EventUUID:       ev.EventUUID,
			TurnstileID:     ev.TurnstileID,
			CampusID:        ev.CampusID,
			StudentID:       ev.StudentID,
			StudentRUT:      ev.StudentRUT,
			AccessTimestamp: t,
			AccessResult:    ev.AccessResult,
			DenialReason:    denialReason,
			LatencyMs:       ev.LatencyMs,
			PayloadHash:     ev.PayloadHash,
			PreviousHash:    wp.lastHash,
			CurrentHash:     currHash,
			IngestedAt:      time.Now().UTC(),
		})

		wp.lastHash = currHash
	}
	wp.mu.Unlock()

	// Persistir en base de datos si el repositorio está configurado
	var persistErr error
	if wp.repo != nil {
		persistErr = wp.repo.PersistBatch(wp.ctx, records)
	}

	elapsed := time.Since(startTime)

	resp := models.BatchResponse{
		Status:        "ACK_CONFIRMED",
		ProcessedAt:   time.Now().UTC(),
		BatchSize:     len(batch.Events),
		AckMap:        ackMap,
		ExecutionTime: elapsed.String(),
	}

	job.RespChan <- JobResult{
		Response: resp,
		Err:      persistErr,
	}
}

// QueueDepth retorna la cantidad actual de lotes esperando en el canal
func (wp *WorkerPool) QueueDepth() int {
	return len(wp.jobQueue)
}

// Stop finaliza ordenadamente el Worker Pool (Graceful Shutdown)
func (wp *WorkerPool) Stop() {
	wp.cancel()
	close(wp.jobQueue)
	wp.wg.Wait()
}
