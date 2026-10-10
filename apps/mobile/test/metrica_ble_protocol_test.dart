import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/core/services/metrica_ble_permissions.dart';
import 'package:motoline/core/services/metrica_ble_protocol.dart';

void main() {
  test('UUIDs match firmware 0.6.8-ble', () {
    const suffix = '5c3e-4b8e-9a51-4d4554524943';
    expect(MetricaBleProtocol.serviceUuid, '6f8a0001-$suffix');
    expect(MetricaBleProtocol.infoUuid, '6f8a0002-$suffix');
    expect(MetricaBleProtocol.authUuid, '6f8a0003-$suffix');
    expect(MetricaBleProtocol.pairUuid, '6f8a0004-$suffix');
    expect(MetricaBleProtocol.wifiUuid, '6f8a0005-$suffix');
    expect(MetricaBleProtocol.statusUuid, '6f8a0006-$suffix');
    expect(MetricaBleProtocol.fragmentMagic, 0x1E);
    expect(MetricaBleProtocol.requestedMtu, 247);
    expect(MetricaBleProtocol.maxWriteLength(247), 244);
    expect(MetricaBleProtocol.fragmentDataLength(247), 241);
    expect(MetricaBleProtocol.fragmentDataLength(23), 17);
  });

  test('advertisement accepts Metrica-XXXX name or the service UUID', () {
    expect(
      MetricaBleProtocol.matchesAdvertisement(
        name: 'Metrica-7638',
        serviceUuidStrings: [MetricaBleProtocol.serviceUuid.toUpperCase()],
      ),
      isTrue,
    );
    // Name alone (UUID arrives later / other packet).
    expect(
      MetricaBleProtocol.matchesAdvertisement(
        name: 'Metrica-7638',
        serviceUuidStrings: const ['0000fea6-0000-1000-8000-00805f9b34fb'],
      ),
      isTrue,
    );
    expect(
      MetricaBleProtocol.matchesAdvertisement(
        name: 'metrica-763a',
        serviceUuidStrings: const [],
      ),
      isTrue,
    );
    // UUID alone (name in scan response not merged yet).
    expect(
      MetricaBleProtocol.matchesAdvertisement(
        name: '',
        serviceUuidStrings: [MetricaBleProtocol.serviceUuid],
      ),
      isTrue,
    );
    expect(
      MetricaBleProtocol.matchesAdvertisement(
        name: 'GoPro-7638',
        serviceUuidStrings: const [],
      ),
      isFalse,
    );
    expect(
      MetricaBleProtocol.matchesAdvertisement(
        name: 'Metrica-763G',
        serviceUuidStrings: const [],
      ),
      isFalse,
    );
    expect(
      MetricaBleProtocol.bestAdvertisedName(
        advName: 'metrica-7638',
        platformName: 'something',
      ),
      'Metrica-7638',
    );
  });

  test('INFO and STATUS JSON parse the firmware fields', () {
    final info = MetricaBleProtocol.parseInfo(
      utf8.encode(
        '{"hw":"f42dc9d07638","fw":"0.6.8-ble","role":"rider",'
        '"paired":false,"device_id":"","wifi":true,"authed":false,"mtu":247}',
      ),
    );
    expect(info.hw, 'f42dc9d07638');
    expect(info.firmware, '0.6.8-ble');
    expect(info.role, 'rider');
    expect(info.paired, isFalse);
    expect(info.deviceId, isEmpty);
    expect(info.wifi, isTrue);
    expect(info.authed, isFalse);
    expect(info.mtu, 247);

    final status = MetricaBleProtocol.parseStatus(
      utf8.encode('{"ok":false,"code":"pin_invalid","err":"bad_pin","left":3}'),
    );
    expect(status.ok, isFalse);
    expect(status.err, 'bad_pin');
    expect(status.left, 3);
    expect(status.msg, isEmpty);
    expect(
      MetricaBleProtocol.statusLogLine(status),
      'ok=false err=bad_pin left=3',
    );

    final sneaky = MetricaBleProtocol.parseStatus(
      utf8.encode('{"ok":true,"msg":"super-secret-value"}'),
    );
    expect(MetricaBleProtocol.statusLogLine(sneaky), 'ok=true msg=unlisted');
    expect(
      MetricaBleProtocol.statusLogLine(sneaky),
      isNot(contains('super-secret')),
    );
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

  test('writes that fit stay raw and larger ones use 0x1E chunks of mtu-6', () {
    final small = utf8.encode('{"ok":true}');
    final one = MetricaBleProtocol.encodeWrite(small, maxChunk: 20);
    expect(one, [small]);

    const mtu = 247;
    final maxChunk = MetricaBleProtocol.maxWriteLength(mtu);
    final payload = List<int>.filled(245, 0x41);
    final wide = MetricaBleProtocol.encodeWrite(payload, maxChunk: maxChunk);
    expect(wide, hasLength(2));
    expect(wide[0].first, 0x1E);
    expect(wide[0][1], 0);
    expect(wide[0][2], 2);
    expect(wide[0].sublist(3), hasLength(241));
    expect(wide[0], hasLength(244));
    expect(wide[1][1], 1);
    expect(wide[1].sublist(3), hasLength(4));

    final secret = 'super-secret-value';
    final pair = MetricaBleProtocol.pairPayload(
      deviceId: 'dev-1',
      secret: secret,
      ingestUrl: 'https://example.test/ingest',
    );
    final frames = MetricaBleProtocol.encodeWrite(pair, maxChunk: 20);
    expect(frames.length, greaterThan(1));
    for (final frame in frames) {
      expect(frame.length, lessThanOrEqualTo(20));
      expect(frame.first, 0x1E);
      expect(frame.length - 3, lessThanOrEqualTo(17));
    }
    final box = MetricaReassembler();
    List<int>? rebuilt;
    for (final frame in frames) {
      rebuilt = box.add(frame);
    }
    expect(rebuilt, pair);
    expect(utf8.decode(rebuilt!), contains(secret));
  });

  test('index 0 restarts reassembly and an out-of-order index drops it', () {
    final box = MetricaReassembler();
    expect(box.add([0x1E, 1, 2, 1]), isNull);
    expect(box.add([0x1E, 0, 2, 9]), isNull);
    expect(box.add([0x1E, 0, 2, 7]), isNull);
    expect(box.add([0x1E, 1, 2, 8]), [7, 8]);
  });

  test('STATUS err and left classify PIN, lock, and protocol errors', () {
    expect(
      () => MetricaBleProtocol.requireMsg(
        const MetricaStatus(ok: true, msg: 'paired'),
        'paired',
      ),
      returnsNormally,
    );
    expect(
      () => MetricaBleProtocol.requireAccepted(
        MetricaBleProtocol.parseStatus(
          utf8.encode('{"ok":false,"err":"bad_pin","left":3}'),
        ),
      ),
      throwsA(
        isA<MetricaBleException>()
            .having(
              (error) => error.failure,
              'failure',
              MetricaBleFailure.wrongPin,
            )
            .having((error) => error.attemptsLeft, 'left', 3),
      ),
    );
    expect(
      () => MetricaBleProtocol.requireAccepted(
        MetricaBleProtocol.parseStatus(
          utf8.encode('{"ok":false,"err":"bad_pin","left":0}'),
        ),
      ),
      throwsA(
        isA<MetricaBleException>()
            .having(
              (error) => error.failure,
              'failure',
              MetricaBleFailure.pinLocked,
            )
            .having((error) => error.attemptsLeft, 'left', 0),
      ),
    );
    expect(
      () => MetricaBleProtocol.requireAccepted(
        MetricaBleProtocol.parseStatus(
          utf8.encode('{"ok":false,"code":"pin_invalid"}'),
        ),
      ),
      throwsA(
        isA<MetricaBleException>().having(
          (error) => error.failure,
          'failure',
          MetricaBleFailure.protocol,
        ),
      ),
    );
    for (final err in [
      'auth_required',
      'bad_json',
      'missing_fields',
      'bad_fields',
    ]) {
      expect(
        () => MetricaBleProtocol.requireAccepted(
          MetricaBleProtocol.parseStatus(
            utf8.encode('{"ok":false,"err":"$err"}'),
          ),
        ),
        throwsA(
          isA<MetricaBleException>()
              .having(
                (error) => error.failure,
                'failure',
                MetricaBleFailure.protocol,
              )
              .having((error) => error.detail, 'detail', err),
        ),
        reason: err,
      );
    }
  });

  test('redact strips the secret and toString does not keep it', () {
    const secret = 'super-secret-value';
    final status = const MetricaStatus(
      ok: true,
      msg: 'paired super-secret-value',
    ).redact(const [secret]);
    expect(status.msg, 'paired ***');
    expect(status.msg, isNot(contains(secret)));

    const success = MetricaPairSuccess(
      deviceId: 'dev-1',
      status: MetricaStatus(ok: true, msg: 'paired'),
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
