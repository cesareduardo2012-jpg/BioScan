-- ============================================================================
-- BioScan - Corrige fuga de datos entre cuentas (multi-tenant RLS)
-- ============================================================================
-- Las politicas RLS creadas en 20260909_optimized_production_schema.sql
-- incluyen "OR auth.role() = 'anon'" en las 6 tablas multi-tenant
-- (cuentas, usuarios, dispositivos, ganaderos, mediciones, audit_logs).
--
-- La app trae integrada su anon/publishable key en el binario (normal y
-- necesario para conectarse sin backend propio -- ver
-- lib/utils/supabase_config.dart). El problema es que cualquier peticion
-- hecha SIN una sesion de Supabase Auth activa queda autenticada como
-- 'anon', y esa clausula le daba acceso de LECTURA Y ESCRITURA a los datos
-- de TODAS las cuentas, no solo la propia -- explotable con solo la anon
-- key publica via HTTP directo, sin necesitar login.
--
-- No es un escenario remoto: sync_service.dart dispara sus upserts/selects
-- sin verificar antes si hay una sesion de Supabase Auth activa, y el login
-- local (admin/admin123, o cualquier cuenta creada offline) nunca establece
-- una sesion real de Supabase Auth.
--
-- Esta migracion quita esa clausula de las 6 politicas, y agrega una
-- funcion RPC minima y "security definer" para que el login pueda seguir
-- resolviendo el correo real a partir de un username ANTES de autenticarse
-- (Supabase Auth exige correo, no username), sin necesitar dejar abierto el
-- acceso anonimo de lectura a la tabla completa de usuarios. Ejecutar este
-- archivo en el SQL Editor del dashboard de Supabase (o via `supabase db
-- push` si se usa el CLI) del proyecto real -- no se puede aplicar desde
-- aqui, solo se tiene la anon key publica, sin permisos para alterar
-- politicas.
-- ============================================================================

DROP POLICY IF EXISTS "rls_cuentas_acceso" ON public.cuentas;
DROP POLICY IF EXISTS "rls_usuarios_acceso" ON public.usuarios;
DROP POLICY IF EXISTS "rls_dispositivos_acceso" ON public.dispositivos;
DROP POLICY IF EXISTS "rls_ganaderos_acceso" ON public.ganaderos;
DROP POLICY IF EXISTS "rls_mediciones_acceso" ON public.mediciones;
DROP POLICY IF EXISTS "rls_audit_logs_acceso" ON public.audit_logs;

CREATE POLICY "rls_cuentas_acceso" ON public.cuentas
FOR ALL USING (
    public.is_superadmin() OR id = public.get_auth_cuenta_id()
);

CREATE POLICY "rls_usuarios_acceso" ON public.usuarios
FOR ALL USING (
    public.is_superadmin() OR cuenta_id = public.get_auth_cuenta_id()
);

CREATE POLICY "rls_dispositivos_acceso" ON public.dispositivos
FOR ALL USING (
    public.is_superadmin() OR cuenta_id = public.get_auth_cuenta_id()
);

CREATE POLICY "rls_ganaderos_acceso" ON public.ganaderos
FOR ALL USING (
    public.is_superadmin() OR cuenta_id = public.get_auth_cuenta_id()
);

CREATE POLICY "rls_mediciones_acceso" ON public.mediciones
FOR ALL USING (
    public.is_superadmin() OR cuenta_id = public.get_auth_cuenta_id()
);

CREATE POLICY "rls_audit_logs_acceso" ON public.audit_logs
FOR ALL USING (
    public.is_superadmin() OR cuenta_id = public.get_auth_cuenta_id()
);

-- ----------------------------------------------------------------------------
-- RPC segura para que el login (auth_service.dart) pueda resolver el correo
-- real a partir de un username/correo introducido por el usuario, sin
-- necesitar acceso anonimo de lectura a toda la tabla usuarios. Solo
-- devuelve el correo de una cuenta activa, nada mas del registro.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.resolve_login_email(p_identifier TEXT)
RETURNS TEXT AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION public.resolve_login_email(TEXT) TO anon, authenticated;
