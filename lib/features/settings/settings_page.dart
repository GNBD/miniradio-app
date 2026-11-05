/*
 * SPDX-License-Identifier: MIT
 * Copyright (c) miniradio Contributors
 * Copyright (c) 2026 GNBD
 *
 * Settings tab: app preferences + live radio values.
 */
import 'package:flutter/material.dart';

import '../../ble/controller.dart';
import '../../ble/protocol.dart';
import '../../core/ui.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.ble,
    required this.themeMode,
    required this.onThemeMode,
    required this.status,
  });

  final BleController ble;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeMode;
  final RadioStatus? status;

  @override
  Widget build(BuildContext context) {
    final p = Pal(context);
    final st = status;
    return ListView(
      padding: const EdgeInsets.only(bottom: 110),
      children: [
        CardX(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CardHead(
                  title: 'Application Settings', overline: 'PREFERENCES'),
              const SizedBox(height: 14),
              FieldBox(
                label: 'Appearance',
                value: switch (themeMode) {
                  ThemeMode.system => 'SYSTEM',
                  ThemeMode.light => 'LIGHT',
                  ThemeMode.dark => 'DARK',
                },
                child: _Segmented(
                  options: const ['System', 'Light', 'Dark'],
                  selected: switch (themeMode) {
                    ThemeMode.system => 0,
                    ThemeMode.light => 1,
                    ThemeMode.dark => 2,
                  },
                  onSelect: (i) => onThemeMode(switch (i) {
                    1 => ThemeMode.light,
                    2 => ThemeMode.dark,
                    _ => ThemeMode.system,
                  }),
                ),
              ),
              const SizedBox(height: 10),
              FieldBox(
                label: 'Frequency unit',
                value: const ['AUTO', 'kHz', 'MHz'][ble.unitMode.clamp(0, 2)],
                child: _Segmented(
                  options: const ['Auto', 'kHz', 'MHz'],
                  selected: ble.unitMode.clamp(0, 2),
                  onSelect: (i) => ble.setUnitMode(i),
                ),
              ),
            ],
          ),
        ),
        CardX(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CardHead(
                  title: 'Network Bridge', overline: 'PHONE AS GATEWAY'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Serve HTTP for the radio',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: p.ink)),
                        Text(
                          ble.isAts
                              ? 'Not available with ATS Mini firmware'
                              : ble.bridgeEnabled
                                  ? (ble.bridgeBusy
                                      ? 'Serving request…'
                                      : 'On · weather and EiBi use this phone')
                                  : 'Off · radio uses its own Wi-Fi',
                          style: TextStyle(fontSize: 10.5, color: p.muted),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: ble.bridgeEnabled && !ble.isAts,
                    activeThumbColor: Colors.white,
                    activeTrackColor: p.green,
                    onChanged: ble.isAts
                        ? null
                        : (v) => ble.setBridgeEnabled(v),
                  ),
                ],
              ),
              if (ble.bridgeEnabled && ble.bridgeLast.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    ble.bridgeLast,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: p.muted),
                  ),
                ),
            ],
          ),
        ),
        CardX(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CardHead(title: 'Radio', overline: 'LIVE VALUES'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _kv(p, 'Frequency', st == null
                      ? '—'
                      : '${st.freqLabel} ${st.unitLabel}')),
                  const SizedBox(width: 10),
                  Expanded(child: _kv(p, 'Band', st?.bandName ?? '—')),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _kv(p, 'Mode', st?.modeName ?? '—')),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _kv(p, 'Volume', st == null ? '—' : '${st.volume}')),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                      child: _kv(p, 'RSSI',
                          st == null ? '—' : '${st.rssi} dBµV')),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _kv(p, 'SNR', st == null ? '—' : '${st.snr} dB')),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                      child: _kv(p, 'Battery',
                          st == null || st.battery < 0 ? '—' : '${st.battery}%')),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _kv(p, 'BLE',
                          st == null ? '—' : st.bleState == 2 ? 'Linked' : 'Idle')),
                ],
              ),
            ],
          ),
        ),
        CardX(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CardHead(title: 'About', overline: 'COMPANION'),
              const SizedBox(height: 12),
              _row(p, 'Version', '0.1.0 beta'),
              const Divider(height: 20),
              _row(p, 'Protocol',
                  ble.isAts ? 'ATS Mini (ad hoc)' : 'GNBD (BLE NUS)'),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'miniradio companion',
                  applicationVersion: '0.1.0 beta',
                ),
                child: Row(
                  children: [
                    Text('Open source licenses',
                        style: TextStyle(fontSize: 12, color: p.blue)),
                    const Spacer(),
                    Icon(Icons.chevron_right, size: 16, color: p.muted),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'MIT License. ESP-IDF / NimBLE (Apache-2.0) notices are '
                'shipped with the firmware repository.',
                style: TextStyle(fontSize: 10.5, color: p.muted, height: 1.5),
              ),
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

  Widget _row(Pal p, String k, String v) => Row(
        children: [
          Text(k, style: TextStyle(fontSize: 12, color: p.muted)),
          const Spacer(),
          Text(v,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: p.ink)),
        ],
      );
}

/// iOS style segmented control.
class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final List<String> options;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = Pal(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: p.soft,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: List.generate(options.length, (i) {
          final active = i == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: active ? p.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: active
                      ? [
                          BoxShadow(
                              color: p.shadow,
                              blurRadius: 5,
                              offset: const Offset(0, 1))
                        ]
                      : null,
                ),
                child: Text(
                  options[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: active ? p.blue : p.muted,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
