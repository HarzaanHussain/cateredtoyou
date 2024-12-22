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

  static const FirebaseOptions web = FirebaseOptions( // Define Firebase options for web
  apiKey: 'AIzaSyCRhKTJdSDL9uuaP9uvtnQYPtMA2HXDly8', // API key for web
  appId: '1:328369352197:web:e6b756d4ee8bccd318f66c', // App ID for web
  messagingSenderId: '328369352197', // Messaging sender ID for web
  projectId: 'cateredtoyou-7eeed', // Project ID for web
  authDomain: 'cateredtoyou-7eeed.firebaseapp.com', // Auth domain for web
  storageBucket: 'cateredtoyou-7eeed.appspot.com', // Storage bucket for web
  );

  static const FirebaseOptions android = FirebaseOptions( // Define Firebase options for Android
  apiKey: 'AIzaSyCRhKTJdSDL9uuaP9uvtnQYPtMA2HXDly8', // API key for Android
  appId: '1:328369352197:android:b4117760c126493f18f66c', // App ID for Android
  messagingSenderId: '328369352197', // Messaging sender ID for Android
  projectId: 'cateredtoyou-7eeed', // Project ID for Android
  storageBucket: 'cateredtoyou-7eeed.appspot.com', // Storage bucket for Android
  );

  static const FirebaseOptions ios = FirebaseOptions( // Define Firebase options for iOS
  apiKey: 'AIzaSyCRhKTJdSDL9uuaP9uvtnQYPtMA2HXDly8', // API key for iOS
  appId: '1:328369352197:ios:36fe039818df4c1b18f66c', // App ID for iOS
  messagingSenderId: '328369352197', // Messaging sender ID for iOS
  projectId: 'cateredtoyou-7eeed', // Project ID for iOS
  storageBucket: 'cateredtoyou-7eeed.appspot.com', // Storage bucket for iOS
  iosClientId: 'your_ios_client_id.apps.googleusercontent.com', // iOS client ID
  );
}
