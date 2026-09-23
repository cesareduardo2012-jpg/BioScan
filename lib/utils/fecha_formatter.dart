/// Formateo de fechas de medición para mostrar e imprimir.
///
/// Las mediciones se guardan en UTC (`DateTime.now().toUtc()` en
/// home_screen.dart) para que la sincronización con Supabase sea consistente
/// entre dispositivos y zonas horarias. El problema es que quien las mostraba
/// nunca las convertía de vuelta: el ticket térmico hacía `DateTime.parse()`
/// --que sobre una cadena terminada en 'Z' devuelve un DateTime en UTC-- y el
/// historial y el PDF directamente recortaban la cadena ISO. El resultado era
/// una hora adelantada 6 horas en México, que no coincidía con el momento real
/// de la prueba.
///
/// Este formateador centraliza la conversión. `DateTime.parse(...).toLocal()`
/// resuelve ambos formatos que existen en la base:
///   * "2026-09-23T15:34:13.128Z" (UTC, registros nuevos) -> se convierte
///   * "2026-09-23T09:34:13.128"  (ingenua, registros viejos guardados en
///     hora local antes de que se usara toUtc) -> toLocal() no la altera
class FechaFormatter {
  FechaFormatter._();

  /// Convierte la fecha almacenada a la hora local del dispositivo.
  ///
  /// Devuelve null si la cadena no es parseable, para que quien llame decida
  /// el texto de reemplazo en vez de inventar una fecha.
  static DateTime? aLocal(String? isoString) {
    if (isoString == null || isoString.trim().isEmpty) return null;
    return DateTime.tryParse(isoString)?.toLocal();
  }

  /// "23/09/2026 09:34" -- para el ticket térmico y el certificado PDF.
  static String fechaHora(String? isoString, {String siNoHay = 'N/D'}) {
    final fecha = aLocal(isoString);
    if (fecha == null) return siNoHay;
    return '${_dosDigitos(fecha.day)}/${_dosDigitos(fecha.month)}/${fecha.year} '
        '${_dosDigitos(fecha.hour)}:${_dosDigitos(fecha.minute)}';
  }

  /// "23/09/2026 09:34:13" -- para el historial, donde los segundos ayudan a
  /// distinguir mediciones tomadas con pocos minutos de diferencia.
  static String fechaHoraConSegundos(String? isoString, {String siNoHay = 'N/D'}) {
    final fecha = aLocal(isoString);
    if (fecha == null) return siNoHay;
    return '${_dosDigitos(fecha.day)}/${_dosDigitos(fecha.month)}/${fecha.year} '
        '${_dosDigitos(fecha.hour)}:${_dosDigitos(fecha.minute)}:${_dosDigitos(fecha.second)}';
  }

  static String _dosDigitos(int valor) => valor.toString().padLeft(2, '0');
}
