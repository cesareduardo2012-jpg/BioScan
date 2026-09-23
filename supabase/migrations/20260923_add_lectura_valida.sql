-- ============================================================================
-- BioScan - Deja de fabricar valores cuando el sensor manda una lectura imposible
-- ============================================================================
-- Las columnas ph, densidad y temperatura son NUMERIC NOT NULL con CHECK de
-- rango (ph 0-14, densidad 0.9-1.2, temperatura -20-120). Una lectura fuera
-- de rango -- por ejemplo densidad negativa cuando la sonda no esta sumergida
-- en leche -- no cabe en esas columnas, asi que medicion.dart la recortaba con
-- clamp() para que el upsert no fallara.
--
-- El efecto es que una lectura invalida se guardaba como un numero plausible y
-- quedaba indistinguible de una medicion buena. Medido el 23/09/2026: 4 de 19
-- mediciones (21%) tenian densidad exactamente 0.9000, el piso del clamp.
-- Peor aun, cuando el sensor no manda nada el valor por defecto de densidad es
-- 1.0, que es justo la densidad del agua pura -- la adulteracion que la app
-- existe para detectar.
--
-- El ticket impreso SI dice la verdad (analisis_leche.dart marca
-- densImplausible y emite "LECTURA DE DENSIDAD NO VALIDA"), asi que el papel y
-- la nube se contradecian.
--
-- Estas columnas conservan lo que realmente mando el sensor, sin tocar los
-- CHECK que protegen a las columnas numericas de datos basura.
-- ============================================================================

ALTER TABLE public.mediciones
  ADD COLUMN IF NOT EXISTS lectura_valida BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS ph_raw TEXT,
  ADD COLUMN IF NOT EXISTS densidad_raw TEXT,
  ADD COLUMN IF NOT EXISTS temperatura_raw TEXT;

COMMENT ON COLUMN public.mediciones.lectura_valida IS
  'false cuando el sensor reporto un valor fuera de rango fisico o no reporto nada, y las columnas numericas traen un valor ajustado en vez del medido. Ver *_raw para lo que realmente llego.';
COMMENT ON COLUMN public.mediciones.densidad_raw IS
  'Texto crudo del sensor antes de convertir y recortar. Null en registros anteriores a esta migracion.';

-- ----------------------------------------------------------------------------
-- Marcar los registros que ya quedaron con la densidad recortada.
-- ----------------------------------------------------------------------------
-- La leche real ronda 1.028-1.034 g/mL. Un valor de EXACTAMENTE 0.9000 o
-- 1.2000 (los dos topes del clamp, al cuarto decimal) no ocurre midiendo: es
-- la firma del recorte. Su valor original ya no es recuperable desde la nube,
-- pero al menos dejan de pasar por mediciones legitimas.
UPDATE public.mediciones
SET lectura_valida = false
WHERE densidad IN (0.9000, 1.2000)
   OR ph IN (0.00, 14.00)
   OR temperatura IN (-20.00, 120.00);
