import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/entities.dart';
import '../../../services/firestore_paths.dart';

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
/// right after registering, or by [AuthRepository.signIn] when a
/// still-pending account tries to sign in. LoginScreen watches this
/// reactively (not a one-time read) so it updates correctly even if the
/// screen was rebuilt by a router redirect partway through a sign-in
/// attempt.
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
  ///
  /// If the account isn't usable the session is immediately signed back
  /// out and a notice is written to [pendingNoticeProvider] directly from
  /// here (via the provider's own Ref, not the calling widget's) rather
  /// than relying on the caller to catch the thrown exception and
  /// setState. This matters because signInWithEmailAndPassword flips
  /// Firebase Auth state to "signed in" the instant it succeeds — before
  /// this check runs — which can cause a router redirect to the
  /// authenticated area and back, disposing the LoginScreen that started
  /// this call before the exception it's awaiting ever arrives. Writing
  /// the notice here means whichever LoginScreen is mounted when this
  /// finishes will show it, regardless of what happened to the original.
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

    // 1. Explicitly removed or rejected.
    if (doc.exists && status == kStatusDeleted) {
      await _auth.signOut();
      _ref.read(pendingNoticeProvider.notifier).state =
          AccountDisabledException().toString();
      throw AccountDisabledException();
    }

    // 2. Missing doc, not yet approved, or an unrecognised role.
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

  /// Creates the Firebase Auth account, sets the display name, and writes
  /// the matching profile doc to `users/{uid}`.
  ///
  /// IMPORTANT: the live `role` field is always written as `'pending'`
  /// AND `status` as `'pending'` — never the role the user requested at
  /// sign-up. This matches the Firestore security rule, which only
  /// permits a brand-new user to create their own profile doc when BOTH
  /// `role == 'pending'` and `status == 'pending'`. That solves the
  /// bootstrapping problem (a user can't already be an admin before their
  /// profile doc exists) while preventing any client from self-assigning
  /// a privileged role (admin / annotator / adjudicator).
  ///
  /// Omitting `status` here is what caused the earlier
  /// `permission-denied` on registration: the rule compares
  /// `request.resource.data.status == 'pending'`, and a missing field
  /// reads as null. Both fields must be present on every write to this
  /// collection.
  ///
  /// `requestedRole` is stored alongside them purely so an admin (or an
  /// automated promotion function, for roles that don't require manual
  /// approval) can see what they asked for. Administration > Users &
  /// Roles reads it to pre-fill the pending row's Accept/Reject cell, and
  /// deletes it on approval.
  ///
  /// The account is signed back out right after the profile doc is
  /// written, since a newly-created account must not be treated as
  /// authenticated until its role is approved — the caller should route
  /// to the login screen afterwards, not into the app.
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

        // Effective privileges: NONE until an admin approves. Both of
        // these are hard-coded and are validated verbatim by the rules.
        'role': kStatusPending,
        'status': kStatusPending,

        // What the user asked for — advisory only, never granted here.
        'requestedRole': requestedRole,

        'scope': '—',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e, st) {
      // The Auth account already exists at this point even though the
      // profile write failed — surface this loudly rather than letting it
      // look like sign-up silently "worked".
      debugPrint('signUp: failed to write users/$uid profile doc: $e');
      debugPrintStack(stackTrace: st);

      // Still sign out, so a half-provisioned account can never sit
      // signed in and slip past the router on the next rebuild.
      await _auth.signOut();

      throw ProfileCreationException(e);
    }

    // Don't leave the newly-created account signed in — it can't be used
    // until an admin (or the auto-promotion function) approves the role.
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