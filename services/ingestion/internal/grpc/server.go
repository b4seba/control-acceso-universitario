package grpc

import (
	"context"
	"fmt"
	"log"
	"net"
	"strings"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"

	"cl.uautonoma.acceso/ingestion/internal/crypto"
	"cl.uautonoma.acceso/ingestion/internal/models"
	"cl.uautonoma.acceso/ingestion/internal/repository"
	"cl.uautonoma.acceso/ingestion/internal/workerpool"
)

// TurnstileGRPCServer gestiona conexiones binarias HTTP/2 de alta velocidad para torniquetes Edge
type TurnstileGRPCServer struct {
	pool       *workerpool.WorkerPool
	repo       repository.RepositoryInterface
	qdrant     *repository.QdrantClient
	grpcServer *grpc.Server
	startTime  time.Time
}

// NewTurnstileGRPCServer inicializa el servidor gRPC con interceptores de seguridad JWT
func NewTurnstileGRPCServer(
	pool *workerpool.WorkerPool,
	repo repository.RepositoryInterface,
	qdrant *repository.QdrantClient,
) *TurnstileGRPCServer {
	s := &TurnstileGRPCServer{
		pool:      pool,
		repo:      repo,
		qdrant:    qdrant,
		startTime: time.Now().UTC(),
	}

	// Servidor gRPC con middleware / interceptor unario para validación de tokens JWT
	server := grpc.NewServer(
		grpc.UnaryInterceptor(s.jwtAuthInterceptor),
	)

	s.grpcServer = server
	return s
}

// jwtAuthInterceptor valida la presencia y autenticidad del JWT RFC 7519 en los metadatos gRPC
func (s *TurnstileGRPCServer) jwtAuthInterceptor(
	ctx context.Context,
	req interface{},
	info *grpc.UnaryServerInfo,
	handler grpc.UnaryHandler,
) (interface{}, error) {
	// Permitir healthchecks sin autenticación
	if strings.Contains(info.FullMethod, "HealthCheck") {
		return handler(ctx, req)
	}

	md, ok := metadata.FromIncomingContext(ctx)
	if !ok {
		return nil, status.Errorf(codes.Unauthenticated, "Metadatos gRPC no encontrados")
	}

	authHeaders := md.Get("authorization")
	if len(authHeaders) == 0 {
		return nil, status.Errorf(codes.Unauthenticated, "Cabecera authorization requerida en metadatos gRPC")
	}

	tokenStr := strings.TrimPrefix(authHeaders[0], "Bearer ")

	// Validación de token de nodo Edge o JWT institucional
	if tokenStr != "UA_EDGE_TOKEN_2026_JWT" {
		claims, err := crypto.ValidateJWT(tokenStr)
		if err != nil {
			return nil, status.Errorf(codes.PermissionDenied, "Token JWT gRPC inválido o expirado: %v", err)
		}
		// Inyectar claims en contexto
		ctx = context.WithValue(ctx, "student_id", claims.StudentID)
		ctx = context.WithValue(ctx, "role", claims.Role)
	}

	return handler(ctx, req)
}

// Start arranca el servidor gRPC en el puerto especificado (por defecto 50051)
func (s *TurnstileGRPCServer) Start(port int) error {
	lis, err := net.Listen("tcp", fmt.Sprintf("0.0.0.0:%d", port))
	if err != nil {
		return fmt.Errorf("error al enlazar puerto gRPC %d: %w", port, err)
	}

	log.Printf("[gRPC] Servidor de Ingesta Binario (HTTP/2 + Protobuf) escuchando en :%d", port)
	return s.grpcServer.Serve(lis)
}

// Stop realiza un apagado ordenado del servidor gRPC
func (s *TurnstileGRPCServer) Stop() {
	if s.grpcServer != nil {
		s.grpcServer.GracefulStop()
		log.Println("[gRPC] Servidor gRPC finalizado ordenadamente.")
	}
}

// IngestBatchHandler procesa un lote de eventos desde torniquetes perimetrales
func (s *TurnstileGRPCServer) IngestBatchHandler(ctx context.Context, batch models.BatchRequest) (*models.BatchResponse, error) {
	// Enviar al Worker Pool para amortiguar la Tormenta de Reconexión
	res, err := s.pool.Submit(batch)
	if err != nil {
		return nil, status.Errorf(codes.ResourceExhausted, "Worker Pool saturado: %v", err)
	}

	return &res, nil
}
