-- ============================================================================
-- SCRIPT DE ESQUEMA COMPLETO DE BASE DE DATOS Y RESPALDO NUBE - BIOSCAN (SUPABASE)
-- Soporta IDs en formato TEXT (compatibilidad total con SQLite local)
-- ============================================================================

-- 1. TIPOS DE ROLES DE USUARIO
DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('ADMINISTRADOR', 'OPERADOR');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 2. TABLA DE CUENTAS / CLIENTES (MULTI-TENANT)
CREATE TABLE IF NOT EXISTS public.cuentas (
    id TEXT PRIMARY KEY,
    nombre TEXT NOT NULL,
    empresa TEXT,
    telefono TEXT,
    correo TEXT,
    activo BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. TABLA DE PERFILES DE USUARIOS
CREATE TABLE IF NOT EXISTS public.usuarios (
    id TEXT PRIMARY KEY,
    auth_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    cuenta_id TEXT NOT NULL REFERENCES public.cuentas(id) ON DELETE CASCADE,
    username TEXT NOT NULL UNIQUE,
    nombre TEXT NOT NULL,
    correo TEXT NOT NULL,
    rol user_role NOT NULL DEFAULT 'OPERADOR',
    activo BOOLEAN NOT NULL DEFAULT true,
    fecha_registro TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ultimo_acceso TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. TABLA DE DISPOSITIVOS FISICOS (ESCANERES ESP32)
CREATE TABLE IF NOT EXISTS public.dispositivos (
    id TEXT PRIMARY KEY,
    cuenta_id TEXT NOT NULL REFERENCES public.cuentas(id) ON DELETE CASCADE,
    numero_serie TEXT NOT NULL,
    nombre TEXT NOT NULL,
    modelo TEXT NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT true,
    fecha_registro TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. TABLA DE GANADEROS Y PRODUCTORES
CREATE TABLE IF NOT EXISTS public.ganaderos (
    id TEXT PRIMARY KEY,
    cuenta_id TEXT NOT NULL REFERENCES public.cuentas(id) ON DELETE CASCADE,
    nombre TEXT NOT NULL,
    apellido_paterno TEXT NOT NULL,
    apellido_materno TEXT NOT NULL,
    rancho TEXT NOT NULL,
    telefono TEXT NOT NULL,
    correo TEXT NOT NULL,
    fecha_registro TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 6. TABLA DE MEDICIONES Y ENSAYOS DE LECHE
CREATE TABLE IF NOT EXISTS public.mediciones (
    id TEXT PRIMARY KEY,
    ganadero_id TEXT NOT NULL REFERENCES public.ganaderos(id) ON DELETE CASCADE,
    dispositivo_id TEXT REFERENCES public.dispositivos(id) ON DELETE SET NULL,
    usuario_id TEXT REFERENCES public.usuarios(id) ON DELETE SET NULL,
    ph TEXT NOT NULL,
    densidad TEXT NOT NULL,
    temperatura TEXT NOT NULL,
    fecha TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    observaciones TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 7. TABLA DE AUDITORIA (AUDIT LOGS)
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    cuenta_id TEXT REFERENCES public.cuentas(id) ON DELETE SET NULL,
    usuario_id TEXT REFERENCES public.usuarios(id) ON DELETE SET NULL,
    action TEXT NOT NULL,
    details JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- REGLAS DE INTEGRIDAD Y RESTRICCION ESTRICTA: MAXIMO 1 OPERADOR POR CUENTA
-- ============================================================================
CREATE UNIQUE INDEX IF NOT EXISTS idx_max_one_operator_per_account 
ON public.usuarios (cuenta_id) 
WHERE (rol = 'OPERADOR' AND activo = true);

CREATE OR REPLACE FUNCTION check_max_one_operator_per_account()
RETURNS TRIGGER AS $$
DECLARE
    operator_count INTEGER;
BEGIN
    IF NEW.rol = 'OPERADOR' AND NEW.activo = true THEN
        SELECT COUNT(*) INTO operator_count
        FROM public.usuarios
        WHERE cuenta_id = NEW.cuenta_id
          AND rol = 'OPERADOR'
          AND activo = true
          AND id <> COALESCE(NEW.id, '');
          
        IF operator_count >= 1 THEN
            RAISE EXCEPTION 'Restricción BioScan: Una cuenta no puede tener más de 1 usuario Operador activo.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_check_max_one_operator ON public.usuarios;
CREATE TRIGGER trigger_check_max_one_operator
BEFORE INSERT OR UPDATE ON public.usuarios
FOR EACH ROW
EXECUTE FUNCTION check_max_one_operator_per_account();

-- ============================================================================
-- INDICES B-TREE DE RENDIMIENTO EN NUBE
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_cloud_usuarios_cuenta ON public.usuarios(cuenta_id);
CREATE INDEX IF NOT EXISTS idx_cloud_ganaderos_cuenta ON public.ganaderos(cuenta_id);
CREATE INDEX IF NOT EXISTS idx_cloud_mediciones_ganadero ON public.mediciones(ganadero_id);
CREATE INDEX IF NOT EXISTS idx_cloud_mediciones_usuario ON public.mediciones(usuario_id);

-- ============================================================================
-- POLÍTICAS DE PERMISOS ABIERTOS PARA SYNC DE ESCRITORIA (ANON)
-- ============================================================================
ALTER TABLE public.cuentas DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.usuarios DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.dispositivos DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.ganaderos DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.mediciones DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs DISABLE ROW LEVEL SECURITY;
