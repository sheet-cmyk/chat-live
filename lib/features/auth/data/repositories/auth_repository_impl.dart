import 'package:firebase_auth/firebase_auth.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/user_model.dart';

class AuthRepository {
  final AuthRemoteDataSource _dataSource = AuthRemoteDataSource();

  User? get currentUser => _dataSource.currentFirebaseUser;

  Stream<User?> get authStateChanges => _dataSource.authStateChanges;

  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(PhoneAuthCredential) onAutoVerified,
    required void Function(String verId, int? resendToken) onCodeSent,
    required void Function(FirebaseAuthException) onError,
  }) {
    return _dataSource.sendOtp(
      phoneNumber: phoneNumber,
      onAutoVerified: onAutoVerified,
      onCodeSent: onCodeSent,
      onError: onError,
    );
  }

  // يُستخدم من شاشة OTP القديمة
  Future<UserModel?> verifyOtpAndGetUser({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = await _dataSource.verifyOtp(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final uid = credential.user!.uid;
    return _dataSource.fetchUser(uid);
  }

  // يُستخدم من OtpLoginScreen (تسجيل الهاتف الجديد)
  Future<UserModel?> verifyOtpAndLogin({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = await _dataSource.verifyOtp(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final uid = credential.user!.uid;
    return _dataSource.fetchUser(uid);
  }

  Future<UserModel?> signInWithGoogle() async {
    final credential = await _dataSource.signInWithGoogle();
    final uid = credential.user!.uid;
    return _dataSource.fetchUser(uid);
  }

  Future<UserModel?> signInWithYahoo() async {
    final credential = await _dataSource.signInWithYahoo();
    final uid = credential.user!.uid;
    return _dataSource.fetchUser(uid);
  }

  Future<void> signInAnonymously() async {
    await _dataSource.signInAnonymously();
  }

  Future<void> signOut() async {
    final uid = currentUser?.uid;
    if (uid != null) {
      await _dataSource.setOnlineStatus(uid, false);
    }
    await _dataSource.signOut();
  }

  Future<UserModel?> fetchCurrentUser() async {
    final uid = currentUser?.uid;
    if (uid == null) return null;
    return _dataSource.fetchUser(uid);
  }

  Future<void> saveNewUser(UserModel user) async {
    await _dataSource.saveUser(user);
    await _dataSource.setOnlineStatus(user.uid, true);
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _dataSource.updateUser(uid, data);
  }

}
