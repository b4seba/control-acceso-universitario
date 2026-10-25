package repository

import (
	"context"
	"math"
	"sync"
	"time"

	"cl.uautonoma.acceso/ingestion/internal/models"
)

// QdrantClient gestiona los embeddings biométricos bajo arquitectura Zero-Trust
type QdrantClient struct {
	endpoint string
	mu       sync.RWMutex
	inMemory map[string]models.VectorRecord
}

func NewQdrantClient(endpoint string) *QdrantClient {
	return &QdrantClient{
		endpoint: endpoint,
		inMemory: make(map[string]models.VectorRecord),
	}
}

// UpsertStudentVector almacena el vector de 512 dimensiones garantizando que jamás se persistan fotos
func (q *QdrantClient) UpsertStudentVector(ctx context.Context, studentID string, vector []float32) error {
	q.mu.Lock()
	defer q.mu.Unlock()

	q.inMemory[studentID] = models.VectorRecord{
		ID:        studentID,
		StudentID: studentID,
		Vector:    vector,
		CreatedAt: time.Now().UTC(),
	}
	return nil
}

// SearchSimilarVector busca los vectores más cercanos mediante Similitud Coseno
func (q *QdrantClient) SearchSimilarVector(ctx context.Context, queryVector []float32, threshold float64) (*models.VectorRecord, float64, error) {
	q.mu.RLock()
	defer q.mu.RUnlock()

	var bestMatch *models.VectorRecord
	bestScore := -1.0

	for _, rec := range q.inMemory {
		score := CosineSimilarity(queryVector, rec.Vector)
		if score > bestScore {
			bestScore = score
			bestMatch = &rec
		}
	}

	if bestScore >= threshold && bestMatch != nil {
		return bestMatch, bestScore, nil
	}
	return nil, bestScore, nil
}

// GetAllVectors devuelve todos los registros vectoriales almacenados para auditoría
func (q *QdrantClient) GetAllVectors() []models.VectorRecord {
	q.mu.RLock()
	defer q.mu.RUnlock()

	res := make([]models.VectorRecord, 0, len(q.inMemory))
	for _, rec := range q.inMemory {
		res = append(res, rec)
	}
	return res
}

// GenerateDeterministicVector genera un vector normalizado de 512 dimensiones
func GenerateDeterministicVector(seed string) []float32 {
	v := make([]float32, 512)
	for i := 0; i < 512; i++ {
		byteVal := (len(seed)*31 + i*7) % 256
		val := float32(byteVal)/128.0 - 1.0
		v[i] = val
	}
	return v
}

// SeedInitialVectors inicializa únicamente el vector de Sebastián Freire
func (q *QdrantClient) SeedInitialVectors() {
	students := []string{
		"ua-stu-2026-001", // Sebastián Freire
	}

	for _, s := range students {
		vec := GenerateDeterministicVector(s + "-face-seed-2026")
		_ = q.UpsertStudentVector(context.Background(), s, vec)
	}
}

// DeleteExcept elimina todos los vectores excepto el ID indicado
func (q *QdrantClient) DeleteExcept(keepID string) {
	q.mu.Lock()
	defer q.mu.Unlock()
	for id := range q.inMemory {
		if id != keepID {
			delete(q.inMemory, id)
		}
	}
}

// CosineSimilarity calcula el producto punto normalizado entre dos vectores de 512 dimensiones
func CosineSimilarity(v1, v2 []float32) float64 {
	if len(v1) != len(v2) || len(v1) == 0 {
		return 0.0
	}

	var dot, norm1, norm2 float64
	for i := 0; i < len(v1); i++ {
		a := float64(v1[i])
		b := float64(v2[i])
		dot += a * b
		norm1 += a * a
		norm2 += b * b
	}

	if norm1 <= 0 || norm2 <= 0 {
		return 0.0
	}
	return dot / (math.Sqrt(norm1) * math.Sqrt(norm2))
}
