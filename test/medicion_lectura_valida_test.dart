import 'package:flutter_test/flutter_test.dart';
import 'package:scanner_leche_app/models/medicion.dart';

/// Regresión: una lectura imposible del sensor se guardaba en la nube como un
/// número plausible, sin dejar rastro de que había sido ajustada.
///
/// Las columnas numéricas de Supabase son NOT NULL con CHECK de rango, así que
/// un valor fuera de rango no cabe y hay que recortarlo. El problema era que el
/// recorte no se registraba: 4 de 19 mediciones acabaron con densidad
/// exactamente 0.9000 --el piso del clamp-- indistinguibles de una medición
/// real. El caso peor es cuando el sensor no manda nada: el valor por defecto
/// de densidad es 1.0, justo la densidad del agua pura, que es la adulteración
/// que la app existe para detectar.
Medicion _medicion({
  required String ph,
  required String densidad,
  required String temperatura,
}) {
  return Medicion(
    id: 'm-test',
    clienteId: 'cuenta-1',
    ganaderoId: 'g-1',
    ph: ph,
    agua: densidad,
    temperatura: temperatura,
    fecha: '2026-09-23T09:00:00.000Z',
  );
}

void main() {
  group('Medicion.toSupabaseMap: lecturas válidas', () {
    test('una medición normal de leche no se marca ni se altera', () {
      final payload = _medicion(ph: '6.70', densidad: '1.031', temperatura: '4.0')
          .toSupabaseMap();

      expect(payload['lectura_valida'], isTrue);
      expect(payload['ph'], 6.70);
      expect(payload['densidad'], 1.031);
      expect(payload['temperatura'], 4.0);
    });

    test('conserva el texto crudo del sensor junto al valor numérico', () {
      final payload = _medicion(ph: '6.7', densidad: '1.031%', temperatura: '4.0°C')
          .toSupabaseMap();

      expect(payload['ph_raw'], '6.7');
      expect(payload['densidad_raw'], '1.031%');
      expect(payload['temperatura_raw'], '4.0°C');
    });
  });

  group('Medicion.toSupabaseMap: lecturas imposibles', () {
    test('una densidad negativa se marca como no válida', () {
      // Valor real observado saliendo del ESP32 con la sonda fuera de la leche.
      final payload = _medicion(ph: '6.7', densidad: '-0.026', temperatura: '4.0')
          .toSupabaseMap();

      expect(payload['lectura_valida'], isFalse,
          reason: 'una densidad negativa no existe fisicamente');
      expect(payload['densidad'], 0.9, reason: 'se recorta para caber en el CHECK');
      expect(payload['densidad_raw'], '-0.026',
          reason: 'el valor medido debe quedar registrado aunque sea absurdo');
    });

    test('la ausencia de lectura NO se guarda como agua pura sin marcar', () {
      // Este es el caso mas peligroso: densidad 1.0 es exactamente la del agua.
      final payload = _medicion(ph: 'N/D', densidad: 'N/D', temperatura: 'N/D')
          .toSupabaseMap();

      expect(payload['lectura_valida'], isFalse);
      expect(payload['densidad_raw'], 'N/D',
          reason: 'debe poder distinguirse de una medicion que dio 1.0 de verdad');
    });

    test('una densidad por encima del rango también se marca', () {
      final payload = _medicion(ph: '6.7', densidad: '2.5', temperatura: '4.0')
          .toSupabaseMap();

      expect(payload['lectura_valida'], isFalse);
      expect(payload['densidad'], 1.2);
      expect(payload['densidad_raw'], '2.5');
    });

    test('basta con que UNO de los tres valores sea imposible', () {
      final payload = _medicion(ph: '99', densidad: '1.031', temperatura: '4.0')
          .toSupabaseMap();

      expect(payload['lectura_valida'], isFalse,
          reason: 'el pH fuera de rango invalida la medicion completa');
      expect(payload['ph'], 14.0);
      expect(payload['ph_raw'], '99');
    });

    test('una temperatura imposible se marca sin afectar densidad ni pH', () {
      final payload = _medicion(ph: '6.7', densidad: '1.031', temperatura: '500')
          .toSupabaseMap();

      expect(payload['lectura_valida'], isFalse);
      expect(payload['temperatura'], 120.0);
      expect(payload['densidad'], 1.031, reason: 'los valores buenos no se tocan');
    });
  });
}
