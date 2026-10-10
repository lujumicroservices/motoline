import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/core/services/metrica_ble_permissions.dart';
import 'package:motoline/core/services/metrica_ble_protocol.dart';

void main() {
  test('advertisement requires Metrica-XXXX and the service UUID', () {
    expect(
      MetricaBleProtocol.matchesAdvertisement(
        name: 'Metrica-A1B2',
        serviceUuidStrings: [MetricaBleProtocol.serviceUuid.toUpperCase()],
      ),
      isTrue,
    );
    expect(
      MetricaBleProtocol.matchesAdvertisement(
        name: 'Metrica-A1B2',
        serviceUuidStrings: const ['0000fea6-0000-1000-8000-00805f9b34fb'],
      ),
      isFalse,
    );
    expect(
      MetricaBleProtocol.matchesAdvertisement(
        name: 'GoPro-A1B2',
        serviceUuidStrings: [MetricaBleProtocol.serviceUuid],
      ),
      isFalse,
    );
    expect(
      MetricaBleProtocol.matchesAdvertisement(
        name: 'Metrica-ABCDE',
        serviceUuidStrings: [MetricaBleProtocol.serviceUuid],
      ),
      isFalse,
    );
    expect(
      MetricaBleProtocol.bestAdvertisedName(
        advName: 'Metrica-00ff',
        platformName: 'something',
      ),
      'Metrica-00ff',
    );
  });

  test('INFO and STATUS JSON parse the firmware fields', () {
    final info = MetricaBleProtocol.parseInfo(
      utf8.encode('{"fw":"0.6.8-ble","paired":false,"pairing":true}'),
    );
    expect(info.firmware, '0.6.8-ble');
    expect(info.paired, isFalse);
    expect(info.pairingMode, isTrue);

    final status = MetricaBleProtocol.parseStatus(
      utf8.encode('{"ok":false,"code":"pin_invalid","msg":"PIN incorrecto"}'),
    );
    expect(status.ok, isFalse);
    expect(status.code, 'pin_invalid');
    expect(status.message, 'PIN incorrecto');
    expect(
      MetricaBleProtocol.statusLogLine(status),
      'ok=false code=pin_invalid',
    );
    expect(MetricaBleProtocol.statusLogLine(status), isNot(contains('PIN')));
  });

  test('PAIR and WIFI JSON use the firmware keys', () {
    final pair =
        jsonDecode(
              utf8.decode(
                MetricaBleProtocol.pairPayload(
                  deviceId: 'dev-1',
                  secret: 'super-secret-value',
                  ingestUrl: 'https://example.test/ingest',
                ),
              ),
            )
            as Map<String, Object?>;
    expect(pair.keys.toList(), ['device_id', 'secret', 'ingest_url']);
    expect(pair['secret'], 'super-secret-value');

    final wifi =
        jsonDecode(
              utf8.decode(
                MetricaBleProtocol.wifiPayload(
                  ssid: 'paddock',
                  pass: 'clave-wifi',
                ),
              ),
            )
            as Map<String, Object?>;
    expect(wifi, {'ssid': 'paddock', 'pass': 'clave-wifi'});
  });

  test('writes that fit stay raw and larger ones round-trip', () {
    final small = utf8.encode('{"ok":true}');
    final one = MetricaBleProtocol.encodeWrite(small, maxChunk: 20);
    expect(one, [small]);

    final secret = 'super-secret-value';
    final payload = MetricaBleProtocol.pairPayload(
      deviceId: 'dev-1',
      secret: secret,
      ingestUrl: 'https://example.test/ingest',
    );
    final frames = MetricaBleProtocol.encodeWrite(payload, maxChunk: 20);
    expect(frames.length, greaterThan(1));
    for (final frame in frames) {
      expect(frame.length, lessThanOrEqualTo(20));
      expect(frame.first, MetricaBleProtocol.fragmentMagic);
    }
    final box = MetricaReassembler();
    List<int>? rebuilt;
    for (final frame in frames) {
      rebuilt = box.add(frame);
    }
    expect(rebuilt, payload);
    expect(utf8.decode(rebuilt!), contains(secret));
  });

  test('STATUS codes classify PIN, lock, and timeout', () {
    expect(
      () => MetricaBleProtocol.requireAccepted(
        const MetricaStatus(ok: true, code: 'paired', message: 'ok'),
      ),
      returnsNormally,
    );
    expect(
      () => MetricaBleProtocol.requireAccepted(
        const MetricaStatus(ok: false, code: 'wrong_pin', message: 'no'),
      ),
      throwsA(
        isA<MetricaBleException>().having(
          (error) => error.failure,
          'failure',
          MetricaBleFailure.wrongPin,
        ),
      ),
    );
    expect(
      () => MetricaBleProtocol.requireAccepted(
        const MetricaStatus(ok: false, code: 'pin_locked', message: 'out'),
      ),
      throwsA(
        isA<MetricaBleException>().having(
          (error) => error.failure,
          'failure',
          MetricaBleFailure.pinLocked,
        ),
      ),
    );
    expect(
      () => MetricaBleProtocol.requireAccepted(
        const MetricaStatus(ok: false, code: 'timeout', message: ''),
      ),
      throwsA(
        isA<MetricaBleException>().having(
          (error) => error.failure,
          'failure',
          MetricaBleFailure.timeout,
        ),
      ),
    );
  });

  test('redact strips the secret and toString does not keep it', () {
    const secret = 'super-secret-value';
    final status = const MetricaStatus(
      ok: true,
      code: 'paired',
      message: 'guardado super-secret-value',
    ).redact(const [secret]);
    expect(status.message, 'guardado ***');
    expect(status.message, isNot(contains(secret)));

    const success = MetricaPairSuccess(
      deviceId: 'dev-1',
      status: MetricaStatus(ok: true, code: 'paired', message: 'ok'),
    );
    expect(success.toString(), isNot(contains(secret)));
    expect(
      const MetricaBleException(
        MetricaBleFailure.protocol,
        detail: secret,
      ).toString(),
      isNot(contains(secret)),
    );

    expect(
      MetricaBleException.fromPairingService(
        StateError('Not signed in'),
      ).failure,
      MetricaBleFailure.noSession,
    );
    expect(
      MetricaBleException.fromPairingService(
        StateError('claim failed'),
      ).toString(),
      isNot(contains(secret)),
    );
  });

  test('Android 12 asks for scan and connect, older asks for location', () {
    expect(
      chooseBlePermissions(isAndroid: true, androidSdkInt: 34).plan,
      MetricaBlePermissionPlan.android12ScanConnect,
    );
    expect(
      chooseBlePermissions(isAndroid: true, androidSdkInt: 34).usesFineLocation,
      isFalse,
    );
    expect(
      chooseBlePermissions(isAndroid: true, androidSdkInt: 30).plan,
      MetricaBlePermissionPlan.legacyLocation,
    );
    expect(
      chooseBlePermissions(isAndroid: true, androidSdkInt: 30).usesFineLocation,
      isTrue,
    );
    expect(
      chooseBlePermissions(isAndroid: false, androidSdkInt: null).plan,
      MetricaBlePermissionPlan.appleBluetooth,
    );
  });
}
