import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AppCurrentUser {
  final String uid;
  final String role;
  final String? email;

  const AppCurrentUser({required this.uid, required this.role, this.email});
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

  AuthProvider() {
    _authSubscription = _auth.authStateChanges().listen((firebaseUser) async {
      user = firebaseUser;

      if (firebaseUser == null) {
        currentUser = null;
        authResolved = true;
      } else {
        await _loadUserFromFirestore(firebaseUser.uid);
        authResolved = true; // 🔥 بعد تحميل Firestore
      }

      notifyListeners();
    });
  }

  String? get uid => user?.uid;
  bool get isLoggedIn => user != null;
  String? get role => currentUser?.role.toLowerCase();
  String get safeRole => (currentUser?.role ?? 'customer').toLowerCase();

  Future<void> _loadUserFromFirestore(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();

      if (doc.exists) {
        final data = doc.data()!;
        currentUser = AppCurrentUser(
          uid: uid,
          role: (data['role'] ?? 'customer').toString().toLowerCase(),
          email: (data['email'] ?? user?.email)?.toString(),
        );
      } else {
        await _firestore.collection('users').doc(uid).set({
          'uid': uid,
          'email': user?.email,
          'role': 'customer',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        currentUser = AppCurrentUser(
          uid: uid,
          role: 'customer',
          email: user?.email,
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
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      currentUser = AppCurrentUser(
        uid: uid,
        role: normalizedRole,
        email: email.trim(),
      );
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
    try {
      isLoading = true;
      errorMessage = null;
      notifyListeners();

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

  Future<void> fakeLoginAs(Object? role) async {
    // مؤقتًا للتوافق مع الشاشات القديمة:
    await registerWithEmail(
      email:
          '${role.toString().toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}@test.com',
      password: 'Test@123456',
      role: role.toString(),
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
