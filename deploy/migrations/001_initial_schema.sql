-- ============================================================================
-- UNIVERSIDAD - CONTROL DE ACCESO DESCENTRALIZADO
-- Script DDL Inicial para PostgreSQL 16 (Auditoría Forense con Hash-Chaining)
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1. Tabla de Sedes Universitarias (Campus Multi-Sede)
CREATE TABLE IF NOT EXISTS campus (
    id VARCHAR(32) PRIMARY KEY,
    name VARCHAR(128) NOT NULL,
    city VARCHAR(64) NOT NULL,
    address VARCHAR(255) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 2. Tabla de Torniquetes Perimetrales (Nodos Edge)
CREATE TABLE IF NOT EXISTS turnstiles (
    id VARCHAR(32) PRIMARY KEY,
    campus_id VARCHAR(32) NOT NULL REFERENCES campus(id) ON DELETE CASCADE,
    name VARCHAR(128) NOT NULL,
    hardware_model VARCHAR(64) NOT NULL DEFAULT 'EDGE-7INCH-TOUCH-RPI4',
    ip_address VARCHAR(45),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    last_sync_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 3. Tabla de Control de Acceso Basado en Roles (RBAC)
CREATE TABLE IF NOT EXISTS users_rbac (
    student_id VARCHAR(64) PRIMARY KEY,
    rut VARCHAR(20) UNIQUE NOT NULL,
    full_name VARCHAR(128) NOT NULL,
    email VARCHAR(128) UNIQUE NOT NULL,
    role VARCHAR(32) NOT NULL CHECK (role IN ('ESTUDIANTE', 'ACADEMICO', 'GUARDIA', 'ADMIN')),
    career VARCHAR(128) NOT NULL,
    campus_id VARCHAR(32) NOT NULL REFERENCES campus(id),
    enrollment_status VARCHAR(32) NOT NULL CHECK (enrollment_status IN ('VIGENTE', 'SUSPENDIDO')),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 4. Tabla de Bitácora Forense Inmutable (Hash-Chaining)
CREATE TABLE IF NOT EXISTS access_audit_log (
    id BIGSERIAL PRIMARY KEY,
    event_uuid VARCHAR(64) UNIQUE NOT NULL,
    turnstile_id VARCHAR(32) NOT NULL REFERENCES turnstiles(id),
    campus_id VARCHAR(32) NOT NULL REFERENCES campus(id),
    student_id VARCHAR(64) NOT NULL,
    student_rut VARCHAR(20) NOT NULL,
    access_timestamp TIMESTAMPTZ NOT NULL,
    access_result VARCHAR(16) NOT NULL CHECK (access_result IN ('GRANTED', 'DENIED')),
    denial_reason TEXT,
    latency_ms INT NOT NULL CHECK (latency_ms >= 0),
    payload_hash CHAR(64) NOT NULL,
    previous_hash CHAR(64) NOT NULL,
    current_hash CHAR(64) NOT NULL,
    ingested_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Índices Compuestos para Auditoría Forense y Rendimiento
CREATE INDEX IF NOT EXISTS idx_audit_campus_timestamp ON access_audit_log(campus_id, access_timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_audit_student_rut ON access_audit_log(student_rut);
CREATE INDEX IF NOT EXISTS idx_audit_current_hash ON access_audit_log(current_hash);
CREATE INDEX IF NOT EXISTS idx_audit_event_uuid ON access_audit_log(event_uuid);

-- ============================================================================
-- Poblado de Datos Maestros Institucionales
-- ============================================================================

INSERT INTO campus (id, name, city, address) VALUES
('CAMPUS_PROVIDENCIA', 'Campus Providencia', 'Santiago', 'Av. Pedro de Valdivia 425'),
('CAMPUS_EL_LLANO', 'Campus El Llano Subercaseaux', 'San Miguel', 'Ricardo Morales 3369'),
('CAMPUS_TALCA', 'Campus Talca', 'Talca', 'Av. 5 Poniente 1670'),
('CAMPUS_TEMUCO', 'Campus Temuco', 'Temuco', 'Av. Alemania 01090')
ON CONFLICT (id) DO NOTHING;

INSERT INTO turnstiles (id, campus_id, name, ip_address) VALUES
('TRN-PROV-01', 'CAMPUS_PROVIDENCIA', 'Torniquete Acceso Principal Providencia 1', '192.168.10.101'),
('TRN-PROV-02', 'CAMPUS_PROVIDENCIA', 'Torniquete Acceso Principal Providencia 2', '192.168.10.102'),
('TRN-LLANO-01', 'CAMPUS_EL_LLANO', 'Torniquete Acceso Biblioteca El Llano', '192.168.20.101'),
('TRN-TALCA-01', 'CAMPUS_TALCA', 'Torniquete Entrada Sur Talca', '192.168.30.101'),
('TRN-TEMUCO-01', 'CAMPUS_TEMUCO', 'Torniquete Central Temuco', '192.168.40.101')
ON CONFLICT (id) DO NOTHING;

INSERT INTO users_rbac (student_id, rut, full_name, email, role, career, campus_id, enrollment_status) VALUES
('ua-stu-2026-001', '21.460.709-3', 'Sebastián Freire', 'sfreire@uautonoma.cl', 'ESTUDIANTE', 'Ingeniería Civil Informática', 'CAMPUS_PROVIDENCIA', 'VIGENTE'),
ON CONFLICT (student_id) DO NOTHING;
