import 'package:firebase_core/firebase_core.dart' show FirebaseOptions; // Importing FirebaseOptions from firebase_core package
import 'package:flutter/foundation.dart' // Importing necessary Flutter foundation utilities
  show defaultTargetPlatform, kIsWeb, TargetPlatform; // Importing specific utilities for platform detection

class DefaultFirebaseOptions { // Defining a class to hold default Firebase options
  static FirebaseOptions get currentPlatform { // Getter to return Firebase options based on the current platform
  if (kIsWeb) { // Check if the platform is web
    return web; // Return web Firebase options
  }
  switch (defaultTargetPlatform) { // Switch based on the default target platform
    case TargetPlatform.android: // If the platform is Android
    return android; // Return Android Firebase options
    case TargetPlatform.iOS: // If the platform is iOS
    return ios; // Return iOS Firebase options
    default: // If the platform is not supported
    throw UnsupportedError( // Throw an error indicating unsupported platform
      'DefaultFirebaseOptions are not supported for this platform.',
    );
  }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAPRNiq7ySYwSvSQFes8h1M5fL1PJVQdKA',
    appId: '1:416890687838:web:8bad42f3883df5b0067fcf',
    messagingSenderId: '416890687838',
    projectId: 'cateredtoyoutest',
    authDomain: 'cateredtoyoutest.firebaseapp.com',
    storageBucket: 'cateredtoyoutest.firebasestorage.app',
    measurementId: 'G-FJ10PZJ19J',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDK8ffkKGv8be38yeC1ehxxHjzSoRVtR8w',
    appId: '1:416890687838:android:7c8c80a8146d6dbf067fcf',
    messagingSenderId: '416890687838',
    projectId: 'cateredtoyoutest',
    storageBucket: 'cateredtoyoutest.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDx9LrlGXN8u6d1dbx2Lyo1wMVbEQHmFlY',
    appId: '1:416890687838:ios:4c5d279a881bf088067fcf',
    messagingSenderId: '416890687838',
    projectId: 'cateredtoyoutest',
    storageBucket: 'cateredtoyoutest.firebasestorage.app',
    iosBundleId: 'com.example.cateredtoyou',
  );

}