import 'medicion.dart';

/// Modelo de evaluación analítica oficial para diagnosticar la calidad de la muestra de leche
/// según las especificaciones normativas NOM-155-SCFI-2012, FAO y COFOCALEC.
/// Densidad de referencia de la leche cruda normal, en g/mL.
/// La NOM-155-SCFI-2012 fija 1.028 como minimo; 1.030 es el valor tipico que
/// se usa como referencia para estimar dilucion.
const double _densidadLecheNormal = 1.030;

/// Cuanto mas densa es la leche normal que el agua pura (1.030 - 1.000).
/// Es el rango sobre el que se mide la dilucion: agregar agua mueve la
/// densidad linealmente dentro de este intervalo.
const double _rangoDensidadLecheAgua = 0.030;

class AnalisisLeche {
  final double? ph;
  final double? densidad;
  final double? temp;
  final String rawPh;
  final String rawDensidad;
  final String rawTemp;

  final bool hasWaterAdulteration;
  final double? estimatedWaterPct;
  final bool isAcidic;
  final bool isAlkaline;
  final bool isPhNormal;
  final bool isDensNormal;
  final bool isGlobalApproved;
  final bool isGlobalWarning;
  final bool isGlobalDanger;

  final String globalTitle;
  final String globalSubtitle;

  const AnalisisLeche({
    required this.ph,
    required this.densidad,
    required this.temp,
    required this.rawPh,
    required this.rawDensidad,
    required this.rawTemp,
    required this.hasWaterAdulteration,
    required this.estimatedWaterPct,
    required this.isAcidic,
    required this.isAlkaline,
    required this.isPhNormal,
    required this.isDensNormal,
    required this.isGlobalApproved,
    required this.isGlobalWarning,
    required this.isGlobalDanger,
    required this.globalTitle,
    required this.globalSubtitle,
  });

  factory AnalisisLeche.evaluate(Medicion medicion) {
    // 1. Extraer número de pH (el ESP32 puede mandar valores negativos ante
    //    fallas de sensor o lecturas fuera de rango, por lo que el signo "-"
    //    debe ser parte del valor capturado -- igual que en bluetooth_manager.dart)
    final phMatch = RegExp(r'(-?[0-9]+(?:\.[0-9]+)?)').firstMatch(medicion.ph);
    final phVal = phMatch != null ? double.tryParse(phMatch.group(1)!) : null;

    // 2. Extraer densidad / agua (también puede venir negativa)
    final rawAgua = medicion.agua.trim();
    final densMatch = RegExp(r'(-?[0-9]+(?:\.[0-9]+)?)').firstMatch(rawAgua);
    double? parsedNum = densMatch != null ? double.tryParse(densMatch.group(1)!) : null;

    bool waterDetected = false;
    bool densImplausible = false;
    double? waterPct;
    double? densVal;

    if (rawAgua.contains('%')) {
      waterPct = parsedNum;
      if (waterPct != null && waterPct > 0.0) {
        waterDetected = true;
      }
      if (waterPct != null) {
        // Inversa de la formula lactometrica: diluir con agua mueve la
        // densidad linealmente desde la de la leche (1.030) hacia la del agua
        // (1.000), asi que cada 1% de agua resta 0.0003 g/mL. El factor
        // anterior (0.0008) daba 0.951 g/mL para 100% de agua, por debajo de
        // la densidad del agua pura.
        densVal = _densidadLecheNormal -
            (waterPct.clamp(0.0, 100.0) / 100.0) * _rangoDensidadLecheAgua;
      }
    } else if (parsedNum != null) {
      if (parsedNum > 20 && parsedNum < 40) {
        // Conversión grados lactodensimétricos Quevenne (°Q) a g/mL
        parsedNum = 1.0 + (parsedNum / 1000.0);
      }

      densVal = parsedNum;
      // Criterio NOM-155-SCFI-2012 / COFOCALEC: Densidad normal mínima 1.028 g/mL.
      // Por debajo de 0.90 g/mL el valor ya no es físicamente posible para leche
      // (incluye lecturas negativas o cero por falla de sensor/dilución extrema):
      // se marca como anomalía crítica en vez de aplicarle la fórmula de % de
      // agua, que solo es válida dentro de un rango realista.
      if (densVal < 0.90) {
        densImplausible = true;
        waterPct = null;
      } else if (densVal < 1.0280) {
        waterDetected = true;
        // % de agua agregada por grados lactometricos (Quevenne):
        //
        //   L = (densidad - 1) * 1000        -> leche normal = 30, agua = 0
        //   % agua = (L_normal - L_muestra) / L_normal * 100
        //
        // que se reduce a dividir entre el RANGO entre leche y agua (0.030),
        // no entre la densidad de la leche. La formula anterior dividia entre
        // 1.030 y compensaba multiplicando por 280, lo que subestimaba el agua
        // unas 12 veces: una mezcla 50/50 medida en 1.016 g/mL se reportaba
        // como 3.8% en vez de ~47%, y un vaso de agua pura como 8.2%.
        waterPct = ((_densidadLecheNormal - densVal) / _rangoDensidadLecheAgua) * 100.0;
        if (waterPct < 0.0) waterPct = 0.0;
        if (waterPct > 100.0) waterPct = 100.0;
      } else {
        waterPct = 0.0;
      }
    }

    // 3. Extraer temperatura (también puede venir negativa)
    final tempMatch = RegExp(r'(-?[0-9]+(?:\.[0-9]+)?)').firstMatch(medicion.temperatura);
    final tempVal = tempMatch != null ? double.tryParse(tempMatch.group(1)!) : null;

    // Diagnóstico de pH (NOM-155-SCFI-2012 / FAO: Rango 6.60 a 6.80, tolerancia 6.50-6.80)
    final isAcid = phVal != null && phVal < 6.50;
    final isAlk = phVal != null && phVal > 6.80;
    final isPhOk = phVal != null && phVal >= 6.50 && phVal <= 6.80;

    // Diagnóstico de Densidad (NOM-155-SCFI-2012: 1.028 a 1.034 g/mL)
    final isDensOk = densVal != null && densVal >= 1.028 && densVal <= 1.034 && !waterDetected && !densImplausible;
    final isDensAbnormalHigh = densVal != null && densVal > 1.034;

    // Dictamen Global: hasDanger/hasWarning/isApproved son mutuamente
    // excluyentes y exhaustivos para cualquier lectura numérica válida (pH
    // siempre cae en ácido/normal/alcalino, densidad siempre cae en
    // implausible/agua/normal/alta), para que el título del certificado, el
    // color y el badge nunca se contradigan entre sí.
    final hasDanger = waterDetected || densImplausible;
    final hasWarning = !hasDanger && (isAcid || isAlk || isDensAbnormalHigh);
    final isApproved = !hasDanger && !hasWarning;

    String title;
    String subtitle;

    if (densImplausible) {
      title = 'ALERTA CRÍTICA: LECTURA DE DENSIDAD NO VÁLIDA';
      subtitle = 'La densidad reportada (${densVal!.toStringAsFixed(4)} g/mL) está fuera de cualquier rango físicamente posible para leche. Verifique el sensor y repita la medición antes de emitir un dictamen; no se aplicó el cálculo de % de agua por estar fuera de su rango de validez.';
    } else if (hasDanger) {
      title = 'ALERTA CRÍTICA: AGUA ADICIONADA DETECTADA';
      subtitle = 'Muestra NO CONFORME según NOM-155-SCFI-2012. Densidad por debajo de 1.028 g/mL con dilución estimada de ${waterPct != null ? waterPct.toStringAsFixed(1) : ''}%. La leche no cumple estándares para acopio por disminución severa de sólidos no grasos.';
    } else if (hasWarning) {
      title = 'PRECAUCIÓN: MUESTRA FUERA DE RANGO ÓPTIMO';
      if (isAcid) {
        subtitle = 'Acidez láctica elevada (pH ${phVal.toStringAsFixed(2)}). Posible proliferación microbiana por enfriamiento tardío o higiene deficiente en el ordeño.';
      } else if (isAlk) {
        subtitle = 'Alcalinidad anormal (pH ${phVal.toStringAsFixed(2)}). Sospecha de mastitis en el ganado o adición de neutralizantes químicos alcalinos.';
      } else {
        subtitle = 'Densidad superior al rango habitual (> 1.034 g/mL). Sospecha de alteración composicional o descremado parcial.';
      }
    } else {
      title = 'DICTAMEN: APROBADA - CALIDAD ÓPTIMA';
      subtitle = 'Muestra CONFORME con las especificaciones de la NOM-155-SCFI-2012 y FAO. Sin detección de agua agregada y balance fisicoquímico óptimo para su entrega.';
    }

    return AnalisisLeche(
      ph: phVal,
      densidad: densVal,
      temp: tempVal,
      rawPh: medicion.ph,
      rawDensidad: medicion.agua,
      rawTemp: medicion.temperatura,
      hasWaterAdulteration: hasDanger,
      estimatedWaterPct: waterPct,
      isAcidic: isAcid,
      isAlkaline: isAlk,
      isPhNormal: isPhOk,
      isDensNormal: isDensOk,
      isGlobalApproved: isApproved,
      isGlobalWarning: hasWarning,
      isGlobalDanger: hasDanger,
      globalTitle: title,
      globalSubtitle: subtitle,
    );
  }
}
