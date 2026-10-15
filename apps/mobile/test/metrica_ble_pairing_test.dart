import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/core/services/logger_pairing_service.dart';
import 'package:motoline/core/services/metrica_ble_pairing.dart';
import 'package:motoline/core/services/metrica_ble_protocol.dart';

const _secret = 'super-secret-value';

void main() {
  test('no session does not write the PIN or mint', () async {
    final link = _FakeLink();
    final api = _FakeApi();
    final pairing = MetricaBlePairing(api: api);

    await expectLater(
      pairing.pair(
        link: link,
        pin: '123456',
        hasSession: () async => false,
        onStatus: (_) {},
      ),
      throwsA(
        isA<MetricaBleException>().having(
          (error) => error.failure,
          'failure',
          MetricaBleFailure.noSession,
        ),
      ),
    );
    expect(link.authBytes, isNull);
    expect(api.creates, 0);
  });

  test('wrong PIN does not mint', () async {
    final link = _FakeLink()
      ..authStatus = const MetricaStatus(ok: false, err: 'bad_pin', left: 4);
    final api = _FakeApi();
    await expectLater(
      MetricaBlePairing(api: api).pair(
        link: link,
        pin: '123456',
        hasSession: () async => true,
        onStatus: (_) {},
      ),
      throwsA(
        isA<MetricaBleException>().having(
          (error) => error.failure,
          'failure',
          MetricaBleFailure.wrongPin,
        ),
      ),
    );
    expect(api.creates, 0);
    expect(link.pairPayload, isNull);
  });

  test('timeout does not mint', () async {
    final link = _FakeLink()
      ..authError = const MetricaBleException(MetricaBleFailure.timeout);
    final api = _FakeApi();
    await expectLater(
      MetricaBlePairing(api: api).pair(
        link: link,
        pin: '123456',
        hasSession: () async => true,
        onStatus: (_) {},
      ),
      throwsA(
        isA<MetricaBleException>().having(
          (error) => error.failure,
          'failure',
          MetricaBleFailure.timeout,
        ),
      ),
    );
    expect(api.creates, 0);
  });

  test('success writes PAIR JSON and hides the secret', () async {
    final link = _FakeLink();
    final api = _FakeApi();
    final seen = <String>[];
    final success = await MetricaBlePairing(api: api).pair(
      link: link,
      pin: '123456',
      label: 'Metrica-A1B2',
      hasSession: () async => true,
      onStatus: (status) => seen.add('${status.msg}${status.err}'),
    );

    expect(api.creates, 1);
    expect(api.labels, ['Metrica-A1B2']);
    expect(utf8.decode(link.authBytes!), '123456');
    final pair =
        jsonDecode(utf8.decode(link.pairPayload!)) as Map<String, Object?>;
    expect(pair['device_id'], 'dev-1');
    expect(pair['secret'], _secret);
    expect(pair['ingest_url'], 'https://example.test/ingest');
    expect(success.deviceId, 'dev-1');
    expect(success.toString(), isNot(contains(_secret)));
    expect(seen.join(' '), isNot(contains(_secret)));
    expect(link.pairStatus.msg, 'paired');
    expect(link.ops, ['pair']);
  });

  test(
    'a STATUS echo of the secret is redacted before the UI sees it',
    () async {
      final link = _FakeLink()
        ..pairStatus = const MetricaStatus(
          ok: true,
          msg: 'paired super-secret-value',
        );
      final seen = <String>[];
      await expectLater(
        MetricaBlePairing(api: _FakeApi()).pair(
          link: link,
          pin: '123456',
          hasSession: () async => true,
          onStatus: (status) => seen.add(status.msg),
        ),
        throwsA(
          isA<MetricaBleException>().having(
            (error) => error.failure,
            'failure',
            MetricaBleFailure.protocol,
          ),
        ),
      );
      expect(seen.join(' '), isNot(contains(_secret)));
      expect(seen.join(' '), contains('***'));
    },
  );

  test('Wi-Fi is written and acknowledged before PAIR', () async {
    final link = _FakeLink();
    final api = _FakeApi();
    await MetricaBlePairing(api: api).pair(
      link: link,
      pin: '123456',
      hasSession: () async => true,
      onStatus: (_) {},
      requestWifi: () async =>
          const MetricaWifiCredentials(ssid: 'paddock', password: 'clave-wifi'),
    );
    expect(link.ops, ['wifi', 'pair']);
    expect(api.creates, 1);
    final wifi =
        jsonDecode(utf8.decode(link.wifiPayload!)) as Map<String, Object?>;
    expect(wifi['ssid'], 'paddock');
    expect(wifi['pass'], 'clave-wifi');
  });

  test('a failed Wi-Fi write does not mint or PAIR', () async {
    final link = _FakeLink()
      ..wifiStatus = const MetricaStatus(ok: false, err: 'bad_fields');
    final api = _FakeApi();
    await expectLater(
      MetricaBlePairing(api: api).pair(
        link: link,
        pin: '123456',
        hasSession: () async => true,
        onStatus: (_) {},
        requestWifi: () async => const MetricaWifiCredentials(
          ssid: 'paddock',
          password: 'clave-wifi',
        ),
      ),
      throwsA(
        isA<MetricaBleException>().having(
          (error) => error.failure,
          'failure',
          MetricaBleFailure.wifiRejected,
        ),
      ),
    );
    expect(link.ops, ['wifi']);
    expect(api.creates, 0);
    expect(link.pairPayload, isNull);
  });

  test('Wi-Fi password is redacted from STATUS shown to the UI', () async {
    final link = _FakeLink()
      ..wifiStatus = const MetricaStatus(
        ok: true,
        msg: 'wifi_saved clave-wifi',
      );
    final seen = <String>[];
    await expectLater(
      MetricaBlePairing().sendWifi(
        link: link,
        ssid: 'paddock',
        password: 'clave-wifi',
        onStatus: (status) => seen.add(status.msg),
      ),
      throwsA(
        isA<MetricaBleException>().having(
          (error) => error.failure,
          'failure',
          MetricaBleFailure.wifiRejected,
        ),
      ),
    );
    final wifi =
        jsonDecode(utf8.decode(link.wifiPayload!)) as Map<String, Object?>;
    expect(wifi['pass'], 'clave-wifi');
    expect(seen.single, isNot(contains('clave-wifi')));
    expect(seen.single, contains('***'));
  });
}

class _FakeApi implements LoggerPairingApi {
  int creates = 0;
  final labels = <String>[];

  @override
  Future<String> mintPairCode() async => 'ABCD1234';

  @override
  Future<LoggerPairResult> claimCode(
    String code, {
    String label = 'M5 Logger',
  }) async {
    throw UnsupportedError('BLE uses createDevice');
  }

  @override
  Future<LoggerPairResult> createDevice({String label = 'M5 Logger'}) async {
    creates++;
    labels.add(label);
    return const LoggerPairResult(
      deviceId: 'dev-1',
      deviceSecret: _secret,
      ingestUrl: 'https://example.test/ingest',
    );
  }
}

class _FakeLink implements MetricaGattLink {
  MetricaStatus authStatus = const MetricaStatus(ok: true, msg: 'auth_ok');
  MetricaStatus pairStatus = const MetricaStatus(ok: true, msg: 'paired');
  MetricaStatus wifiStatus = const MetricaStatus(ok: true, msg: 'wifi_saved');
  MetricaBleException? authError;
  List<int>? authBytes;
  List<int>? pairPayload;
  List<int>? wifiPayload;
  final ops = <String>[];

  @override
  int get maxWriteLength => 244;

  @override
  Future<MetricaDeviceInfo> readInfo() async {
    return const MetricaDeviceInfo(
      firmware: '0.6.8-ble',
      paired: false,
      deviceId: '',
      wifi: true,
      authed: false,
      mtu: 247,
    );
  }

  @override
  Future<MetricaStatus> writeAuth(List<int> pinBytes) async {
    authBytes = pinBytes;
    final error = authError;
    if (error != null) throw error;
    return authStatus;
  }

  @override
  Future<MetricaStatus> writePair(List<int> payload) async {
    ops.add('pair');
    pairPayload = payload;
    return pairStatus;
  }

  @override
  Future<MetricaStatus> writeWifi(List<int> payload) async {
    ops.add('wifi');
    wifiPayload = payload;
    return wifiStatus;
  }

  @override
  Future<void> disconnect() async {}
}
