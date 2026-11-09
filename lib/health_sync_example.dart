import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ovok_flutter/ovok_flutter.dart';

/// Demonstrates consent-based Apple Health and Health Connect sync.
class HealthSyncExample extends StatefulWidget {
  /// Creates the health sync example for the signed-in patient.
  const HealthSyncExample({
    required this.client,
    required this.baseUrl,
    required this.tenantCode,
    required this.patientReference,
    super.key,
  });

  /// Ovok client used to save synced observations.
  final Ovok client;

  /// API host used by the client.
  final String baseUrl;

  /// Tenant used by the client.
  final String tenantCode;

  /// Patient reference whose records are synced.
  final String patientReference;

  @override
  State<HealthSyncExample> createState() => _HealthSyncExampleState();
}

class _HealthSyncExampleState extends State<HealthSyncExample>
    with AutomaticKeepAliveClientMixin<HealthSyncExample> {
  static const _syncPreferencePrefix = 'ovok_flutter_example_health_sync';

  final _storage = const FlutterSecureStorage();
  late final HealthImportController<HealthSyncSourceType> _healthImport =
      HealthImportController(
    types: const [
      HealthSyncSourceType.steps,
      HealthSyncSourceType.heartRate,
    ],
    adapter: HealthPluginImportAdapter(),
  );
  late final HealthSyncConfiguration<HealthSyncSourceType> _configuration =
      HealthSyncConfiguration(
    dataToSync: {
      'stepCount': HealthSyncTypeConfiguration(
        typeIdentifiers: const [
          HealthSyncTypeIdentifier(
            typeIdentifier: HealthSyncSourceType.steps,
          ),
        ],
      ),
      'heartRate': HealthSyncTypeConfiguration(
        typeIdentifiers: const [
          HealthSyncTypeIdentifier(
            typeIdentifier: HealthSyncSourceType.heartRate,
          ),
        ],
      ),
    },
    onError: _showSyncError,
    onProgress: _updateProgress,
  );

  Map<String, SyncProgress>? _progress;
  String? _accessError;
  String? _syncError;
  var _busy = false;

  @override
  bool get wantKeepAlive => true;

  String get _preferenceKey =>
      '$_syncPreferencePrefix:${widget.baseUrl}:${widget.tenantCode}:${widget.patientReference}';

  @override
  void initState() {
    super.initState();
    _healthImport.addListener(_refresh);
    if (_supportsHealthSync) unawaited(_restoreSyncPreference());
  }

  @override
  void dispose() {
    _healthImport
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!_supportsHealthSync) return _unsupportedMessage(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Health data sync', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
          'Read step counts and heart rate from Apple Health or Health Connect. '
          'The first sync can read up to 30 days of data. The SDK saves it for '
          'the signed-in patient in this Ovok tenant. Sync runs in the '
          'foreground and retries after connectivity returns. Use a sandbox tenant.',
        ),
        const SizedBox(height: 24),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: _busy
              ? const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync),
          title: const Text('Automatically sync steps and heart rate'),
          subtitle: const Text(
            'Starts after permission is granted. Revoke access in device settings.',
          ),
          value: _healthImport.enabled,
          onChanged: _busy ? null : _onSyncChanged,
        ),
        if (_accessError != null) ...[
          const SizedBox(height: 8),
          _ErrorMessage(_accessError!),
        ],
        if (_healthImport.enabled) ...[
          const SizedBox(height: 24),
          _syncTask(),
          Text('Sync progress', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SyncProgressList(progress: _progress),
          if (_syncError != null) ...[
            const SizedBox(height: 12),
            _ErrorMessage(_syncError!),
          ],
        ],
      ],
    );
  }

  Widget _unsupportedMessage(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Health sync is available on iOS and Android devices.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );

  Widget _syncTask() => switch (defaultTargetPlatform) {
        TargetPlatform.iOS => AppleHealthSync(
            client: widget.client,
            configuration: _configuration,
          ),
        TargetPlatform.android => AndroidHealthSync(
            client: widget.client,
            configuration: _configuration,
          ),
        _ => const SizedBox.shrink(),
      };

  Future<void> _restoreSyncPreference() async {
    try {
      if (await _storage.read(key: _preferenceKey) == 'true' && mounted) {
        await _enableSync();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _accessError = 'Could not restore the sync setting.');
      }
    }
  }

  Future<void> _onSyncChanged(bool enabled) async {
    if (enabled) {
      await _enableSync();
      return;
    }
    await _disableSync();
  }

  Future<void> _enableSync() async {
    setState(() {
      _busy = true;
      _accessError = null;
    });
    try {
      try {
        await _healthImport.setEnabled(true);
      } catch (_) {
        if (mounted) {
          setState(() {
            _accessError =
                'Could not request health access. Check device permissions and try again.';
          });
        }
        return;
      }
      if (!_healthImport.enabled) {
        if (mounted) {
          setState(() {
            _accessError =
                'Allow step count and heart rate access in device settings, then try again.';
          });
        }
        return;
      }

      try {
        await _storage.write(key: _preferenceKey, value: 'true');
      } catch (_) {
        if (mounted) {
          setState(() {
            _accessError =
                'Sync is on for this session, but the setting could not be saved.';
          });
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disableSync() async {
    setState(() {
      _busy = true;
      _accessError = null;
    });
    try {
      await _healthImport.setEnabled(false);
      try {
        await _storage.delete(key: _preferenceKey);
      } catch (_) {
        if (mounted) {
          setState(() {
            _accessError =
                'Sync stopped, but the setting could not be cleared.';
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _accessError = 'Could not save the sync setting.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _showSyncError(Object? _) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _syncError =
            'Health sync failed. Check access and connectivity, then try again.';
      });
    });
  }

  void _updateProgress(Map<String, SyncProgress> progress) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _progress = progress;
        _syncError = null;
      });
    });
  }

  bool get _supportsHealthSync =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
}
