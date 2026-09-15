-- ============================================================================
-- BIOSCAN: RPC PARA RESTABLECIMIENTO DE CONTRASEÑAS DE OPERADORES
-- ============================================================================
-- Este script crea la función RPC requerida para que un Administrador 
-- pueda cambiar la contraseña de sus operadores directamente sin validación 
-- de correos electrónicos.

CREATE OR REPLACE FUNCTION public.update_operator_password(
    p_operator_id UUID,
    p_new_password TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_caller_user RECORD;
    v_operator_user RECORD;
    v_auth_id UUID;
BEGIN
    -- 1. Validar que quien ejecuta la función es un Administrador Activo
    SELECT * INTO v_caller_user
    FROM public.usuarios
    WHERE auth_user_id = auth.uid() AND activo = true;

    IF v_caller_user IS NULL OR (v_caller_user.rol::text NOT IN ('SUPERADMIN', 'ADMIN_CUENTA', 'ADMINISTRADOR')) THEN
        RAISE EXCEPTION 'Acceso denegado. Solamente un Administrador puede cambiar contraseñas.';
    END IF;

    -- 2. Validar que el operador existe y pertenece a la misma cuenta del Administrador
    SELECT * INTO v_operator_user
    FROM public.usuarios
    WHERE id = p_operator_id;

    IF v_operator_user IS NULL THEN
        RAISE EXCEPTION 'El operador no existe en la base de datos.';
    END IF;

    -- Validar que no estemos intentando cambiarle la contraseña a alguien de otra cuenta
    -- (A menos que el que ejecuta sea SUPERADMIN)
    IF v_caller_user.rol::text != 'SUPERADMIN' AND v_operator_user.cuenta_id != v_caller_user.cuenta_id THEN
        RAISE EXCEPTION 'Acceso denegado. Este operador pertenece a una organización distinta.';
    END IF;

    -- 3. Obtener el UUID asociado en auth.users
    v_auth_id := v_operator_user.auth_user_id;

    IF v_auth_id IS NULL THEN
        RAISE EXCEPTION 'Este operador no tiene una cuenta de inicio de sesión nube vinculada (auth_user_id es NULL).';
    END IF;

    -- 4. Actualizar la contraseña en auth.users (esquema seguro)
    -- Usamos extensions.crypt para generar el hash de forma segura, idéntico a cómo
    -- lo hace Supabase internamente.
    UPDATE auth.users
    SET encrypted_password = extensions.crypt(p_new_password, extensions.gen_salt('bf')),
        updated_at = NOW()
    WHERE id = v_auth_id;

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Contraseña actualizada exitosamente',
        'operator_id', p_operator_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions;
