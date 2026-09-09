/// Domain layer for Administration > Users & Roles.
///
/// Pure Dart — no Flutter, no Firebase. Holds the status/role vocabulary
/// and the read model used by the admin table.

// ===========================================================================
// ACCOUNT STATUS
// ===========================================================================

/// Account lifecycle values.
///
/// These mirror `isValidStatus` in firestore.rules and the kStatus*
/// constants in features/auth/data/auth_repository.dart. Status is always
/// evaluated BEFORE role — a removed or rejected account keeps no
/// privileges even though its old role string is still on the document.
class AccountStatus {
  const AccountStatus._();

  /// Registered, awaiting an admin decision. No access.
  static const String pending = 'pending';

  /// Approved by an admin. Full access for their role.
  static const String active = 'active';

  /// Removed or rejected by an admin. No access.
  static const String deleted = 'deleted';

  static const Set<String> all = {pending, active, deleted};

  static bool isValid(String value) => all.contains(value);
}

// ===========================================================================
// ROLES
// ===========================================================================

/// Role vocabulary + the mapping between raw Firestore values and the
/// labels shown in the Users & Roles table.
///
/// The UI says "Researcher" where Firestore stores 'admin', so every
/// translation between the two lives here rather than being scattered
/// through the widgets.
class AdminRole {
  const AdminRole._();

  // ---- raw Firestore values -------------------------------------------
  static const String admin = 'admin';
  static const String adjudicator = 'adjudicator';
  static const String annotator = 'annotator';
  static const String pending = 'pending';

  // ---- UI labels -------------------------------------------------------
  static const String researcherLabel = 'Researcher';
  static const String adjudicatorLabel = 'Adjudicator';
  static const String annotatorLabel = 'Annotator';

  /// Roles an admin can assign, in menu order.
  static const List<String> assignableLabels = [
    researcherLabel,
    adjudicatorLabel,
    annotatorLabel,
  ];

  static String _titleCase(String s) {
    return s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
  }

  /// Raw Firestore role value -> UI label.
  static String labelFor(String role) {
    final normalized = role.toLowerCase();

    if (normalized == admin || normalized == 'researcher') {
      return researcherLabel;
    }

    return _titleCase(role);
  }

  /// UI label -> raw Firestore role value.
  static String valueFor(String label) {
    switch (label.toLowerCase()) {
      case 'researcher':
        return admin;
      case 'adjudicator':
        return adjudicator;
      case 'annotator':
        return annotator;
      default:
        return label.toLowerCase();
    }
  }
}

// ===========================================================================
// READ MODEL
// ===========================================================================

/// Read model for a row in the Users & Roles table.
class AdminUser {
  const AdminUser({
    required this.id,
    required this.name,
    required this.role,
    required this.status,
    required this.scope,
    this.requestedRole,
  });

  final String id;
  final String name;
  final String role;
  final String status;
  final String scope;
  final String? requestedRole;

  /// Status is checked before role to determine active privileges.
  bool get isActive => status == AccountStatus.active;

  bool get isDeleted => status == AccountStatus.deleted;

  /// A pending row is one awaiting an admin decision. A deleted account
  /// is never "pending" again, even though its role may still read
  /// 'pending' — rejection leaves the role untouched and only flips the
  /// status, so the status check has to come first here too.
  bool get isPending =>
      !isDeleted &&
      (status == AccountStatus.pending ||
          role.toLowerCase() == AdminRole.pending);

  /// The role label to show/pre-select for this row.
  String get displayRoleLabel {
    if (isPending) {
      return AdminRole.labelFor(
        requestedRole ?? AdminRole.assignableLabels.first,
      );
    }

    return AdminRole.labelFor(role);
  }

  /// Ordering rank: pending decisions first (they need attention), then
  /// active accounts, then deleted ones parked at the bottom.
  int get sortRank {
    if (isDeleted) return 2;
    if (isPending) return 0;
    return 1;
  }

  factory AdminUser.fromMap(String id, Map<String, dynamic> map) {
    return AdminUser(
      id: id,
      name: (map['name'] as String?) ??
          (map['displayName'] as String?) ??
          'Unnamed user',
      role: (map['role'] as String?) ?? '—',

      // Default to 'pending', never 'active' — a malformed or legacy doc
      // must fail closed, not grant access.
      status: ((map['status'] as String?) ?? AccountStatus.pending)
          .toLowerCase(),

      scope: (map['scope'] as String?) ?? '—',
      requestedRole: map['requestedRole'] as String?,
    );
  }
}