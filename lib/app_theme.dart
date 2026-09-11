import 'package:flutter/material.dart';

/// Colores semánticos de estado (bueno / revisar / alerta) y superficies
/// derivadas del logo de BioScan. Viven aparte de [ColorScheme] porque
/// Material no tiene un slot nativo para "advertencia" y porque el color
/// de marca (instrumento conectado) nunca debe confundirse visualmente
/// con el semáforo de calidad de la leche.
class BioScanColors extends ThemeExtension<BioScanColors> {
  const BioScanColors({
    required this.ink,
    required this.inkMuted,
    required this.brand,
    required this.brandStrong,
    required this.brandSoft,
    required this.surface2,
    required this.border,
    required this.good,
    required this.goodSoft,
    required this.warn,
    required this.warnSoft,
    required this.alert,
    required this.alertSoft,
  });

  final Color ink;
  final Color inkMuted;
  final Color brand;
  final Color brandStrong;
  final Color brandSoft;
  final Color surface2;
  final Color border;
  final Color good;
  final Color goodSoft;
  final Color warn;
  final Color warnSoft;
  final Color alert;
  final Color alertSoft;

  static const light = BioScanColors(
    ink: Color(0xFF17323A),
    inkMuted: Color(0xFF52706A),
    brand: Color(0xFF2E7A6C),
    brandStrong: Color(0xFF1E5A4F),
    brandSoft: Color(0xFFDCEFE8),
    surface2: Color(0xFFE7EEEB),
    border: Color(0xFFD1DDD9),
    good: Color(0xFF3E8F44),
    goodSoft: Color(0xFFE3F2E2),
    warn: Color(0xFFB5791C),
    warnSoft: Color(0xFFF6E9D3),
    alert: Color(0xFFAC3F29),
    alertSoft: Color(0xFFF5E1DA),
  );

  static const dark = BioScanColors(
    ink: Color(0xFFE9F3EF),
    inkMuted: Color(0xFF9AB4AE),
    brand: Color(0xFF4FB49E),
    brandStrong: Color(0xFF7BCDBA),
    brandSoft: Color(0xFF1E3B36),
    surface2: Color(0xFF1D3235),
    border: Color(0xFF294744),
    good: Color(0xFF6FBD73),
    goodSoft: Color(0xFF1E3324),
    warn: Color(0xFFE0A548),
    warnSoft: Color(0xFF3A2E18),
    alert: Color(0xFFE2795F),
    alertSoft: Color(0xFF3A2019),
  );

  @override
  BioScanColors copyWith({
    Color? ink,
    Color? inkMuted,
    Color? brand,
    Color? brandStrong,
    Color? brandSoft,
    Color? surface2,
    Color? border,
    Color? good,
    Color? goodSoft,
    Color? warn,
    Color? warnSoft,
    Color? alert,
    Color? alertSoft,
  }) {
    return BioScanColors(
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      brand: brand ?? this.brand,
      brandStrong: brandStrong ?? this.brandStrong,
      brandSoft: brandSoft ?? this.brandSoft,
      surface2: surface2 ?? this.surface2,
      border: border ?? this.border,
      good: good ?? this.good,
      goodSoft: goodSoft ?? this.goodSoft,
      warn: warn ?? this.warn,
      warnSoft: warnSoft ?? this.warnSoft,
      alert: alert ?? this.alert,
      alertSoft: alertSoft ?? this.alertSoft,
    );
  }

  @override
  BioScanColors lerp(ThemeExtension<BioScanColors>? other, double t) {
    if (other is! BioScanColors) return this;
    return BioScanColors(
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      brandStrong: Color.lerp(brandStrong, other.brandStrong, t)!,
      brandSoft: Color.lerp(brandSoft, other.brandSoft, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      border: Color.lerp(border, other.border, t)!,
      good: Color.lerp(good, other.good, t)!,
      goodSoft: Color.lerp(goodSoft, other.goodSoft, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      warnSoft: Color.lerp(warnSoft, other.warnSoft, t)!,
      alert: Color.lerp(alert, other.alert, t)!,
      alertSoft: Color.lerp(alertSoft, other.alertSoft, t)!,
    );
  }
}

/// Familias tipográficas: serif de "documento/certificado" para el wordmark
/// y encabezados, monoespaciada de cifras tabulares para las lecturas de
/// sensores (la misma familia que ya usa la terminal cruda de Beta BLE).
const kSerifFamily = 'serif';
const kMonoFamily = 'monospace';

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.light, BioScanColors.light, const Color(0xFFF2F6F4), Colors.white);

  static ThemeData dark() => _build(Brightness.dark, BioScanColors.dark, const Color(0xFF0F1C1E), const Color(0xFF16282A));

  static ThemeData _build(Brightness brightness, BioScanColors colors, Color bg, Color surface) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: colors.brand,
      onPrimary: Colors.white,
      secondary: colors.brandStrong,
      onSecondary: Colors.white,
      tertiary: colors.good,
      onTertiary: Colors.white,
      error: colors.alert,
      onError: Colors.white,
      surface: surface,
      onSurface: colors.ink,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,
      extensions: [colors],
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: colors.ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: kSerifFamily,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: colors.ink,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: colors.brandSoft,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(color: states.contains(WidgetState.selected) ? colors.brandStrong : colors.inkMuted),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? colors.brandStrong : colors.inkMuted,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.brand,
          foregroundColor: Colors.white,
          disabledBackgroundColor: colors.border,
          disabledForegroundColor: colors.inkMuted,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.2),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(backgroundColor: colors.brand, foregroundColor: Colors.white),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: colors.border)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: colors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: colors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: colors.brand, width: 1.6)),
        labelStyle: TextStyle(color: colors.inkMuted),
      ),
      textTheme: TextTheme(
        bodyMedium: TextStyle(color: colors.ink),
        bodySmall: TextStyle(color: colors.inkMuted),
      ),
    );
  }
}
