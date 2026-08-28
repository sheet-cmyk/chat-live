import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';

class AuthRemoteDataSource {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    // Web client ID (type 3 in google-services.json) — required to get idToken for Firebase
    serverClientId: '699687299124-bg9qfbsteucq0vposgfg2rb1tj348ens.apps.googleusercontent.com',
  );

  User? get currentFirebaseUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // رقم الهاتف — إرسال OTP
  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(PhoneAuthCredential) onAutoVerified,
    required void Function(String verId, int? resendToken) onCodeSent,
    required void Function(FirebaseAuthException) onError,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: onAutoVerified,
      verificationFailed: onError,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: (_) {},
      timeout: const Duration(seconds: 60),
    );
  }

  // رقم الهاتف — التحقق من OTP
  Future<UserCredential> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return _auth.signInWithCredential(credential);
  }

  // Yahoo Login
  Future<UserCredential> signInWithYahoo() async {
    final provider = OAuthProvider('yahoo.com')
      ..addScope('profile')
      ..addScope('email');
    return _auth.signInWithProvider(provider);
  }

  // Google Login
  // NOTE for production: make sure to add Play App Signing SHA-1 to Firebase Console.
  // Get it from: Google Play Console → App → Setup → App Signing → SHA-1 certificate fingerprint.
  // Then re-download google-services.json after adding it.
  Future<UserCredential> signInWithGoogle() async {
    // Sign out first so the user always sees the account picker
    await _googleSignIn.signOut().catchError((_) => null);
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('cancelled');
    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) {
      // This usually means SHA-1 fingerprint mismatch or missing Play App Signing SHA-1 in Firebase
      throw FirebaseAuthException(
        code: 'google-idtoken-null',
        message:
            'فشل جلب idToken من Google — تأكد من إضافة SHA-1 (Play App Signing) في Firebase Console',
      );
    }
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: idToken,
    );
    return _auth.signInWithCredential(credential);
  }

  // Guest Mode
  Future<UserCredential> signInAnonymously() async {
    return _auth.signInAnonymously();
  }

  // تسجيل الخروج
  Future<void> signOut() async {
    await _googleSignIn.signOut().catchError((_) => null);
    await _auth.signOut();
  }

  // Firestore: جلب بيانات المستخدم
  Future<UserModel?> fetchUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  // Firestore: حفظ بيانات مستخدم جديد
  Future<void> saveUser(UserModel user) async {
    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(user.toFirestore(), SetOptions(merge: true));
  }

  // Firestore: تحديث حقول المستخدم
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).set(data, SetOptions(merge: true));
  }

  // تحديث حالة الاتصال
  Future<void> setOnlineStatus(String uid, bool isOnline) async {
    await _firestore.collection('users').doc(uid).set({
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
