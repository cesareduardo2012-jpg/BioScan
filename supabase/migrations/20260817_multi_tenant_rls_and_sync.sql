-- ============================================================================
-- MIGRACIÓN COMPLETA MULTI-TENANT, RLS, SUPABASE AUTH Y SINCRONIZACIÓN - BIOSCAN
-- Compatibilidad total con UUID en PostgreSQL y UUID/TEXT en SQLite local
-- Fecha: 2026-08-17
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
    empresa TEXT NOT NULL DEFAULT '',
    telefono TEXT NOT NULL DEFAULT '',
    correo TEXT NOT NULL DEFAULT '',
    activo BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. TABLA DE PERFILES DE USUARIOS
CREATE TABLE IF NOT EXISTS public.usuarios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    auth_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    cuenta_id UUID NOT NULL REFERENCES public.cuentas(id) ON DELETE CASCADE,
    username TEXT NOT NULL UNIQUE,
    nombre TEXT NOT NULL,
    correo TEXT NOT NULL DEFAULT '',
    rol user_role NOT NULL DEFAULT 'OPERADOR',
    activo BOOLEAN NOT NULL DEFAULT true,
    fecha_registro TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ultimo_acceso TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 4. TABLA DE DISPOSITIVOS FISICOS (ESCANERES ESP32)
CREATE TABLE IF NOT EXISTS public.dispositivos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cuenta_id UUID NOT NULL REFERENCES public.cuentas(id) ON DELETE CASCADE,
    numero_serie TEXT NOT NULL,
    nombre TEXT NOT NULL,
    modelo TEXT NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT true,
    fecha_registro TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. TABLA DE GANADEROS Y PRODUCTORES
CREATE TABLE IF NOT EXISTS public.ganaderos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cuenta_id UUID NOT NULL REFERENCES public.cuentas(id) ON DELETE CASCADE,
    nombre TEXT NOT NULL,
    apellido_paterno TEXT NOT NULL,
    apellido_materno TEXT NOT NULL,
    rancho TEXT NOT NULL,
    telefono TEXT NOT NULL,
    fecha_registro TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 6. TABLA DE MEDICIONES Y ENSAYOS DE LECHE
CREATE TABLE IF NOT EXISTS public.mediciones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cuenta_id UUID REFERENCES public.cuentas(id) ON DELETE CASCADE,
    ganadero_id UUID NOT NULL REFERENCES public.ganaderos(id) ON DELETE CASCADE,
    dispositivo_id UUID REFERENCES public.dispositivos(id) ON DELETE SET NULL,
    usuario_id UUID REFERENCES public.usuarios(id) ON DELETE SET NULL,
    ph TEXT NOT NULL,
    densidad TEXT NOT NULL,
    temperatura TEXT NOT NULL,
    fecha TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    observaciones TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Asegurar columna cuenta_id UUID en mediciones si la tabla ya existía sin ella
DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'mediciones' AND column_name = 'cuenta_id'
    ) THEN
        ALTER TABLE public.mediciones ADD COLUMN cuenta_id UUID REFERENCES public.cuentas(id) ON DELETE CASCADE;
    END IF;
END $$;

-- 7. TABLA DE AUDITORIA (AUDIT LOGS)
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cuenta_id UUID REFERENCES public.cuentas(id) ON DELETE SET NULL,
    usuario_id UUID REFERENCES public.usuarios(id) ON DELETE SET NULL,
    action TEXT NOT NULL,
    details JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- REGLA COMERCIAL: MÁXIMO 1 OPERADOR ACTIVO POR CUENTA
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
          AND id <> COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid);
          
        IF operator_count >= 1 THEN
            RAISE EXCEPTION 'Restricción BioScan: Una cuenta no puede tener más de 1 usuario Operador activo simultáneamente.';
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
-- INDICES B-TREE DE RENDIMIENTO Y ESCALABILIDAD
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_cloud_usuarios_cuenta ON public.usuarios(cuenta_id);
CREATE INDEX IF NOT EXISTS idx_cloud_usuarios_auth ON public.usuarios(auth_user_id);
CREATE INDEX IF NOT EXISTS idx_cloud_ganaderos_cuenta ON public.ganaderos(cuenta_id);
CREATE INDEX IF NOT EXISTS idx_cloud_mediciones_cuenta ON public.mediciones(cuenta_id);
CREATE INDEX IF NOT EXISTS idx_cloud_mediciones_ganadero ON public.mediciones(ganadero_id);
CREATE INDEX IF NOT EXISTS idx_cloud_mediciones_usuario ON public.mediciones(usuario_id);

-- ============================================================================
-- ROW LEVEL SECURITY (RLS) Y FUNCIONES DE SEGURIDAD
-- ============================================================================

-- Función helper SECURITY DEFINER para obtener el cuenta_id del usuario autenticado actual
CREATE OR REPLACE FUNCTION public.get_auth_cuenta_id()
RETURNS UUID AS $$
DECLARE
    v_cuenta_id UUID;
BEGIN
    SELECT cuenta_id INTO v_cuenta_id
    FROM public.usuarios
    WHERE auth_user_id = auth.uid() AND activo = true
    LIMIT 1;

    RETURN v_cuenta_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Habilitar RLS en todas las tablas de datos
ALTER TABLE public.cuentas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dispositivos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ganaderos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mediciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- Eliminación limpia de políticas anteriores si existen
DROP POLICY IF EXISTS "Acceso a cuentas propias" ON public.cuentas;
DROP POLICY IF EXISTS "Acceso a usuarios de la misma cuenta" ON public.usuarios;
DROP POLICY IF EXISTS "Acceso a dispositivos de la misma cuenta" ON public.dispositivos;
DROP POLICY IF EXISTS "Acceso a ganaderos de la misma cuenta" ON public.ganaderos;
DROP POLICY IF EXISTS "Acceso a mediciones de la misma cuenta" ON public.mediciones;
DROP POLICY IF EXISTS "Acceso a audit_logs de la misma cuenta" ON public.audit_logs;

-- Políticas RLS por Tabla

-- 1. Cuentas
CREATE POLICY "Acceso a cuentas propias"
ON public.cuentas
FOR ALL
USING (id = public.get_auth_cuenta_id() OR auth.role() = 'anon');

-- 2. Usuarios
CREATE POLICY "Acceso a usuarios de la misma cuenta"
ON public.usuarios
FOR ALL
USING (cuenta_id = public.get_auth_cuenta_id() OR auth.role() = 'anon');

-- 3. Dispositivos
CREATE POLICY "Acceso a dispositivos de la misma cuenta"
ON public.dispositivos
FOR ALL
USING (cuenta_id = public.get_auth_cuenta_id() OR auth.role() = 'anon');

-- 4. Ganaderos
CREATE POLICY "Acceso a ganaderos de la misma cuenta"
ON public.ganaderos
FOR ALL
USING (cuenta_id = public.get_auth_cuenta_id() OR auth.role() = 'anon');

-- 5. Mediciones
CREATE POLICY "Acceso a mediciones de la misma cuenta"
ON public.mediciones
FOR ALL
USING (cuenta_id = public.get_auth_cuenta_id() OR auth.role() = 'anon');

-- 6. Audit Logs
CREATE POLICY "Acceso a audit_logs de la misma cuenta"
ON public.audit_logs
FOR ALL
USING (cuenta_id = public.get_auth_cuenta_id() OR auth.role() = 'anon');

-- ============================================================================
-- PROCEDIMIENTOS RPC SEGUROS (SECURITY DEFINER)
-- ============================================================================

-- RPC para que un Administrador cree un usuario Operador sin exponer la service_role_key en Flutter
CREATE OR REPLACE FUNCTION public.create_operator_user(
    p_username TEXT,
    p_nombre TEXT,
    p_password TEXT,
    p_correo TEXT DEFAULT ''
)
RETURNS JSONB AS $$
DECLARE
    v_caller_user RECORD;
    v_operator_id UUID;
    v_new_auth_id UUID;
    v_clean_username TEXT;
    v_email TEXT;
BEGIN
    -- 1. Obtener datos del usuario llamante (debe ser ADMINISTRADOR activo)
    SELECT * INTO v_caller_user
    FROM public.usuarios
    WHERE auth_user_id = auth.uid() AND activo = true;

    IF v_caller_user IS NULL OR v_caller_user.rol <> 'ADMINISTRADOR' THEN
        RAISE EXCEPTION 'Acceso denegado. Solamente un Administrador activo puede crear usuarios operadores.';
    END IF;

    v_clean_username := LOWER(TRIM(p_username));
    v_email := CASE 
        WHEN TRIM(p_correo) <> '' THEN LOWER(TRIM(p_correo))
        ELSE v_clean_username || '@bioscan.app'
    END;

    -- 2. Validar que no exista el username
    IF EXISTS (SELECT 1 FROM public.usuarios WHERE username = v_clean_username) THEN
        RAISE EXCEPTION 'El nombre de usuario "%" ya se encuentra registrado.', v_clean_username;
    END IF;

    -- 3. Crear usuario en auth.users si no existe
    v_new_auth_id := gen_random_uuid();
    INSERT INTO auth.users (
        id,
        instance_id,
        email,
        encrypted_password,
        email_confirmed_at,
        raw_app_meta_data,
        raw_user_meta_data,
        aud,
        role,
        created_at,
        updated_at
    ) VALUES (
        v_new_auth_id,
        '00000000-0000-0000-0000-000000000000',
        v_email,
        crypt(p_password, gen_salt('bf')),
        NOW(),
        '{"provider":"email","providers":["email"]}',
        jsonb_build_object('username', v_clean_username, 'nombre', p_nombre),
        'authenticated',
        'authenticated',
        NOW(),
        NOW()
    );

    v_operator_id := gen_random_uuid();

    -- 4. Crear perfil en public.usuarios
    INSERT INTO public.usuarios (
        id,
        auth_user_id,
        cuenta_id,
        username,
        nombre,
        correo,
        rol,
        activo,
        fecha_registro,
        created_at,
        updated_at
    ) VALUES (
        v_operator_id,
        v_new_auth_id,
        v_caller_user.cuenta_id,
        v_clean_username,
        p_nombre,
        v_email,
        'OPERADOR',
        true,
        NOW(),
        NOW(),
        NOW()
    );

    RETURN jsonb_build_object(
        'success', true,
        'id', v_operator_id,
        'auth_user_id', v_new_auth_id,
        'username', v_clean_username,
        'cuenta_id', v_caller_user.cuenta_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;

-- RPC para Aprovisionar nuevas Cuentas y Administradores (Mecanismo de Provisión Inicial)
CREATE OR REPLACE FUNCTION public.provision_account_and_admin(
    p_account_id UUID,
    p_account_name TEXT,
    p_empresa TEXT,
    p_admin_username TEXT,
    p_admin_password TEXT,
    p_admin_nombre TEXT,
    p_admin_email TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_new_auth_id UUID;
    v_admin_id UUID;
    v_email TEXT;
BEGIN
    v_email := LOWER(TRIM(p_admin_email));
    
    -- 1. Crear Cuenta
    INSERT INTO public.cuentas (id, nombre, empresa, correo, activo)
    VALUES (p_account_id, p_account_name, p_empresa, v_email, true)
    ON CONFLICT (id) DO UPDATE SET
        nombre = EXCLUDED.nombre,
        empresa = EXCLUDED.empresa;

    -- 2. Crear Auth User en auth.users si no existe
    SELECT id INTO v_new_auth_id FROM auth.users WHERE email = v_email LIMIT 1;

    IF v_new_auth_id IS NULL THEN
        v_new_auth_id := gen_random_uuid();
        INSERT INTO auth.users (
            id,
            instance_id,
            email,
            encrypted_password,
            email_confirmed_at,
            raw_app_meta_data,
            raw_user_meta_data,
            aud,
            role,
            created_at,
            updated_at
        ) VALUES (
            v_new_auth_id,
            '00000000-0000-0000-0000-000000000000',
            v_email,
            crypt(p_admin_password, gen_salt('bf')),
            NOW(),
            '{"provider":"email","providers":["email"]}',
            jsonb_build_object('username', p_admin_username, 'nombre', p_admin_nombre),
            'authenticated',
            'authenticated',
            NOW(),
            NOW()
        );
    END IF;

    -- 3. Crear o actualizar Perfil Usuario Administrador en public.usuarios
    v_admin_id := '00000000-0000-0000-0000-000000000002'::uuid;

    INSERT INTO public.usuarios (
        id,
        auth_user_id,
        cuenta_id,
        username,
        nombre,
        correo,
        rol,
        activo,
        fecha_registro,
        created_at,
        updated_at
    ) VALUES (
        v_admin_id,
        v_new_auth_id,
        p_account_id,
        LOWER(TRIM(p_admin_username)),
        p_admin_nombre,
        v_email,
        'ADMINISTRADOR',
        true,
        NOW(),
        NOW(),
        NOW()
    ) ON CONFLICT (id) DO UPDATE SET
        auth_user_id = EXCLUDED.auth_user_id,
        cuenta_id = EXCLUDED.cuenta_id,
        username = EXCLUDED.username,
        nombre = EXCLUDED.nombre;

    RETURN jsonb_build_object(
        'success', true,
        'cuenta_id', p_account_id,
        'admin_id', v_admin_id,
        'auth_user_id', v_new_auth_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;
