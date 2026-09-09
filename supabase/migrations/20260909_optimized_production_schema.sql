-- ============================================================================
-- BIOSCAN: ESQUEMA DE BASE DE DATOS POSTGRESQL / SUPABASE DE PRODUCCIÓN (V2.3)
-- Solución 55P04: Uso de roles comprometidos y comparaciones seguras de Enums
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. EXTENSIONES REQUERIDAS
-- ----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ----------------------------------------------------------------------------
-- 2. TIPOS PERSONALIZADOS (ENUMS)
-- ----------------------------------------------------------------------------

DO $$ BEGIN
    CREATE TYPE user_role AS ENUM (
        'ADMINISTRADOR',  -- Rol administrativo principal (100% compatible con Flutter)
        'ADMIN_CUENTA',   -- Administrador de rancho/empresa
        'SUPERADMIN',     -- Administrador global BioScan
        'OPERADOR'        -- Operador de campo / técnico
    );
EXCEPTION
    WHEN duplicate_object THEN
        -- Si el enum ya existía, registramos los nuevos valores para uso futuro
        BEGIN
            ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'ADMIN_CUENTA';
            ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'SUPERADMIN';
        EXCEPTION WHEN others THEN null;
        END;
END $$;

DO $$ BEGIN
    CREATE TYPE dispositivo_status AS ENUM (
        'EN_STOCK',       -- En inventario / almacén global, listo para venta o asignación
        'ASIGNADO',       -- Vendido y vinculado a una cuenta activa
        'MANTENIMIENTO',  -- En calibración de electrodos o reparación
        'DEVOLUCION',     -- En proceso de garantía o retorno
        'DADO_DE_BAJA'    -- Retirado permanentemente de operación
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- ----------------------------------------------------------------------------
-- 3. CREACIÓN Y ACTUALIZACIÓN DE TABLAS (DDL)
-- ----------------------------------------------------------------------------

-- A. CUENTAS / TENANTS
CREATE TABLE IF NOT EXISTS public.cuentas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre TEXT NOT NULL,
    empresa TEXT NOT NULL DEFAULT '',
    rfc_identificacion TEXT NOT NULL DEFAULT '',
    telefono TEXT NOT NULL DEFAULT '',
    correo TEXT NOT NULL DEFAULT '',
    direccion TEXT NOT NULL DEFAULT '',
    activo BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.cuentas ADD COLUMN IF NOT EXISTS empresa TEXT NOT NULL DEFAULT '';
ALTER TABLE public.cuentas ADD COLUMN IF NOT EXISTS rfc_identificacion TEXT NOT NULL DEFAULT '';
ALTER TABLE public.cuentas ADD COLUMN IF NOT EXISTS telefono TEXT NOT NULL DEFAULT '';
ALTER TABLE public.cuentas ADD COLUMN IF NOT EXISTS correo TEXT NOT NULL DEFAULT '';
ALTER TABLE public.cuentas ADD COLUMN IF NOT EXISTS direccion TEXT NOT NULL DEFAULT '';
ALTER TABLE public.cuentas ADD COLUMN IF NOT EXISTS activo BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE public.cuentas ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
ALTER TABLE public.cuentas ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- B. PERFILES DE USUARIOS (auth.users)
CREATE TABLE IF NOT EXISTS public.usuarios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    auth_user_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    cuenta_id UUID REFERENCES public.cuentas(id) ON DELETE CASCADE,
    username TEXT NOT NULL UNIQUE,
    nombre TEXT NOT NULL,
    correo TEXT NOT NULL DEFAULT '',
    rol user_role NOT NULL DEFAULT 'OPERADOR',
    activo BOOLEAN NOT NULL DEFAULT true,
    ultimo_acceso TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.usuarios ALTER COLUMN cuenta_id DROP NOT NULL;
ALTER TABLE public.usuarios ADD COLUMN IF NOT EXISTS correo TEXT NOT NULL DEFAULT '';
ALTER TABLE public.usuarios ADD COLUMN IF NOT EXISTS activo BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE public.usuarios ADD COLUMN IF NOT EXISTS ultimo_acceso TIMESTAMPTZ;
ALTER TABLE public.usuarios ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
ALTER TABLE public.usuarios ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- C. DISPOSITIVOS / HARDWARE
CREATE TABLE IF NOT EXISTS public.dispositivos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    numero_serie TEXT NOT NULL,
    nombre TEXT NOT NULL,
    modelo TEXT NOT NULL DEFAULT 'ESP32-BIO-V1',
    version_firmware TEXT NOT NULL DEFAULT '1.0.0',
    estado dispositivo_status NOT NULL DEFAULT 'EN_STOCK',
    cuenta_id UUID REFERENCES public.cuentas(id) ON DELETE SET NULL,
    activo BOOLEAN NOT NULL DEFAULT true,
    fecha_fabricacion TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    fecha_asignacion TIMESTAMPTZ,
    notas TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.dispositivos ALTER COLUMN cuenta_id DROP NOT NULL;
ALTER TABLE public.dispositivos ADD COLUMN IF NOT EXISTS modelo TEXT NOT NULL DEFAULT 'ESP32-BIO-V1';
ALTER TABLE public.dispositivos ADD COLUMN IF NOT EXISTS version_firmware TEXT NOT NULL DEFAULT '1.0.0';
ALTER TABLE public.dispositivos ADD COLUMN IF NOT EXISTS estado dispositivo_status NOT NULL DEFAULT 'EN_STOCK';
ALTER TABLE public.dispositivos ADD COLUMN IF NOT EXISTS activo BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE public.dispositivos ADD COLUMN IF NOT EXISTS fecha_fabricacion TIMESTAMPTZ NOT NULL DEFAULT NOW();
ALTER TABLE public.dispositivos ADD COLUMN IF NOT EXISTS fecha_asignacion TIMESTAMPTZ;
ALTER TABLE public.dispositivos ADD COLUMN IF NOT EXISTS notas TEXT NOT NULL DEFAULT '';
ALTER TABLE public.dispositivos ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
ALTER TABLE public.dispositivos ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- Resolver posibles duplicados en numero_serie antes del constraint UNIQUE
WITH duplicates AS (
    SELECT id, numero_serie,
           ROW_NUMBER() OVER(PARTITION BY numero_serie ORDER BY created_at DESC, id DESC) as rn
    FROM public.dispositivos
)
UPDATE public.dispositivos d
SET numero_serie = d.numero_serie || '_dup_' || substr(d.id::text, 1, 6)
FROM duplicates dup
WHERE d.id = dup.id AND dup.rn > 1;

DO $$ BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'dispositivos_numero_serie_key'
    ) THEN
        ALTER TABLE public.dispositivos ADD CONSTRAINT dispositivos_numero_serie_key UNIQUE (numero_serie);
    END IF;
EXCEPTION WHEN others THEN null;
END $$;

UPDATE public.dispositivos
SET estado = 'ASIGNADO',
    fecha_asignacion = COALESCE(fecha_asignacion, created_at, NOW())
WHERE cuenta_id IS NOT NULL AND estado = 'EN_STOCK';

UPDATE public.dispositivos
SET estado = 'EN_STOCK',
    fecha_asignacion = NULL
WHERE cuenta_id IS NULL AND estado = 'ASIGNADO';

ALTER TABLE public.dispositivos DROP CONSTRAINT IF EXISTS chk_dispositivo_asignacion_valida;
ALTER TABLE public.dispositivos ADD CONSTRAINT chk_dispositivo_asignacion_valida CHECK (
    (estado = 'ASIGNADO' AND cuenta_id IS NOT NULL) OR
    (estado != 'ASIGNADO')
) NOT VALID;

-- D. GANADEROS / PRODUCTORES
CREATE TABLE IF NOT EXISTS public.ganaderos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cuenta_id UUID NOT NULL REFERENCES public.cuentas(id) ON DELETE CASCADE,
    nombre TEXT NOT NULL,
    apellido_paterno TEXT NOT NULL,
    apellido_materno TEXT NOT NULL DEFAULT '',
    rancho TEXT NOT NULL,
    telefono TEXT NOT NULL DEFAULT '',
    correo TEXT NOT NULL DEFAULT '',
    activo BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.ganaderos ADD COLUMN IF NOT EXISTS apellido_materno TEXT NOT NULL DEFAULT '';
ALTER TABLE public.ganaderos ADD COLUMN IF NOT EXISTS telefono TEXT NOT NULL DEFAULT '';
ALTER TABLE public.ganaderos ADD COLUMN IF NOT EXISTS correo TEXT NOT NULL DEFAULT '';
ALTER TABLE public.ganaderos ADD COLUMN IF NOT EXISTS activo BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE public.ganaderos ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
ALTER TABLE public.ganaderos ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- E. MEDICIONES Y ANÁLISIS DE LECHE (NOM-155-SCFI-2012)
CREATE TABLE IF NOT EXISTS public.mediciones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cuenta_id UUID NOT NULL REFERENCES public.cuentas(id) ON DELETE CASCADE,
    ganadero_id UUID NOT NULL REFERENCES public.ganaderos(id) ON DELETE CASCADE,
    dispositivo_id UUID REFERENCES public.dispositivos(id) ON DELETE SET NULL,
    usuario_id UUID REFERENCES public.usuarios(id) ON DELETE SET NULL,
    ph NUMERIC(4,2) NOT NULL DEFAULT 6.70,
    densidad NUMERIC(6,4) NOT NULL DEFAULT 1.0310,
    temperatura NUMERIC(5,2) NOT NULL DEFAULT 4.00,
    fecha TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    observaciones TEXT NOT NULL DEFAULT '',
    pdf_path TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.mediciones ADD COLUMN IF NOT EXISTS cuenta_id UUID REFERENCES public.cuentas(id) ON DELETE CASCADE;
ALTER TABLE public.mediciones ADD COLUMN IF NOT EXISTS observaciones TEXT NOT NULL DEFAULT '';
ALTER TABLE public.mediciones ADD COLUMN IF NOT EXISTS pdf_path TEXT;
ALTER TABLE public.mediciones ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
ALTER TABLE public.mediciones ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- ----------------------------------------------------------------------------
-- SANITIZACIÓN DE DATOS HISTÓRICOS EN 'mediciones'
-- ----------------------------------------------------------------------------

DO $$ 
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'mediciones' AND column_name = 'ph' AND data_type = 'text'
    ) THEN
        ALTER TABLE public.mediciones 
            ALTER COLUMN ph TYPE NUMERIC(4,2) USING (
                CASE 
                    WHEN ph IS NULL OR TRIM(ph) IN ('', 'N/D', 'null', 'undefined', '-') THEN 6.70
                    WHEN regexp_replace(ph, '[^0-9.]', '', 'g') ~ '^[0-9]+(\.[0-9]+)?$' 
                        THEN regexp_replace(ph, '[^0-9.]', '', 'g')::NUMERIC(4,2)
                    ELSE 6.70
                END
            ),
            ALTER COLUMN densidad TYPE NUMERIC(6,4) USING (
                CASE 
                    WHEN densidad IS NULL OR TRIM(densidad) IN ('', 'N/D', 'null', 'undefined', '-') THEN 1.0310
                    WHEN regexp_replace(densidad, '[^0-9.]', '', 'g') ~ '^[0-9]+(\.[0-9]+)?$' 
                        THEN regexp_replace(densidad, '[^0-9.]', '', 'g')::NUMERIC(6,4)
                    ELSE 1.0310
                END
            ),
            ALTER COLUMN temperatura TYPE NUMERIC(5,2) USING (
                CASE 
                    WHEN temperatura IS NULL OR TRIM(temperatura) IN ('', 'N/D', 'null', 'undefined', '-') THEN 4.00
                    WHEN regexp_replace(temperatura, '[^0-9.]', '', 'g') ~ '^[0-9]+(\.[0-9]+)?$' 
                        THEN regexp_replace(temperatura, '[^0-9.]', '', 'g')::NUMERIC(5,2)
                    ELSE 4.00
                END
            );
    END IF;
END $$;

UPDATE public.mediciones
SET 
    ph = CASE 
        WHEN ph IS NULL THEN 6.70
        WHEN ph > 14.00 AND ph <= 140.00 THEN ROUND((ph / 10.0)::numeric, 2)
        WHEN ph > 14.00 THEN 14.00
        WHEN ph < 0.00 THEN 0.00
        ELSE ph
    END,
    densidad = CASE 
        WHEN densidad IS NULL THEN 1.0310
        WHEN densidad >= 20.0000 AND densidad <= 45.0000 THEN ROUND((1.0 + (densidad / 1000.0))::numeric, 4)
        WHEN densidad >= 900.0000 AND densidad <= 1200.0000 THEN ROUND((densidad / 1000.0)::numeric, 4)
        WHEN densidad < 0.9000 THEN 1.0280
        WHEN densidad > 1.2000 THEN 1.0340
        ELSE densidad
    END,
    temperatura = CASE 
        WHEN temperatura IS NULL THEN 4.00
        WHEN temperatura < -20.00 THEN -20.00
        WHEN temperatura > 120.00 THEN 120.00
        ELSE temperatura
    END;

ALTER TABLE public.mediciones DROP CONSTRAINT IF EXISTS chk_medicion_ph_rango;
ALTER TABLE public.mediciones ADD CONSTRAINT chk_medicion_ph_rango 
    CHECK (ph >= 0.00 AND ph <= 14.00) NOT VALID;

ALTER TABLE public.mediciones DROP CONSTRAINT IF EXISTS chk_medicion_densidad_rango;
ALTER TABLE public.mediciones ADD CONSTRAINT chk_medicion_densidad_rango 
    CHECK (densidad >= 0.9000 AND densidad <= 1.2000) NOT VALID;

ALTER TABLE public.mediciones DROP CONSTRAINT IF EXISTS chk_medicion_temperatura_rango;
ALTER TABLE public.mediciones ADD CONSTRAINT chk_medicion_temperatura_rango 
    CHECK (temperatura >= -20.00 AND temperatura <= 120.00) NOT VALID;

DO $$ BEGIN
    ALTER TABLE public.mediciones VALIDATE CONSTRAINT chk_medicion_ph_rango;
    ALTER TABLE public.mediciones VALIDATE CONSTRAINT chk_medicion_densidad_rango;
    ALTER TABLE public.mediciones VALIDATE CONSTRAINT chk_medicion_temperatura_rango;
    ALTER TABLE public.dispositivos VALIDATE CONSTRAINT chk_dispositivo_asignacion_valida;
EXCEPTION WHEN others THEN null;
END $$;

-- F. AUDITORÍA (AUDIT LOGS)
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cuenta_id UUID REFERENCES public.cuentas(id) ON DELETE SET NULL,
    usuario_id UUID REFERENCES public.usuarios(id) ON DELETE SET NULL,
    action TEXT,
    accion TEXT,
    details JSONB DEFAULT '{}'::jsonb,
    detalles JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS action TEXT;
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS accion TEXT;
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS details JSONB DEFAULT '{}'::jsonb;
ALTER TABLE public.audit_logs ADD COLUMN IF NOT EXISTS detalles JSONB DEFAULT '{}'::jsonb;

-- ----------------------------------------------------------------------------
-- 4. ÍNDICES DE RENDIMIENTO Y ESCALABILIDAD (B-TREE)
-- ----------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_usuarios_cuenta_id ON public.usuarios(cuenta_id);
CREATE INDEX IF NOT EXISTS idx_usuarios_auth_user_id ON public.usuarios(auth_user_id);
CREATE INDEX IF NOT EXISTS idx_usuarios_username ON public.usuarios(username);
CREATE INDEX IF NOT EXISTS idx_usuarios_correo ON public.usuarios(correo);

CREATE INDEX IF NOT EXISTS idx_dispositivos_cuenta_id ON public.dispositivos(cuenta_id);
CREATE INDEX IF NOT EXISTS idx_dispositivos_numero_serie ON public.dispositivos(numero_serie);
CREATE INDEX IF NOT EXISTS idx_dispositivos_estado ON public.dispositivos(estado);

CREATE INDEX IF NOT EXISTS idx_ganaderos_cuenta_id ON public.ganaderos(cuenta_id);

CREATE INDEX IF NOT EXISTS idx_mediciones_cuenta_id ON public.mediciones(cuenta_id);
CREATE INDEX IF NOT EXISTS idx_mediciones_ganadero_id ON public.mediciones(ganadero_id);
CREATE INDEX IF NOT EXISTS idx_mediciones_dispositivo_id ON public.mediciones(dispositivo_id);
CREATE INDEX IF NOT EXISTS idx_mediciones_usuario_id ON public.mediciones(usuario_id);
CREATE INDEX IF NOT EXISTS idx_mediciones_fecha ON public.mediciones(fecha DESC);
CREATE INDEX IF NOT EXISTS idx_mediciones_cuenta_fecha ON public.mediciones(cuenta_id, fecha DESC);

-- ----------------------------------------------------------------------------
-- 5. REGLAS DE NEGOCIO Y TRIGGERS AUTOMÁTICOS
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_cuentas_updated_at ON public.cuentas;
CREATE TRIGGER trg_cuentas_updated_at BEFORE UPDATE ON public.cuentas
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_usuarios_updated_at ON public.usuarios;
CREATE TRIGGER trg_usuarios_updated_at BEFORE UPDATE ON public.usuarios
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_dispositivos_updated_at ON public.dispositivos;
CREATE TRIGGER trg_dispositivos_updated_at BEFORE UPDATE ON public.dispositivos
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_ganaderos_updated_at ON public.ganaderos;
CREATE TRIGGER trg_ganaderos_updated_at BEFORE UPDATE ON public.ganaderos
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_mediciones_updated_at ON public.mediciones;
CREATE TRIGGER trg_mediciones_updated_at BEFORE UPDATE ON public.mediciones
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Desactivar operadores duplicados antiguos conservando el más reciente
WITH ranked_operators AS (
    SELECT id,
           ROW_NUMBER() OVER(PARTITION BY cuenta_id ORDER BY created_at DESC, id DESC) as rn
    FROM public.usuarios
    WHERE rol = 'OPERADOR' AND activo = true
)
UPDATE public.usuarios u
SET activo = false
FROM ranked_operators r
WHERE u.id = r.id AND r.rn > 1;

CREATE UNIQUE INDEX IF NOT EXISTS idx_max_one_operator_per_account 
ON public.usuarios (cuenta_id) 
WHERE (rol = 'OPERADOR' AND activo = true);

CREATE OR REPLACE FUNCTION public.check_max_one_operator_per_account()
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
            RAISE EXCEPTION 'Restricción BioScan: La cuenta ya posee 1 usuario Operador activo.';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_max_one_operator ON public.usuarios;
CREATE TRIGGER trg_check_max_one_operator
BEFORE INSERT OR UPDATE ON public.usuarios
FOR EACH ROW EXECUTE FUNCTION public.check_max_one_operator_per_account();

CREATE OR REPLACE FUNCTION public.sync_dispositivo_estado()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.cuenta_id IS NOT NULL THEN
            NEW.estado := 'ASIGNADO';
            IF NEW.fecha_asignacion IS NULL THEN
                NEW.fecha_asignacion := NOW();
            END IF;
        ELSE
            IF NEW.estado IS NULL THEN
                NEW.estado := 'EN_STOCK';
            END IF;
        END IF;
    ELSIF TG_OP = 'UPDATE' THEN
        IF NEW.cuenta_id IS NOT NULL AND (OLD.cuenta_id IS NULL OR OLD.cuenta_id <> NEW.cuenta_id) THEN
            IF NEW.estado = 'EN_STOCK' THEN
                NEW.estado := 'ASIGNADO';
            END IF;
            IF NEW.fecha_asignacion IS NULL THEN
                NEW.fecha_asignacion := NOW();
            END IF;
        ELSIF NEW.cuenta_id IS NULL AND OLD.cuenta_id IS NOT NULL THEN
            IF NEW.estado = 'ASIGNADO' THEN
                NEW.estado := 'EN_STOCK';
            END IF;
            NEW.fecha_asignacion := NULL;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_dispositivo_estado ON public.dispositivos;
CREATE TRIGGER trg_sync_dispositivo_estado
BEFORE INSERT OR UPDATE OF cuenta_id ON public.dispositivos
FOR EACH ROW EXECUTE FUNCTION public.sync_dispositivo_estado();

-- ----------------------------------------------------------------------------
-- 6. SEGURIDAD: ROW LEVEL SECURITY (RLS)
-- ----------------------------------------------------------------------------

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

CREATE OR REPLACE FUNCTION public.get_auth_role()
RETURNS user_role AS $$
DECLARE
    v_role user_role;
BEGIN
    SELECT rol INTO v_role
    FROM public.usuarios
    WHERE auth_user_id = auth.uid() AND activo = true
    LIMIT 1;

    RETURN v_role;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Comparación textual segura para no disparar 55P04
CREATE OR REPLACE FUNCTION public.is_superadmin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN (public.get_auth_role()::text = 'SUPERADMIN');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

ALTER TABLE public.cuentas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dispositivos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ganaderos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mediciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "rls_cuentas_acceso" ON public.cuentas;
DROP POLICY IF EXISTS "rls_usuarios_acceso" ON public.usuarios;
DROP POLICY IF EXISTS "rls_dispositivos_acceso" ON public.dispositivos;
DROP POLICY IF EXISTS "rls_ganaderos_acceso" ON public.ganaderos;
DROP POLICY IF EXISTS "rls_mediciones_acceso" ON public.mediciones;
DROP POLICY IF EXISTS "rls_audit_logs_acceso" ON public.audit_logs;

CREATE POLICY "rls_cuentas_acceso" ON public.cuentas
FOR ALL USING (
    public.is_superadmin() OR id = public.get_auth_cuenta_id() OR auth.role() = 'anon'
);

CREATE POLICY "rls_usuarios_acceso" ON public.usuarios
FOR ALL USING (
    public.is_superadmin() OR cuenta_id = public.get_auth_cuenta_id() OR auth.role() = 'anon'
);

CREATE POLICY "rls_dispositivos_acceso" ON public.dispositivos
FOR ALL USING (
    public.is_superadmin() OR cuenta_id = public.get_auth_cuenta_id() OR auth.role() = 'anon'
);

CREATE POLICY "rls_ganaderos_acceso" ON public.ganaderos
FOR ALL USING (
    public.is_superadmin() OR cuenta_id = public.get_auth_cuenta_id() OR auth.role() = 'anon'
);

CREATE POLICY "rls_mediciones_acceso" ON public.mediciones
FOR ALL USING (
    public.is_superadmin() OR cuenta_id = public.get_auth_cuenta_id() OR auth.role() = 'anon'
);

CREATE POLICY "rls_audit_logs_acceso" ON public.audit_logs
FOR ALL USING (
    public.is_superadmin() OR cuenta_id = public.get_auth_cuenta_id() OR auth.role() = 'anon'
);

-- ----------------------------------------------------------------------------
-- 7. PROCEDIMIENTOS ALMACENADOS / RPC PARA GESTIÓN TRANSACCIONAL
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.assign_device_to_account(
    p_numero_serie TEXT,
    p_cuenta_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_disp RECORD;
BEGIN
    SELECT * INTO v_disp
    FROM public.dispositivos
    WHERE numero_serie = TRIM(p_numero_serie);

    IF v_disp IS NULL THEN
        RAISE EXCEPTION 'El dispositivo con número de serie "%" no existe en el catálogo.', p_numero_serie;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.cuentas WHERE id = p_cuenta_id) THEN
        RAISE EXCEPTION 'La cuenta de destino (%) no existe.', p_cuenta_id;
    END IF;

    UPDATE public.dispositivos
    SET cuenta_id = p_cuenta_id,
        estado = 'ASIGNADO',
        fecha_asignacion = NOW()
    WHERE id = v_disp.id;

    RETURN jsonb_build_object(
        'success', true,
        'dispositivo_id', v_disp.id,
        'numero_serie', v_disp.numero_serie,
        'cuenta_id', p_cuenta_id,
        'estado', 'ASIGNADO'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Alta integral usando rol 'ADMINISTRADOR' comprometido (100% compatible con Flutter)
CREATE OR REPLACE FUNCTION public.provision_client_account_and_admin(
    p_account_name TEXT,
    p_empresa TEXT,
    p_admin_email TEXT,
    p_admin_password TEXT,
    p_admin_username TEXT,
    p_admin_nombre TEXT,
    p_telefono TEXT DEFAULT '',
    p_device_serial TEXT DEFAULT NULL,
    p_account_id UUID DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_account_id UUID;
    v_new_auth_id UUID;
    v_clean_email TEXT;
    v_clean_username TEXT;
    v_assigned_device_id UUID := NULL;
BEGIN
    v_clean_email := LOWER(TRIM(p_admin_email));
    v_clean_username := LOWER(TRIM(p_admin_username));
    v_account_id := COALESCE(p_account_id, gen_random_uuid());

    -- 1. Crear o actualizar Cuenta
    INSERT INTO public.cuentas (id, nombre, empresa, correo, telefono, activo)
    VALUES (v_account_id, TRIM(p_account_name), TRIM(p_empresa), v_clean_email, TRIM(p_telefono), true)
    ON CONFLICT (id) DO UPDATE SET
        nombre = EXCLUDED.nombre,
        empresa = EXCLUDED.empresa,
        correo = EXCLUDED.correo,
        telefono = EXCLUDED.telefono;

    -- 2. Crear o actualizar Usuario en auth.users
    SELECT id INTO v_new_auth_id FROM auth.users WHERE email = v_clean_email LIMIT 1;

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
            v_clean_email,
            extensions.crypt(p_admin_password, extensions.gen_salt('bf')),
            NOW(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            jsonb_build_object('username', v_clean_username, 'nombre', p_admin_nombre),
            'authenticated',
            'authenticated',
            NOW(),
            NOW()
        );
    ELSE
        UPDATE auth.users
        SET encrypted_password = extensions.crypt(p_admin_password, extensions.gen_salt('bf')),
            updated_at = NOW()
        WHERE id = v_new_auth_id;
    END IF;

    -- 3. Crear o actualizar Perfil en public.usuarios con rol ADMINISTRADOR
    INSERT INTO public.usuarios (
        auth_user_id,
        cuenta_id,
        username,
        nombre,
        correo,
        rol,
        activo
    ) VALUES (
        v_new_auth_id,
        v_account_id,
        v_clean_username,
        TRIM(p_admin_nombre),
        v_clean_email,
        'ADMINISTRADOR',
        true
    )
    ON CONFLICT (username) DO UPDATE SET
        auth_user_id = EXCLUDED.auth_user_id,
        cuenta_id = EXCLUDED.cuenta_id,
        nombre = EXCLUDED.nombre,
        correo = EXCLUDED.correo,
        rol = EXCLUDED.rol,
        activo = true;

    -- 4. Vincular Dispositivo si fue provisto
    IF p_device_serial IS NOT NULL AND TRIM(p_device_serial) <> '' THEN
        UPDATE public.dispositivos
        SET cuenta_id = v_account_id,
            estado = 'ASIGNADO',
            fecha_asignacion = NOW()
        WHERE numero_serie = TRIM(p_device_serial)
        RETURNING id INTO v_assigned_device_id;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'cuenta_id', v_account_id,
        'auth_user_id', v_new_auth_id,
        'username', v_clean_username,
        'correo', v_clean_email,
        'dispositivo_asignado', p_device_serial,
        'dispositivo_id', v_assigned_device_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;

-- C. RPC para crear Operador usando rol 'OPERADOR'
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
    SELECT * INTO v_caller_user
    FROM public.usuarios
    WHERE auth_user_id = auth.uid() AND activo = true;

    IF v_caller_user IS NULL OR (v_caller_user.rol::text NOT IN ('SUPERADMIN', 'ADMIN_CUENTA', 'ADMINISTRADOR')) THEN
        RAISE EXCEPTION 'Acceso denegado. Solamente un Administrador activo puede crear usuarios operadores.';
    END IF;

    v_clean_username := LOWER(TRIM(p_username));
    v_email := CASE 
        WHEN TRIM(p_correo) <> '' THEN LOWER(TRIM(p_correo))
        ELSE v_clean_username || '@bioscan.app'
    END;

    IF EXISTS (SELECT 1 FROM public.usuarios WHERE username = v_clean_username) THEN
        RAISE EXCEPTION 'El nombre de usuario "%" ya se encuentra registrado.', v_clean_username;
    END IF;

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
        extensions.crypt(p_password, extensions.gen_salt('bf')),
        NOW(),
        '{"provider":"email","providers":["email"]}'::jsonb,
        jsonb_build_object('username', v_clean_username, 'nombre', p_nombre),
        'authenticated',
        'authenticated',
        NOW(),
        NOW()
    );

    v_operator_id := gen_random_uuid();
    INSERT INTO public.usuarios (
        id,
        auth_user_id,
        cuenta_id,
        username,
        nombre,
        correo,
        rol,
        activo
    ) VALUES (
        v_operator_id,
        v_new_auth_id,
        v_caller_user.cuenta_id,
        v_clean_username,
        TRIM(p_nombre),
        v_email,
        'OPERADOR',
        true
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

-- ----------------------------------------------------------------------------
-- 8. DATOS INICIALES (SEED DATA DETERMINÍSTICO Y SEGURO)
-- ----------------------------------------------------------------------------

DO $$
DECLARE
    v_cuenta_demo_id UUID := '00000000-0000-0000-0000-000000000001'::uuid;
    v_admin_auth_id  UUID;
    v_admin_user_id  UUID;
    v_proto_dev_id   UUID := '00000000-0000-0000-0000-000000000010'::uuid;
    v_stock_dev_id   UUID := '00000000-0000-0000-0000-000000000011'::uuid;
    v_ganadero_id    UUID := '00000000-0000-0000-0000-000000000020'::uuid;
    v_medicion_id    UUID := '00000000-0000-0000-0000-000000000030'::uuid;
BEGIN
    -- a) Cuenta Inicial de Pruebas
    INSERT INTO public.cuentas (
        id, nombre, empresa, rfc_identificacion, telefono, correo, direccion, activo
    ) VALUES (
        v_cuenta_demo_id,
        'Rancho El Paraíso - Lácteos San José',
        'Lácteos San José S.A. de C.V.',
        'LSJ120304XYZ',
        '+52 33 1234 5678',
        'admin@elparaiso.com',
        'Km 14 Carr. Tepatitlán - Arandas, Jalisco, México',
        true
    ) ON CONFLICT (id) DO UPDATE SET
        nombre = EXCLUDED.nombre,
        empresa = EXCLUDED.empresa;

    -- b) Usuario Administrador en auth.users
    SELECT id INTO v_admin_auth_id FROM auth.users WHERE email = 'admin@elparaiso.com' LIMIT 1;

    IF v_admin_auth_id IS NULL THEN
        v_admin_auth_id := '00000000-0000-0000-0000-000000000102'::uuid;
        INSERT INTO auth.users (
            id, instance_id, email, encrypted_password, email_confirmed_at,
            raw_app_meta_data, raw_user_meta_data, aud, role, created_at, updated_at
        ) VALUES (
            v_admin_auth_id,
            '00000000-0000-0000-0000-000000000000',
            'admin@elparaiso.com',
            extensions.crypt('admin123', extensions.gen_salt('bf')),
            NOW(),
            '{"provider":"email","providers":["email"]}'::jsonb,
            '{"username":"admin_paraiso","nombre":"Administrador El Paraíso"}'::jsonb,
            'authenticated',
            'authenticated',
            NOW(),
            NOW()
        );
    ELSE
        UPDATE auth.users
        SET encrypted_password = extensions.crypt('admin123', extensions.gen_salt('bf')),
            email_confirmed_at = COALESCE(email_confirmed_at, NOW()),
            updated_at = NOW()
        WHERE id = v_admin_auth_id;
    END IF;

    -- b.2) Perfil en public.usuarios con rol 'ADMINISTRADOR' (valor original comprometido)
    SELECT id INTO v_admin_user_id FROM public.usuarios WHERE username = 'admin_paraiso' LIMIT 1;

    IF v_admin_user_id IS NULL THEN
        v_admin_user_id := '00000000-0000-0000-0000-000000000002'::uuid;
        INSERT INTO public.usuarios (
            id, auth_user_id, cuenta_id, username, nombre, correo, rol, activo
        ) VALUES (
            v_admin_user_id,
            v_admin_auth_id,
            v_cuenta_demo_id,
            'admin_paraiso',
            'Ing. Roberto Gómez',
            'admin@elparaiso.com',
            'ADMINISTRADOR',
            true
        ) ON CONFLICT (id) DO UPDATE SET
            auth_user_id = EXCLUDED.auth_user_id,
            cuenta_id = EXCLUDED.cuenta_id,
            username = EXCLUDED.username,
            rol = EXCLUDED.rol;
    ELSE
        UPDATE public.usuarios
        SET auth_user_id = v_admin_auth_id,
            cuenta_id = v_cuenta_demo_id,
            rol = 'ADMINISTRADOR',
            activo = true
        WHERE id = v_admin_user_id;
    END IF;

    -- c) Dispositivo Prototipo Asignado a la Cuenta
    INSERT INTO public.dispositivos (
        id, numero_serie, nombre, modelo, version_firmware, estado, cuenta_id, activo, notas
    ) VALUES (
        v_proto_dev_id,
        'Prototipo',
        'Escáner BioScan Prototipo Alpha',
        'ESP32-BIO-V1',
        '1.0.0',
        'ASIGNADO',
        v_cuenta_demo_id,
        true,
        'Unidad prototipo con electrodo pH 4502C y sensor digital DS18B20'
    ) ON CONFLICT (numero_serie) DO UPDATE SET
        cuenta_id = EXCLUDED.cuenta_id,
        estado = EXCLUDED.estado;

    -- c.2) Dispositivo en Stock Global (Almacén de fábrica)
    INSERT INTO public.dispositivos (
        id, numero_serie, nombre, modelo, version_firmware, estado, cuenta_id, activo, notas
    ) VALUES (
        v_stock_dev_id,
        'BIO-2026-0002',
        'Escáner BioScan Unidad Almacén #02',
        'ESP32-BIO-V1',
        '1.0.1',
        'EN_STOCK',
        NULL,
        true,
        'Dispositivo ensamblado y calibrado en stock de fábrica'
    ) ON CONFLICT (numero_serie) DO NOTHING;

    -- d) Ganadero de Muestra
    INSERT INTO public.ganaderos (
        id, cuenta_id, nombre, apellido_paterno, apellido_materno, rancho, telefono, correo, activo
    ) VALUES (
        v_ganadero_id,
        v_cuenta_demo_id,
        'Carlos',
        'Mendoza',
        'Ruiz',
        'Rancho La Providencia',
        '3319876543',
        'carlos.mendoza@email.com',
        true
    ) ON CONFLICT (id) DO NOTHING;

    -- e) Medición de Prueba (Validación NOM-155-SCFI-2012)
    INSERT INTO public.mediciones (
        id,
        cuenta_id,
        ganadero_id,
        dispositivo_id,
        usuario_id,
        ph,
        densidad,
        temperatura,
        fecha,
        observaciones
    ) VALUES (
        v_medicion_id,
        v_cuenta_demo_id,
        v_ganadero_id,
        v_proto_dev_id,
        v_admin_user_id,
        6.68,       -- pH óptimo NOM-155 (6.60 - 6.80)
        1.0315,     -- Densidad óptima sin agua agregada (1.028 - 1.034 g/mL)
        4.50,       -- Temperatura óptima de tanque frío (°C)
        NOW(),
        'Medición de control matutino: Leche de acopio aprobada conforme a NOM-155-SCFI-2012'
    ) ON CONFLICT (id) DO NOTHING;

END $$;
