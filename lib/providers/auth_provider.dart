import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/services/push_notification_service.dart';

class AppCurrentUser {
  final String uid;
  final String role;
  final String? email;
  final bool isActive;
  final bool disabledByAdmin;

  const AppCurrentUser({
    required this.uid,
    required this.role,
    this.email,
    this.isActive = true,
    this.disabledByAdmin = false,
  });
}

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? user;
  AppCurrentUser? currentUser;
  bool isLoading = false;
  bool authResolved = false;
  String? errorMessage;

  StreamSubscription<User?>? _authSubscription;

  static const String disabledAccountMessage =
      'تم تعطيل حسابك من الإدارة. لا يمكنك الدخول إلا بعد إعادة التفعيل من الإدارة.';

  AuthProvider() {
    _authSubscription = _auth.authStateChanges().listen((firebaseUser) async {
      user = firebaseUser;

      if (firebaseUser == null) {
        currentUser = null;
        authResolved = true;
        notifyListeners();
        return;
      }

      await _loadUserFromFirestore(firebaseUser.uid);

      if (user != null && currentUser != null && !isDisabledByAdmin) {
        await PushNotificationService.instance.syncCurrentUserToken();
      }

      authResolved = true;
      notifyListeners();
    });
  }

  String? get uid => user?.uid;
  bool get isLoggedIn => user != null && currentUser != null;
  String? get role => currentUser?.role.toLowerCase();
  String get safeRole => (currentUser?.role ?? 'customer').toLowerCase();

  bool get isDisabledByAdmin =>
      currentUser?.isActive == false ||
      currentUser?.disabledByAdmin == true;

  Future<void> _forceLogoutDisabledUser() async {
    try {
      final currentUid = _auth.currentUser?.uid;
      if (currentUid != null && currentUid.isNotEmpty) {
        await PushNotificationService.instance.removeCurrentDeviceToken(
          uid: currentUid,
        );
      }
    } catch (_) {
      // Ignore token cleanup errors for disabled accounts.
    }

    try {
      await _auth.signOut();
    } catch (_) {
      // Ignore sign out errors and still clear local state.
    }

    user = null;
    currentUser = null;
  }

  Future<void> _loadUserFromFirestore(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();

      if (doc.exists) {
        final data = doc.data()!;

        final role = (data['role'] ?? 'customer').toString().toLowerCase();
        final email = (data['email'] ?? user?.email)?.toString();

        final isActive = data['isActive'] != false;
        final disabledByAdmin = data['disabledByAdmin'] == true;

        if (!isActive || disabledByAdmin) {
          currentUser = AppCurrentUser(
            uid: uid,
            role: role,
            email: email,
            isActive: false,
            disabledByAdmin: true,
          );

          errorMessage = disabledAccountMessage;

          await _forceLogoutDisabledUser();
          return;
        }

        currentUser = AppCurrentUser(
          uid: uid,
          role: role,
          email: email,
          isActive: true,
          disabledByAdmin: false,
        );
      } else {
        await _firestore.collection('users').doc(uid).set({
          'uid': uid,
          'email': user?.email,
          'role': 'customer',
          'isActive': true,
          'disabledByAdmin': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        currentUser = AppCurrentUser(
          uid: uid,
          role: 'customer',
          email: user?.email,
          isActive: true,
          disabledByAdmin: false,
        );
      }
    } catch (e) {
      errorMessage = 'فشل تحميل بيانات المستخدم: $e';
    }
  }

  Future<void> registerWithEmail({
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      final normalizedRole = role.trim().toLowerCase();
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = cred.user!.uid;

      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'email': email.trim(),
        'role': normalizedRole,
        'isActive': true,
        'disabledByAdmin': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      user = cred.user;

      currentUser = AppCurrentUser(
        uid: uid,
        role: normalizedRole,
        email: email.trim(),
        isActive: true,
        disabledByAdmin: false,
      );

      await PushNotificationService.instance.syncCurrentUserToken();
    } on FirebaseAuthException catch (e) {
      errorMessage = e.message ?? 'فشل إنشاء الحساب';
    } catch (e) {
      errorMessage = 'فشل إنشاء الحساب: $e';
    } finally {
      isLoading = false;
      authResolved = true;
      notifyListeners();
    }
  }

  Future<void> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      user = cred.user;

      if (user != null) {
        await _loadUserFromFirestore(user!.uid);

        if (user != null && currentUser != null && !isDisabledByAdmin) {
          await PushNotificationService.instance.syncCurrentUserToken();
        }
      }
    } on FirebaseAuthException catch (e) {
      errorMessage = e.message ?? 'فشل تسجيل الدخول';
    } catch (e) {
      errorMessage = 'فشل تسجيل الدخول: $e';
    } finally {
      isLoading = false;
      authResolved = true;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    final currentUid = user?.uid;

    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

      if (currentUid != null && currentUid.isNotEmpty) {
        await PushNotificationService.instance.removeCurrentDeviceToken(
          uid: currentUid,
        );
      }

      await _auth.signOut();
      user = null;
      currentUser = null;
    } on FirebaseAuthException catch (e) {
      errorMessage = e.message ?? 'فشل تسجيل الخروج';
    } catch (e) {
      errorMessage = 'فشل تسجيل الخروج: $e';
    } finally {
      isLoading = false;
      authResolved = true;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}