/*
 * SPDX-License-Identifier: MIT
 * Copyright (c) miniradio Contributors
 * Copyright (c) 2026 GNBD
 *
 * Radio tab: read / write real device settings.
 */
import 'package:flutter/material.dart';

import '../../ble/controller.dart';
import '../../ble/protocol.dart';
import '../../core/ui.dart';

class RadioPage extends StatelessWidget {
  const RadioPage({super.key, required this.ble});

  final BleController ble;

  @override
  Widget build(BuildContext context) {
    final p = Pal(context);
    final st = ble.status;
    final rs = ble.radio;
    final connected = ble.state == LinkState.connected;
    final fm = rs.fmBand || (st?.band == 0);

    if (ble.isAts) {
      return _atsView(context, p, st, connected);
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 110),
      children: [
        CardX(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CardHead(
                title: 'Radio Settings',
                overline: 'LIVE FROM DEVICE',
                trailing: SmallButton('Refresh',
                    onTap: connected ? ble.loadRadioSettings : null),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FieldBox(
                      label: 'Band',
                      child: _dropdown<int>(
                        context,
                        value: st?.band.clamp(0, 13),
                        items: [
                          for (int i = 0; i < RadioStatus.bandNames.length; i++)
                            (i, RadioStatus.bandNames[i])
                        ],
                        onChanged: connected
                            ? (v) async {
                                await ble.setBand(v);
                                await ble.loadRadioSettings();
                              }
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FieldBox(
                      label: 'Mode',
                      child: _dropdown<int>(
                        context,
                        value: st?.mode.clamp(0, 3),
                        items: [
                          for (int i = 0; i < RadioStatus.modeNames.length; i++)
                            (i, RadioStatus.modeNames[i])
                        ],
                        onChanged: connected ? ble.setMode : null,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        CardX(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CardHead(title: 'Tuning', overline: 'STEP / BANDWIDTH'),
              const SizedBox(height: 14),
              FieldBox(
                label: 'Tuning Step',
                value: rs.stepLabel,
                child: _dropdown<int>(
                  context,
                  value: rs.stepSel.clamp(
                      0, rs.stepHz.isEmpty ? 0 : rs.stepHz.length - 1),
                  items: [
                    for (int i = 0; i < rs.stepHz.length; i++)
                      (
                        i,
                        i == 0
                            ? 'BAND DEFAULT'
                            : (rs.stepHz[i] >= 1000 &&
                                    rs.stepHz[i] % 1000 == 0
                                ? '${rs.stepHz[i] ~/ 1000} kHz'
                                : '${rs.stepHz[i]} Hz')
                      )
                  ],
                  onChanged: connected
                      ? (v) => ble.setRadioSetting(0, v)
                      : null,
                ),
              ),
              const SizedBox(height: 10),
              FieldBox(
                label: 'Bandwidth',
                value: rs.bwLabel,
                child: _dropdown<int>(
                  context,
                  value: rs.bwSel.clamp(
                      0, rs.bwLabels.isEmpty ? 0 : rs.bwLabels.length - 1),
                  items: [
                    for (int i = 0; i < rs.bwLabels.length; i++)
                      (i, rs.bwLabels[i])
                  ],
                  onChanged: connected
                      ? (v) => ble.setRadioSetting(1, v)
                      : null,
                ),
              ),
            ],
          ),
        ),
        CardX(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CardHead(title: 'Signal', overline: 'AGC / SQUELCH'),
              const SizedBox(height: 14),
              FieldBox(
                label: 'AGC',
                value: rs.agcLabel,
                child: Slider(
                  min: 0,
                  max: (rs.agcMax + 1).toDouble().clamp(1, 40),
                  divisions: (rs.agcMax + 1).clamp(1, 40),
                  value: rs.agcSel
                      .clamp(0, (rs.agcMax + 1).clamp(1, 40))
                      .toDouble(),
                  activeColor: p.blue,
                  onChanged:
                      connected ? (v) => _setDebounced(ble, 2, v.round()) : null,
                ),
              ),
              const SizedBox(height: 10),
              FieldBox(
                label: 'Squelch',
                value: rs.squelch == 0 ? 'OFF' : '${rs.squelch}',
                child: Slider(
                  min: 0,
                  max: 100,
                  divisions: 100,
                  value: rs.squelch.clamp(0, 100).toDouble(),
                  activeColor: p.blue,
                  onChanged:
                      connected ? (v) => _setDebounced(ble, 3, v.round()) : null,
                ),
              ),
            ],
          ),
        ),
        if (fm)
          CardX(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const CardHead(title: 'FM Options', overline: 'RDS / AUDIO'),
                const SizedBox(height: 6),
                _switchRow(
                  context,
                  'RDS',
                  'Radio Data System',
                  rs.rdsOn,
                  connected ? (v) => ble.setRadioSetting(4, v ? 0 : 1) : null,
                ),
                _switchRow(
                  context,
                  'Stereo',
                  'Force mono when off',
                  !rs.stereo,
                  connected ? (v) => ble.setRadioSetting(5, v ? 0 : 1) : null,
                ),
                _switchRow(
                  context,
                  'De-emphasis 75 µs',
                  'Off = 50 µs',
                  rs.deemph75,
                  connected ? (v) => ble.setRadioSetting(6, v ? 1 : 0) : null,
                ),
              ],
            ),
          ),
      ],
    );
  }

  static int? _lastItem;
  static int? _lastValue;
  static DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Throttle continuous slider updates to 150 ms.
  static void _setDebounced(BleController ble, int item, int value) {
    final now = DateTime.now();
    if (_lastItem == item &&
        _lastValue == value &&
        now.difference(_lastAt).inMilliseconds < 150) {
      return;
    }
    _lastItem = item;
    _lastValue = value;
    _lastAt = now;
    ble.setRadioSetting(item, value);
  }

  /// Official ATS Mini firmware exposes key-based controls only.
  Widget _atsView(
      BuildContext context, Pal p, RadioStatus? st, bool connected) {
    Widget stepper(String label, String? value, VoidCallback? dec,
            VoidCallback? inc) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: p.ink)),
                    if (value != null && value.isNotEmpty)
                      Text(value,
                          style: TextStyle(fontSize: 10.5, color: p.muted)),
                  ],
                ),
              ),
              _round(Icons.remove, dec),
              const SizedBox(width: 8),
              _round(Icons.add, inc),
            ],
          ),
        );

    return ListView(
      padding: const EdgeInsets.only(bottom: 110),
      children: [
        CardX(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CardHead(
                  title: 'Radio Settings', overline: 'ATS MINI FIRMWARE'),
              const SizedBox(height: 8),
              Text(
                'Official ATS Mini firmware supports key-based control only.',
                style: TextStyle(fontSize: 11, color: p.muted),
              ),
              const SizedBox(height: 10),
              stepper('Tuning step', st?.stepText,
                  connected ? () => ble.stepCycle(-1) : null,
                  connected ? () => ble.stepCycle(1) : null),
              stepper('Bandwidth', st?.bwText,
                  connected ? () => ble.bwCycle(-1) : null,
                  connected ? () => ble.bwCycle(1) : null),
              stepper('AGC / Attenuator',
                  st?.agcIdx == null ? null : '${st!.agcIdx}',
                  connected ? () => ble.agcCycle(-1) : null,
                  connected ? () => ble.agcCycle(1) : null),
              stepper('Backlight', null,
                  connected ? () => ble.backlightCycle(-1) : null,
                  connected ? () => ble.backlightCycle(1) : null),
            ],
          ),
        ),
        CardX(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CardHead(title: 'Status', overline: 'MONITOR'),
              const SizedBox(height: 10),
              _kv(p, 'Frequency',
                  st == null
                      ? '—'
                      : '${st.labelFor(ble.unitMode)} ${st.unitFor(ble.unitMode)}'),
              const SizedBox(height: 8),
              _kv(p, 'Mode / Band',
                  st == null ? '—' : '${st.modeName} · ${st.bandName}'),
              const SizedBox(height: 8),
              _kv(p, 'RSSI / SNR',
                  st == null ? '—' : '${st.rssi} / ${st.snr} dB'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _kv(Pal p, String k, String v) => FieldBox(
        label: k,
        child: Text(v,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: p.ink)),
      );

  Widget _round(IconData i, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFF2F4F8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(i, size: 18, color: const Color(0xFF6B7280)),
      ),
    );
  }

  Widget _switchRow(
    BuildContext context,
    String title,
    String sub,
    bool value,
    ValueChanged<bool>? onChanged,
  ) {
    final p = Pal(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: p.ink)),
                Text(sub,
                    style: TextStyle(fontSize: 10.5, color: p.muted)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: Colors.white,
            activeTrackColor: p.green,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _dropdown<T>(
    BuildContext context, {
    required T? value,
    required List<(T, String)> items,
    required ValueChanged<T>? onChanged,
  }) {
    final p = Pal(context);
    final valid = items.any((e) => e.$1 == value) ? value : null;
    return DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        isExpanded: true,
        isDense: true,
        value: valid,
        hint: Text('-', style: TextStyle(fontSize: 12, color: p.muted)),
        dropdownColor: p.surface,
        style: TextStyle(fontSize: 12, color: p.ink),
        items: items
            .map((e) => DropdownMenuItem(
                value: e.$1,
                child: Text(e.$2,
                    style: TextStyle(fontSize: 12, color: p.ink))))
            .toList(),
        onChanged: onChanged == null
            ? null
            : (v) {
                if (v != null) onChanged(v);
              },
      ),
    );
  }
}
