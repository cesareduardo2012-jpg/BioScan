-- ============================================================================
-- BioScan -- Script consolidado de migraciones PENDIENTES
-- ============================================================================
-- Reune las 3 migraciones que aun NO se han aplicado al proyecto real:
--   * 20260914_add_es_simulado_column.sql
--   * 20260914_fix_rls_remove_anon_bypass.sql
--   * 20260914211000_fix_schema_inconsistencies.sql
--
-- COMO USARLO: Dashboard de Supabase -> SQL Editor -> New query -> pegar
-- todo este archivo -> Run.
--
-- Es idempotente: se puede ejecutar varias veces sin romper nada. Los
-- ALTER TYPE ... RENAME originales NO lo eran (fallaban en la 2a corrida),
-- aqui van envueltos en un guard.
-- ============================================================================

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. Columnas faltantes en mediciones
-- ----------------------------------------------------------------------------
-- es_simulado: la app YA la manda en el payload de sync_service.dart. Sin
-- esta columna, Postgrest rechaza el upsert COMPLETO y NINGUNA medicion
-- sube a la nube.
ALTER TABLE public.mediciones ADD COLUMN IF NOT EXISTS es_simulado BOOLEAN NOT NULL DEFAULT false;

-- activo: soft delete de mediciones.
ALTER TABLE public.mediciones ADD COLUMN IF NOT EXISTS activo BOOLEAN NOT NULL DEFAULT true;

-- ----------------------------------------------------------------------------
-- 2. Limpieza de columnas duplicadas/redundantes
-- ----------------------------------------------------------------------------
-- audit_logs tenia 'accion'/'detalles' duplicando 'action'/'details'.
ALTER TABLE public.audit_logs
  DROP COLUMN IF EXISTS accion,
  DROP COLUMN IF EXISTS detalles;

-- fecha_registro se estandariza en created_at.
ALTER TABLE public.usuarios     DROP COLUMN IF EXISTS fecha_registro;
ALTER TABLE public.dispositivos DROP COLUMN IF EXISTS fecha_registro;
ALTER TABLE public.ganaderos    DROP COLUMN IF EXISTS fecha_registro;

-- ----------------------------------------------------------------------------
-- 3. Estandarizar nombres de ENUMs (con guard para poder re-ejecutar)
-- ----------------------------------------------------------------------------
DO $rename_role$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
             WHERE t.typname = 'user_role' AND n.nspname = 'public')
     AND NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                     WHERE t.typname = 'rol_usuario' AND n.nspname = 'public')
  THEN
    ALTER TYPE public.user_role RENAME TO rol_usuario;
  END IF;
END
$rename_role$;

DO $rename_status$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
             WHERE t.typname = 'dispositivo_status' AND n.nspname = 'public')
     AND NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                     WHERE t.typname = 'estado_dispositivo' AND n.nspname = 'public')
  THEN
    ALTER TYPE public.dispositivo_status RENAME TO estado_dispositivo;
  END IF;
END
$rename_status$;

-- ----------------------------------------------------------------------------
-- 4. SEGURIDAD: quitar el bypass anonimo de las politicas RLS
-- ----------------------------------------------------------------------------
-- Las politicas tenian "OR auth.role() = 'anon'", lo que daba lectura Y
-- escritura sobre los datos de TODAS las cuentas a cualquiera que tuviera
-- la anon key -- y esa key viaja dentro del APK.
DROP POLICY IF EXISTS "rls_cuentas_acceso"      ON public.cuentas;
DROP POLICY IF EXISTS "rls_usuarios_acceso"     ON public.usuarios;
DROP POLICY IF EXISTS "rls_dispositivos_acceso" ON public.dispositivos;
DROP POLICY IF EXISTS "rls_ganaderos_acceso"    ON public.ganaderos;
DROP POLICY IF EXISTS "rls_mediciones_acceso"   ON public.mediciones;
DROP POLICY IF EXISTS "rls_audit_logs_acceso"   ON public.audit_logs;

CREATE POLICY "rls_cuentas_acceso" ON public.cuentas
FOR ALL USING (public.is_superadmin() OR id = public.get_auth_cuenta_id());

CREATE POLICY "rls_usuarios_acceso" ON public.usuarios
FOR ALL USING (public.is_superadmin() OR cuenta_id = public.get_auth_cuenta_id());

CREATE POLICY "rls_dispositivos_acceso" ON public.dispositivos
FOR ALL USING (public.is_superadmin() OR cuenta_id = public.get_auth_cuenta_id());

CREATE POLICY "rls_ganaderos_acceso" ON public.ganaderos
FOR ALL USING (public.is_superadmin() OR cuenta_id = public.get_auth_cuenta_id());

CREATE POLICY "rls_mediciones_acceso" ON public.mediciones
FOR ALL USING (public.is_superadmin() OR cuenta_id = public.get_auth_cuenta_id());

CREATE POLICY "rls_audit_logs_acceso" ON public.audit_logs
FOR ALL USING (public.is_superadmin() OR cuenta_id = public.get_auth_cuenta_id());

-- ----------------------------------------------------------------------------
-- 5. RPC para resolver el correo a partir del username SIN acceso anonimo
-- ----------------------------------------------------------------------------
-- Supabase Auth exige correo, no username. Esta funcion deja que el login
-- lo resuelva sin tener que abrir la tabla usuarios entera al rol anon.
CREATE OR REPLACE FUNCTION public.resolve_login_email(p_identifier TEXT)
RETURNS TEXT AS $fn$
DECLARE
    v_correo TEXT;
BEGIN
    SELECT correo INTO v_correo
    FROM public.usuarios
    WHERE (username = p_identifier OR correo = p_identifier)
      AND activo = true
    LIMIT 1;

    RETURN v_correo;
END;
$fn$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.resolve_login_email(TEXT) TO anon, authenticated;

COMMIT;
