-- ============================================================================
-- BIOSCAN: RPC PARA ELIMINACIÓN FÍSICA DE OPERADORES
-- ============================================================================

CREATE OR REPLACE FUNCTION public.delete_operator_user(
    p_operator_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_caller_user RECORD;
    v_operator_user RECORD;
    v_auth_id UUID;
BEGIN
    -- 1. Validar Administrador Activo
    SELECT * INTO v_caller_user
    FROM public.usuarios
    WHERE auth_user_id = auth.uid() AND activo = true;

    IF v_caller_user IS NULL OR (v_caller_user.rol::text NOT IN ('SUPERADMIN', 'ADMIN_CUENTA', 'ADMINISTRADOR')) THEN
        RAISE EXCEPTION 'Acceso denegado. Solamente un Administrador puede eliminar usuarios.';
    END IF;

    -- 2. Validar que el operador existe
    SELECT * INTO v_operator_user
    FROM public.usuarios
    WHERE id = p_operator_id;

    IF v_operator_user IS NULL THEN
        RETURN jsonb_build_object('success', true, 'message', 'Operador ya no existía en la BD.');
    END IF;

    -- Validar organización
    IF v_caller_user.rol::text != 'SUPERADMIN' AND v_operator_user.cuenta_id != v_caller_user.cuenta_id THEN
        RAISE EXCEPTION 'Acceso denegado. Este operador pertenece a una organización distinta.';
    END IF;

    v_auth_id := v_operator_user.auth_user_id;

    -- 3. Eliminar de Auth Users (que en cascada puede borrar en public.usuarios, pero lo forzamos abajo por si acaso)
    IF v_auth_id IS NOT NULL THEN
        DELETE FROM auth.users WHERE id = v_auth_id;
    END IF;

    -- 4. Eliminar de public.usuarios (por si no hay cascada)
    DELETE FROM public.usuarios WHERE id = p_operator_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Operador eliminado permanentemente'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;
