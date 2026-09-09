import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/firestore_paths.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/admin_user.dart';

/// All Firestore access for the Administration > Users & Roles panel.
///
/// Every write re-sends BOTH `role` and `status`, because the Firestore
/// update rule validates `request.resource.data.role` and `.status` on
/// each write — omitting either makes the field read as null and the
/// write is denied.
class AdminUsersRepository {
  AdminUsersRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(FirestorePaths.users);

  /// ALL users, including soft-deleted ones, so the admin keeps a
  /// complete audit view of every account that has ever registered.
  /// Sorted client-side by [AdminUser.sortRank] then name.
  Stream<List<AdminUser>> watchUsers() {
    return _users.snapshots().map((snapshot) {
      final users = snapshot.docs
          .map((d) => AdminUser.fromMap(d.id, d.data()))
          .toList();

      users.sort((a, b) {
        final byRank = a.sortRank.compareTo(b.sortRank);
        if (byRank != 0) return byRank;

        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      return users;
    });
  }

  Future<void> _write(String uid, Map<String, Object?> data) {
    return _users.doc(uid).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Change role — updates the role while preserving status.
  Future<void> changeRole(AdminUser user, String newRoleLabel) {
    return _write(user.id, {
      'role': AdminRole.valueFor(newRoleLabel),
      'status': user.status,
    });
  }

  /// Accept role — assigns the selected role, activates the account, and
  /// clears the requestedRole placeholder.
  Future<void> acceptRole(AdminUser user, String roleLabel) {
    return _write(user.id, {
      'role': AdminRole.valueFor(roleLabel),
      'status': AccountStatus.active,
      'requestedRole': FieldValue.delete(),
    });
  }

  /// Reject role — soft-deletes the registration request.
  Future<void> rejectRole(AdminUser user) {
    return _write(user.id, {
      'role': user.role,
      'status': AccountStatus.deleted,
      'requestedRole': FieldValue.delete(),
    });
  }

  /// Remove user — soft-deletes an active user.
  Future<void> removeUser(AdminUser user) {
    return _write(user.id, {
      'role': user.role,
      'status': AccountStatus.deleted,
    });
  }
}

final adminUsersRepositoryProvider = Provider<AdminUsersRepository>(
  (ref) => AdminUsersRepository(ref.watch(firestoreProvider)),
);

final adminUsersStreamProvider = StreamProvider<List<AdminUser>>(
  (ref) => ref.watch(adminUsersRepositoryProvider).watchUsers(),
);