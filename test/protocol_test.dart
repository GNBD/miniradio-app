// SPDX-License-Identifier: MIT
import 'package:flutter_test/flutter_test.dart';
import 'package:miniradio_companion/ble/protocol.dart';

void main() {
  test('GNBD status 8 fields (legacy firmware)', () {
    final s = RadioStatus.parse('87500000,0,1,25,-60,28,87,2');
    expect(s, isNotNull);
    expect(s!.freqHz, 87500000);
    expect(s.battery, 87);
    expect(s.voltage, -1);
  });

  test('GNBD status 9 fields includes voltage', () {
    final s = RadioStatus.parse('100700000,0,0,19,33,3,100,2,4445');
    expect(s, isNotNull);
    expect(s!.freqHz, 100700000);
    expect(s.battery, 100);
    expect(s.bleState, 2);
    expect(s.voltage, closeTo(4.445, 0.001));
  });

  test('future GNBD status fields are ignored, not fatal', () {
    final s = RadioStatus.parse('100700000,0,0,19,33,3,100,2,4445,1,2,3');
    expect(s, isNotNull);
    expect(s!.freqHz, 100700000);
    expect(s.voltage, closeTo(4.445, 0.001));
  });

  test('short / broken status is rejected', () {
    expect(RadioStatus.parse('1,2,3'), isNull);
    expect(RadioStatus.parse('garbage'), isNull);
  });

  test('ATS monitor line still parses with battery and voltage', () {
    final s = RadioStatus.parseAts(
        '244,21224,1000,0,15M,USB,1k,3.0k,0,15,43,0,1,4.54,8');
    expect(s, isNotNull);
    expect(s!.bandName, '15M');
    expect(s.modeName, 'USB');
    expect(s.battery, 1);
    expect(s.voltage, closeTo(4.54, 0.001));
  });

  test('frequency formatting stays stable', () {
    final s = RadioStatus.parse('101700000,0,0,30,41,22,88,2');
    expect(s!.freqLabel, '101.7');
    expect(s.unitLabel, 'MHz');
  });
}
