-- 1. Unificar columnas en audit_logs eliminando las redundantes en español
ALTER TABLE public.audit_logs 
  DROP COLUMN IF EXISTS accion,
  DROP COLUMN IF EXISTS detalles;

-- 2. Agregar soft delete a mediciones
ALTER TABLE public.mediciones 
  ADD COLUMN IF NOT EXISTS activo boolean NOT NULL DEFAULT true;

-- 3. Limpiar fecha_registro redundante (usaremos created_at para mantener estándar)
ALTER TABLE public.usuarios DROP COLUMN IF EXISTS fecha_registro;
ALTER TABLE public.dispositivos DROP COLUMN IF EXISTS fecha_registro;
ALTER TABLE public.ganaderos DROP COLUMN IF EXISTS fecha_registro;

-- 4. Estandarizar nombres de ENUMs
ALTER TYPE public.user_role RENAME TO rol_usuario;
ALTER TYPE public.dispositivo_status RENAME TO estado_dispositivo;
