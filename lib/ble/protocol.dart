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

  /// Raw band name from the official ATS Mini firmware (null for GNBD).
  final String? bandText;

  const RadioStatus({
    required this.freqHz,
    required this.mode,
    required this.band,
    required this.volume,
    required this.rssi,
    required this.snr,
    required this.battery,
    required this.bleState,
    this.bandText,
  });

  static const List<String> modeNames = ['FM', 'AM', 'LSB', 'USB'];
  static const List<String> bandNames = [
    'VHF', 'MW', 'LW', 'SW', '160m', '80m', '40m', '30m',
    '20m', '17m', '15m', '12m', '10m', 'CB',
  ];

  /// Display unit per band (VHF/ham = MHz, MW/LW/SW = kHz).
  bool get useMhz =>
      bandText != null ? (freqHz >= 1000000) : (band == 0 || band >= 4);

  String get modeName =>
      (mode >= 0 && mode < modeNames.length) ? modeNames[mode] : '?';

  String get bandName =>
      bandText ?? ((band >= 0 && band < bandNames.length) ? bandNames[band] : '?');

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

  /// Official ATS Mini monitor line (15 CSV fields).
  ///
  /// version,freq,bfo,bandCal,bandName,mode,step,bw,agc,vol,rssi,snr,cap,volt,seq
  static bool isAtsMonitor(String text) {
    final p = text.trim().split(',');
    if (p.length < 12) return false;
    // field 4 is a band name, field 5 a mode name (not numeric)
    return int.tryParse(p[4].trim()) == null && int.tryParse(p[5].trim()) == null;
  }

  static RadioStatus? parseAts(String text) {
    final p = text.trim().split(',');
    if (p.length < 12) return null;
    int at(int i, [int fallback = 0]) =>
        i < p.length ? (int.tryParse(p[i].trim()) ?? fallback) : fallback;

    final bandName = p[4].trim().toUpperCase();
    int band = bandNames.indexWhere((n) => n.toUpperCase() == bandName);
    if (band < 0) band = 0;

    final modeStr = p[5].trim().toUpperCase();
    int mode = 0;
    for (int i = 0; i < modeNames.length; i++) {
      if (modeNames[i] == modeStr) mode = i;
    }

    final freq = at(1);
    final bfo = at(2);
    final int hz = (modeStr == 'FM')
        ? freq * 10000
        : freq * 1000 + ((modeStr == 'LSB' || modeStr == 'USB') ? bfo : 0);

    return RadioStatus(
      freqHz: hz.abs(),
      mode: mode,
      band: band,
      bandText: p[4].trim(),
      volume: at(9),
      rssi: at(10),
      snr: at(11),
      battery: -1,
      bleState: 2,
    );
  }
}

/// Official ATS Mini ad hoc key commands.
class AtsCmd {
  static const String encUp = 'R';
  static const String encDown = 'r';
  static const String click = 'e';
  static const String shortPress = 'E';
  static const String volUp = 'V';
  static const String volDown = 'v';
  static const String bandNext = 'B';
  static const String bandPrev = 'b';
  static const String modeNext = 'M';
  static const String modePrev = 'm';
  static const String stepNext = 'S';
  static const String stepPrev = 's';
  static const String bwNext = 'W';
  static const String bwPrev = 'w';
  static const String agcUp = 'A';
  static const String agcDown = 'a';
  static const String screenUp = 'L';
  static const String screenDown = 'l';
  static const String sleepOn = 'O';
  static const String sleepOff = 'o';
  static const String monitorToggle = 't';

  static String setFreq(int hz) => 'F$hz\r';
}
