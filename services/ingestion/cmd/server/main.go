package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"cl.uautonoma.acceso/ingestion/internal/api"
	edgegrpc "cl.uautonoma.acceso/ingestion/internal/grpc"
	"cl.uautonoma.acceso/ingestion/internal/repository"
	"cl.uautonoma.acceso/ingestion/internal/workerpool"
	"github.com/gin-gonic/gin"
)

func main() {
	fmt.Println("================================================================================")
	fmt.Println(" UNIVERSIDAD - MICROSERVICIO DE INGESTA CENTRAL (GOLANG)")
	fmt.Println(" Concurrencia con Worker Pools, PostgreSQL 16 y Qdrant Vector DB")
	fmt.Println("================================================================================")

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	pgConnStr := os.Getenv("DATABASE_URL")
	if pgConnStr == "" {
		pgConnStr = "postgres://postgres:ua2026pass@localhost:5432/ua_access_db?sslmode=disable"
	}

	// 1. Inicialización de Repositorio (PostgreSQL con fallback a InMemory)
	var repo repository.RepositoryInterface
	pgRepo, err := repository.NewPostgresRepository(pgConnStr)
	if err != nil {
		log.Printf("[Repo] PostgreSQL no detectado en %s (%v). Activando InMemoryRepository con hash-chaining.", pgConnStr, err)
		repo = repository.NewInMemoryRepository()
	} else {
		log.Printf("[Repo] Conectado exitosamente al pool de PostgreSQL 16.")
		repo = pgRepo
	}

	// 2. Inicialización de Qdrant Vector DB (Zero-Trust: solo vectores de 512D)
	qdrantEndpoint := os.Getenv("QDRANT_URL")
	if qdrantEndpoint == "" {
		qdrantEndpoint = "localhost:6333"
	}
	qdrantClient := repository.NewQdrantClient(qdrantEndpoint)
	qdrantClient.SeedInitialVectors()
	log.Printf("[Qdrant] Cliente Zero-Trust inicializado en %s (%d vectores 512D cargados en memoria).",
		qdrantEndpoint, len(qdrantClient.GetAllVectors()))

	// 3. Inicialización del Worker Pool Concurrente (16 Goroutines, Buffer de 500 lotes)
	workerCount := 16
	queueCapacity := 500
	pool := workerpool.NewWorkerPool(workerCount, queueCapacity, repo)
	pool.Start()
	defer pool.Stop()

	// 4. Configuración del Router Gin
	gin.SetMode(gin.ReleaseMode)
	router := gin.New()
	router.Use(gin.Recovery())
	router.Use(gin.Logger())

	apiHandler := api.NewAPIHandler(pool, repo, qdrantClient)
	apiHandler.RegisterRoutes(router)

	srv := &http.Server{
		Addr:         ":" + port,
		Handler:      router,
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// 5. Inicialización y arranque del Servidor gRPC (HTTP/2 + Protobuf en puerto 50051)
	grpcServer := edgegrpc.NewTurnstileGRPCServer(pool, repo, qdrantClient)
	go func() {
		if err := grpcServer.Start(50051); err != nil {
			log.Printf("[gRPC] Servidor gRPC finalizado: %v", err)
		}
	}()

	// 6. Arranque no bloqueante del servidor HTTP/REST (Gin en puerto 8080)
	go func() {
		log.Printf("[Server] Microservicio REST escuchando en http://0.0.0.0:%s", port)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("[Server] Error fatal al escuchar REST: %v", err)
		}
	}()

	// 7. Manejo de Graceful Shutdown ante SIGINT / SIGTERM
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("[Server] Señal de apagado recibida. Cerrando conexiones gRPC, HTTP y drenando Worker Pool...")

	grpcServer.Stop()

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("[Server] Forzado de apagado del servidor: %v", err)
	}

	log.Println("[Server] Microservicio de Ingesta finalizado ordenadamente.")
}
