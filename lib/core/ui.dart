/*
 * SPDX-License-Identifier: MIT
 * Copyright (c) miniradio Contributors
 * Copyright (c) 2026 GNBD
 *
 * Shared styles / widgets (light & dark).
 */
import 'package:flutter/material.dart';

class Pal {
  Pal(BuildContext c) : dark = Theme.of(c).brightness == Brightness.dark;
  final bool dark;

  Color get bg => dark ? const Color(0xFF0B0E14) : const Color(0xFFF3F5FA);
  Color get surface => dark ? const Color(0xFF161A22) : Colors.white;
  Color get ink => dark ? const Color(0xFFE9EEF7) : const Color(0xFF171B26);
  Color get muted => dark ? const Color(0xFF8A93A6) : const Color(0xFF858D9D);
  Color get line => dark ? const Color(0xFF262C38) : const Color(0xFFEDF0F5);
  Color get soft => dark ? const Color(0xFF1E2530) : const Color(0xFFF2F4F8);
  Color get soft2 => dark ? const Color(0xFF232B38) : const Color(0xFFF7F8FB);
  Color get blue => dark ? const Color(0xFF6BA6FF) : const Color(0xFF2878F0);
  Color get blueSoft =>
      dark ? const Color(0xFF1B2A44) : const Color(0xFFEAF2FF);
  Color get green => const Color(0xFF21A675);
  Color get amber => const Color(0xFFE5A53D);
  Color get red => const Color(0xFFE5484D);
  Color get shadow => dark
      ? Colors.black.withValues(alpha: 0.35)
      : const Color(0xFF263B5B).withValues(alpha: 0.05);
}

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final p = dark
      ? const Color(0xFF0B0E14)
      : const Color(0xFFF3F5FA);
  final base = ThemeData(useMaterial3: true, brightness: b);
  return base.copyWith(
    scaffoldBackgroundColor: p,
    colorScheme: base.colorScheme.copyWith(
      primary: dark ? const Color(0xFF6BA6FF) : const Color(0xFF2878F0),
      surface: dark ? const Color(0xFF161A22) : Colors.white,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    dividerColor: dark ? const Color(0xFF262C38) : const Color(0xFFEDF0F5),
  );
}

/// White card (radius 25, soft shadow).
class CardX extends StatelessWidget {
  const CardX({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin = const EdgeInsets.only(bottom: 13),
    this.color,
    this.radius = 25,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final Color? color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = Pal(context);
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? p.surface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: p.shadow,
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Card header (left: title/overline, right: action).
class CardHead extends StatelessWidget {
  const CardHead({
    super.key,
    required this.title,
    this.overline,
    this.trailing,
  });

  final String title;
  final String? overline;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = Pal(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (overline != null)
                Text(overline!,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                        color: p.muted)),
              Text(title,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: p.ink)),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Small rounded button (soft blue).
class SmallButton extends StatelessWidget {
  const SmallButton(this.text, {super.key, this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: p.blueSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: p.blue)),
      ),
    );
  }
}

/// Field box (label + value/control).
class FieldBox extends StatelessWidget {
  const FieldBox({
    super.key,
    required this.label,
    this.value,
    this.child,
  });

  final String label;
  final String? value;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final p = Pal(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.soft2,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: p.ink)),
              ),
              if (value != null)
                Text(value!,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: p.muted)),
            ],
          ),
          if (child != null) ...[
            const SizedBox(height: 8),
            child!,
          ],
        ],
      ),
    );
  }
}

/// Toast (bottom).
void showToast(BuildContext context, String msg) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (c) => Positioned(
      bottom: 96,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFF202A3C),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Text(msg,
              style: const TextStyle(color: Colors.white, fontSize: 11.5)),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future.delayed(const Duration(milliseconds: 1600), entry.remove);
}
