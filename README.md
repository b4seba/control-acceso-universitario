# SISTEMA DE CONTROL DE ACCESO INTELIGENTE Y DESCENTRALIZADO
## Evaluación Sumativa 2 (EV2) - Arquitectura de Software
**Universidad | Campus Principal | Octubre 2026**  
**Docente Evaluador:** Cristofher Rojas Rojas  
**Integrantes:** Sebastián Freire y Luciano Valenzuela  
**Calificación Objetivo:** Nota 7.0 (100% de cumplimiento de rúbrica)

---

## 1. Visión General del Proyecto

Este repositorio contiene la implementación técnica integral del sistema de control de acceso perimetral para más de 30.000 estudiantes y académicos distribuidos en múltiples campus.

La arquitectura resuelve de raíz el problema de cortes de conectividad por fibra óptica de hasta 72 horas mediante **Edge Computing Descentralizado**, garantizando:

1. **Modo Isla 72h**: Los torniquetes perimetrales validan accesos y retienen bitácoras de forma 100% autónoma en SQLite WAL sin requerir conexión a Internet.
2. **Alta Fluidez Peatonal (SLA $\le$ 500 ms)**: Procesamiento biométrico 1:1 local con latencia real de decisión entre **80 ms y 150 ms**.
3. **Seguridad y Privacidad Estricta**: Doble factor de autenticación (**2FA: Posesión vía NFC HCE / QR TOTP 15s + Inherencia mediante vectores matemáticos de 512D**), bajo política Zero-Trust (prohibición absoluta de almacenar o transmitir fotos crudas).
4. **Mitigación de la Tormenta de Reconexión**: Ingesta masiva concurrente en Golang mediante **Worker Pools** (16 goroutines) y verificación forense con **hash-chaining SHA-256** en PostgreSQL 16.
5. **Comunicación de Alto Rendimiento**: Servidor dual **gRPC (HTTP/2 + Protobuf)** en `:50051` y **REST API (Gin)** en `:8080` protegido con **JWT RFC 7519**.

---

## 2. Puesta en Marcha y Ejecución del Sistema

Para levantar y probar todos los servicios de forma limpia e independiente, abre consolas de terminal separadas y ejecuta los comandos correspondientes:

### Terminal 1: Backend Central en Golang (REST :8080 y gRPC :50051)
```bash
cd services/ingestion
./bin/ingest_server.exe
# o compilar en vivo: go run ./cmd/server
```

### Terminal 2: Servicio Edge de Cámara y Reconocimiento 512D
```bash
python scripts/kiosk_camera_service.py
```
> Expone el stream MJPEG y la telemetría biométrica en `http://127.0.0.1:5050`.

### Terminal 3: Portal Web de Enrolamiento (React 18 + Vite)
```bash
cd apps/web_enrollment
npm install
npm run dev
```
> Accede en el navegador a `http://localhost:3000` para capturar rostro por webcam y enrolar usuarios.

### Terminal 4: Kiosko Torniquete Edge (Flutter Desktop)
```bash
cd apps/kiosk_app
flutter pub get
flutter run -d windows
```

### Terminal 5: Credencial Móvil Estudiante (Flutter Web / Android)
```bash
cd apps/student_app
flutter pub get
flutter run -d chrome
```

---

## 3. Estructura del Repositorio

```text
control-acceso-universitario/
├── apps/
│   ├── student_app/          # App Móvil Estudiante (Flutter / MVVM)
│   │   ├── lib/domain/       # Modelos y emisión criptográfica NFC HCE / QR TOTP 15s
│   │   ├── lib/presentation/ # ViewModels y Vistas (Login RBAC y Credencial Digital)
│   │   └── test/             # Pruebas unitarias de tokens y vectores biometricos 512D
│   ├── kiosk_app/            # Kiosko Torniquete Edge 7" (Flutter / GoF State Pattern)
│   │   ├── lib/domain/fsm/   # Máquina de Estados Finitos (Idle, FaceScanning, Granted, Denied)
│   │   ├── lib/data/         # SQLite en modo WAL y Transactional Outbox Worker
│   │   ├── lib/presentation/ # UI de alto contraste, bloque de torniquete digital y panel de guardia
│   │   └── test/             # Pruebas unitarias de FSM y Similitud Coseno
│   └── web_enrollment/       # Portal Web de Enrolamiento (React 18 + Vite + Tailwind)
│       └── src/              # Captura facial por webcam, vectorizador 512D y despacho API
├── deploy/                   # Infraestructura y Contenedores
│   ├── docker-compose.yml    # Orquestación de PostgreSQL 16 y Qdrant Vector DB
│   └── migrations/           # DDL de base de datos relacional y datos semilla
├── proto/
│   └── access_control.proto  # Contrato gRPC (Protocol Buffers v3 / HTTP/2)
├── scripts/                  # Servicios de Visión Artificial e Inspección Forense
│   ├── enrolar_mi_cara.py    # Script CLI para enrolar rostro con cámara real
│   ├── kiosk_camera_service.py # Stream MJPEG y servicio perimetral de vectores 512D
│   ├── inspect_edge_db.py    # Auditoría forense de SQLite WAL y outbox
│   └── qdrant_dashboard_demo.py # Visualizador de embeddings en Qdrant (HNSW / Cosine)
├── services/
│   └── ingestion/            # Microservicio de Ingesta Central (Golang 1.22+)
│       ├── cmd/server/       # Servidor HTTP/REST Gin y gRPC Server concurrente
│       ├── internal/grpc/    # Servidor gRPC e interceptores de seguridad JWT
│       ├── internal/workerpool/ # Worker Pool concurrente (16 Goroutines)
│       ├── internal/crypto/  # JWT RFC 7519, hash-chaining SHA-256 y firmas ACK
│       ├── internal/repository/ # Adaptadores PostgreSQL 16 y cliente Qdrant Zero-Trust
│       └── internal/api/     # Handlers REST, middleware de autenticación y endpoints
├── requirements.txt          # Dependencias de Python
└── ua_turnstile_edge.db      # Base de datos SQLite WAL local del torniquete
```

---

## 4. Patrones de Diseño Implementados

| Patrón | Ubicación en el Código | Rol Arquitectónico |
| :--- | :--- | :--- |
| **GoF State Pattern** | `apps/kiosk_app/lib/domain/fsm/` | Modela la **FSM del torniquete** (`IdleState` $\rightarrow$ `FaceScanningState` $\rightarrow$ `Evaluating2FAState` $\rightarrow$ `AccessGrantedState` / `AccessDeniedState`). Desacopla la lógica de transición de la vista. |
| **MVVM (Model-View-ViewModel)** | `apps/student_app/` y `apps/kiosk_app/` | Separa limpiamente el estado reactivo (`ViewModel`), la interfaz gráfica Flutter (`View`) y los contratos inmutables (`Model`). |
| **Transactional Outbox Pattern** | `apps/kiosk_app/lib/data/outbox/` | Permite el **Modo Isla**: los pasos se guardan en SQLite WAL local y un worker en segundo plano los despacha con Exponential Backoff y confirmación por ACK criptográfico. |
| **Worker Pool Pattern** | `services/ingestion/internal/workerpool/` | **16 goroutines concurrentes** consumiendo de un canal `chan IngestJob` con buffer de 500 lotes, amortiguando la **Tormenta de Reconexión** y protegiendo PostgreSQL 16. |

---

## 5. Seguridad y Protocolos

* **JWT (RFC 7519)**: Tokens firmados con HMAC-SHA256 (`HS256`), duración de 24 horas y claims institucionales (`student_id`, `rut`, `full_name`, `role`, `campus`). Verificado en `services/ingestion/internal/crypto/jwt.go`.
* **gRPC (Protocol Buffers v3)**: Servicio binario de alto rendimiento definido en `proto/access_control.proto` ejecutándose en el puerto `:50051` con interceptores de seguridad JWT unarios.
* **Zero-Trust Biometrics**: Solo se procesan y almacenan vectores normalizados de 512 floats en Qdrant y SQLite WAL. Cero almacenamiento o transmisión de fotografías crudas.
* **Encadenamiento Forense (Hash-Chaining)**: Cada evento de auditoría enlaza su `previous_hash` con el `current_hash` mediante SHA-256 estilo blockchain, imposibilitando la alteración retroactiva de bitácoras.

---

## 6. Ejecución Manual de Componentes

### 6.1. Microservicio Go (Ingesta Central)
```bash
cd services/ingestion
go test -v ./...
go build -o bin/ingest_server.exe ./cmd/server
./bin/ingest_server.exe
```

### 6.2. App Estudiante (Flutter)
```bash
cd apps/student_app
flutter pub get
flutter test
flutter run -d chrome
```

### 6.3. Kiosko Torniquete Edge (Flutter)
```bash
cd apps/kiosk_app
flutter pub get
flutter test
flutter run -d windows
```

### 6.4. Portal Web de Enrolamiento (React)
```bash
cd apps/web_enrollment
npm install
npm run dev
# Abrir en navegador: http://localhost:3000
```

---

## 7. Flujo de Demostración 2FA

1. **Credencial**: En la app de estudiante, inicia sesión con el RUT `21.460.709-3`. Se generará el QR/NFC firmado.
2. **Kiosko**: Copia o ingresa el RUT/payload en el Kiosko.
3. **Cámara 512D**: La cámara detecta tu rostro en vivo, calcula el vector 512D y lo compara con SQLite WAL mediante Similitud Coseno ($> 0.70$).
4. **Validación y Apertura**: Al verificarse el 2FA, la pantalla muestra el bloque **`TORNIQUETE ABIERTO`** en verde esmeralda con cuenta regresiva de 2 segundos, registrando la auditoría inmutable en SQLite WAL y sincronizándola con el Backend Central.
