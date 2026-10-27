// lib/core/theme/app_colors.dart
//
// Paleta de colores canónica del sistema Happy House ERP/POS.
// Derivada del UI_STYLE_GUIDE.md. Todos los colores de la app
// deben referenciarse desde esta clase.

import 'package:flutter/material.dart';

class AppColors {
  AppColors._(); // Prevenir instanciación

  // ── Backgrounds ─────────────────────────────────────────────────────────
  /// Fondo principal de las pantallas (gris humo claro)
  static const Color backgroundCanvas = Color(0xFFF4F5F7);
  /// Fondo de tarjetas (Cards) y paneles elevados
  static const Color backgroundCard = Color(0xFFFFFFFF);

  // ── Color Primario (Acento Naranja Vibrante) ─────────────────────────────
  /// Botones de acción principal, tabs activos, barras de progreso
  static const Color primary = Color(0xFFFF6B00);
  static const Color primaryLight = Color(0xFFFF8C3A);
  static const Color primaryDark = Color(0xFFCC5500);

  // ── Textos ───────────────────────────────────────────────────────────────
  /// Títulos y texto de mayor jerarquía
  static const Color textPrimary = Color(0xFF1E1E24);
  /// Subtítulos, descripciones, textos secundarios
  static const Color textSecondary = Color(0xFF6B7280);
  /// Texto sobre fondos de acento (ej. botones naranjas)
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ── Colores Semánticos ───────────────────────────────────────────────────
  /// Éxito, estado óptimo, pedidos entregados
  static const Color success = Color(0xFF22C55E);
  static const Color successLight = Color(0xFFDCFCE7);
  /// Alertas críticas, agotados, pedidos muy demorados
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  /// Órdenes nuevas entrantes (KDS)
  static const Color orderNew = Color(0xFFA78BFA); // Morado claro
  static const Color orderNewLight = Color(0xFFEDE9FE);
  /// En preparación (KDS)
  static const Color orderInProgress = Color(0xFFFF6B00); // Naranja (primary)
  /// Advertencia, pedidos demorados moderados
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);

  // ── Bordes y Dividers ────────────────────────────────────────────────────
  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFF3F4F6);

  // ── PIN Indicator ────────────────────────────────────────────────────────
  static const Color pinFilled = Color(0xFF1E1E24);
  static const Color pinEmpty = Color(0xFFD1D5DB);
  static const Color pinError = Color(0xFFEF4444);
}
