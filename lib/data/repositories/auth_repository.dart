import 'package:eflutter/core/base/local_data_base.dart';
import 'package:eflutter/core/base/remote_data_base.dart';
import 'package:eflutter/core/base/result.dart';
import 'package:eflutter/data/repositories/api_safe_result.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:injectable/injectable.dart';
import 'package:talker_flutter/talker_flutter.dart';

@lazySingleton
class AuthRepository {
  final Talker _logger;
  final LocalDataBase _localData;
  final RemoteDataBase _remoteData;

  AuthRepository(this._localData, this._logger, this._remoteData);

  Future<bool> get initAuthenticated async {
    final token = await _localData.getAccessToken();
    return token != null;
  }

  Future<void> logout() => _localData.clearTokens();

  bool _isGoogleSignInInitialized = false;

  Future<Result<void>> login() async {
    try {
      String? idToken;

      if (kIsWeb) {
        final authProvider = GoogleAuthProvider();
        final userCredential = await FirebaseAuth.instance.signInWithPopup(authProvider);
        idToken = await userCredential.user?.getIdToken();
      } else {
        if (!_isGoogleSignInInitialized) {
          await GoogleSignIn.instance.initialize();
          _isGoogleSignInInitialized = true;
        }

        final googleUser = await GoogleSignIn.instance.authenticate();
        idToken = googleUser.authentication.idToken;
      }

      if (idToken == null) {
        return const Result.cancelled();
      }

      final result = await _remoteData.login(idToken).safeResult();
      if (result case Success(data: final data)) {
        await _localData.saveTokens(data.$1, data.$2);
      }
      return result;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request') {
        return const Result.cancelled();
      }
      _logger.error('[GoogleSignInError]:', e, e.stackTrace);
      return const Result.failure(message: 'An unexpected error occurred while logging in. Please try again.');
    } catch (e, st) {
      _logger.error('[GoogleSignInError]:', e, st);
      return const Result.failure(message: 'An unexpected error occurred while logging in. Please try again.');
    }
  }
}
