import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
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

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBuG1Y0uvyNj1sLJFhK89dDh6lgyn5Adjg',
    appId: '1:229275247278:web:94b781024d6f0a7446033f',
    messagingSenderId: '229275247278',
    projectId: 'workout-tracker-abdul',
    authDomain: 'workout-tracker-abdul.firebaseapp.com',
    storageBucket: 'workout-tracker-abdul.firebasestorage.app',
    measurementId: 'G-8ZBKBVC853',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA_f6T0VPcJyyZR3nVparLp2aqOY9IOMDA',
    appId: '1:229275247278:android:4c29e1bde251d77d46033f',
    messagingSenderId: '229275247278',
    projectId: 'workout-tracker-abdul',
    storageBucket: 'workout-tracker-abdul.firebasestorage.app',
  );
}
