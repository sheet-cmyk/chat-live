import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository_impl.dart';

final authRepositoryProvider = Provider<AuthRepository>((_) => AuthRepository());

// حالة المصادقة الحالية (Firebase user)
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

// بيانات الملف الشخصي المباشرة من Firestore (realtime)
final userProfileStreamProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return const Stream.empty();
  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((s) => s.data());
});

// بيانات المستخدم الكاملة من Firestore
final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) async {
      if (user == null) return null;
      return ref.read(authRepositoryProvider).fetchCurrentUser();
    },
    loading: () async => null,
    error: (_, __) async => null,
  );
});

// حالة OTP
class OtpState {
  final bool isLoading;
  final String? verificationId;
  final String? error;
  final bool codeSent;
  final int? resendToken;

  const OtpState({
    this.isLoading = false,
    this.verificationId,
    this.error,
    this.codeSent = false,
    this.resendToken,
  });

  OtpState copyWith({
    bool? isLoading,
    String? verificationId,
    String? error,
    bool? codeSent,
    int? resendToken,
  }) {
    return OtpState(
      isLoading: isLoading ?? this.isLoading,
      verificationId: verificationId ?? this.verificationId,
      error: error,
      codeSent: codeSent ?? this.codeSent,
      resendToken: resendToken ?? this.resendToken,
    );
  }
}

class OtpNotifier extends StateNotifier<OtpState> {
  OtpNotifier(this._repo) : super(const OtpState());

  final AuthRepository _repo;

  Future<void> sendOtp(String phoneNumber) async {
    state = state.copyWith(isLoading: true, error: null);
    await _repo.sendOtp(
      phoneNumber: phoneNumber,
      onAutoVerified: (credential) async {
        // تحقق تلقائي (Android)
        state = state.copyWith(isLoading: false);
      },
      onCodeSent: (verId, resendToken) {
        state = state.copyWith(
          isLoading: false,
          verificationId: verId,
          codeSent: true,
          resendToken: resendToken,
        );
      },
      onError: (e) {
        state = state.copyWith(isLoading: false, error: e.message);
      },
    );
  }

  Future<UserModel?> verifyOtp(String smsCode) async {
    if (state.verificationId == null) return null;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repo.verifyOtpAndGetUser(
        verificationId: state.verificationId!,
        smsCode: smsCode,
      );
      state = state.copyWith(isLoading: false);
      return user;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return null;
    }
  }

  void reset() => state = const OtpState();
}

final otpProvider = StateNotifierProvider<OtpNotifier, OtpState>((ref) {
  return OtpNotifier(ref.read(authRepositoryProvider));
});
