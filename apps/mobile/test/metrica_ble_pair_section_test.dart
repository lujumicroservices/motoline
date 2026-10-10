import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motoline/core/services/logger_pairing_service.dart';
import 'package:motoline/core/services/metrica_ble_pairing.dart';
import 'package:motoline/core/services/metrica_ble_protocol.dart';
import 'package:motoline/features/settings/metrica_ble_pair_section.dart';
import 'package:motoline/l10n/app_localizations.dart';

void main() {
  testWidgets('button is on the logger screen section', (tester) async {
    await tester.pumpWidget(_app(const MetricaBlePairSection()));
    expect(find.byKey(const Key('metrica-ble-pair')), findsOneWidget);
    expect(find.text('Emparejar por Bluetooth'), findsOneWidget);
  });

  testWidgets('no session is reported before scanning', (tester) async {
    final transport = _FakeTransport();
    await tester.pumpWidget(
      _app(
        MetricaBlePairSection(
          transport: transport,
          hasSession: () async => false,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('metrica-ble-pair')));
    await tester.pumpAndSettle();
    expect(find.text('Inicia sesión para emparejar Métrica.'), findsOneWidget);
    expect(transport.scans, 0);
  });

  testWidgets('empty scan says the logger was not found', (tester) async {
    await tester.pumpWidget(
      _app(
        MetricaBlePairSection(
          transport: _FakeTransport(),
          hasSession: () async => true,
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('metrica-ble-pair')));
    await tester.pumpAndSettle();
    expect(find.textContaining('No se encontró el equipo'), findsOneWidget);
  });

  testWidgets('a successful pair never shows the secret', (tester) async {
    const secret = 'super-secret-value';
    final link = _ScriptedLink();
    final transport = _FakeTransport()
      ..hits = [
        const MetricaScanHit(remoteId: 'aa', name: 'Metrica-A1B2', rssi: -40),
      ]
      ..link = link;
    await tester.pumpWidget(
      _app(
        MetricaBlePairSection(
          transport: transport,
          pairing: MetricaBlePairing(api: _Api(secret)),
          hasSession: () async => true,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('metrica-ble-pair')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.text('Versión 0.6.8-ble. Aún no está emparejado.'),
      findsNothing,
    );
    await tester.tap(find.text('Metrica-A1B2'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.text('Versión 0.6.8-ble. Aún no está emparejado.'),
      findsOneWidget,
    );
    expect(find.text('PIN de Métrica'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('metrica-ble-pin')), '123456');
    await tester.tap(find.text('Continuar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Ahora no'), findsOneWidget);
    await tester.tap(find.text('Ahora no'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Métrica emparejada (dev-1).'), findsOneWidget);
    expect(find.textContaining(secret), findsNothing);
    expect(link.disconnected, isTrue);
  });
}

Widget _app(Widget home) {
  return MaterialApp(
    locale: const Locale('es'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: home)),
  );
}

class _Api implements LoggerPairingApi {
  _Api(this.secret);
  final String secret;

  @override
  Future<String> mintPairCode() async => 'ABCD1234';

  @override
  Future<LoggerPairResult> claimCode(
    String code, {
    String label = 'M5 Logger',
  }) async {
    return LoggerPairResult(
      deviceId: 'dev-1',
      deviceSecret: secret,
      ingestUrl: 'https://example.test/ingest',
    );
  }
}

class _FakeTransport implements MetricaBleTransport {
  List<MetricaScanHit> hits = const [];
  MetricaGattLink? link;
  int scans = 0;

  @override
  Future<void> ensureReady() async {}

  @override
  Future<List<MetricaScanHit>> scan({required Duration timeout}) async {
    scans++;
    return hits;
  }

  @override
  Future<MetricaGattLink> connect(MetricaScanHit device) async => link!;
}

class _ScriptedLink implements MetricaGattLink {
  bool disconnected = false;

  @override
  int get maxWriteLength => 185;

  @override
  Future<MetricaDeviceInfo> readInfo() async {
    return const MetricaDeviceInfo(
      firmware: '0.6.8-ble',
      paired: false,
      pairingMode: true,
    );
  }

  @override
  Future<MetricaStatus> writeAuth(List<int> pinBytes) async {
    return const MetricaStatus(ok: true, code: 'auth_ok', message: 'ok');
  }

  @override
  Future<MetricaStatus> writePair(List<int> payload) async {
    return const MetricaStatus(ok: true, code: 'paired', message: 'listo');
  }

  @override
  Future<MetricaStatus> writeWifi(List<int> payload) async {
    return const MetricaStatus(ok: true, code: 'wifi_saved', message: 'wifi');
  }

  @override
  Future<void> disconnect() async {
    disconnected = true;
  }
}
