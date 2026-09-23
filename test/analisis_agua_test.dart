import 'package:flutter_test/flutter_test.dart';
import 'package:scanner_leche_app/models/analisis_leche.dart';
import 'package:scanner_leche_app/models/medicion.dart';

/// Regresión: el cálculo de % de agua agregada subestimaba la adulteración
/// unas 12 veces.
///
/// La fórmula dividía entre 1.030 (la densidad de la leche) en vez de entre
/// 0.030 (cuánto más densa es la leche que el agua), y compensaba
/// multiplicando por 280. Detectado con una prueba física el 23/09/2026: una
/// mezcla de 50 ml de leche y 50 ml de agua midió 1.0160 g/mL --densidad
/// correcta-- pero se reportó como 3.8% de agua en vez de ~47%.
///
/// El caso límite muestra la gravedad: un vaso de agua pura se reportaba con
/// 8.2% de agua, es decir, casi como leche buena.
AnalisisLeche _evaluarDensidad(String densidad) {
  return AnalisisLeche.evaluate(
    Medicion(
      id: 'm-test',
      clienteId: 'cuenta-1',
      ganaderoId: 'g-1',
      ph: '6.70',
      agua: densidad,
      temperatura: '20.0',
      fecha: '2026-09-23T13:47:00.000Z',
    ),
  );
}

void main() {
  group('% de agua agregada a partir de la densidad', () {
    test('la mezcla 50/50 medida en campo se reporta cerca del 50%', () {
      // Medición real: 50 ml de leche + 50 ml de agua -> 1.0160 g/mL.
      final analisis = _evaluarDensidad('1.0160');

      expect(analisis.hasWaterAdulteration, isTrue);
      expect(analisis.estimatedWaterPct, isNotNull);
      expect(analisis.estimatedWaterPct!, closeTo(46.7, 0.5),
          reason: 'la formula anterior daba 3.8%');
    });

    test('el agua pura se reporta como 100%, no como un porcentaje bajo', () {
      final analisis = _evaluarDensidad('1.0000');

      expect(analisis.hasWaterAdulteration, isTrue);
      expect(analisis.estimatedWaterPct!, closeTo(100.0, 0.1),
          reason: 'la formula anterior daba 8.2%, casi leche buena');
    });

    test('una dilución leve se reporta proporcionalmente', () {
      // 1.027 g/mL = 27 grados lactometricos -> (30-27)/30 = 10%
      final analisis = _evaluarDensidad('1.0270');

      expect(analisis.estimatedWaterPct!, closeTo(10.0, 0.2));
    });

    test('la leche normal no dispara deteccion de agua', () {
      // 1.029 esta por encima del minimo de la NOM-155 (1.028), asi que ni
      // siquiera entra al calculo.
      final analisis = _evaluarDensidad('1.0290');

      expect(analisis.hasWaterAdulteration, isFalse);
      expect(analisis.estimatedWaterPct, 0.0);
    });

    test('una densidad imposible se marca como lectura invalida, no como agua', () {
      final analisis = _evaluarDensidad('-0.026');

      expect(analisis.estimatedWaterPct, isNull,
          reason: 'no se aplica la formula fuera del rango fisico');
    });
  });

  group('conversión inversa cuando el sensor manda el % directo', () {
    test('100% de agua no produce una densidad menor a la del agua pura', () {
      // La conversion anterior (1.031 - pct * 0.0008) daba 0.951 g/mL, por
      // debajo del agua, lo que ademas disparaba la alerta de lectura
      // fisicamente imposible.
      final analisis = _evaluarDensidad('100%');

      expect(analisis.densidad, isNotNull);
      expect(analisis.densidad!, closeTo(1.000, 0.001));
    });

    test('50% de agua corresponde al punto medio entre leche y agua', () {
      final analisis = _evaluarDensidad('50%');

      expect(analisis.densidad!, closeTo(1.015, 0.001));
    });

    test('0% de agua corresponde a la densidad de la leche normal', () {
      final analisis = _evaluarDensidad('0%');

      expect(analisis.densidad!, closeTo(1.030, 0.001));
    });
  });
}
