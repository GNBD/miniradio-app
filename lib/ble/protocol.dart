/*
 * SPDX-License-Identifier: MIT
 * Copyright (c) miniradio Contributors
 * Copyright (c) 2026 GNBD
 *
 * NUS (Nordic UART Service) protocol constants + status parser.
 */
class Nus {
  static const String service = '6E400001-B5A3-F393-E0A9-E50E24DCCA9E';
  static const String rx = '6E400002-B5A3-F393-E0A9-E50E24DCCA9E';
  static const String tx = '6E400003-B5A3-F393-E0A9-E50E24DCCA9E';
  static const String deviceName = 'miniradio';
}

/// Commands (must match firmware ble.c parser).
class Cmd {
  static const String tuneUp = 'U';
  static const String tuneDown = 'D';
  static const String bandUp = 'u';
  static const String bandDown = 'd';
  static const String mode = 'M';
  static const String volUp = '+';
  static const String volDown = '-';
  static const String seekUp = 'S';
  static const String seekDown = 's';
  static const String preset = 'P';
  static const String wifi = 'W';
  static const String query = 'Q';

  /// Absolute volume: 'V' + 1 byte (0..63).
  static List<int> setVolume(int v) => [0x56, v & 0xFF];

  /// Absolute frequency: 'F' + 4 bytes LE (Hz).
  static List<int> setFreq(int hz) => [
        0x46,
        hz & 0xFF,
        (hz >> 8) & 0xFF,
        (hz >> 16) & 0xFF,
        (hz >> 24) & 0xFF,
      ];

  /// Band select: 'B' + index.
  static List<int> setBand(int idx) => [0x42, idx & 0xFF];

  /// Mode select: 'O' + radio_mode_t.
  static List<int> setMode(int idx) => [0x4F, idx & 0xFF];

  /// Request preset list.
  static const String presetList = 'L';

  /// Save current frequency as preset.
  static const String presetSave = 'K';

  /// Tune preset: 'T' + index.
  static List<int> presetTune(int idx) => [0x54, idx & 0xFF];

  /// Delete preset: 'X' + index.
  static List<int> presetDelete(int idx) => [0x58, idx & 0xFF];

  /// Read radio settings.
  static const String getSettings = 'g';

  /// Write radio setting: 'c' + item + value.
  static List<int> setSetting(int item, int value) =>
      [0x63, item & 0xFF, value & 0xFF];
}

class RadioStatus {
  final int freqHz;
  final int mode;
  final int band;
  final int volume;
  final int rssi;
  final int snr;
  final int battery;
  final int bleState;

  const RadioStatus({
    required this.freqHz,
    required this.mode,
    required this.band,
    required this.volume,
    required this.rssi,
    required this.snr,
    required this.battery,
    required this.bleState,
  });

  static const List<String> modeNames = ['FM', 'AM', 'LSB', 'USB'];
  static const List<String> bandNames = [
    'VHF', 'MW', 'LW', 'SW', '160m', '80m', '40m', '30m',
    '20m', '17m', '15m', '12m', '10m', 'CB',
  ];

  /// Display unit per band (VHF/ham = MHz, MW/LW/SW = kHz).
  bool get useMhz => band == 0 || band >= 4;

  String get modeName =>
      (mode >= 0 && mode < modeNames.length) ? modeNames[mode] : '?';

  String get bandName =>
      (band >= 0 && band < bandNames.length) ? bandNames[band] : '?';

  String get unitLabel => useMhz ? 'MHz' : 'kHz';

  /// Three decimals (default editor value).
  String get freqText => useMhz
      ? (freqHz / 1000000).toStringAsFixed(3)
      : (freqHz / 1000).toStringAsFixed(0);

  /// Display form: FM 101.7 / SW 9.58 / MW 1000.
  String get freqLabel {
    if (useMhz) {
      var s = (freqHz / 1000000).toStringAsFixed(3);
      while (s.endsWith('0') && s.split('.').last.length > 1) {
        s = s.substring(0, s.length - 1);
      }
      return s;
    }
    return (freqHz / 1000).toStringAsFixed(0);
  }

  static RadioStatus? parse(String text) {
    final p = text.trim().split(',');
    if (p.length < 6) return null;
    int at(int i, [int fallback = 0]) =>
        i < p.length ? (int.tryParse(p[i].trim()) ?? fallback) : fallback;
    return RadioStatus(
      freqHz: at(0),
      mode: at(1),
      band: at(2),
      volume: at(3),
      rssi: at(4),
      snr: at(5),
      battery: at(6, -1),
      bleState: at(7, 2),
    );
  }
}
