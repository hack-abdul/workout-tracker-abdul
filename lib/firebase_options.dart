import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web-only in this file.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA_f6T0VPcJyyZR3nVparLp2aqOY9IOMDA',
    appId: '1:229275247278:android:4c29e1bde251d77d46033f',
    messagingSenderId: '229275247278',
    projectId: 'workout-tracker-abdul',
    storageBucket: 'workout-tracker-abdul.firebasestorage.app',
  );
}
