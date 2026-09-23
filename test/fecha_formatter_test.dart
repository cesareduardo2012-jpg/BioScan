import 'package:flutter_test/flutter_test.dart';
import 'package:scanner_leche_app/utils/fecha_formatter.dart';

/// Regresión: el ticket térmico impreso mostraba una hora que no coincidía con
/// el momento en que se realizó la prueba.
///
/// Las mediciones se guardan en UTC para que la sincronización sea consistente
/// entre dispositivos, pero el ticket, el certificado PDF y el historial
/// mostraban esa hora sin convertirla de vuelta. En México (UTC-6) eso daba una
/// diferencia de 6 horas respecto a la realidad.
void main() {
  group('FechaFormatter: conversión de UTC a hora local', () {
    test('convierte una fecha UTC a la hora local del dispositivo', () {
      // 15:34 UTC. En cualquier zona al oeste de Greenwich la hora local es
      // distinta; la prueba no asume una zona concreta, solo que la conversión
      // ocurre y coincide con lo que Dart calcula como local.
      const utc = '2026-09-23T15:34:13.128Z';
      final esperado = DateTime.utc(2026, 9, 23, 15, 34, 13, 128).toLocal();

      final resultado = FechaFormatter.aLocal(utc);

      expect(resultado, isNotNull);
      expect(resultado!.hour, esperado.hour);
      expect(resultado.minute, esperado.minute);
      expect(resultado.isUtc, isFalse,
          reason: 'debe entregarse en hora local, no en UTC');
    });

    test('la hora formateada NO es la hora cruda de la cadena UTC', () {
      // Este es exactamente el bug reportado: el ticket imprimía "15:34"
      // cuando la prueba se hizo a las 09:34 hora local.
      const utc = '2026-09-23T15:34:13.128Z';
      final local = DateTime.utc(2026, 9, 23, 15, 34, 13).toLocal();

      final texto = FechaFormatter.fechaHora(utc);

      final horaLocal = local.hour.toString().padLeft(2, '0');
      expect(texto, contains('$horaLocal:34'));
      if (local.hour != 15) {
        expect(texto, isNot(contains('15:34')),
            reason: 'no debe imprimirse la hora UTC sin convertir');
      }
    });

    test('respeta las fechas antiguas guardadas en hora local (sin sufijo Z)', () {
      // Antes de que home_screen usara toUtc(), las mediciones se guardaban
      // como hora local ingenua. toLocal() sobre una fecha ya local no la
      // altera, asi que esos registros deben mostrarse tal cual.
      const ingenua = '2026-09-23T09:34:13.000';

      expect(FechaFormatter.fechaHora(ingenua), '23/09/2026 09:34');
    });

    test('incluye segundos en el formato del historial', () {
      const ingenua = '2026-09-23T09:34:13.000';

      expect(FechaFormatter.fechaHoraConSegundos(ingenua), '23/09/2026 09:34:13');
    });

    test('devuelve el texto de reemplazo cuando la fecha es inválida o vacía', () {
      expect(FechaFormatter.fechaHora(null), 'N/D');
      expect(FechaFormatter.fechaHora(''), 'N/D');
      expect(FechaFormatter.fechaHora('no-es-una-fecha'), 'N/D');
      expect(FechaFormatter.aLocal('no-es-una-fecha'), isNull);
    });

    test('rellena con cero los componentes de un solo dígito', () {
      const ingenua = '2026-01-05T07:08:09.000';

      expect(FechaFormatter.fechaHoraConSegundos(ingenua), '05/01/2026 07:08:09');
    });
  });
}
