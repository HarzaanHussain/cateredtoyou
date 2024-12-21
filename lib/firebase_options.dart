// lib/firebase_options.dart

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
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCRhKTJdSDL9uuaP9uvtnQYPtMA2HXDly8',
    appId: '1:328369352197:web:e6b756d4ee8bccd318f66c',
    messagingSenderId: '328369352197',
    projectId: 'cateredtoyou-7eeed',
    authDomain: 'cateredtoyou-7eeed.firebaseapp.com',
    storageBucket: 'cateredtoyou-7eeed.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCRhKTJdSDL9uuaP9uvtnQYPtMA2HXDly8',
    appId: '1:328369352197:android:b4117760c126493f18f66c',
    messagingSenderId: '328369352197',
    projectId: 'cateredtoyou-7eeed',
    storageBucket: 'cateredtoyou-7eeed.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCRhKTJdSDL9uuaP9uvtnQYPtMA2HXDly8',
    appId: '1:328369352197:ios:36fe039818df4c1b18f66c',
    messagingSenderId: '328369352197',
    projectId: 'cateredtoyou-7eeed',
    storageBucket: 'cateredtoyou-7eeed.appspot.com',
    iosClientId: 'your_ios_client_id.apps.googleusercontent.com',
  );
}