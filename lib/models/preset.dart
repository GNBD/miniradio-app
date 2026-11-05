/*
 * SPDX-License-Identifier: MIT
 * Copyright (c) miniradio Contributors
 * Copyright (c) 2026 GNBD
 */
class Preset {
  Preset({required this.name, required this.freqHz, required this.band});

  String name;
  int freqHz;
  int band;

  String get freqLabel {
    if (band == 0 || band >= 4) {
      var s = (freqHz / 1000000).toStringAsFixed(3);
      while (s.endsWith('0') && s.split('.').last.length > 1) {
        s = s.substring(0, s.length - 1);
      }
      return '$s MHz';
    }
    return '${(freqHz / 1000).toStringAsFixed(0)} kHz';
  }

  String get bandName => const [
        'VHF', 'MW', 'LW', 'SW', '160m', '80m', '40m', '30m',
        '20m', '17m', '15m', '12m', '10m', 'CB',
      ][band.clamp(0, 13)];
}
