// lib/utils/app_colors.dart
//
// ✅ 4 COLOURS ONLY — black | light blue | faded blue | white
// NO dark navy anywhere
//
import 'package:flutter/material.dart';

class AppColors {
  // ── Primary brand ─────────────────────────────────────────
  static const Color primary     = Color(0xFF29ABE2); // light blue
  static const Color primaryDark = Color(0xFF1A9ECE); // slightly darker

  // ── Backgrounds ───────────────────────────────────────────
  static const Color pageBg      = Color(0xFFE8F6FD); // faded blue (page bg)
  static const Color onboardBg   = Color(0xFFE8F6FD); // same faded blue
  static const Color iconBg      = Color(0xFFD4EEFA); // slightly deeper faded blue
  static const Color cardBg      = Color(0xFFFFFFFF); // white card

  // ── Wallet card ────────────────────────────────────────── 
  // Uses primary as solid colour — no navy gradient
  static const Color cardStart   = Color(0xFF29ABE2);
  static const Color cardEnd     = Color(0xFF1A9ECE);

  // ── Header / AppBar ───────────────────────────────────────
  // White header, primary accent — NO dark navy
  static const Color headerBg    = Color(0xFFFFFFFF);
  static const Color dark        = Color(0xFF29ABE2); // was navy — now light blue

  // ── Text ──────────────────────────────────────────────────
  static const Color textDark    = Color(0xFF111827); // near black
  static const Color textMuted   = Color(0xFF6B7280); // grey

  // ── Service icon colours ──────────────────────────────────
  static const Color airtime     = Color(0xFF29ABE2); // primary
  static const Color data        = Color(0xFF06B6D4); // cyan
  static const Color electricity = Color(0xFFF59E0B); // amber
  static const Color cable       = Color(0xFF8B5CF6); // purple

  // ── Status ────────────────────────────────────────────────
  static const Color success = Color(0xFF16A34A);
  static const Color error   = Color(0xFFDC2626);
  static const Color warning = Color(0xFFF59E0B);

  // ── Misc ──────────────────────────────────────────────────
  static const Color white  = Color(0xFFFFFFFF);
  static const Color grey   = Color(0xFF9CA3AF);
  static const Color border = Color(0xFFE5E7EB);
}
