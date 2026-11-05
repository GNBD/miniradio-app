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
        _encoderRow(context, connected),
      ],
    );
  }

  // ---------------------------------------------------------- encoder row
  Widget _encoderRow(BuildContext context, bool connected) {
    final p = Pal(context);
    Widget btn(IconData icon, String label, VoidCallback? onTap) => Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: p.soft2,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon,
                      size: 20,
                      color: connected ? p.blue : p.muted),
                  const SizedBox(height: 5),
                  Text(label,
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: connected ? p.ink : p.muted)),
                ],
              ),
            ),
          ),
        );

    return CardX(
      child: Row(
        children: [
          btn(Icons.rotate_left, 'LEFT',
              connected ? () => ble.encoderRotate(-1) : null),
          btn(Icons.rotate_right, 'RIGHT',
              connected ? () => ble.encoderRotate(1) : null),
          btn(Icons.touch_app, 'CLICK',
              connected ? ble.encoderClick : null),
          btn(Icons.pan_tool, 'HOLD',
              connected ? ble.encoderHold : null),
        ],
      ),
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
                      ? 'Connected'
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
                          '$mode · ${(st?.mode ?? 0) == 0 ? 'STEREO' : 'RECEIVE'}',
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
                      ble.station.isNotEmpty ? ble.station : ' ',
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
                      _bandSelectorRow(context, st?.bandName ?? '-', connected),
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

  /// Official ATS Mini: step through bands with the arrows instead of
  /// jumping straight to a band (the receiver only supports next/previous).
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
                size: 24, color: connected ? p.blue : p.muted),
          ),
          Expanded(
            child: Text(bandName,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: p.blue)),
          ),
          GestureDetector(
            onTap: connected ? () => ble.bandStep(1) : null,
            child: Icon(Icons.chevron_right,
                size: 24, color: connected ? p.blue : p.muted),
          ),
        ],
      ),
    );
  }

  /// GNBD: tap to open the full band list and pick one.
  Widget _bandSelectorRow(
      BuildContext context, String bandName, bool connected) {
    final p = Pal(context);
    return GestureDetector(
      onTap: connected ? () => _showBandSheet(context) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: p.soft,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            Text('BAND',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: p.muted)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(bandName,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: p.blue)),
            ),
            Icon(Icons.expand_more, size: 20, color: p.muted),
          ],
        ),
      ),
    );
  }

  Future<void> _showBandSheet(BuildContext context) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (c) {
        final p = Pal(c);
        return Container(
          constraints: const BoxConstraints(maxHeight: 520),
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 18),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                    color: p.line, borderRadius: BorderRadius.circular(2)),
              ),
              Text('Select band',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: p.ink)),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: RadioStatus.bandNames.length,
                  itemBuilder: (c2, i) {
                    final selected = ble.status?.band == i;
                    return ListTile(
                      dense: true,
                      onTap: () => Navigator.pop(c2, i),
                      title: Text(RadioStatus.bandNames[i],
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: selected ? p.blue : p.ink)),
                      trailing: selected
                          ? Icon(Icons.check, size: 18, color: p.blue)
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
    if (picked != null) await ble.setBand(picked);
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
      ble.tuneStep(dir);
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
