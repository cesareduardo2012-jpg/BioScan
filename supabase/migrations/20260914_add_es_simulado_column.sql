-- ============================================================================
-- BioScan - Agrega columna es_simulado a mediciones
-- ============================================================================
-- El Modo Simulación/Demo (bluetooth_manager.dart) genera lecturas con el
-- mismo formato de texto que una lectura real del ESP32 -- sin un campo
-- explícito, una medición simulada era indistinguible de una real una vez
-- guardada, tanto en la base de datos como en el certificado PDF/ticket
-- impreso entregado al ganadero.
--
-- Esta columna ya se agregó del lado de la app (SQLite local, migración v9
-- en database_migrator.dart) y el certificado/ticket ya la muestran cuando
-- es true. Falta aplicar este archivo en el proyecto real de Supabase (SQL
-- Editor del dashboard o `supabase db push`) antes de que sync_service.dart
-- pueda mandarla a la nube sin romper el upsert por columna inexistente
-- -- mismo patrón que el bug ya corregido de 'fecha_registro' en ganaderos.
-- ============================================================================

ALTER TABLE public.mediciones ADD COLUMN IF NOT EXISTS es_simulado BOOLEAN NOT NULL DEFAULT false;
