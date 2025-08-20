import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

// To use this app, you need to add the `local_auth` package to your pubspec.yaml file.
//
// dependencies:
//   flutter:
//     sdk: flutter
//   local_auth: ^2.1.7 # Use the latest version
//
// Also, you must configure platform-specific settings.
//
// For iOS:
// Add the following key to your Info.plist file:
// <key>NSFaceIDUsageDescription</key>
// <string>Why is my app authenticating using face id?</string>
//
// For Android:
// 1. Update your `android/app/src/main/AndroidManifest.xml` to include the USE_BIOMETRIC permission:
//    <uses-permission android:name="android.permission.USE_BIOMETRIC"/>
//
// 2. Change the `MainActivity.kt` (or `MainActivity.java`) to use `FlutterFragmentActivity`
//    instead of `FlutterActivity`.
//    Kotlin:
//    import io.flutter.embedding.android.FlutterFragmentActivity
//    class MainActivity: FlutterFragmentActivity() {
//    }
//    Java:
//    import io.flutter.embedding.android.FlutterFragmentActivity;
//    public class MainActivity extends FlutterFragmentActivity {
//    }


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fingerprint Auth Demo',
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
  // Instance of the local authentication plugin
  final LocalAuthentication auth = LocalAuthentication();
  
  String _authorized = 'Not Authorized';
  bool _isAuthenticating = false;

  /// This function is called when the fingerprint is successfully verified.
  void unlockDoor() {
    // This is a placeholder for your actual door-unlocking logic.
    print("Door Unlocked! Welcome home.");
  }

  /// Authenticates the user using biometrics.
  Future<void> _authenticate() async {
    bool authenticated = false;
    try {
      setState(() {
        _isAuthenticating = true;
        _authorized = 'Authenticating';
      });

      final bool canCheckBiometrics = await auth.canCheckBiometrics;
      final List<BiometricType> availableBiometrics = await auth.getAvailableBiometrics();

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
    if (!mounted) {
      return;
    }

    // If authentication is successful, update the state and call the unlock function.
    if (authenticated) {
      setState(() => _authorized = 'Authorized');
      unlockDoor();
    } else {
      setState(() => _authorized = 'Not Authorized');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fingerprint Door Unlock'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Display the current authorization status
            Text(
              'Status: $_authorized',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            // Icon to visually represent the fingerprint
            const Icon(Icons.fingerprint, size: 100, color: Colors.blue),
            const SizedBox(height: 30),
            // Button to trigger the authentication process
            ElevatedButton(
              onPressed: _isAuthenticating ? null : _authenticate,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                textStyle: const TextStyle(fontSize: 18),
              ),
              child: _isAuthenticating
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Authenticate to Unlock'),
            ),
          ],
        ),
      ),
    );
  }
}
