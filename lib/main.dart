/*
 * SPDX-License-Identifier: MIT
 * Copyright (c) miniradio Contributors
 * Copyright (c) 2026 GNBD
 *
 * miniradio companion v0.4 — ATS Mini style BLE remote.
 */
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ble/controller.dart';
import 'features/presets/presets_page.dart';
import 'features/remote/remote_page.dart';
import 'features/settings/settings_page.dart';
import 'core/ui.dart';

void main() => runApp(const MiniradioApp());

class MiniradioApp extends StatefulWidget {
  const MiniradioApp({super.key});

  @override
  State<MiniradioApp> createState() => _MiniradioAppState();
}

class _MiniradioAppState extends State<MiniradioApp> {
  ThemeMode _mode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getString('theme_mode');
    if (v == null) return;
    final mode = switch (v) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };
    if (mounted) setState(() => _mode = mode);
  }

  Future<void> _setTheme(ThemeMode m) async {
    setState(() => _mode = m);
    final p = await SharedPreferences.getInstance();
    await p.setString(
        'theme_mode',
        switch (m) {
          ThemeMode.dark => 'dark',
          ThemeMode.system => 'system',
          ThemeMode.light => 'light',
        });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Radio Control',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: _mode,
      home: HomeShell(
        themeMode: _mode,
        onThemeMode: _setTheme,
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.themeMode,
    required this.onThemeMode,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeMode;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final BleController ble = BleController();
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    ble.addListener(_onBle);
    ble.autoConnect();
  }

  void _onBle() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ble.removeListener(_onBle);
    ble.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal(context);
    final pages = [
      RemotePage(
        ble: ble,
        onConnectTap: _openConnectionSheet,
      ),
      PresetsPage(ble: ble),
      SettingsPage(
        ble: ble,
        themeMode: widget.themeMode,
        onThemeMode: widget.onThemeMode,
        status: ble.status,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(p),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 17),
                child: IndexedStack(index: _tab, children: pages),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _tabBar(p),
    );
  }

  Widget _header(Pal p) {
    final connected = ble.state == LinkState.connected;
    final scanning = ble.state == LinkState.scanning;
    final color = connected ? p.green : p.amber;
    final text = connected
        ? 'Connected'
        : scanning
            ? 'Scanning…'
            : 'Not connected';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mini Control',
                    style: TextStyle(
                        fontSize: 27,
                        letterSpacing: -0.8,
                        fontWeight: FontWeight.w700,
                        color: p.ink)),
                Text('by GNBD',
                    style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                        color: p.muted)),
              ],
            ),
          ),
          GestureDetector(
            onTap: _openConnectionSheet,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: p.shadow,
                      blurRadius: 18,
                      offset: const Offset(0, 6)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                        color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 7),
                  Text(text,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: p.ink)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------- connection sheet
  void _openConnectionSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => _ConnectionSheet(ble: ble),
    );
  }

  Widget _tabBar(Pal p) {
    const items = [
      ('◉', 'Remote'),
      ('☆', 'Presets'),
      ('⚙', 'Settings'),
    ];
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(17, 0, 17, 8),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 9),
        decoration: BoxDecoration(
          color: p.surface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(21),
          border: Border.all(
              color: p.dark ? p.line : Colors.white.withValues(alpha: 0.9)),
          boxShadow: [
            BoxShadow(
                color: p.shadow,
                blurRadius: 28,
                offset: const Offset(0, 9)),
          ],
        ),
        child: Row(
          children: List.generate(items.length, (i) {
            final active = _tab == i;
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _tab = i),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(items[i].$1,
                        style: TextStyle(
                            fontSize: 18,
                            height: 1.1,
                            color: active ? p.blue : p.muted)),
                    const SizedBox(height: 4),
                    Text(items[i].$2,
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: active ? p.blue : p.muted)),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Connection / scan bottom sheet.
class _ConnectionSheet extends StatefulWidget {
  const _ConnectionSheet({required this.ble});
  final BleController ble;

  @override
  State<_ConnectionSheet> createState() => _ConnectionSheetState();
}

class _ConnectionSheetState extends State<_ConnectionSheet> {
  @override
  void initState() {
    super.initState();
    widget.ble.addListener(_onBle);
  }

  void _onBle() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.ble.removeListener(_onBle);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ble = widget.ble;
    final p = Pal(context);
    final connected = ble.state == LinkState.connected;
    final scanning = ble.state == LinkState.scanning;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 26),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Bluetooth LE',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: p.ink)),
              const Spacer(),
              if (connected)
                SmallButton('Disconnect', onTap: ble.disconnect)
              else
                SmallButton(scanning ? 'Scanning…' : 'Scan',
                    onTap: scanning ? null : ble.startScan),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            connected
                ? '${ble.deviceName ?? 'miniradio'} · ${ble.deviceId ?? ''}'
                : 'Searching for miniradio / ATS-Mini…',
            style: TextStyle(fontSize: 11, color: p.muted),
          ),
          const SizedBox(height: 14),
          if (ble.found.isEmpty && !scanning)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text('No devices found.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: p.muted)),
            ),
          if (!connected)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: GestureDetector(
                onTap: () => ble.startScan(all: true),
                child: Text('Show all Bluetooth devices',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: p.blue)),
              ),
            ),
          ...ble.found.entries.map(
            (e) => GestureDetector(
              onTap: () => ble.connect(e.key),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: p.line),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.bluetooth, size: 16, color: p.blue),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.value,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: p.ink)),
                          Text(e.key,
                              style:
                                  TextStyle(fontSize: 10, color: p.muted)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 18, color: p.muted),
                  ],
                ),
              ),
            ),
          ),
          if (ble.error != null) ...[
            const SizedBox(height: 8),
            Text(ble.error!,
                style: TextStyle(fontSize: 11, color: p.red)),
          ],
          if (connected) ...[
            const SizedBox(height: 4),
            Text('Connected. Close this sheet to control.',
                style: TextStyle(fontSize: 11, color: p.green)),
          ],
        ],
      ),
    );
  }
}

