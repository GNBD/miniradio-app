# miniradio companion

Android (and Windows) companion app for the GNBD ATS Mini / miniradio receiver.

Controls the radio over Bluetooth LE using the Nordic UART Service (NUS) and can
act as a network bridge: when the radio has no Wi-Fi, the phone fetches
weather / EiBi schedule / time and forwards the result over BLE.

## Features

- BLE remote: tune, band, mode, volume, presets, radio settings
- Live status: frequency, band, mode, volume, RSSI, SNR, battery, RDS/EiBi text
- Presets: loaded from and saved to the radio
- Radio tab: step / bandwidth / AGC / squelch / FM options
- Network bridge: weather, EiBi download and clock sync without radio Wi-Fi
- Automatic reconnect to the last used radio

## Requirements

- Flutter 3.47+ / Dart 3.13+
- Android SDK 36, JDK 17 or 21 (JDK 26 currently breaks AGP jlink transforms)

## Build

```bash
flutter pub get
flutter build apk --release --split-per-abi
```

Release signing uses `android/key.properties` (not committed). Copy
`android/key.properties.example` and point it at your own keystore.

The Windows target is kept for development; build with
`flutter build windows --debug`.

## Protocol (BLE NUS)

- Service `6E400001-B5A3-F393-E0A9-E50E24DCCA9E`
- RX `6E400002-...` (central writes)
- TX `6E400003-...` (notify)

See `lib/ble/protocol.dart` for commands.

## License

MIT. See `LICENSE` and `THIRD_PARTY_NOTICES.md`.

The firmware is a separate project (MIT, with ESP-IDF/NimBLE under Apache-2.0).
