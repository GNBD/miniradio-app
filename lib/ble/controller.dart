/*
 * SPDX-License-Identifier: MIT
 * Copyright (c) miniradio Contributors
 * Copyright (c) 2026 GNBD
 *
 * BLE connection / command / status controller (universal_ble).
 */
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'protocol.dart';
import '../models/preset.dart';
import '../models/radio_settings.dart';

enum LinkState { idle, scanning, connecting, connected }

/// Which firmware protocol the connected radio speaks.
enum RadioProtocol { unknown, gnbd, ats }

class BleController extends ChangeNotifier {
  BleController() {
    UniversalBle.onScanResult = _onScan;
    UniversalBle.onValueChange = _onValue;
    UniversalBle.onConnectionChange = _onConnectionChange;
  }

  LinkState state = LinkState.idle;
  RadioProtocol protocol = RadioProtocol.unknown;
  bool _statusSeen = false;

  bool get isAts => protocol == RadioProtocol.ats;
  bool get isGnbd => protocol == RadioProtocol.gnbd;
  String? deviceId;
  String? deviceName;
  String? error;
  RadioStatus? status;
  final List<String> log = [];

  /// Preset list read from the radio.
  final List<Preset> presets = [];
  final Map<int, Preset> _tmpPresets = {};

  /// Radio settings snapshot.
  final RadioSettings radio = RadioSettings();

  /// RDS / EiBi station text.
  String station = '';

  /// Network bridge (phone performs HTTP for the radio).
  bool bridgeEnabled = true;
  bool bridgeBusy = false;
  String bridgeLast = '';
  int _lastStatusMs = 0;

  /// Scan results (deviceId -> name).
  final Map<String, String> found = {};

  /// Saved (registered) device for auto-reconnect.
  String? savedDeviceId;
  String? savedDeviceName;
  String? _autoTarget;

  /// Manual protocol override: 'auto' | 'gnbd' | 'ats'.
  String protocolPref = 'auto';

  /// Write mode negotiated during detection (ATS uses write-without-response).
  bool _writeWithoutResponse = false;

  Timer? _watchdog;

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!isAts || state != LinkState.connected) return;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (nowMs - _lastStatusMs > 4000) {
        // Recover from a stuck ad hoc command first, then re-arm the monitor.
        await sendRaw('\r', 'resync');
        await Future.delayed(const Duration(milliseconds: 150));
        await sendRaw(AtsCmd.monitorToggle, 'monitor rearm');
      }
    });
  }

  void _stopWatchdog() {    _watchdog?.cancel();
    _watchdog = null;
  }

  void _set(LinkState s) {
    state = s;
    notifyListeners();
  }

  void _log(String msg) {
    log.insert(0, '${DateTime.now().toIso8601String().substring(11, 19)}  $msg');
    if (log.length > 40) log.removeLast();
  }

  Future<void> startScan({bool all = false}) async {
    error = null;
    found.clear();
    _set(LinkState.scanning);
    try {
      await UniversalBle.requestPermissions();
      UniversalBle.onScanResult = _onScan;
      await UniversalBle.startScan(
        scanFilter: all
            ? null
            : ScanFilter(withNamePrefix: const ['miniradio', 'ATS']),
        skipDuplicates: true,
      );
      _log('scan started');
    } catch (e) {
      error = '$e';
      _set(LinkState.idle);
    }
  }

  Future<void> stopScan() async {
    try {
      await UniversalBle.stopScan();
    } catch (_) {}
    if (state == LinkState.scanning) {
      _set(LinkState.idle);
    }
  }

  void _onScan(BleDevice d) {
    final name = (d.name?.isNotEmpty == true) ? d.name! : '(no name)';
    found[d.deviceId] = name;
    if (_autoTarget != null &&
        UniversalBle.canonicalDeviceId(d.deviceId) ==
            UniversalBle.canonicalDeviceId(_autoTarget!)) {
      _autoTarget = null;
      unawaited(connect(d.deviceId));
    }
    notifyListeners();
  }

  /// Register / recall the device for automatic reconnection.
  Future<void> loadSavedDevice() async {
    final p = await SharedPreferences.getInstance();
    savedDeviceId = p.getString('ble_device');
    savedDeviceName = p.getString('ble_device_name');
    protocolPref = p.getString('radio_protocol') ?? 'auto';
  }

  Future<void> setProtocolPref(String value) async {
    protocolPref = value;
    final p = await SharedPreferences.getInstance();
    await p.setString('radio_protocol', value);
    if (state == LinkState.connected) {
      _stopWatchdog();
      await _detectProtocol();
      if (isGnbd) {
        await send(Cmd.query);
        await send(Cmd.presetList);
        await send(Cmd.getSettings);
        await setBridgeEnabled(bridgeEnabled);
      } else if (isAts) {
        await loadPresets();
        _startWatchdog();
      }
    }
    notifyListeners();
  }

  Future<void> _saveDevice(String id, String? name) async {
    savedDeviceId = id;
    if (name != null && name.isNotEmpty) savedDeviceName = name;
    final p = await SharedPreferences.getInstance();
    await p.setString('ble_device', id);
    if (savedDeviceName != null) {
      await p.setString('ble_device_name', savedDeviceName!);
    }
  }

  /// Try to reconnect to the registered device without user interaction.
  Future<void> autoConnect() async {
    await loadSavedDevice();
    if (savedDeviceId == null || savedDeviceId!.isEmpty) return;
    _autoTarget = savedDeviceId;
    await startScan();
    // Give up after 15 s and fall back to manual scanning.
    Timer(const Duration(seconds: 15), () {
      if (_autoTarget != null) {
        _autoTarget = null;
        stopScan();
      }
    });
  }

  Future<void> connect(String id) async {
    error = null;
    deviceId = id;
    deviceName = found[id] ?? savedDeviceName;
    _set(LinkState.connecting);
    try {
      await stopScan();
      debugPrint('BLE: connecting $id');
      try {
        await UniversalBle.unpair(id)
            .timeout(const Duration(seconds: 3));
        debugPrint('BLE: old bond cleared');
      } catch (_) {}
      await UniversalBle.connect(id)
          .timeout(const Duration(seconds: 20));
      _log('connected: $id');
      await _saveDevice(id, deviceName);
      try {
        await UniversalBle.requestMtu(id, 247)
            .timeout(const Duration(seconds: 5));
        debugPrint('BLE: mtu done');
      } catch (e) {
        debugPrint('BLE: mtu skipped $e');
      }
      await UniversalBle.discoverServices(id)
          .timeout(const Duration(seconds: 15));
      debugPrint('BLE: services done');
      await UniversalBle.subscribeNotifications(id, Nus.service, Nus.tx)
          .timeout(const Duration(seconds: 10));
      debugPrint('BLE: subscribed');
      _log('notify subscribed');
      _set(LinkState.connected);
      await _detectProtocol();
      if (isGnbd) {
        await send(Cmd.query);
        await send(Cmd.presetList);
        await send(Cmd.getSettings);
        await setBridgeEnabled(bridgeEnabled);
      } else if (isAts) {
        await loadPresets();
        _startWatchdog();
      }
    } catch (e) {
      error = '$e';
      _log('connect failed: $e');
      _set(LinkState.idle);
    }
  }

  Future<void> disconnect() async {
    _stopWatchdog();
    final id = deviceId;
    if (id != null) {
      try {
        await UniversalBle.disconnect(id);
      } catch (_) {}
    }
    deviceId = null;
    _set(LinkState.idle);
  }

  /// Auto-detect the firmware protocol.
  ///
  /// Sends the official monitor toggle ('t') a few times (it is also a toggle,
  /// so retrying covers the "was already on" case). The GNBD firmware ignores
  /// it and streams its own status within ~1 s.
  Future<void> _detectProtocol() async {
    protocol = RadioProtocol.unknown;
    _statusSeen = false;
    status = null;

    if (protocolPref == 'gnbd') {
      protocol = RadioProtocol.gnbd;
      _writeWithoutResponse = false;
      for (int i = 0; i < 15 && !_statusSeen; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      notifyListeners();
      return;
    }
    if (protocolPref == 'ats') {
      protocol = RadioProtocol.ats;
      _writeWithoutResponse = true;
      for (int i = 0; i < 4 && !_statusSeen; i++) {
        await sendBytes(const [0x74], 'probe', withoutResponse: true);
        for (int j = 0; j < 12 && !_statusSeen; j++) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
      notifyListeners();
      return;
    }

    // Prefer the advertised name: it is deterministic and avoids relying on
    // the monitor toggle timing.
    final nm = (deviceName ?? '').toUpperCase();
    if (nm.contains('ATS')) {
      protocol = RadioProtocol.ats;
      _writeWithoutResponse = true;
      for (int i = 0; i < 4 && !_statusSeen; i++) {
        await sendBytes(const [0x74], 'probe',
            withoutResponse: true);
        for (int j = 0; j < 12 && !_statusSeen; j++) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
      debugPrint('BLE protocol: ats (name)');
      notifyListeners();
      return;
    }
    if (nm.contains('MINIRADIO')) {
      protocol = RadioProtocol.gnbd;
      _writeWithoutResponse = false;
      for (int i = 0; i < 15 && !_statusSeen; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      debugPrint('BLE protocol: gnbd (name)');
      notifyListeners();
      return;
    }

    for (int attempt = 0; attempt < 3 && !_statusSeen; attempt++) {
      if (attempt == 0) {
        // The official firmware exposes RX as write-without-response only,
        // the GNBD firmware as write-with-response only. Probe accordingly.
        try {
          await sendBytes(const [0x74], 'probe',
              withoutResponse: true, rethrowError: true);
          _writeWithoutResponse = true;
        } catch (_) {
          _writeWithoutResponse = false;
          await sendBytes(const [0x74], 'probe', withoutResponse: false);
        }
      } else {
        await sendBytes(const [0x74], 'probe',
            withoutResponse: _writeWithoutResponse);
      }
      for (int i = 0; i < 12 && !_statusSeen; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    if (protocol == RadioProtocol.unknown) {
      protocol = RadioProtocol.gnbd;
    }
    debugPrint('BLE protocol: $protocol');
    notifyListeners();
  }

  Future<void> sendRaw(String cmd, String label) async {
    await sendBytes(utf8.encode(cmd), label);
  }

  Future<void> send(String cmd) async {
    await sendBytes(utf8.encode(cmd), cmd);
  }

  /// Absolute volume (0..63).
  Future<void> setVolume(int v) async {
    if (isAts) {
      final cur = status?.volume ?? 0;
      final delta = (v - cur).clamp(-63, 63);
      for (int i = 0; i < delta.abs(); i++) {
        await sendRaw(delta > 0 ? AtsCmd.volUp : AtsCmd.volDown, 'vol');
        await Future.delayed(const Duration(milliseconds: 25));
      }
      return;
    }
    await sendBytes(Cmd.setVolume(v), 'V$v');
  }

  /// Absolute frequency (Hz).
  Future<void> setFrequency(int hz) async {
    if (isAts) {
      await sendRaw(AtsCmd.setFreq(hz), 'F$hz');
      return;
    }
    await sendBytes(Cmd.setFreq(hz), 'F$hz');
  }

  Future<void> setBand(int idx) async {
    if (isAts) {
      const map = {0: 'VHF', 1: 'MW2', 2: 'MW1', 3: '41M'};
      await _atsSelectBand(map[idx] ?? 'VHF');
      return;
    }
    await sendBytes(Cmd.setBand(idx), 'B$idx');
  }

  /// One tuning step (native step of the connected firmware).
  Future<void> tuneStep(int dir) async {
    if (isAts) {
      await sendRaw(dir > 0 ? AtsCmd.encUp : AtsCmd.encDown, 'tune');
      return;
    }
    await sendRaw(dir > 0 ? 'U' : 'D', dir > 0 ? 'U' : 'D');
  }

  Future<void> bandStep(int dir) async {    if (isAts) {
      await sendRaw(dir > 0 ? AtsCmd.bandNext : AtsCmd.bandPrev, 'band');
      return;
    }
    await send(dir > 0 ? Cmd.bandUp : Cmd.bandDown);
  }

  Future<void> setMode(int idx) async {
    if (isAts) {
      int cur = status?.mode ?? 0;
      for (int i = 0; i < 4 && cur != idx; i++) {
        await sendRaw(AtsCmd.modeNext, 'M');
        await Future.delayed(const Duration(milliseconds: 120));
        cur = (cur + 1) % 4;
      }
      return;
    }
    await sendBytes(Cmd.setMode(idx), 'O$idx');
  }

  Future<void> loadPresets() async {
    if (isAts) {
      presets.clear();
      notifyListeners();
      await sendRaw(r'$', 'mem list');
      return;
    }
    await send(Cmd.presetList);
  }

  Future<void> savePreset() async {
    if (isAts) {
      final st = status;
      if (st == null) return;
      final slot = presets.length + 1;
      final band = st.bandText ?? st.bandName;
      final frame =
          '#${slot.toString().padLeft(2, '0')},$band,${st.freqHz},${st.modeName},\r';
      await sendRaw(frame, 'mem save');
      await Future.delayed(const Duration(milliseconds: 400));
      await loadPresets();
      return;
    }
    await send(Cmd.presetSave);
  }

  Future<void> tunePreset(int idx) async {
    if (isAts) {
      if (idx < 0 || idx >= presets.length) return;
      final p = presets[idx];
      await _atsSelectBand(p.bandLabel);
      await setFrequency(p.freqHz);
      return;
    }
    await sendBytes(Cmd.presetTune(idx), 'T$idx');
  }

  Future<void> _atsSelectBand(String target) async {
    final t = target.toUpperCase();
    for (int i = 0; i < 30; i++) {
      if ((status?.bandText ?? '').toUpperCase() == t) return;
      await sendRaw(AtsCmd.bandNext, 'band');
      await Future.delayed(const Duration(milliseconds: 550));
    }
  }

  Future<void> deletePreset(int idx) async {
    if (isAts) {
      if (idx < 0 || idx >= presets.length) return;
      final p = presets[idx];
      final slot = idx + 1;
      final frame =
          '#${slot.toString().padLeft(2, '0')},${p.bandLabel},0,AM,\r';
      await sendRaw(frame, 'mem delete');
      await Future.delayed(const Duration(milliseconds: 400));
      await loadPresets();
      return;
    }
    await sendBytes(Cmd.presetDelete(idx), 'X$idx');
  }

  Future<void> loadRadioSettings() async {
    if (isAts) return;
    await send(Cmd.getSettings);
  }

  /// item: 0=step 1=bw 2=agc 3=squelch 4=rds 5=stereo 6=deemph
  Future<void> setRadioSetting(int item, int value) async {
    if (isAts) return;
    await sendBytes(Cmd.setSetting(item, value), 'c$item=$value');
  }

  // ---- ATS Mini key-based controls ----

  Future<void> stepCycle(int dir) async {
    if (!isAts) return;
    await sendRaw(dir > 0 ? AtsCmd.stepNext : AtsCmd.stepPrev, 'step');
  }

  Future<void> bwCycle(int dir) async {
    if (!isAts) return;
    await sendRaw(dir > 0 ? AtsCmd.bwNext : AtsCmd.bwPrev, 'bw');
  }

  Future<void> agcCycle(int dir) async {
    if (!isAts) return;
    await sendRaw(dir > 0 ? AtsCmd.agcUp : AtsCmd.agcDown, 'agc');
  }

  Future<void> backlightCycle(int dir) async {
    if (!isAts) return;
    await sendRaw(dir > 0 ? AtsCmd.screenUp : AtsCmd.screenDown, 'light');
  }

  // ---- encoder emulation ----

  Future<void> encoderRotate(int dir) async {
    if (isAts) {
      await sendRaw(dir > 0 ? AtsCmd.encUp : AtsCmd.encDown, 'enc');
    } else {
      await sendRaw(dir > 0 ? 'Y' : 'y', 'enc');
    }
  }

  Future<void> encoderClick() async {
    await sendRaw(isAts ? AtsCmd.click : 'j', 'click');
  }

  Future<void> encoderHold() async {
    await sendRaw(isAts ? AtsCmd.shortPress : 'J', 'hold');
  }

  Future<void> toggleMonitor() async {
    await sendRaw(AtsCmd.monitorToggle, 'monitor');
  }

  Future<void> setBridgeEnabled(bool on) async {
    bridgeEnabled = on;
    notifyListeners();
    await sendBytes([0x6E, on ? 1 : 0], 'bridge ${on ? 'on' : 'off'}');
  }

  Future<void> _handleBridgeRequest(int id, String url) async {
    bridgeBusy = true;
    bridgeLast = url;
    notifyListeners();

    int status = 0;
    HttpClient? client;
    try {
      client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10);
      final req = await client.getUrl(Uri.parse(url));
      final res = await req.close();
      if (res.statusCode >= 200 && res.statusCode < 300) {
        await for (final chunk in res) {
          if (!bridgeEnabled) {
            status = 3;
            break;
          }
          for (int i = 0; i < chunk.length; i += 200) {
            final end = math.min(i + 200, chunk.length);
            await _sendBridgeChunk(id, chunk.sublist(i, end));
          }
        }
      } else {
        status = 1;
      }
    } catch (_) {
      status = 2;
    } finally {
      client?.close(force: true);
    }

    await sendBytes([0x65, id & 0xFF, status & 0xFF], 'bridge end $id/$status');
    bridgeBusy = false;
    notifyListeners();
  }

  Future<void> _sendTime() async {
    final secs = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final frame = <int>[0x7A];
    for (int i = 0; i < 8; i++) {
      frame.add((secs >> (8 * i)) & 0xFF);
    }
    await sendBytes(frame, 'time $secs');
  }

  Future<void> _sendBridgeChunk(int id, List<int> data) async {    final frame = <int>[
      0x64,
      id & 0xFF,
      data.length & 0xFF,
      (data.length >> 8) & 0xFF,
      ...data,
    ];
    await sendBytes(frame, 'bridge data ${data.length}B');
  }

  Future<void> sendBytes(List<int> bytes, String label,
      {bool? withoutResponse, bool rethrowError = false}) async {
    final id = deviceId;
    if (id == null || state != LinkState.connected) return;
    final nr = withoutResponse ??
        (protocol == RadioProtocol.ats);
    try {
      await UniversalBle.write(
        id,
        Nus.service,
        Nus.rx,
        Uint8List.fromList(bytes),
        withoutResponse: nr,
      );
      _log('TX $label');
      debugPrint('BLE TX $label${nr ? ' (nr)' : ''}');
    } catch (e) {
      _log('write failed: $e');
      debugPrint('BLE TX failed $label: $e');
      if (rethrowError) rethrow;
    }
  }

  String _rxPending = '';

  bool _looksStandalone(String t) {
    if (protocol == RadioProtocol.ats) return false;
    if (RadioStatus.isAtsMonitor(t)) return true;
    final p = t.split(',');
    if (p.length == 8 && int.tryParse(p[0].trim()) != null) return true; // GNBD status
    for (final pre in const [
      'PC,', 'P,', 'N,', 'PE', 'SI,', 'BRQ,', '#',
      'RSTEP,', 'RBW,', 'RAGC,', 'RSQ,', 'RRDS,', 'RSTE,', 'RDE,', 'RMODE,',
    ]) {
      if (t.startsWith(pre)) return true;
    }
    return false;
  }

  void _onValue(BleCharacteristicValue v) {
    if (v.characteristicId.toUpperCase() != Nus.tx.toUpperCase()) return;
    final text = utf8.decode(v.value, allowMalformed: true);
    debugPrint('BLE RX: ${text.trim()}');
    _rxPending += text;

    // Complete CRLF terminated lines (official ATS Mini monitor).
    for (;;) {
      final idx = _rxPending.indexOf('\n');
      if (idx < 0) break;
      final line = _rxPending.substring(0, idx).trim();
      _rxPending = _rxPending.substring(idx + 1);
      if (line.isNotEmpty) _handleRxText(line);
    }

    // The GNBD firmware sends unframed one-line messages; the ATS monitor can
    // also arrive as a single complete line when the MTU is large enough.
    final rest = _rxPending.trim();
    if (rest.isNotEmpty && _looksStandalone(rest)) {
      _rxPending = '';
      _handleRxText(rest);
    }
  }

  void _handleRxText(String text) {
    // ATS Mini memory slot line: #NN,BAND,freq,mode[,name]
    if (isAts && text.startsWith('#')) {
      final f = text.substring(1).split(',');
      if (f.length >= 4) {
        final freq = int.tryParse(f[2].trim()) ?? 0;
        if (freq > 0) {
          presets.add(Preset(
            name: f.length > 4 ? f.sublist(4).join(',').trim() : '',
            freqHz: freq,
            band: 0,
            bandText: f[1].trim(),
          ));
          notifyListeners();
        }
      }
      return;
    }

    // Official ATS Mini monitor stream (15 CSV fields).
    if (RadioStatus.isAtsMonitor(text)) {
      final st = RadioStatus.parseAts(text);
      if (st != null) {
        protocol = RadioProtocol.ats;
        _statusSeen = true;
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        status = st;
        _lastStatusMs = nowMs;
        debugPrint('BLE ATS ${st.freqHz} ${st.bandName} ${st.modeName} '
            'v${st.volume} rssi${st.rssi}');
        notifyListeners();
      }
      return;
    }

    // Preset list protocol: PC,<count> / P,<i>,<freq>,<band>,<mode>[,name] /
    //                        N,<i>,<name> / PE
    if (text.startsWith('PC,')) {
      _tmpPresets.clear();
      return;
    }
    if (text.startsWith('P,')) {
      final f = text.split(',');
      if (f.length >= 5) {
        final i = int.tryParse(f[1]);
        final hz = int.tryParse(f[2]);
        final band = int.tryParse(f[3]);
        if (i != null && hz != null && band != null) {
          final name = f.length > 5 ? f.sublist(5).join(',') : '';
          _tmpPresets[i] = Preset(name: name, freqHz: hz, band: band);
        }
      }
      notifyListeners();
      return;
    }
    if (text.startsWith('N,')) {
      final f = text.split(',');
      if (f.length >= 3) {
        final i = int.tryParse(f[1]);
        if (i != null && _tmpPresets[i] != null) {
          _tmpPresets[i]!.name = f.sublist(2).join(',');
        }
      }
      return;
    }
    if (text == 'PE') {
      final keys = _tmpPresets.keys.toList()..sort();
      presets
        ..clear()
        ..addAll(keys.map((k) => _tmpPresets[k]!));
      notifyListeners();
      return;
    }

    if (text == 'TIM') {
      unawaited(_sendTime());
      return;
    }

    if (text.startsWith('SI,')) {
      station = text.substring(3).trim();
      notifyListeners();
      return;
    }

    if (text.startsWith('BRQ,')) {
      final first = text.indexOf(',');
      final second = text.indexOf(',', first + 1);
      if (second > first) {
        final id = int.tryParse(text.substring(first + 1, second));
        final url = text.substring(second + 1);
        debugPrint('BLE BRQ $id $url enabled=$bridgeEnabled');
        if (id != null && url.isNotEmpty && bridgeEnabled) {
          unawaited(_handleBridgeRequest(id, url));
        }
      }
      return;
    }

    // Radio settings snapshot.
    if (text.startsWith('RSTEP,')) {
      final f = text.split(',');
      radio.stepSel = int.tryParse(f[1]) ?? 0;
      radio.stepHz = [
        for (int i = 3; i < f.length; i++) int.tryParse(f[i]) ?? 0
      ];
      notifyListeners();
      return;
    }
    if (text.startsWith('RBW,')) {
      final f = text.split(',');
      radio.bwSel = int.tryParse(f[1]) ?? 0;
      radio.bwLabels = f.length > 3 ? f.sublist(3).join(',').split('|') : ['AUTO'];
      notifyListeners();
      return;
    }
    if (text.startsWith('RAGC,')) {
      final f = text.split(',');
      radio.agcSel = int.tryParse(f[1]) ?? 0;
      radio.agcMax = f.length > 2 ? (int.tryParse(f[2]) ?? 0) : 0;
      notifyListeners();
      return;
    }
    if (text.startsWith('RSQ,')) {
      radio.squelch = int.tryParse(text.substring(4)) ?? 0;
      notifyListeners();
      return;
    }
    if (text.startsWith('RRDS,')) {
      final v = int.tryParse(text.substring(5)) ?? 0;
      radio.rdsOn = v == 0;
      notifyListeners();
      return;
    }
    if (text.startsWith('RSTE,')) {
      final v = int.tryParse(text.substring(5)) ?? 0;
      radio.stereo = v == 1;
      notifyListeners();
      return;
    }
    if (text.startsWith('RDE,')) {
      final v = int.tryParse(text.substring(4)) ?? 0;
      radio.deemph75 = v == 1;
      notifyListeners();
      return;
    }
    if (text.startsWith('RMODE,')) {
      final f = text.split(',');
      radio.mode = int.tryParse(f[1]) ?? 0;
      radio.fmBand = f.length > 2 && f[2].trim() == '1';
      notifyListeners();
      return;
    }

    final st = RadioStatus.parse(text);
    if (st != null) {
      protocol = RadioProtocol.gnbd;
      _statusSeen = true;
      final old = status;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final coreChanged = old == null ||
          old.freqHz != st.freqHz ||
          old.mode != st.mode ||
          old.band != st.band ||
          old.bandText != st.bandText ||
          old.stepText != st.stepText ||
          old.bwText != st.bwText ||
          old.agcIdx != st.agcIdx ||
          old.volume != st.volume ||
          old.battery != st.battery;
      status = st;
      if (!coreChanged && (nowMs - _lastStatusMs) < 500) {
        return;                       // 신호값만 변할 때는 0.5s 스로틀
      }
      _lastStatusMs = nowMs;
      notifyListeners();
    } else {
      _log('RX "$text"');
    }
  }

  void _onConnectionChange(BleConnectionChange c) {
    final id = deviceId;
    if (id == null) return;
    if (UniversalBle.canonicalDeviceId(c.deviceId) !=
        UniversalBle.canonicalDeviceId(id)) {
      return;
    }
    if (!c.isConnected) {
      _log('disconnected');
      _set(LinkState.idle);
    }
  }

  @override
  void dispose() {
    _stopWatchdog();
    UniversalBle.onScanResult = null;
    UniversalBle.onValueChange = null;
    UniversalBle.onConnectionChange = null;
    super.dispose();
  }
}
