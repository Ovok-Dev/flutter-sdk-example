import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ovok_flutter/ovok_flutter.dart';
import 'package:ovok_flutter_example/health_sync_example.dart';

const _baseUrl = String.fromEnvironment(
  'OVOK_BASE_URL',
  defaultValue: 'https://api.sandbox.ovok.com',
);
const _tenantCode = String.fromEnvironment('OVOK_TENANT_CODE');
const _clientId = String.fromEnvironment('OVOK_CLIENT_ID');
const _googleInternalId = String.fromEnvironment('GOOGLE_INTERNAL_ID');
const _googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
const _googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
const _exampleSeedColor = Color(0xFF345E77);
const _examplePadding = 24.0;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final tenantCode = _tenantCode.trim();
  runApp(
    OvokFlutterExample(
      ovok: tenantCode.isEmpty
          ? null
          : Ovok(
              baseUrl: _baseUrl,
              tenantCode: tenantCode,
              clientId: _clientId.isEmpty ? null : _clientId,
              secureStore: _FlutterSecureStore(const FlutterSecureStorage()),
            ),
      googleInternalId: _googleInternalId.isEmpty ? null : _googleInternalId,
      googleClientId: _googleClientId.isEmpty ? null : _googleClientId,
      googleServerClientId:
          _googleServerClientId.isEmpty ? null : _googleServerClientId,
    ),
  );
}

/// Shows the Flutter widgets against the configured Ovok sandbox tenant.
class OvokFlutterExample extends StatelessWidget {
  /// Creates the example app.
  const OvokFlutterExample({
    this.ovok,
    this.googleInternalId,
    this.googleClientId,
    this.googleServerClientId,
    super.key,
  });

  /// The configured client, or null when the tenant code is missing.
  final Ovok? ovok;

  /// The Ovok identifier used for Google social login.
  final String? googleInternalId;

  /// The Google OAuth client ID.
  final String? googleClientId;

  /// The native Google server client ID.
  final String? googleServerClientId;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Ovok Flutter SDK',
        theme: ThemeData(colorSchemeSeed: _exampleSeedColor),
        home: ovok == null
            ? const _SetupScreen()
            : _AuthExampleHome(
                ovok: ovok!,
                googleInternalId: googleInternalId,
                googleClientId: googleClientId,
                googleServerClientId: googleServerClientId,
              ),
      );
}

class _SetupScreen extends StatelessWidget {
  const _SetupScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Ovok Flutter SDK')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(_examplePadding),
            child: Text(
              'Set OVOK_TENANT_CODE to connect this example to your sandbox tenant.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
}

class _AuthExampleHome extends StatefulWidget {
  const _AuthExampleHome({
    required this.ovok,
    required this.googleInternalId,
    required this.googleClientId,
    required this.googleServerClientId,
  });

  final Ovok ovok;
  final String? googleInternalId;
  final String? googleClientId;
  final String? googleServerClientId;

  @override
  State<_AuthExampleHome> createState() => _AuthExampleHomeState();
}

class _AuthExampleHomeState extends State<_AuthExampleHome> {
  Session? _session;
  BluetoothRuntime? _bluetoothRuntime;
  var _checkingSession = true;
  var _page = _AuthPage.signIn;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final session = await widget.ovok.auth.current();
    final bluetooth = session == null ? null : _createBluetoothRuntime();
    if (!mounted) {
      await bluetooth?.dispose();
      return;
    }
    setState(() {
      _session = session;
      _bluetoothRuntime = bluetooth;
      _checkingSession = false;
    });
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString())),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingSession) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_session != null) return _accountHome();
    return Scaffold(
      appBar: AppBar(title: const Text('Ovok Flutter SDK')),
      body: switch (_page) {
        _AuthPage.signIn => SignIn(
            key: const ValueKey('sign-in'),
            ovok: widget.ovok,
            profileType: ProfileType.patient,
            googleInternalId: widget.googleInternalId,
            googleClientId: widget.googleClientId,
            googleServerClientId: widget.googleServerClientId,
            onSuccess: _signedIn,
            onRegister: () => setState(() => _page = _AuthPage.register),
            onResetPassword: () =>
                setState(() => _page = _AuthPage.resetPassword),
            onError: _showError,
          ),
        _AuthPage.register => Register(
            key: const ValueKey('register'),
            ovok: widget.ovok,
            onSuccess: _signedIn,
            onSignIn: () => setState(() => _page = _AuthPage.signIn),
            onError: _showError,
          ),
        _AuthPage.resetPassword => ResetPassword(
            key: const ValueKey('reset-password'),
            ovok: widget.ovok,
            onBack: () => setState(() => _page = _AuthPage.signIn),
            onError: _showError,
          ),
      },
    );
  }

  Future<void> _signedIn(Session session) {
    final bluetooth = _createBluetoothRuntime();
    if (!mounted) {
      unawaited(bluetooth.dispose());
      return Future<void>.value();
    }
    setState(() {
      _session = session;
      _bluetoothRuntime = bluetooth;
    });
    return Future<void>.value();
  }

  void _signedOut() {
    final bluetooth = _bluetoothRuntime;
    setState(() {
      _session = null;
      _bluetoothRuntime = null;
    });
    if (bluetooth != null) unawaited(bluetooth.dispose());
  }

  BluetoothRuntime _createBluetoothRuntime() => createBluetoothRuntime(
        client: widget.ovok,
        devices: [
          builtInDevices([
            IntegratedDevices.aoj20a,
            IntegratedDevices.pc60wf,
            IntegratedDevices.taidocGlucose,
          ]),
        ],
      );

  @override
  void dispose() {
    final bluetooth = _bluetoothRuntime;
    if (bluetooth != null) unawaited(bluetooth.dispose());
    super.dispose();
  }

  Widget _accountHome() => DefaultTabController(
        length: 6,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Ovok Flutter SDK'),
            bottom: const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'Profile'),
                Tab(text: 'Sessions'),
                Tab(text: 'Account'),
                Tab(text: 'Realtime'),
                Tab(text: 'Devices'),
                Tab(text: 'Health sync'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              ProfileForm(
                key: const ValueKey('profile'),
                ovok: widget.ovok,
                fields: const [
                  ProfileFormField(
                      path: '/name/0/given/0', label: 'First name'),
                  ProfileFormField(path: '/name/0/family', label: 'Last name'),
                ],
                onError: _showError,
              ),
              SessionList(ovok: widget.ovok, onError: _showError),
              ListView(
                padding: const EdgeInsets.all(_examplePadding),
                children: [
                  LogoutButton(
                    ovok: widget.ovok,
                    onSuccess: _signedOut,
                    onError: _showError,
                  ),
                  const SizedBox(height: 16),
                  DeleteAccountButton(
                    ovok: widget.ovok,
                    onSuccess: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Account deletion was scheduled.'),
                      ),
                    ),
                    onError: _showError,
                  ),
                ],
              ),
              _RealtimeTab(
                ovok: widget.ovok,
                session: _session!,
              ),
              BluetoothProvider(
                runtime: _bluetoothRuntime!,
                child: const BluetoothDeviceManager(),
              ),
              HealthSyncExample(
                client: widget.ovok,
                baseUrl: _baseUrl,
                tenantCode: _tenantCode.trim(),
                patientReference: _session!.profile.reference,
              ),
            ],
          ),
        ),
      );
}

class _RealtimeTab extends StatefulWidget {
  const _RealtimeTab({required this.ovok, required this.session});

  final Ovok ovok;
  final Session session;

  @override
  State<_RealtimeTab> createState() => _RealtimeTabState();
}

class _RealtimeTabState extends State<_RealtimeTab> {
  RealtimeUnsubscribe? _unsubscribe;
  var _connecting = false;
  var _stopping = false;
  var _notificationCount = 0;
  String? _error;

  @override
  void dispose() {
    final unsubscribe = _unsubscribe;
    if (unsubscribe != null) {
      unawaited(unsubscribe().catchError((Object _) {}));
    }
    super.dispose();
  }

  Future<void> _startListening() async {
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      final unsubscribe = await widget.ovok.realtime.subscribe(
        'Observation?subject=${widget.session.profile.reference}',
        (_) {
          if (mounted) setState(() => _notificationCount++);
        },
      );
      if (!mounted) {
        await unsubscribe();
        return;
      }
      setState(() => _unsubscribe = unsubscribe);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not start realtime updates.');
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _stopListening() async {
    final unsubscribe = _unsubscribe;
    if (unsubscribe == null) return;
    setState(() {
      _stopping = true;
      _error = null;
    });
    try {
      await unsubscribe();
      if (mounted) setState(() => _unsubscribe = null);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not stop realtime updates.');
    } finally {
      if (mounted) setState(() => _stopping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listening = _unsubscribe != null;
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(_examplePadding),
      children: [
        Text(
          'Observation updates',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text('Listen for Observation updates for the signed-in patient.'),
        const SizedBox(height: 24),
        Text('Notifications received: $_notificationCount'),
        const SizedBox(height: 8),
        Text(
          _error ??
              (listening
                  ? 'Listening for patient Observation updates.'
                  : 'Not listening.'),
          style: _error == null ? null : TextStyle(color: colorScheme.error),
        ),
        const SizedBox(height: 16),
        if (listening)
          OutlinedButton(
            onPressed: _stopping ? null : _stopListening,
            child: Text(_stopping ? 'Stopping…' : 'Stop listening'),
          )
        else
          FilledButton(
            onPressed: _connecting ? null : _startListening,
            child: Text(_connecting ? 'Connecting…' : 'Start listening'),
          ),
      ],
    );
  }
}

enum _AuthPage { signIn, register, resetPassword }

class _FlutterSecureStore implements OvokSecureStore {
  const _FlutterSecureStore(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);
}
