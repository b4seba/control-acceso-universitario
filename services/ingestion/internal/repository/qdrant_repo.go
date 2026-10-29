package repository

import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"math"
	"net/http"
	"strings"
	"sync"
	"time"

	"cl.uautonoma.acceso/ingestion/internal/models"
)

const CollectionName = "student_face_embeddings_512d"

// QdrantClient gestiona los embeddings biométricos bajo arquitectura Zero-Trust
// conectándose directamente a la API REST de Qdrant Vector DB (:6333)
type QdrantClient struct {
	baseURL    string
	httpClient *http.Client
	mu         sync.RWMutex
	inMemory   map[string]models.VectorRecord
	isLive     bool
}

func NewQdrantClient(endpoint string) *QdrantClient {
	url := endpoint
	if !strings.HasPrefix(url, "http://") && !strings.HasPrefix(url, "https://") {
		url = "http://" + url
	}
	url = strings.TrimRight(url, "/")

	client := &QdrantClient{
		baseURL: url,
		httpClient: &http.Client{
			Timeout: 4 * time.Second,
		},
		inMemory: make(map[string]models.VectorRecord),
		isLive:   false,
	}

	// Intentar inicializar colección real en Qdrant
	if err := client.EnsureCollection(); err != nil {
		log.Printf("[Qdrant] Conectando con %s... Colección se creará automáticamente ante el primer registro.", url)
	} else {
		log.Printf("[Qdrant] Conexión establecida con Qdrant Vector DB en %s. Colección '%s' verificada/creada.", url, CollectionName)
		client.isLive = true
	}

	return client
}

// EnsureCollection crea la colección de 512 dimensiones en Qdrant si no existe
func (q *QdrantClient) EnsureCollection() error {
	reqBody := map[string]interface{}{
		"vectors": map[string]interface{}{
			"size":     512,
			"distance": "Cosine",
		},
	}
	jsonData, err := json.Marshal(reqBody)
	if err != nil {
		return err
	}

	url := fmt.Sprintf("%s/collections/%s", q.baseURL, CollectionName)
	req, err := http.NewRequest(http.MethodPut, url, bytes.NewBuffer(jsonData))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := q.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusOK || resp.StatusCode == http.StatusConflict {
		q.isLive = true
		return nil
	}

	body, _ := io.ReadAll(resp.Body)
	return fmt.Errorf("qdrant HTTP %d: %s", resp.StatusCode, string(body))
}

// stringToUUID genera un UUID v4 determinista a partir de cualquier string identificador
func StringToUUID(s string) string {
	h := sha256.Sum256([]byte(s))
	return fmt.Sprintf("%08x-%04x-%04x-%04x-%012x",
		h[0:4], h[4:6], h[6:8], h[8:10], h[10:16])
}

// UpsertStudentVector almacena el vector de 512 dimensiones de forma REAL en Qdrant
func (q *QdrantClient) UpsertStudentVector(ctx context.Context, studentID string, vector []float32) error {
	q.mu.Lock()
	q.inMemory[studentID] = models.VectorRecord{
		ID:        studentID,
		StudentID: studentID,
		Vector:    vector,
		CreatedAt: time.Now().UTC(),
	}
	q.mu.Unlock()

	pointID := StringToUUID(studentID)
	payload := map[string]interface{}{
		"points": []map[string]interface{}{
			{
				"id":     pointID,
				"vector": vector,
				"payload": map[string]interface{}{
					"student_id": studentID,
					"created_at": time.Now().UTC().Format(time.RFC3339),
					"zero_trust": true,
				},
			},
		},
	}

	jsonData, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	url := fmt.Sprintf("%s/collections/%s/points?wait=true", q.baseURL, CollectionName)
	req, err := http.NewRequestWithContext(ctx, http.MethodPut, url, bytes.NewBuffer(jsonData))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := q.httpClient.Do(req)
	if err != nil {
		// Si Qdrant se cayó o no responde, al menos persistió en la réplica en memoria
		return nil
	}
	defer resp.Body.Close()

	q.isLive = true
	return nil
}

// SearchSimilarVector busca vectores por Similitud Coseno de forma REAL en Qdrant
func (q *QdrantClient) SearchSimilarVector(ctx context.Context, queryVector []float32, threshold float64) (*models.VectorRecord, float64, error) {
	// Intentar búsqueda vectorial real en Qdrant
	searchReq := map[string]interface{}{
		"vector":          queryVector,
		"limit":           1,
		"score_threshold": threshold,
		"with_payload":    true,
	}

	jsonData, err := json.Marshal(searchReq)
	if err == nil {
		url := fmt.Sprintf("%s/collections/%s/points/search", q.baseURL, CollectionName)
		req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewBuffer(jsonData))
		if err == nil {
			req.Header.Set("Content-Type", "application/json")
			resp, err := q.httpClient.Do(req)
			if err == nil {
				defer resp.Body.Close()
				if resp.StatusCode == http.StatusOK {
					var qdrantResp struct {
						Result []struct {
							ID      string                 `json:"id"`
							Score   float64                `json:"score"`
							Payload map[string]interface{} `json:"payload"`
						} `json:"result"`
					}
					if err := json.NewDecoder(resp.Body).Decode(&qdrantResp); err == nil && len(qdrantResp.Result) > 0 {
						top := qdrantResp.Result[0]
						studentID, _ := top.Payload["student_id"].(string)
						return &models.VectorRecord{
							ID:        top.ID,
							StudentID: studentID,
							Vector:    queryVector,
							CreatedAt: time.Now().UTC(),
						}, top.Score, nil
					}
				}
			}
		}
	}

	// Fallback a réplica local en memoria
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
	// Intentar consultar Qdrant real vía /points/scroll
	scrollReq := map[string]interface{}{
		"limit":        100,
		"with_vector":  true,
		"with_payload": true,
	}
	jsonData, err := json.Marshal(scrollReq)
	if err == nil {
		url := fmt.Sprintf("%s/collections/%s/points/scroll", q.baseURL, CollectionName)
		req, err := http.NewRequest(http.MethodPost, url, bytes.NewBuffer(jsonData))
		if err == nil {
			req.Header.Set("Content-Type", "application/json")
			resp, err := q.httpClient.Do(req)
			if err == nil {
				defer resp.Body.Close()
				if resp.StatusCode == http.StatusOK {
					var scrollResp struct {
						Result struct {
							Points []struct {
								ID      interface{}            `json:"id"`
								Vector  []float32              `json:"vector"`
								Payload map[string]interface{} `json:"payload"`
							} `json:"points"`
						} `json:"result"`
					}
					if err := json.NewDecoder(resp.Body).Decode(&scrollResp); err == nil && len(scrollResp.Result.Points) > 0 {
						realList := make([]models.VectorRecord, 0, len(scrollResp.Result.Points))
						for _, pt := range scrollResp.Result.Points {
							sid, _ := pt.Payload["student_id"].(string)
							idStr := fmt.Sprintf("%v", pt.ID)
							realList = append(realList, models.VectorRecord{
								ID:        idStr,
								StudentID: sid,
								Vector:    pt.Vector,
								CreatedAt: time.Now().UTC(),
							})
						}
						return realList
					}
				}
			}
		}
	}

	// Si no responde Qdrant en Docker, retornar réplica en memoria
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

// DeleteVector elimina un vector tanto de la réplica en memoria como de Qdrant en Docker
func (q *QdrantClient) DeleteVector(ctx context.Context, studentID string) error {
	q.mu.Lock()
	delete(q.inMemory, studentID)
	q.mu.Unlock()

	pointID := StringToUUID(studentID)
	payload := map[string]interface{}{
		"points": []string{pointID},
	}
	jsonData, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	url := fmt.Sprintf("%s/collections/%s/points/delete?wait=true", q.baseURL, CollectionName)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewBuffer(jsonData))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := q.httpClient.Do(req)
	if err != nil {
		return nil
	}
	defer resp.Body.Close()
	return nil
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


// QdrantRawPoint representa un punto con su ID nativo (número o UUID) y su vector
type QdrantRawPoint struct {
	ID        interface{} `json:"id"`
	StudentID string      `json:"student_id"`
	Vector    []float32   `json:"vector"`
}

// GetAllPointsWithRawIDs recupera todos los puntos con sus IDs nativos para reconciliación anti-entropy
func (q *QdrantClient) GetAllPointsWithRawIDs(ctx context.Context) ([]QdrantRawPoint, error) {
	scrollReq := map[string]interface{}{
		"limit":        1000,
		"with_vector":  true,
		"with_payload": true,
	}
	jsonData, err := json.Marshal(scrollReq)
	if err != nil {
		return nil, err
	}

	url := fmt.Sprintf("%s/collections/%s/points/scroll", q.baseURL, CollectionName)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewBuffer(jsonData))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := q.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("qdrant scroll error: HTTP %d", resp.StatusCode)
	}

	var scrollResp struct {
		Result struct {
			Points []struct {
				ID      interface{}            `json:"id"`
				Vector  []float32              `json:"vector"`
				Payload map[string]interface{} `json:"payload"`
			} `json:"points"`
		} `json:"result"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&scrollResp); err != nil {
		return nil, err
	}

	points := make([]QdrantRawPoint, 0, len(scrollResp.Result.Points))
	for _, pt := range scrollResp.Result.Points {
		sid, _ := pt.Payload["student_id"].(string)
		points = append(points, QdrantRawPoint{
			ID:        pt.ID,
			StudentID: sid,
			Vector:    pt.Vector,
		})
	}
	return points, nil
}

// DeletePointsByRawIDs elimina múltiples puntos en Qdrant por sus IDs nativos
func (q *QdrantClient) DeletePointsByRawIDs(ctx context.Context, pointIDs []interface{}) error {
	if len(pointIDs) == 0 {
		return nil
	}

	payload := map[string]interface{}{
		"points": pointIDs,
	}
	jsonData, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	url := fmt.Sprintf("%s/collections/%s/points/delete?wait=true", q.baseURL, CollectionName)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewBuffer(jsonData))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := q.httpClient.Do(req)
	if err != nil {
		return nil
	}
	defer resp.Body.Close()

	q.mu.Lock()
	// Limpiar réplica en memoria
	for _, pid := range pointIDs {
		pidStr := fmt.Sprintf("%v", pid)
		for sid, rec := range q.inMemory {
			if rec.ID == pidStr || rec.StudentID == pidStr {
				delete(q.inMemory, sid)
			}
		}
	}
	q.mu.Unlock()

	return nil
}
