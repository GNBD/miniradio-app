// SPDX-License-Identifier: MIT
import 'package:flutter_test/flutter_test.dart';
import 'package:miniradio_companion/ble/protocol.dart';

void main() {
  test('status CSV parse', () {
    final s = RadioStatus.parse('87500000,0,1,25,-60,28,87,2');
    expect(s, isNotNull);
    expect(s!.freqHz, 87500000);
    expect(s.bandName, 'MW');
    expect(s.modeName, 'FM');
    expect(s.volume, 25);
    expect(s.rssi, -60);
    expect(s.snr, 28);
    expect(s.battery, 87);
    expect(s.bleState, 2);
  });

  test('preset CSV parse shape', () {
    final s = RadioStatus.parse('101700000,0,0,30,41,22,88,2');
    expect(s!.freqLabel, '101.7');
    expect(s.unitLabel, 'MHz');
  });
}
