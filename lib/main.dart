import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fingerprint + ESP32 Unlock',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const FingerprintPage(),
    );
  }
}

class FingerprintPage extends StatefulWidget {
  const FingerprintPage({super.key});

  @override
  State<FingerprintPage> createState() => _FingerprintPageState();
}

class _FingerprintPageState extends State<FingerprintPage> {
  // Fingerprint
  final LocalAuthentication auth = LocalAuthentication();
  String _authorized = 'Not Authorized';
  bool _isAuthenticating = false;

  // Bluetooth
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selectedDevice;
  BluetoothConnection? _connection;
  bool _isConnected = false;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    _getPairedDevices();
  }

  Future<void> _getPairedDevices() async {
    try {
      final List<BluetoothDevice> bonded =
          await FlutterBluetoothSerial.instance.getBondedDevices();
      setState(() {
        _devices = bonded;
      });
    } catch (e) {
      print("Error fetching paired devices: $e");
    }
  }

  Future<void> _connect(BluetoothDevice device) async {
    setState(() {
      _isConnecting = true;
    });

    try {
      if (_connection != null) {
        await _connection!.close();
        _connection = null;
        _isConnected = false;
      }

      BluetoothConnection connection =
          await BluetoothConnection.toAddress(device.address);
      setState(() {
        _connection = connection;
        _isConnected = true;
        _selectedDevice = device;
      });

      connection.input?.listen((Uint8List data) {
        final text = String.fromCharCodes(data);
        print('ESP32: $text');
      }, onDone: () {
        setState(() {
          _isConnected = false;
          _connection = null;
        });
      });

      print("Connected to ${device.name}");
    } catch (e) {
      print("Cannot connect: $e");
      setState(() {
        _isConnected = false;
        _connection = null;
      });
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  Future<void> _disconnect() async {
    try {
      await _connection?.close();
      setState(() {
        _isConnected = false;
        _connection = null;
      });
    } catch (e) {
      print("Error disconnecting: $e");
    }
  }

  Future<void> _sendUnlockSignal() async {
    if (_connection != null && _isConnected) {
      _connection!.output.add(Uint8List.fromList("1\n".codeUnits));
      await _connection!.output.allSent;
      print("Unlock signal sent!");
    } else {
      print("Not connected to ESP32");
    }
  }

  Future<void> _authenticate() async {
    bool authenticated = false;
    try {
      setState(() {
        _isAuthenticating = true;
        _authorized = 'Authenticating';
      });

      final bool canCheckBiometrics = await auth.canCheckBiometrics;
      final List<BiometricType> availableBiometrics =
          await auth.getAvailableBiometrics();

      if (!canCheckBiometrics || availableBiometrics.isEmpty) {
        setState(() {
          _authorized = "Biometrics not available on this device.";
          _isAuthenticating = false;
        });
        return;
      }

      authenticated = await auth.authenticate(
        localizedReason: 'Scan your fingerprint to unlock the door',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      setState(() {
        _isAuthenticating = false;
      });
    } on PlatformException catch (e) {
      print(e);
      setState(() {
        _authorized = 'Error - ${e.message}';
        _isAuthenticating = false;
      });
      return;
    }

    if (!mounted) return;

    if (authenticated) {
      setState(() => _authorized = 'Authorized');
      if (_selectedDevice != null) {
        if (!_isConnected) {
          await _connect(_selectedDevice!);
        }
        if (_isConnected) {
          _sendUnlockSignal();
        }
      } else {
        print("No ESP32 selected");
      }
    } else {
      setState(() => _authorized = 'Not Authorized');
    }
  }

  Widget _buildDeviceList() {
    if (_devices.isEmpty) {
      return const Text("No paired devices found. Pair your ESP32 first.");
    }

    return Column(
      children: _devices.map((d) {
        return ListTile(
          title: Text(d.name ?? "Unknown"),
          subtitle: Text(d.address),
          trailing: _selectedDevice?.address == d.address
              ? (_isConnected
                  ? const Chip(label: Text("Connected"))
                  : const Chip(label: Text("Selected")))
              : TextButton(
                  onPressed: () => setState(() => _selectedDevice = d),
                  child: const Text("Select"),
                ),
          onTap: () => setState(() => _selectedDevice = d),
        );
      }).toList(),
    );
  }

  @override
  void dispose() {
    _disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Fingerprint Door Unlock")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Status: $_authorized',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ElevatedButton(
                onPressed: _isAuthenticating ? null : _authenticate,
                child: _isAuthenticating
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Authenticate to Unlock")),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                          "Paired Devices (${_devices.length})",
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 8),
                    _buildDeviceList(),
                    const SizedBox(height: 12),
                    OutlinedButton(
                        onPressed:
                            _isConnected ? _sendUnlockSignal : null,
                        child: const Text(
                            "Manually send unlock signal (if connected)")),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
