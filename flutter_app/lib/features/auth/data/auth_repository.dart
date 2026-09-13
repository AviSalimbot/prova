// lib/features/auth/data/auth_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/entities.dart';
import '../../../services/firestore_paths.dart';
import '../../assessments/data/drive_auth_service.dart';

final firebaseAuthProvider =
    Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

/// Emits the signed-in Firebase user, or null when signed out.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// Resolves the signed-in user's role/profile document from Firestore
/// (the `users` collection in Figure H-5).
final appUserProvider = StreamProvider<AppUser?>((ref) {
  final authState = ref.watch(authStateProvider).value;
  if (authState == null) return Stream.value(null);

  return ref
      .watch(firestoreProvider)
      .collection(FirestorePaths.users)
      .doc(authState.uid)
      .snapshots()
      .map((doc) => doc.exists ? AppUser.fromMap(doc.id, doc.data()!) : null);
});

/// Holds a one-shot message to show on the login screen — set either
/// right after registering, or by [AuthRepository.signIn]/
/// [AuthRepository.signInWithGoogle] when a still-pending account
/// tries to sign in. LoginScreen watches this reactively (not a
/// one-time read) so it updates correctly even if the screen was
/// rebuilt by a router redirect partway through a sign-in attempt.
final pendingNoticeProvider = StateProvider<String?>((ref) => null);

/// Account lifecycle states, mirrored exactly by `isValidStatus` in the
/// Firestore rules and by the router's `approved` check.
///
///   pending  — registered, awaiting admin approval. No access.
///   active   — approved by an admin. Full access for their role.
///   deleted  — removed or rejected by an admin. No access.
const String kStatusPending = 'pending';
const String kStatusActive = 'active';
const String kStatusDeleted = 'deleted';

/// Roles that are allowed to actually use the app, ONCE their status is
/// already 'active'. Status is always evaluated first — a 'deleted' user
/// keeps no privileges even though their old role string is still on the
/// doc. Anything else here — most commonly 'pending', but also a
/// missing/malformed doc — blocks sign-in.
const _activeRoles = {'admin', 'annotator', 'adjudicator'};

/// Thrown specifically when the Auth account was created successfully but
/// writing the matching `users/{uid}` profile doc failed — this is kept
/// distinct from an Auth failure so the UI (and your logs) can tell the
/// two apart instead of a generic "something went wrong".
class ProfileCreationException implements Exception {
  final Object cause;
  ProfileCreationException(this.cause);

  @override
  String toString() =>
      'Account was created, but saving the user profile failed: $cause';
}

/// Thrown when someone with valid credentials tries to sign in but their
/// account isn't usable yet: `status` is still 'pending' (awaiting admin
/// approval), or the profile doc is missing/malformed. The caller signs
/// them back out before this is thrown, so no session is left dangling.
class AccountPendingException implements Exception {
  @override
  String toString() =>
      'Sign up application is processed — please wait for the email '
      'notifying you that your account has been activated before signing in.';
}

/// Thrown when a valid credential belongs to an account an admin has
/// removed or rejected (`status == 'deleted'`). Deliberately separate
/// from [AccountPendingException] so the user isn't told to keep waiting
/// for an approval that is never coming.
class AccountDisabledException implements Exception {
  @override
  String toString() =>
      'This account is no longer active. Please contact an administrator '
      'if you believe this is a mistake.';
}

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final Ref _ref;

  AuthRepository(this._auth, this._firestore, this._ref);

  /// Signs in, then validates the user's profile doc. STATUS IS CHECKED
  /// BEFORE ROLE, matching the Firestore rules, the router redirect and
  /// the AppShell — a removed/rejected user must lose access instantly
  /// regardless of whatever role string is still on their document.
  Future<UserCredential> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final uid = credential.user!.uid;

    final doc =
        await _firestore.collection(FirestorePaths.users).doc(uid).get();

    final data = doc.data();
    final status = (data?['status'] as String?)?.toLowerCase();
    final role = (data?['role'] as String?)?.toLowerCase();

    if (doc.exists && status == kStatusDeleted) {
      await _auth.signOut();
      _ref.read(pendingNoticeProvider.notifier).state =
          AccountDisabledException().toString();
      throw AccountDisabledException();
    }

    if (!doc.exists ||
        status != kStatusActive ||
        role == null ||
        !_activeRoles.contains(role)) {
      await _auth.signOut();
      _ref.read(pendingNoticeProvider.notifier).state =
          AccountPendingException().toString();
      throw AccountPendingException();
    }

    return credential;
  }

  /// Signs in to PROVA using a Google account, and — in the SAME
  /// consent flow — authorizes read-only Drive access via [driveAuth].
  /// The caller must have already completed Google authentication
  /// (native picker via driveAuth.signInInteractively(), or the
  /// rendered web button + onSignInChanged) before calling this; see
  /// LoginScreen.
  ///
  /// Mirrors signIn()'s status/role gate exactly: a brand-new Google
  /// account gets bootstrapped with a 'pending' profile doc (same shape
  /// signUp() writes) and is signed back out, rather than silently
  /// getting in. Google sign-in must go through the same admin
  /// approval as email/password accounts — otherwise anyone with a
  /// Google account could bypass PROVA's access control entirely.
  Future<UserCredential> signInWithGoogle(DriveAuthService driveAuth) async {
    final idToken = await driveAuth.completeGoogleSignInForApp();
    final credential = GoogleAuthProvider.credential(idToken: idToken);

    UserCredential userCredential;
    try {
      userCredential = await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        // This email already has an email/password account. Don't
        // silently merge accounts — surface it clearly instead of a
        // cryptic Firebase error.
        throw Exception(
          'An account already exists for this email using a password. '
          'Sign in with your email and password instead.',
        );
      }
      rethrow;
    }

    final user = userCredential.user!;
    final uid = user.uid;

    final doc =
        await _firestore.collection(FirestorePaths.users).doc(uid).get();

    if (!doc.exists) {
      // First time this Google account has signed in to PROVA —
      // bootstrap a pending profile doc exactly like signUp() does, so
      // it still requires admin approval before any access is granted.
      // Field shapes must match signUp()'s exactly: the Firestore rule
      // only permits this create when role == 'pending' AND
      // status == 'pending'.
      try {
        await _firestore.collection(FirestorePaths.users).doc(uid).set({
          'name': user.displayName ?? user.email ?? 'Unnamed',
          'email': user.email ?? '',
          'role': kStatusPending,
          'status': kStatusPending,
          'requestedRole': 'pending', // Google sign-in has no role picker.
          'scope': '—',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e, st) {
        debugPrint(
            'signInWithGoogle: failed to write users/$uid profile doc: $e');
        debugPrintStack(stackTrace: st);
        await _auth.signOut();
        throw ProfileCreationException(e);
      }

      await _auth.signOut();
      _ref.read(pendingNoticeProvider.notifier).state =
          AccountPendingException().toString();
      throw AccountPendingException();
    }

    final data = doc.data();
    final status = (data?['status'] as String?)?.toLowerCase();
    final role = (data?['role'] as String?)?.toLowerCase();

    if (status == kStatusDeleted) {
      await _auth.signOut();
      _ref.read(pendingNoticeProvider.notifier).state =
          AccountDisabledException().toString();
      throw AccountDisabledException();
    }

    if (status != kStatusActive ||
        role == null ||
        !_activeRoles.contains(role)) {
      await _auth.signOut();
      _ref.read(pendingNoticeProvider.notifier).state =
          AccountPendingException().toString();
      throw AccountPendingException();
    }

    return userCredential;
  }

    /// Sign-up counterpart to [signInWithGoogle]. Same Google auth flow,
  /// but writes the profile doc with the user's selected `requestedRole`
  /// (instead of always writing 'pending' as the requested role), and
  /// treats an existing profile doc as an error rather than silently
  /// falling through to a pending-notice sign-in attempt.
  ///
  /// Like signInWithGoogle, the caller must have already completed
  /// Google authentication via [driveAuth] before calling this.
  Future<UserCredential> signUpWithGoogle(
    String requestedRole,
    DriveAuthService driveAuth,
  ) async {
    final idToken = await driveAuth.completeGoogleSignInForApp();
    final credential = GoogleAuthProvider.credential(idToken: idToken);

    UserCredential userCredential;
    try {
      userCredential = await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        throw Exception(
          'An account already exists for this email using a password. '
          'Sign in with your email and password instead.',
        );
      }
      rethrow;
    }

    final user = userCredential.user!;
    final uid = user.uid;

    final doc =
        await _firestore.collection(FirestorePaths.users).doc(uid).get();

    if (doc.exists) {
      // Already registered — this is a sign-up call, so don't silently
      // bootstrap or sign them in. Send them to sign in instead.
      await _auth.signOut();
      throw Exception(
        'An account already exists for this Google account. '
        'Please sign in instead.',
      );
    }

    try {
      await _firestore.collection(FirestorePaths.users).doc(uid).set({
        'name': user.displayName ?? user.email ?? 'Unnamed',
        'email': user.email ?? '',
        'role': kStatusPending,
        'status': kStatusPending,
        'requestedRole': requestedRole,
        'scope': '—',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e, st) {
      debugPrint(
          'signUpWithGoogle: failed to write users/$uid profile doc: $e');
      debugPrintStack(stackTrace: st);
      await _auth.signOut();
      throw ProfileCreationException(e);
    }

    await _auth.signOut();

    return userCredential;
  }
  /// Creates the Firebase Auth account, sets the display name, and writes
  /// the matching profile doc to `users/{uid}`.
  Future<UserCredential> signUp(
    String name,
    String email,
    String password,
    String requestedRole,
  ) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final uid = credential.user!.uid;

    try {
      await credential.user?.updateDisplayName(name.trim());

      await _firestore.collection(FirestorePaths.users).doc(uid).set({
        'name': name.trim(),
        'email': email.trim(),
        'role': kStatusPending,
        'status': kStatusPending,
        'requestedRole': requestedRole,
        'scope': '—',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e, st) {
      debugPrint('signUp: failed to write users/$uid profile doc: $e');
      debugPrintStack(stackTrace: st);
      await _auth.signOut();
      throw ProfileCreationException(e);
    }

    await _auth.signOut();

    return credential;
  }

  Future<void> signOut() => _auth.signOut();
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
    ref,
  ),
);