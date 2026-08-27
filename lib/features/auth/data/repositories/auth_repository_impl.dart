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

  // ── Phone + Password auth ────────────────────────────────────────────────────

  // تحويل رقم الهاتف إلى بريد وهمي
  static String _toSyntheticEmail(String fullPhone) =>
      '${fullPhone.replaceAll(RegExp(r'[^0-9]'), '')}@partyhub.app';

  // ربط بريد/كلمة مرور بمستخدم الهاتف بعد التحقق من OTP (تسجيل)
  Future<void> linkPasswordAfterOtp({
    required String fullPhone,
    required String password,
  }) async {
    try {
      await _dataSource.linkEmailPassword(
          _toSyntheticEmail(fullPhone), password);
    } on FirebaseAuthException catch (e) {
      // provider-already-linked → نفس الحساب مسجل مسبقاً ← تجاهل
      // email-already-in-use  → البريد الوهمي موجود في حساب آخر ← تجاهل
      if (e.code != 'provider-already-linked' &&
          e.code != 'email-already-in-use') {
        rethrow;
      }
    }
    // لا نستدعي updateUser هنا — الـ doc قد لا يكون موجوداً بعد لمستخدم جديد
    // (updateUser يستخدم Firestore.update() الذي يفشل إذا لم يوجد الـ document)
    // phoneNumber يُحفظ عند إكمال الملف الشخصي أو بواسطة set+merge أدناه
    try {
      final uid = _dataSource.currentFirebaseUser?.uid;
      if (uid != null) {
        await _dataSource.savePhoneNumber(uid, fullPhone);
      }
    } catch (_) {
      // غير حرج — الـ setup profile سيُكمل إنشاء الـ document
    }
  }

  // تسجيل الدخول بالهاتف وكلمة المرور بدون OTP (دخول)
  Future<UserModel?> signInWithPhonePassword({
    required String fullPhone,
    required String password,
  }) async {
    final cred = await _dataSource.signInWithEmailPassword(
        _toSyntheticEmail(fullPhone), password);
    return _dataSource.fetchUser(cred.user!.uid);
  }
}
