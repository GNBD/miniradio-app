/*
 * SPDX-License-Identifier: MIT
 * Copyright (c) miniradio Contributors
 * Copyright (c) 2026 GNBD
 *
 * Presets tab: live sync with the radio favourites.
 */
import 'package:flutter/material.dart';

import '../../ble/controller.dart';
import '../../core/ui.dart';

class PresetsPage extends StatelessWidget {
  const PresetsPage({super.key, required this.ble});

  final BleController ble;

  @override
  Widget build(BuildContext context) {
    final p = Pal(context);
    final connected = ble.state == LinkState.connected;
    final list = ble.presets;

    return ListView(
      padding: const EdgeInsets.only(bottom: 110),
      children: [
        CardX(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CardHead(
                overline: 'STATION LIBRARY',
                title: 'Presets',
                trailing: SmallButton(
                  '＋ Save current',
                  onTap: connected ? () => ble.savePreset() : null,
                ),
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      connected
                          ? '${list.length} SAVED STATIONS'
                          : 'CONNECT TO LOAD PRESETS',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: p.muted),
                    ),
                  ),
                  GestureDetector(
                    onTap: connected ? () => ble.loadPresets() : null,
                    child: Icon(Icons.refresh,
                        size: 18, color: connected ? p.blue : p.muted),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 26),
                  child: Text(
                    connected
                        ? 'No presets stored on the radio.\nUse “Save current” while listening.'
                        : 'Connect to load favourites from the radio.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: p.muted, height: 1.5),
                  ),
                ),
              ...List.generate(list.length, (i) {
                final pr = list[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: p.surface,
                    border: Border.all(color: p.line),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: p.blueSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('${i + 1}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: p.blue)),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pr.name.trim().isEmpty
                                  ? pr.bandName
                                  : pr.name.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: p.ink),
                            ),
                            const SizedBox(height: 4),
                            Text('${pr.bandName} BAND · ${pr.freqLabel}',
                                style: TextStyle(
                                    fontSize: 10, color: p.muted)),
                          ],
                        ),
                      ),
                      _iconBtn(context, Icons.play_arrow,
                          connected ? () => ble.tunePreset(i) : null),
                      const SizedBox(width: 5),
                      _iconBtn(context, Icons.close,
                          connected ? () => _confirmDelete(context, i) : null),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, int i) async {
    final p = Pal(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: p.surface,
        title: Text('Delete preset?',
            style: TextStyle(fontSize: 17, color: p.ink)),
        content: Text('This also removes it from the radio.',
            style: TextStyle(fontSize: 12, color: p.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text('Cancel', style: TextStyle(color: p.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text('Delete', style: TextStyle(color: p.red)),
          ),
        ],
      ),
    );
    if (ok == true) await ble.deletePreset(i);
  }

  Widget _iconBtn(BuildContext context, IconData icon, VoidCallback? onTap) {
    final p = Pal(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 31,
        height: 31,
        decoration: BoxDecoration(
          color: p.soft,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon,
            size: 15, color: onTap == null ? p.line : p.muted),
      ),
    );
  }
}
