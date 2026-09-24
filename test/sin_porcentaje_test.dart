import 'package:flutter_test/flutter_test.dart';
import 'package:scanner_leche_app/models/analisis_leche.dart';
import 'package:scanner_leche_app/models/medicion.dart';

/// Esta rama reporta la adulteración con agua de forma CUALITATIVA, sin dar un
/// porcentaje.
///
/// El % estimado arrastra sesgos que no se pueden controlar en campo:
///   * Hasta ±5 puntos según dónde caiga la leche dentro del rango que permite
///     la NOM-155 (1.028–1.034 g/mL).
///   * Hasta +6 puntos por medir a temperatura ambiente en vez de a 15 °C,
///     que es donde está definida la densidad de referencia.
///   * Sensibilidad enorme al volumen: 1 mL de error en una muestra de 50 mL
///     mueve el resultado 67 puntos porcentuales.
///
/// La DETECCIÓN en cambio es sólida: densidad por debajo de 1.028 g/mL es el
/// criterio de la propia NOM. Así que se afirma lo que se puede sostener.
AnalisisLeche _evaluar(String densidad) {
  return AnalisisLeche.evaluate(
    Medicion(
      id: 'm-test',
      clienteId: 'cuenta-1',
      ganaderoId: 'g-1',
      ph: '6.70',
      agua: densidad,
      temperatura: '20.0',
      fecha: '2026-09-23T14:00:00.000Z',
    ),
  );
}

void main() {
  group('El dictamen no expone un porcentaje de agua', () {
    test('la muestra adulterada se reporta sin cifra', () {
      final analisis = _evaluar('1.0160');

      expect(analisis.hasWaterAdulteration, isTrue,
          reason: 'la deteccion debe seguir funcionando');
      expect(analisis.globalTitle, contains('AGUA ADICIONADA'));
      expect(analisis.globalSubtitle, isNot(contains('%')),
          reason: 'el dictamen no debe cuantificar la dilucion');
    });

    test('una dilución leve y una severa dan el mismo texto', () {
      // Sin porcentaje, ambas comunican lo mismo: hay agua, no cumple.
      final leve = _evaluar('1.0270');
      final severa = _evaluar('1.0050');

      expect(leve.globalTitle, severa.globalTitle);
      expect(leve.globalSubtitle, severa.globalSubtitle);
      expect(leve.globalSubtitle, isNot(contains('%')));
    });

    test('la muestra conforme sigue aprobando', () {
      final analisis = _evaluar('1.0310');

      expect(analisis.hasWaterAdulteration, isFalse);
      expect(analisis.globalSubtitle, isNot(contains('%')));
    });

    test('la lectura imposible se distingue de la adulteración', () {
      final analisis = _evaluar('-0.026');

      expect(analisis.globalTitle, contains('NO VÁLIDA'));
      expect(analisis.globalSubtitle, isNot(contains('% de agua')),
          reason: 'ya no se menciona el calculo de porcentaje');
    });

    test('el umbral sigue siendo el de la NOM-155 (1.028 g/mL)', () {
      expect(_evaluar('1.0279').hasWaterAdulteration, isTrue);
      expect(_evaluar('1.0280').hasWaterAdulteration, isFalse);
    });
  });
}
