/*
 * SPDX-License-Identifier: MIT
 * Copyright (c) miniradio Contributors
 * Copyright (c) 2026 GNBD
 *
 * Remote tab: status / frequency / tuning / band / volume / demod.
 */
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../ble/controller.dart';
import '../../ble/protocol.dart';
import '../../core/ui.dart';

class RemotePage extends StatelessWidget {
  const RemotePage({
    super.key,
    required this.ble,
    required this.onConnectTap,
  });

  final BleController ble;
  final VoidCallback onConnectTap;

  static const int _stepHz = 100000;

  static const _quickBands = [
    (0, 'FM'),
    (1, 'AM'),
    (3, 'SW'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = Pal(context);
    final st = ble.status;
    final connected = ble.state == LinkState.connected;

    return ListView(
      padding: const EdgeInsets.only(bottom: 110),
      children: [
        _deviceCard(context, connected),
        _receiverCard(context, st, connected),
        _configCard(context, st, connected, p),
      ],
    );
  }

  // ------------------------------------------------------------- device
  Widget _deviceCard(BuildContext context, bool connected) {
    final p = Pal(context);
    return CardX(
      child: Column(
        children: [
          CardHead(
            overline: 'DEVICE',
            title: ble.deviceName ?? 'ATS Mini Receiver',
            trailing: SmallButton(
              connected ? 'Disconnect' : 'Connect',
              onTap: () {
                if (connected) {
                  ble.disconnect();
                } else {
                  onConnectTap();
                }
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: connected ? p.green : p.amber,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  connected
                      ? 'Connected · ${ble.isAts ? 'ATS Mini' : ble.isGnbd ? 'GNBD' : 'detecting…'}'
                      : 'Not connected · tap Connect',
                  style: TextStyle(fontSize: 11.5, color: p.muted),
                ),
              ),
              if (ble.deviceId != null)
                Text(
                  ble.deviceId!.length > 17
                      ? ble.deviceId!.substring(0, 17)
                      : ble.deviceId!,
                  style: TextStyle(fontSize: 10, color: p.muted),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------- receiver
  Widget _receiverCard(BuildContext context, RadioStatus? st, bool connected) {
    final band = st?.band ?? 0;
    final freq = st?.freqLabel ?? '---.---';
    final unit = st?.unitLabel ?? 'MHz';
    final mode = st?.modeName ?? 'FM';
    final useMhz = st?.useMhz ?? true;

    return CardX(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF111C31), Color(0xFF1B3154)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -70,
                top: -90,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF3885FA).withValues(alpha: 0.09),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          '$mode · ${band == 0 ? 'STEREO' : 'RECEIVE'}',
                          style: const TextStyle(
                            color: Color(0xFFB8C9E4),
                            fontSize: 10,
                            letterSpacing: 1.3,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: connected
                          ? () => _editFrequency(context, st)
                          : null,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            freq,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 52,
                              height: 1.1,
                              letterSpacing: -2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 7),
                            child: Text(
                              unit,
                              style: const TextStyle(
                                color: Color(0xFFA9C9FF),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (connected)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 9),
                              child: Icon(Icons.edit,
                                  size: 16, color: Color(0xFF8FB4E8)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ble.station.isNotEmpty
                          ? ble.station
                          : (connected
                              ? 'Tap the frequency to type it directly'
                              : 'Receiver ready · connect to control'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xFFB8C9E4), fontSize: 11),
                    ),
                    const SizedBox(height: 18),
                    _signalRow(st),
                    const SizedBox(height: 16),
                    if (ble.isAts)
                      _atsBandRow(context, st?.bandName ?? '-', connected)
                    else
                      _bandRow(context, band, connected),
                    const SizedBox(height: 12),
                    _tuningRow(context, connected, useMhz),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _signalRow(RadioStatus? st) {
    final rssi = st?.rssi ?? 0;
    final snr = st?.snr ?? 0;
    final rssiRatio = (rssi.abs() / 80).clamp(0.0, 1.0);
    final snrRatio = (snr / 30).clamp(0.0, 1.0);
    final snrColor = snr < 10
        ? const Color(0xFFFF5A5A)
        : const Color(0xFF68A7FF);

    return Column(
      children: [
        Row(
          children: [
            Text('RSSI $rssi',
                style:
                    const TextStyle(color: Color(0xFFBDCCE2), fontSize: 10)),
            const Spacer(),
            Text('SNR $snr dB',
                style:
                    const TextStyle(color: Color(0xFFBDCCE2), fontSize: 10)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _halfBar(
                  ratio: rssiRatio,
                  color: const Color(0xFF3DDC84),
                  leftToRight: true),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _halfBar(
                  ratio: snrRatio, color: snrColor, leftToRight: false),
            ),
          ],
        ),
      ],
    );
  }

  /// Half gauge growing left->center or right->center.
  Widget _halfBar({
    required double ratio,
    required Color color,
    required bool leftToRight,
  }) {
    return SizedBox(
      height: 5,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          children: [
            Container(color: Colors.white.withValues(alpha: 0.13)),
            Align(
              alignment:
                  leftToRight ? Alignment.centerLeft : Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: ratio.clamp(0.0, 1.0),
                child: Container(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _atsBandRow(BuildContext context, String bandName, bool connected) {
    final p = Pal(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: p.soft,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: connected ? () => ble.bandStep(-1) : null,
            child: Icon(Icons.chevron_left,
                size: 22, color: connected ? p.blue : p.muted),
          ),
          Expanded(
            child: Text(bandName,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: p.blue)),
          ),
          GestureDetector(
            onTap: connected ? () => ble.bandStep(1) : null,
            child: Icon(Icons.chevron_right,
                size: 22, color: connected ? p.blue : p.muted),
          ),
        ],
      ),
    );
  }

  Widget _bandRow(BuildContext context, int band, bool connected) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F8),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: _quickBands.map((e) {
          final active = band == e.$1 || (e.$1 == 1 && band == 2);
          return Expanded(
            child: GestureDetector(
              onTap: connected ? () => ble.setBand(e.$1) : null,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: const Color(0xFF1B3150)
                                .withValues(alpha: 0.08),
                            blurRadius: 7,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Text(
                  e.$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: active
                        ? const Color(0xFF2878F0)
                        : const Color(0xFF7C8493),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _tuningRow(BuildContext context, bool connected, bool useMhz) {
    Widget btn(IconData icon, VoidCallback? onTap) => GestureDetector(
          onTap: onTap,
          child: Container(
            height: 46,
            width: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF3A6FB8).withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon,
                color: connected
                    ? const Color(0xFF8FC0FF)
                    : const Color(0xFF6E7C93),
                size: 24),
          ),
        );

    void nudge(int dir) {
      final st = ble.status;
      if (st == null) return;
      var next = st.freqHz + dir * _stepHz;
      if (next < 0) next = 0;
      ble.setFrequency(next);
    }

    return Row(
      children: [
        btn(Icons.remove, connected ? () => nudge(-1) : null),
        Expanded(
          child: Column(
            children: [
              const Text('TUNING',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8)),
              const SizedBox(height: 3),
              Text('Step · ${_stepLabel(_stepHz)}',
                  style: const TextStyle(
                      color: Color(0xFFB8C9E4), fontSize: 10)),
            ],
          ),
        ),
        btn(Icons.add, connected ? () => nudge(1) : null),
      ],
    );
  }

  String _stepLabel(int hz) {
    if (hz >= 1000000) return '${hz ~/ 1000000} MHz';
    return '${hz ~/ 1000} kHz';
  }

  // ------------------------------------------------------------- config
  Widget _configCard(
      BuildContext context, RadioStatus? st, bool connected, Pal p) {
    final vol = (st?.volume ?? 0).clamp(0, 63);
    return CardX(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CardHead(title: 'Receiver Configuration', overline: 'RF / DSP'),
          const SizedBox(height: 14),
          FieldBox(
            label: 'Volume',
            value: '$vol',
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                activeTrackColor: p.blue,
                inactiveTrackColor: p.line,
                thumbColor: p.blue,
                overlayColor: Colors.transparent,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 8),
              ),
              child: Slider(
                min: 0,
                max: 63,
                divisions: 63,
                value: vol.toDouble(),
                onChanged: connected
                    ? (v) => ble.setVolume(v.round())
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // ------------------------------------------------------- freq editor
  Future<void> _editFrequency(BuildContext context, RadioStatus? st) async {
    if (st == null) return;
    final ctrl = TextEditingController(text: st.freqText);
    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) {
        final p = Pal(c);
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(c).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 26),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Set frequency',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: p.ink)),
                const SizedBox(height: 4),
                Text('${st.bandName} band · ${st.unitLabel}',
                    style: TextStyle(fontSize: 11, color: p.muted)),
                const SizedBox(height: 16),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: p.ink),
                  decoration: InputDecoration(
                    suffixText: st.unitLabel,
                    filled: true,
                    fillColor: p.soft,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(c),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: p.soft,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text('Cancel',
                            style: TextStyle(color: p.muted)),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          final v =
                              double.tryParse(ctrl.text.trim());
                          if (v == null || v <= 0) return;
                          final hz = st.useMhz
                              ? (v * 1000000).round()
                              : (v * 1000).round();
                          Navigator.pop(c, hz);
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: p.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Apply',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (result != null) {
      await ble.setFrequency(result);
    }
  }
}
