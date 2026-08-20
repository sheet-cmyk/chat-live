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
        throw UnsupportedError(
          'iOS: أضف GoogleService-Info.plist وعرّف خيارات iOS هنا',
        );
      default:
        throw UnsupportedError(
          'المنصة الحالية غير مدعومة: $defaultTargetPlatform',
        );
    }
  }

  // Android — من google-services.json
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBGDl62pxkPq32oatANM8ZulqXMzTiW1fQ',
    appId: '1:699687299124:android:ff41dc74a76ad532d9c261',
    messagingSenderId: '699687299124',
    projectId: 'chatbaby-b3570',
    storageBucket: 'chatbaby-b3570.firebasestorage.app',
  );

  // Web (من إعدادات Firebase Console)
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBGDl62pxkPq32oatANM8ZulqXMzTiW1fQ',
    appId: '1:699687299124:web:ecdcc53c357970eed9c261',
    messagingSenderId: '699687299124',
    projectId: 'chatbaby-b3570',
    storageBucket: 'chatbaby-b3570.firebasestorage.app',
    authDomain: 'chatbaby-b3570.firebaseapp.com',
  );
}
