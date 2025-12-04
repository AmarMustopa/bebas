import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Minimal user model used by the app (keeps only displayName and email)
class UserModel {
  final String? displayName;
  final String? email;
  final String? photoURL;

  UserModel({this.displayName, this.email, this.photoURL});

  Map<String, dynamic> toJson() => {
        'displayName': displayName,
        'email': email,
        'photoURL': photoURL,
      };

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
        displayName: j['displayName'] as String?,
        email: j['email'] as String?,
        photoURL: j['photoURL'] as String?,
      );
}

class AuthService with ChangeNotifier {
  final fb.FirebaseAuth? _auth;
  UserModel? _user;

  UserModel? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isFirebaseAvailable => _auth != null;

  /// If [firebaseAvailable] is false, AuthService won't attempt to access Firebase.
  AuthService({bool firebaseAvailable = true}) : _auth = (firebaseAvailable ? fb.FirebaseAuth.instance : null) {
    // Only listen to auth state if Firebase is available
    try {
      if (_auth != null) {
        _auth!.authStateChanges().listen((fb.User? user) {
          _user = user != null ? UserModel(displayName: user.displayName, email: user.email, photoURL: user.photoURL) : null;
          notifyListeners();
        });
      } else {
        // If Firebase is not available, try to restore local user from SharedPreferences
        _restoreLocalUser();
      }
    } catch (e) {
      // If Firebase was not properly initialized, avoid throwing during provider creation
      print('⚠️ AuthService: Firebase not available: $e');
    }
  }

  Future<void> _restoreLocalUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString('local_user');
      if (s != null) {
        final jsonMap = json.decode(s) as Map<String, dynamic>;
        _user = UserModel.fromJson(jsonMap);
        print('🔁 AuthService: restored local_user ${_user?.email}');
        notifyListeners();
      }
    } catch (_) {}
  }

  // === SIGN IN ===
  Future<String?> signInWithEmailAndPassword(
      String email, String password) async {
    print('🔐 signInWithEmailAndPassword called for $email; firebaseAvailable=${_auth!=null}');
    if (_auth == null) {
      // Local fallback: check SharedPreferences for stored user credentials
      final prefs = await SharedPreferences.getInstance();
      final key = 'user:${email.toLowerCase()}';
      print('🔐 local sign-in using key=$key');
      final s = prefs.getString(key);
      if (s == null) return 'Akun tidak ditemukan (local).';
      final data = json.decode(s) as Map<String, dynamic>;
      final storedPassword = data['password'] as String?;
      if (storedPassword != password) return 'Password salah (local).';
      // Success: set local user
  _user = UserModel(displayName: data['username'] as String?, email: email, photoURL: data['photoURL'] as String?);
      notifyListeners();
      print('🔐 local sign-in success for $email');
      return null;
    }
    if (email.isEmpty || password.isEmpty) {
      return "Email & Password tidak boleh kosong";
    }

    try {
      fb.UserCredential result = await _auth!.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
  final u = result.user;
  _user = u != null ? UserModel(displayName: u.displayName, email: u.email, photoURL: u.photoURL) : null;
      notifyListeners();
      print('🔐 firebase sign-in success for ${_user?.email}');
      return null;
    } on fb.FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return 'Email tidak terdaftar';
        case 'wrong-password':
          return 'Password salah';
        case 'invalid-email':
          return 'Format email tidak valid';
        case 'user-disabled':
          return 'Akun telah dinonaktifkan';
        case 'too-many-requests':
          return 'Terlalu banyak percobaan. Coba lagi nanti';
        default:
          return 'Login gagal: ${e.message}';
      }
    } catch (e) {
      return "Error: $e";
    }
  }

  // === REGISTER ===
  Future<String?> registerWithEmailAndPassword(
      String username, String email, String password) async {
    print('🔐 registerWithEmailAndPassword called for $email; firebaseAvailable=${_auth!=null}');
    if (_auth == null) {
      // Local fallback: store credentials in SharedPreferences (development only)
      final prefs = await SharedPreferences.getInstance();
      final key = 'user:${email.toLowerCase()}';
      print('🔐 local register using key=$key');
      final existing = prefs.getString(key);
      if (existing != null) return 'Email sudah terdaftar (local).';
      final Map<String, dynamic> userObj = {
        'username': username,
        'email': email,
        'password': password,
        'photoURL': null,
      };
      await prefs.setString(key, json.encode(userObj));
      // Also save local_user for restore (include photoURL)
      await prefs.setString('local_user', json.encode({'displayName': username, 'email': email, 'photoURL': null}));
      _user = UserModel(displayName: username, email: email, photoURL: null);
      notifyListeners();
      print('🔐 local register success for $email');
      return null;
    }
    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      return "Semua field wajib diisi";
    }

    try {
      fb.UserCredential result = await _auth!.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      await result.user!.updateDisplayName(username);
      await result.user!.reload();

  final u = _auth!.currentUser;
  _user = u != null ? UserModel(displayName: u.displayName, email: u.email, photoURL: u.photoURL) : null;
      notifyListeners();
      return null;
    } on fb.FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'Email sudah terdaftar. Silakan login atau gunakan email lain';
        case 'invalid-email':
          return 'Format email tidak valid';
        case 'operation-not-allowed':
          return 'Registrasi tidak diizinkan';
        case 'weak-password':
          return 'Password terlalu lemah. Gunakan minimal 6 karakter';
        default:
          return 'Registrasi gagal: ${e.message}';
      }
    } catch (e) {
      return "Error: $e";
    }
  }

  // === LOGOUT ===
  Future<void> signOut() async {
    if (_auth == null) return;
    await _auth!.signOut();
    _user = null;
    notifyListeners();
  }
}
