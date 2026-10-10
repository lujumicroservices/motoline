import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/metrica_ble_client.dart';
import '../../core/services/metrica_ble_pairing.dart';
import '../../core/services/metrica_ble_protocol.dart';
import '../../core/supabase/supabase_bootstrap.dart';
import '../../l10n/l10n_ext.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_snack.dart';

/// Bluetooth pairing for a Métrica logger.
///
/// Shows device id and STATUS text. Never renders `secret` or a Wi-Fi password.
class MetricaBlePairSection extends StatefulWidget {
  const MetricaBlePairSection({
    super.key,
    this.transport,
    this.pairing,
    this.hasSession,
  });

  final MetricaBleTransport? transport;
  final MetricaBlePairing? pairing;
  final Future<bool> Function()? hasSession;

  @override
  State<MetricaBlePairSection> createState() => _MetricaBlePairSectionState();
}

enum _Phase { idle, scanning, picking, working, done, error }

class _MetricaBlePairSectionState extends State<MetricaBlePairSection> {
  MetricaBleTransport? _ownedTransport;
  MetricaBlePairing? _ownedPairing;
  MetricaGattLink? _link;

  _Phase _phase = _Phase.idle;
  bool _busy = false;
  String? _status;
  String? _error;
  String? _result;
  MetricaDeviceInfo? _info;
  List<MetricaScanHit> _hits = const [];
  final List<String> _notes = [];

  MetricaBleTransport get _transport =>
      widget.transport ?? (_ownedTransport ??= MetricaBleClient());

  MetricaBlePairing get _pairing =>
      widget.pairing ?? (_ownedPairing ??= MetricaBlePairing());

  Future<bool> _hasSession() {
    final injected = widget.hasSession;
    if (injected != null) return injected();
    return _defaultHasSession();
  }

  Future<bool> _defaultHasSession() async {
    if (!SupabaseBootstrap.isReady) return false;
    final session = await SupabaseBootstrap.ensureSession();
    return session != null;
  }

  @override
  void dispose() {
    final link = _link;
    _link = null;
    if (link != null) unawaited(link.disconnect());
    super.dispose();
  }

  Future<void> _start() async {
    if (_busy) return;
    await _dropLink();
    if (!mounted) return;
    setState(() {
      _busy = true;
      _phase = _Phase.scanning;
      _error = null;
      _result = null;
      _info = null;
      _hits = const [];
      _notes.clear();
      _status = context.l10n.metricaBleScanning;
    });
    try {
      final signedIn = await _hasSession();
      if (!mounted) return;
      if (!signedIn) {
        _fail(context.l10n.metricaBleNoSession);
        return;
      }
      await _transport.ensureReady();
      if (!mounted) return;
      final hits = await _transport.scan(
        timeout: MetricaBleProtocol.scanTimeout,
      );
      if (!mounted) return;
      if (hits.isEmpty) {
        _fail(context.l10n.metricaBleNotFound);
        return;
      }
      setState(() {
        _hits = hits;
        _phase = _Phase.picking;
        _busy = false;
        _status = null;
      });
    } on MetricaBleException catch (error) {
      if (!mounted) return;
      _fail(_messageFor(error));
    } catch (_) {
      if (!mounted) return;
      _fail(context.l10n.metricaBleFailed);
    }
  }

  Future<void> _connect(MetricaScanHit hit) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _phase = _Phase.working;
      _error = null;
      _status = context.l10n.metricaBleConnecting(hit.name);
    });
    try {
      final link = await _transport.connect(hit);
      _link = link;
      if (!mounted) {
        await link.disconnect();
        return;
      }
      setState(() => _status = context.l10n.metricaBleReading);
      final info = await link.readInfo();
      if (!mounted) return;
      setState(() => _info = info);
      await _runPair(link, hit.name);
    } on MetricaBleException catch (error) {
      await _dropLink();
      if (!mounted) return;
      _fail(_messageFor(error));
    } catch (_) {
      await _dropLink();
      if (!mounted) return;
      _fail(context.l10n.metricaBleFailed);
    }
  }

  Future<void> _runPair(MetricaGattLink link, String label) async {
    while (mounted) {
      final pin = await _askPin();
      if (!mounted) return;
      if (pin == null) {
        await _dropLink();
        if (!mounted) return;
        setState(() {
          _busy = false;
          _phase = _Phase.idle;
          _status = null;
        });
        return;
      }
      setState(() => _status = context.l10n.metricaBleCheckingPin);
      try {
        final success = await _pairing.pair(
          link: link,
          pin: pin,
          label: label,
          hasSession: _hasSession,
          onPhase: _onPhase,
          onStatus: _onStatus,
          requestWifi: _requestWifi,
        );
        if (!mounted) return;
        final result = context.l10n.metricaBleSuccess(success.deviceId);
        setState(() {
          _result = result;
          _status = result;
          _error = null;
        });
        showAppSnack(context, result, tone: AppToastTone.success);
        await _dropLink();
        if (!mounted) return;
        setState(() {
          _busy = false;
          _phase = _Phase.done;
        });
        return;
      } on MetricaBleException catch (error) {
        if (!mounted) return;
        if (error.failure == MetricaBleFailure.wrongPin ||
            error.failure == MetricaBleFailure.pinFormat) {
          final message = _messageFor(error);
          setState(() => _error = message);
          showAppSnackError(context, message);
          continue;
        }
        await _dropLink();
        if (!mounted) return;
        _fail(_messageFor(error));
        return;
      } catch (_) {
        await _dropLink();
        if (!mounted) return;
        _fail(context.l10n.metricaBleFailed);
        return;
      }
    }
  }

  void _onPhase(MetricaPairPhase phase) {
    if (!mounted) return;
    final l10n = context.l10n;
    final text = switch (phase) {
      MetricaPairPhase.auth => l10n.metricaBleCheckingPin,
      MetricaPairPhase.mint => l10n.metricaBleMinting,
      MetricaPairPhase.write => l10n.metricaBleWriting,
      MetricaPairPhase.wifi => l10n.metricaBleWifiSending,
    };
    setState(() => _status = text);
  }

  void _onStatus(MetricaStatus status) {
    if (!mounted) return;
    if (status.ok && status.msg == 'wifi_saved') {
      final saved = context.l10n.metricaBleWifiSaved;
      setState(() => _notes.add(saved));
      showAppSnack(context, saved, tone: AppToastTone.success);
      return;
    }
    if (!status.ok && status.err == 'bad_pin') {
      final left = status.left;
      final line = left != null && left > 0
          ? context.l10n.metricaBleWrongPinLeft(left)
          : context.l10n.metricaBlePinLocked;
      setState(() => _notes.add(line));
    }
  }

  Future<MetricaWifiCredentials?> _requestWifi() async {
    final creds = await _askWifi();
    if (creds == null) return null;
    return MetricaWifiCredentials(ssid: creds.ssid, password: creds.password);
  }

  Future<void> _dropLink() async {
    final link = _link;
    _link = null;
    if (link != null) await link.disconnect();
  }

  void _fail(String message) {
    setState(() {
      _busy = false;
      _phase = _Phase.error;
      _error = message;
      _status = null;
    });
    if (message.isEmpty) return;
    showAppSnackError(context, message);
  }

  String _messageFor(MetricaBleException error) {
    final l10n = context.l10n;
    switch (error.failure) {
      case MetricaBleFailure.notFound:
        return l10n.metricaBleNotFound;
      case MetricaBleFailure.wrongPin:
        final left = error.attemptsLeft;
        if (left != null && left > 0) {
          return l10n.metricaBleWrongPinLeft(left);
        }
        return l10n.metricaBleWrongPin;
      case MetricaBleFailure.pinFormat:
        return l10n.metricaBlePinFormat;
      case MetricaBleFailure.pinLocked:
        return l10n.metricaBlePinLocked;
      case MetricaBleFailure.timeout:
        return l10n.metricaBleTimeout;
      case MetricaBleFailure.noSession:
        return l10n.metricaBleNoSession;
      case MetricaBleFailure.permissionDenied:
        return l10n.metricaBlePermissionDenied;
      case MetricaBleFailure.locationDenied:
        return l10n.metricaBleLocationDenied;
      case MetricaBleFailure.bluetoothOff:
        return l10n.metricaBleBluetoothOff;
      case MetricaBleFailure.unsupported:
        return l10n.metricaBleUnsupported;
      case MetricaBleFailure.connectFailed:
        return l10n.metricaBleConnectFailed;
      case MetricaBleFailure.wifiRejected:
        return l10n.metricaBleWifiFailed;
      case MetricaBleFailure.cancelled:
        return '';
      case MetricaBleFailure.protocol:
        final detail = error.detail?.trim() ?? '';
        if (detail.isEmpty) return l10n.metricaBleFailed;
        return l10n.metricaBleFailedDetail(detail);
    }
  }

  Future<String?> _askPin() {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _PinDialog(),
    );
  }

  Future<_WifiCreds?> _askWifi() {
    return showDialog<_WifiCreds>(
      context: context,
      builder: (context) => const _WifiDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          key: const Key('metrica-ble-pair'),
          onPressed: _busy ? null : _start,
          icon: const Icon(Icons.bluetooth),
          label: Text(l10n.metricaBlePair),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.metricaBlePairHelp,
          style: const TextStyle(
            color: AppTheme.steel,
            fontSize: 13,
            height: 1.35,
          ),
        ),
        if (_busy && _status != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(_status!)),
            ],
          ),
        ],
        if (_info != null) ...[
          const SizedBox(height: 12),
          Text(_infoLine(l10n, _info!)),
        ],
        if (_phase == _Phase.picking) ...[
          const SizedBox(height: 12),
          Text(l10n.metricaBleDevices),
          for (final hit in _hits)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(hit.name),
              subtitle: Text(l10n.metricaBleRssi(hit.rssi)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _busy ? null : () => _connect(hit),
            ),
        ],
        if (_notes.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final note in _notes)
            Text(
              note,
              style: const TextStyle(color: AppTheme.steel, fontSize: 13),
            ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: AppTheme.signal)),
        ],
        if (_result != null) ...[
          const SizedBox(height: 8),
          Text(_result!, style: const TextStyle(color: AppTheme.line)),
        ],
        if (_phase == _Phase.error) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy ? null : _start,
            child: Text(l10n.metricaBleRetry),
          ),
        ],
      ],
    );
  }

  String _infoLine(AppLocalizations l10n, MetricaDeviceInfo info) {
    final firmware = info.firmware.trim().isEmpty
        ? l10n.metricaBleFirmwareUnknown
        : l10n.metricaBleFirmware(info.firmware);
    final paired = switch (info.paired) {
      true => l10n.metricaBlePairedYes,
      false => l10n.metricaBlePairedNo,
      null => l10n.metricaBlePairedUnknown,
    };
    final id = info.deviceId.trim().isEmpty
        ? l10n.metricaBleDeviceIdEmpty
        : l10n.metricaBleDeviceId(info.deviceId);
    final wifi = switch (info.wifi) {
      true => l10n.metricaBleWifiPresent,
      false => l10n.metricaBleWifiAbsent,
      null => l10n.metricaBleWifiUnknown,
    };
    final authed = switch (info.authed) {
      true => l10n.metricaBleAuthedYes,
      false => l10n.metricaBleAuthedNo,
      null => l10n.metricaBleAuthedUnknown,
    };
    final mtu = info.mtu == null
        ? l10n.metricaBleMtuUnknown
        : l10n.metricaBleMtu(info.mtu!);
    return '$firmware $paired $id $wifi $authed $mtu';
  }
}

class _WifiCreds {
  const _WifiCreds({required this.ssid, required this.password});

  final String ssid;
  final String password;
}

class _PinDialog extends StatefulWidget {
  const _PinDialog();

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _controller = TextEditingController();
  var _error = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.metricaBlePinTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.metricaBlePinBody),
            const SizedBox(height: 12),
            TextField(
              key: const Key('metrica-ble-pin'),
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l10n.metricaBlePinLabel,
                counterText: '',
              ),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_error, style: const TextStyle(color: AppTheme.signal)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            final pin = _controller.text.trim();
            if (!MetricaBleProtocol.pinPattern.hasMatch(pin)) {
              setState(() => _error = l10n.metricaBlePinFormat);
              return;
            }
            Navigator.pop(context, pin);
          },
          child: Text(l10n.metricaBleContinue),
        ),
      ],
    );
  }
}

class _WifiDialog extends StatefulWidget {
  const _WifiDialog();

  @override
  State<_WifiDialog> createState() => _WifiDialogState();
}

class _WifiDialogState extends State<_WifiDialog> {
  final _ssid = TextEditingController();
  final _pass = TextEditingController();
  var _error = '';

  @override
  void dispose() {
    _ssid.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.metricaBleWifiTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.metricaBleWifiHelp),
            const SizedBox(height: 12),
            TextField(
              key: const Key('metrica-ble-ssid'),
              controller: _ssid,
              decoration: InputDecoration(labelText: l10n.metricaBleWifiSsid),
            ),
            TextField(
              key: const Key('metrica-ble-wifi-pass'),
              controller: _pass,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.metricaBleWifiPassword,
              ),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_error, style: const TextStyle(color: AppTheme.signal)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.metricaBleWifiSkip),
        ),
        FilledButton(
          onPressed: () {
            final name = _ssid.text.trim();
            if (name.isEmpty) {
              setState(() => _error = l10n.metricaBleWifiNeedSsid);
              return;
            }
            Navigator.pop(
              context,
              _WifiCreds(ssid: name, password: _pass.text),
            );
          },
          child: Text(l10n.metricaBleWifiSend),
        ),
      ],
    );
  }
}
