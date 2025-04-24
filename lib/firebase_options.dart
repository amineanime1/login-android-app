import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    // Replace these values with your Firebase configuration from the Firebase Console
   return const FirebaseOptions(
  apiKey: 'AIzaSyD3KtNCzgyBN7xzzy5YDTVt37dq04i-9N8',    // from "current_key"
  projectId: 'login-app-6c8e3',                          // from "project_id"
  storageBucket: 'login-app-6c8e3.firebasestorage.app', // from "storage_bucket"
  messagingSenderId: '972259037888',                     // from "project_number"
  appId: '1:972259037888:android:48df2808c2d67d808b1325', // from "mobilesdk_app_id"
  authDomain: 'login-app-6c8e3.firebaseapp.com',        // constructed from project_id
);
  }
} 