import 'logger_pairing_service.dart';
import 'metrica_ble_protocol.dart';

/// Mints credentials with the signed-in rider and writes them to a Métrica.
///
/// The returned [MetricaPairSuccess] has the device id only. `secret` stays
/// inside the GATT write.
class MetricaBlePairing {
  MetricaBlePairing({LoggerPairingApi? api})
    : _api = api ?? LoggerPairingService();

  final LoggerPairingApi _api;

  Future<MetricaPairSuccess> pair({
    required MetricaGattLink link,
    required String pin,
    required Future<bool> Function() hasSession,
    required void Function(MetricaStatus status) onStatus,
    void Function(MetricaPairPhase phase)? onPhase,
    String label = 'M5 Logger',
    Future<MetricaWifiCredentials?> Function()? requestWifi,
  }) async {
    MetricaBleProtocol.validatePin(pin);
    if (!await hasSession()) {
      throw const MetricaBleException(MetricaBleFailure.noSession);
    }

    final secrets = <String>[pin];
    onPhase?.call(MetricaPairPhase.auth);
    final auth = (await link.writeAuth(
      MetricaBleProtocol.authBytes(pin),
    )).redact(secrets);
    onStatus(auth);
    MetricaBleProtocol.requireMsg(auth, 'auth_ok');

    // WIFI before PAIR. After `paired` the logger closes the mode in ~3 s.
    if (requestWifi != null) {
      final creds = await requestWifi();
      if (creds != null) {
        await sendWifi(
          link: link,
          ssid: creds.ssid,
          password: creds.password,
          onStatus: onStatus,
          onPhase: onPhase,
        );
      }
    }

    if (!await hasSession()) {
      throw const MetricaBleException(MetricaBleFailure.noSession);
    }

    onPhase?.call(MetricaPairPhase.mint);
    final String code;
    final LoggerPairResult claimed;
    try {
      code = await _api.mintPairCode();
      claimed = await _api.claimCode(code, label: label);
    } on StateError catch (error) {
      throw MetricaBleException.fromPairingService(error);
    }

    secrets.add(claimed.deviceSecret);
    onPhase?.call(MetricaPairPhase.write);
    final paired = (await link.writePair(
      MetricaBleProtocol.pairPayload(
        deviceId: claimed.deviceId,
        secret: claimed.deviceSecret,
        ingestUrl: claimed.ingestUrl,
      ),
    )).redact(secrets);
    onStatus(paired);
    MetricaBleProtocol.requireMsg(paired, 'paired');
    return MetricaPairSuccess(deviceId: claimed.deviceId, status: paired);
  }

  Future<MetricaStatus> sendWifi({
    required MetricaGattLink link,
    required String ssid,
    required String password,
    required void Function(MetricaStatus status) onStatus,
    void Function(MetricaPairPhase phase)? onPhase,
  }) async {
    final name = ssid.trim();
    if (name.isEmpty) {
      throw const MetricaBleException(MetricaBleFailure.protocol);
    }
    final secrets = <String>[password];
    onPhase?.call(MetricaPairPhase.wifi);
    final status = (await link.writeWifi(
      MetricaBleProtocol.wifiPayload(ssid: name, pass: password),
    )).redact(secrets);
    onStatus(status);
    if (!status.ok || status.msg != 'wifi_saved') {
      final err = status.err.trim();
      throw MetricaBleException(
        MetricaBleFailure.wifiRejected,
        detail: MetricaBleProtocol.errorCodes.contains(err) ? err : null,
      );
    }
    return status;
  }
}
