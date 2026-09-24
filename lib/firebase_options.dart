import 'package:firebase_core/firebase_core.dart';
class DefaultFirebaseOptions{
 static const FirebaseOptions android=FirebaseOptions(apiKey:'AIzaSyDPNLtekyLhpnZIDmkFeVKji1ozUKdnyfQ',appId:'1:208738737302:android:ea0410ab60d22ce5fef6b7',messagingSenderId:'208738737302',projectId:'cma-mcq-portal-cf33f',storageBucket:'cma-mcq-portal-cf33f.firebasestorage.app');
 static FirebaseOptions get currentPlatform=>android;
}