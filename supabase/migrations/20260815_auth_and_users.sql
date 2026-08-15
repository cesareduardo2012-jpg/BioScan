-- ============================================================================
-- MIGRACIÓN DE AUTENTICACIÓN, ROLES Y GESTIÓN DE USUARIOS - BIOSCAN
-- ============================================================================

-- 1. TIPOS DE ROLES DE USUARIO
DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('ADMINISTRADOR', 'OPERADOR');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 2. TABLA DE CUENTAS / CLIENTES (MULTI-TENANT)
CREATE TABLE IF NOT EXISTS public.cuentas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre TEXT NOT NULL,
    empresa TEXT,
    telefono TEXT,
    correo TEXT,
    activo BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. TABLA DE PERFILES DE USUARIOS (VINCULADA A AUTH.USERS)
CREATE TABLE IF NOT EXISTS public.usuarios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    auth_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    cuenta_id UUID NOT NULL REFERENCES public.cuentas(id) ON DELETE CASCADE,
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

-- 4. REGLA ESTRICTA DE BASE DE DATOS: MÁXIMO 1 OPERADOR ACTIVO POR CUENTA
-- Este índice único parcial impide a nivel de motor de BD insertar o activar más de 1 operador por cuenta.
CREATE UNIQUE INDEX IF NOT EXISTS idx_max_one_operator_per_account 
ON public.usuarios (cuenta_id) 
WHERE (rol = 'OPERADOR' AND activo = true);

-- DISPARADOR (TRIGGER) PARA VALIDAR RESTRICCIÓN DE 1 OPERADOR
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
          AND id <> COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid);
          
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

-- 5. TABLA DE AUDITORÍA (AUDIT LOGS)
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cuenta_id UUID REFERENCES public.cuentas(id) ON DELETE SET NULL,
    usuario_id UUID REFERENCES public.usuarios(id) ON DELETE SET NULL,
    action TEXT NOT NULL, -- LOGIN, LOGOUT, CREATE_USER, UPDATE_USER, DELETE_USER, CREATE_MEASUREMENT
    details JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 6. HABILITAR ROW LEVEL SECURITY (RLS)
ALTER TABLE public.cuentas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- 7. POLÍTICAS RLS DE USUARIOS
-- Los administradores pueden ver, crear y actualizar usuarios de su propia cuenta (sujeto a la regla de 1 operador)
CREATE POLICY "Admins pueden ver usuarios de su cuenta" 
ON public.usuarios FOR SELECT 
USING (
    cuenta_id IN (
        SELECT u.cuenta_id FROM public.usuarios u 
        WHERE u.auth_user_id = auth.uid()
    )
);

CREATE POLICY "Admins pueden insertar solo 1 operador en su cuenta" 
ON public.usuarios FOR INSERT 
WITH CHECK (
    rol = 'OPERADOR' AND
    EXISTS (
        SELECT 1 FROM public.usuarios u 
        WHERE u.auth_user_id = auth.uid() AND u.rol = 'ADMINISTRADOR' AND u.cuenta_id = usuarios.cuenta_id
    )
);

CREATE POLICY "Admins pueden actualizar operador de su cuenta" 
ON public.usuarios FOR UPDATE 
USING (
    EXISTS (
        SELECT 1 FROM public.usuarios u 
        WHERE u.auth_user_id = auth.uid() AND u.rol = 'ADMINISTRADOR' AND u.cuenta_id = usuarios.cuenta_id
    )
);

CREATE POLICY "Ningún usuario puede eliminar físicamente de forma directa" 
ON public.usuarios FOR DELETE 
USING (false);

-- 8. POLÍTICAS RLS DE AUDITORÍA
CREATE POLICY "Usuarios pueden registrar eventos de auditoría de su cuenta"
ON public.audit_logs FOR INSERT
WITH CHECK (true);

CREATE POLICY "Admins pueden ver logs de auditoría de su cuenta"
ON public.audit_logs FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.usuarios u
        WHERE u.auth_user_id = auth.uid() AND u.rol = 'ADMINISTRADOR' AND u.cuenta_id = audit_logs.cuenta_id
    )
);
