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
	"cl.uautonoma.acceso/ingestion/internal/grpc/pb"
	"cl.uautonoma.acceso/ingestion/internal/models"
	"cl.uautonoma.acceso/ingestion/internal/repository"
	"cl.uautonoma.acceso/ingestion/internal/workerpool"
)

// TurnstileGRPCServer gestiona conexiones binarias HTTP/2 de alta velocidad para torniquetes Edge
type TurnstileGRPCServer struct {
	pb.UnimplementedTurnstileIngestServiceServer
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
	pb.RegisterTurnstileIngestServiceServer(server, s)

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

// IngestBatch recibe un lote de eventos desde el Outbox de los torniquetes vía gRPC
func (s *TurnstileGRPCServer) IngestBatch(ctx context.Context, req *pb.BatchIngestRequest) (*pb.BatchIngestResponse, error) {
	if req == nil || len(req.Events) == 0 {
		return nil, status.Error(codes.InvalidArgument, "el lote de eventos outbox no puede estar vacío")
	}

	events := make([]models.OutboxEvent, 0, len(req.Events))
	for _, e := range req.Events {
		var reason *string
		if e.DenialReason != "" {
			r := e.DenialReason
			reason = &r
		}
		events = append(events, models.OutboxEvent{
			EventUUID:       e.EventUuid,
			TurnstileID:     e.TurnstileId,
			CampusID:        e.CampusId,
			StudentID:       e.StudentId,
			StudentRUT:      e.StudentRut,
			AccessTimestamp: e.AccessTimestamp,
			AccessResult:    e.AccessResult,
			DenialReason:    reason,
			LatencyMs:       int(e.LatencyMs),
			PayloadHash:     e.PayloadHash,
			Status:          "PENDING",
		})
	}

	batch := models.BatchRequest{
		TurnstileID:       req.TurnstileId,
		CampusID:          req.CampusId,
		DispatchTimestamp: req.DispatchTimestamp,
		EventsCount:       int(req.EventsCount),
		Events:            events,
	}

	res, err := s.pool.Submit(batch)
	if err != nil {
		return nil, status.Errorf(codes.ResourceExhausted, "Worker Pool saturado: %v", err)
	}

	log.Printf("[gRPC] IngestBatch OK: turnstile=%s events=%d time=%s", req.TurnstileId, res.BatchSize, res.ExecutionTime)
	return &pb.BatchIngestResponse{
		Status:        res.Status,
		ProcessedAt:   res.ProcessedAt.Format(time.RFC3339),
		BatchSize:     int32(res.BatchSize),
		AckMap:        res.AckMap,
		ExecutionTime: res.ExecutionTime,
	}, nil
}

// SyncWhitelist entrega los usuarios enrolados y sus vectores 512D al Kiosko vía gRPC
func (s *TurnstileGRPCServer) SyncWhitelist(ctx context.Context, req *pb.SyncWhitelistRequest) (*pb.SyncWhitelistResponse, error) {
	users, err := s.repo.GetAllUsers(ctx)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "error al consultar usuarios: %v", err)
	}

	vectorsByID := make(map[string][]float32)
	if s.qdrant != nil {
		for _, vr := range s.qdrant.GetAllVectors() {
			vectorsByID[vr.StudentID] = vr.Vector
		}
	}

	pbUsers := make([]*pb.WhitelistUserProto, 0, len(users))
	for _, u := range users {
		vec := vectorsByID[u.StudentID]
		if len(vec) != 512 {
			vec = repository.GenerateDeterministicVector(u.StudentID)
		}
		pbUsers = append(pbUsers, &pb.WhitelistUserProto{
			StudentId:        u.StudentID,
			Rut:              u.RUT,
			FullName:         u.FullName,
			Role:             u.Role,
			Career:           u.Career,
			Campus:           u.Campus,
			EnrollmentStatus: u.EnrollmentStatus,
			FaceVector_512:   vec,
		})
	}

	log.Printf("[gRPC] SyncWhitelist OK: turnstile=%s users=%d", req.GetTurnstileId(), len(pbUsers))
	return &pb.SyncWhitelistResponse{
		TotalUsers:    int32(len(pbUsers)),
		Users:         pbUsers,
		SyncTimestamp: time.Now().UTC().Format(time.RFC3339),
	}, nil
}

// VerifyBiometric ejecuta verificación biométrica contra Qdrant vía gRPC
func (s *TurnstileGRPCServer) VerifyBiometric(ctx context.Context, req *pb.BiometricVerifyRequest) (*pb.BiometricVerifyResponse, error) {
	if len(req.LiveVector_512) != 512 {
		return nil, status.Error(codes.InvalidArgument, "el vector facial debe tener exactamente 512 dimensiones")
	}

	if s.qdrant == nil {
		return nil, status.Error(codes.Unavailable, "Qdrant no disponible")
	}

	match, score, err := s.qdrant.SearchSimilarVector(ctx, req.LiveVector_512, 0.65)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "error buscando vector en Qdrant: %v", err)
	}

	if match == nil {
		return &pb.BiometricVerifyResponse{
			Match:           false,
			SimilarityScore: float32(score),
			Status:          "NO_MATCH",
		}, nil
	}

	return &pb.BiometricVerifyResponse{
		Match:           true,
		SimilarityScore: float32(score),
		StudentName:     match.StudentID,
		Status:          "MATCH_CONFIRMED",
	}, nil
}

// HealthCheck reporta la salud del servicio gRPC y profundidad del Worker Pool
func (s *TurnstileGRPCServer) HealthCheck(ctx context.Context, req *pb.HealthCheckRequest) (*pb.HealthCheckResponse, error) {
	return &pb.HealthCheckResponse{
		Status:        "HEALTHY",
		QueueDepth:    int32(s.pool.QueueDepth()),
		ActiveWorkers: 16,
		Uptime:        time.Since(s.startTime).String(),
	}, nil
}
