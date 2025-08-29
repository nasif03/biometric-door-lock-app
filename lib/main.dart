import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Biometric Door Lock',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final LocalAuthentication auth = LocalAuthentication();
  final String esp32Name = 'esp32lock.local'; 
  String _status = 'Ready to Scan';

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    bool canCheckBiometrics;
    try {
      canCheckBiometrics = await auth.canCheckBiometrics;
      if (!canCheckBiometrics) {
        setState(() {
          _status = 'Biometrics not available';
        });
      }
    } on PlatformException catch (e) {
      print(e);
      setState(() {
        _status = 'Error checking biometrics';
      });
    }
  }

  Future<void> _authenticate() async {
    bool authenticated = false;
    try {
      setState(() {
        _status = 'Authenticating...';
      });
      authenticated = await auth.authenticate(
        localizedReason: 'Scan your fingerprint to control the lock',
        options: const AuthenticationOptions(
          stickyAuth: true,
        ),
      );
      setState(() {
        _status = authenticated ? 'Authenticated' : 'Authentication failed';
        if (authenticated) {
          _sendSignalToESP32();
        }
      });
    } on PlatformException catch (e) {
      print(e);
      setState(() => _status = 'Error - ${e.message}' );
    }
  }

  Future<void> _sendSignalToESP32() async {
    setState(() => _status = 'Sending signal to ESP32...' );
    try {
      final url = Uri.http(esp32Name, '/control');
      final response = await http.post(url, body: {'signal': '1'}).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        setState(() => _status = 'Signal sent successfully!' );
      } else {
        setState(() => _status = 'Failed to send signal. Status code: ${response.statusCode}' );
      }
    } 
    on TimeoutException catch (_) {
      
    } 
    catch (e) {
      print(e);
      setState(() {
        _status = 'Error sending signal: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biometric Door Lock'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(
              Icons.fingerprint,
              size: 120.0,
              color: Colors.teal,
            ),
            const SizedBox(height: 30),
            Text(
              _status,
              style: const TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              icon: const Icon(Icons.lock_open),
              label: const Text('Authenticate & Unlock'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                textStyle: const TextStyle(fontSize: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: _authenticate,
            ),
          ],
        ),
      ),
    );
  }
}
