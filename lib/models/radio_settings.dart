/*
 * SPDX-License-Identifier: MIT
 * Copyright (c) miniradio Contributors
 * Copyright (c) 2026 GNBD
 *
 * Radio settings snapshot (firmware 'g' response).
 */
class RadioSettings {
  int stepSel = 0;
  List<int> stepHz = const [0];

  int bwSel = 0;
  List<String> bwLabels = const ['AUTO'];

  int agcSel = 0;
  int agcMax = 0;

  int squelch = 0;

  bool rdsOn = true;
  bool stereo = false;
  bool deemph75 = false;

  int mode = 0;
  bool fmBand = false;

  String get stepLabel {
    if (stepSel < 0 || stepSel >= stepHz.length) return 'BAND';
    final hz = stepHz[stepSel];
    if (hz == 0) return 'BAND';
    if (hz >= 1000 && hz % 1000 == 0) return '${hz ~/ 1000} kHz';
    return '$hz Hz';
  }

  String get bwLabel =>
      (bwSel >= 0 && bwSel < bwLabels.length) ? bwLabels[bwSel] : '-';

  String get agcLabel => agcSel <= 0 ? 'AUTO' : (agcSel == 1 ? 'OFF' : '$agcSel');
}
