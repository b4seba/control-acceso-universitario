package grpc

import (
	"context"
	"net"
	"testing"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
	"google.golang.org/grpc/test/bufconn"

	"cl.uautonoma.acceso/ingestion/internal/grpc/pb"
	"cl.uautonoma.acceso/ingestion/internal/models"
	"cl.uautonoma.acceso/ingestion/internal/repository"
	"cl.uautonoma.acceso/ingestion/internal/workerpool"
)

func TestTurnstileGRPCServer_IngestAndSyncWhitelist(t *testing.T) {
	repo := repository.NewInMemoryRepository()
	if err := repo.CreateUser(context.Background(), models.UserRBAC{
		StudentID:        "ua-stu-grpc-01",
		RUT:              "21.111.222-3",
		FullName:         "Estudiante gRPC",
		Email:            "grpc@cloud.uautonoma.cl",
		Role:             "ESTUDIANTE",
		Career:           "Informática",
		Campus:           "CAMPUS_PROVIDENCIA",
		EnrollmentStatus: "VIGENTE",
	}); err != nil {
		t.Fatalf("error creando usuario semilla en memoria: %v", err)
	}

	qdrant := repository.NewQdrantClient("localhost:6333")
	pool := workerpool.NewWorkerPool(2, 20, repo)
	pool.Start()
	defer pool.Stop()

	srv := NewTurnstileGRPCServer(pool, repo, qdrant)
	lis := bufconn.Listen(1024 * 1024)
	go func() {
		_ = srv.grpcServer.Serve(lis)
	}()
	defer srv.Stop()

	conn, err := grpc.NewClient(
		"passthrough:///bufnet",
		grpc.WithContextDialer(func(context.Context, string) (net.Conn, error) {
			return lis.Dial()
		}),
		grpc.WithTransportCredentials(insecure.NewCredentials()),
	)
	if err != nil {
		t.Fatalf("error creando cliente bufconn gRPC: %v", err)
	}
	defer conn.Close()

	client := pb.NewTurnstileIngestServiceClient(conn)

	// 1. HealthCheck sin token debe responder HEALTHY
	hc, err := client.HealthCheck(context.Background(), &pb.HealthCheckRequest{ClientId: "TRN-TEST"})
	if err != nil || hc.Status != "HEALTHY" {
		t.Fatalf("HealthCheck gRPC falló: resp=%v err=%v", hc, err)
	}

	// 2. SyncWhitelist sin token debe fallar con Unauthenticated
	_, err = client.SyncWhitelist(context.Background(), &pb.SyncWhitelistRequest{TurnstileId: "TRN-TEST"})
	if status.Code(err) != codes.Unauthenticated {
		t.Fatalf("esperado Unauthenticated sin metadata, obtenido: %v", err)
	}

	authCtx := metadata.NewOutgoingContext(
		context.Background(),
		metadata.Pairs("authorization", "Bearer UA_EDGE_TOKEN_2026_JWT"),
	)

	// 3. SyncWhitelist autenticado debe devolver usuario y vector 512D
	wlResp, err := client.SyncWhitelist(authCtx, &pb.SyncWhitelistRequest{TurnstileId: "TRN-TEST"})
	if err != nil {
		t.Fatalf("SyncWhitelist gRPC falló: %v", err)
	}
	if wlResp.TotalUsers != 1 || len(wlResp.Users) != 1 || len(wlResp.Users[0].FaceVector_512) != 512 {
		t.Fatalf("respuesta SyncWhitelist inesperada: total=%d users=%d", wlResp.TotalUsers, len(wlResp.Users))
	}

	// 4. IngestBatch autenticado debe devolver ACK_CONFIRMED con ack_map
	batchResp, err := client.IngestBatch(authCtx, &pb.BatchIngestRequest{
		TurnstileId:       "TRN-TEST",
		CampusId:          "CAMPUS_PROVIDENCIA",
		DispatchTimestamp: time.Now().UTC().Format(time.RFC3339),
		EventsCount:       1,
		Events: []*pb.OutboxEventProto{
			{
				EventUuid:       "evt-grpc-001",
				TurnstileId:     "TRN-TEST",
				CampusId:        "CAMPUS_PROVIDENCIA",
				StudentId:       "ua-stu-grpc-01",
				StudentRut:      "21.111.222-3",
				AccessTimestamp: time.Now().UTC().Format(time.RFC3339),
				AccessResult:    "GRANTED",
				LatencyMs:       85,
				PayloadHash:     "hash-grpc-test-001",
			},
		},
	})
	if err != nil {
		t.Fatalf("IngestBatch gRPC falló: %v", err)
	}
	if batchResp.Status != "ACK_CONFIRMED" || batchResp.AckMap["evt-grpc-001"] == "" {
		t.Fatalf("respuesta IngestBatch inesperada: %+v", batchResp)
	}
}
