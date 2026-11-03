import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Client identifiers of the Firebase project `sabtawya-a4907`. These are
/// public by design (they ship in every web bundle); the private service key
/// lives only in Supabase secrets.
class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static FirebaseOptions get current => kIsWeb ? web : android;

  static const web = FirebaseOptions(
    apiKey: 'AIzaSyASmWEC8FPkfXLRt1VLX4gj4mcRdOrE114',
    appId: '1:202734221696:web:ca324a1126e9e55d7b6965',
    messagingSenderId: '202734221696',
    projectId: 'sabtawya-a4907',
    authDomain: 'sabtawya-a4907.firebaseapp.com',
    storageBucket: 'sabtawya-a4907.firebasestorage.app',
  );

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyASmWEC8FPkfXLRt1VLX4gj4mcRdOrE114',
    appId: '1:202734221696:android:821a79a906be27eb7b6965',
    messagingSenderId: '202734221696',
    projectId: 'sabtawya-a4907',
    storageBucket: 'sabtawya-a4907.firebasestorage.app',
  );

  /// Web push (VAPID) public key.
  static const webVapidKey =
      'BMxJiS1PYBHpB8-kSW3MSo7zJNpILxF7EYzuoq-mrD1SYh6Qg16Mq_uyeIF5EFsJGbFC62mPrZYF40VpE0L3hbU';
}
