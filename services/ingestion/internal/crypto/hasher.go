package crypto

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
)

const GenesisHash = "0000000000000000000000000000000000000000000000000000000000000000"

// ComputeCurrentHash implementa el encadenamiento forense (hash-chaining) estilo blockchain.
// Formula: current_hash = SHA256(previous_hash + "|" + event_uuid + "|" + timestamp + "|" + result + "|" + latency + "|" + payload_hash)
func ComputeCurrentHash(previousHash, eventUUID, timestamp, result string, latencyMs int, payloadHash string) string {
	if previousHash == "" {
		previousHash = GenesisHash
	}
	raw := fmt.Sprintf("%s|%s|%s|%s|%d|%s",
		previousHash, eventUUID, timestamp, result, latencyMs, payloadHash)

	h := sha256.New()
	h.Write([]byte(raw))
	return hex.EncodeToString(h.Sum(nil))
}

// ComputeAckHash calcula el acuse de recibo criptográfico devuelto al Kiosko Edge
func ComputeAckHash(eventUUID, currentHash string) string {
	raw := fmt.Sprintf("ACK|%s|%s|UA_CENTRAL_2026", eventUUID, currentHash)
	h := sha256.New()
	h.Write([]byte(raw))
	return hex.EncodeToString(h.Sum(nil))
}

// ComputeSHA256 calcula el hash SHA-256 de una cadena de texto
func ComputeSHA256(raw string) string {
	h := sha256.New()
	h.Write([]byte(raw))
	return hex.EncodeToString(h.Sum(nil))
}

// VerifyChainIntegrity verifica matemáticamente si un registro enlaza de forma legítima con su predecesor
func VerifyChainIntegrity(previousHash, eventUUID, timestamp, result string, latencyMs int, payloadHash, currentHash string) bool {
	expected := ComputeCurrentHash(previousHash, eventUUID, timestamp, result, latencyMs, payloadHash)
	return expected == currentHash
}
