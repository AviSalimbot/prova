import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/header_banner.dart';
import '../../auth/data/auth_repository.dart';
import '../data/admin_users_repository.dart';
import '../domain/admin_user.dart';

/// Frontend module: "Administration" (Figure H-1) — Admin sub-view only.
///
/// Sub-tabs: Users & Roles (live), Dataset Registry, System & Storage,
/// Export & Audit (still placeholders).
class AdministrationScreen extends StatefulWidget {
  const AdministrationScreen({super.key});

  @override
  State<AdministrationScreen> createState() =>
      _AdministrationScreenState();
}

class _AdministrationScreenState extends State<AdministrationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _subTabController =
      TabController(length: 4, vsync: this);

  @override
  void dispose() {
    _subTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const ProvaHeaderBanner(
              pageTitle: 'Admin',
              stage: PipelineStage.notApplicable,
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TabBar(
                  controller: _subTabController,
                  labelColor: ProvaColors.green,
                  unselectedLabelColor: ProvaColors.subtitleGray,
                  indicatorColor: ProvaColors.green,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: const TextStyle(fontSize: 13),
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  dividerColor: Colors.transparent,
                  dividerHeight: 0,
                  tabs: const [
                    Tab(text: 'Users & Roles'),
                    Tab(text: 'Dataset Registry'),
                    Tab(text: 'System & Storage'),
                    Tab(text: 'Export & Audit'),
                  ],
                ),
              ),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Divider(
                height: 1,
                color: ProvaColors.dividerGray,
              ),
            ),

            Expanded(
              child: TabBarView(
                controller: _subTabController,
                children: const [
                  _UsersAndRolesPanel(),
                  _EmptyPanel(),
                  _EmptyPanel(),
                  _EmptyPanel(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

// ===========================================================================
// TABLE METRICS
// ===========================================================================

/// Shared layout constants, so the header and the rows can't drift out
/// of alignment.
const double _kNameExtraInset = 12;
const double _kRoleExtraInset = 10;
const double _kRoleHeaderInset = 4;
const double _kRemoveExtraInset = 12;

const double _kActionColumnWidth = 80;

const int _kNameFlex = 3;
const int _kRoleFlex = 2;
const int _kScopeFlex = 3;
const int _kStatusFlex = 2;

/// Opacity applied to a soft-deleted row so it reads as archived without
/// disappearing from the audit list.
const double _kDeletedRowOpacity = 0.55;

// ===========================================================================
// USERS & ROLES PANEL
// ===========================================================================

class _UsersAndRolesPanel extends ConsumerWidget {
  const _UsersAndRolesPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(adminUsersStreamProvider);
    final currentUid = ref.watch(authStateProvider).value?.uid;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: ProvaColors.dividerGray),
        ),
        child: usersAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          ),

          error: (error, _) => Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Text('Failed to load users: $error'),
            ),
          ),

          data: (users) => _buildTable(context, ref, users, currentUid),
        ),
      ),
    );
  }

  Widget _buildTable(
    BuildContext context,
    WidgetRef ref,
    List<AdminUser> users,
    String? currentUid,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(36, 20, 36, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Users & Roles',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),

              ElevatedButton.icon(
                onPressed: () {
                  // TODO: wire up invite-user flow.
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ProvaColors.green,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Invite user'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        if (users.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 36,
              vertical: 24,
            ),
            child: Text(
              'No users found.',
              style: TextStyle(
                color: ProvaColors.subtitleGray,
                fontSize: 13,
              ),
            ),
          )
        else
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _UsersTableHeader(),

                  const Divider(
                    height: 1,
                    color: ProvaColors.dividerGray,
                  ),

                  ...users.map(
                    (u) => Column(
                      children: [
                        _UsersTableRow(
                          key: ValueKey(u.id),
                          user: u,
                          isSelf: u.id == currentUid,
                          onRoleChanged: (newRole) => _run(
                            context,
                            ref,
                            (repo) => repo.changeRole(u, newRole),
                            '${u.name} is now '
                            '${AdminRole.labelFor(newRole)}.',
                          ),
                          onRoleAccepted: (newRole) => _run(
                            context,
                            ref,
                            (repo) => repo.acceptRole(u, newRole),
                            '${u.name} approved as '
                            '${AdminRole.labelFor(newRole)}.',
                          ),
                          onRoleRejected: () => _run(
                            context,
                            ref,
                            (repo) => repo.rejectRole(u),
                            "${u.name}'s request was rejected.",
                          ),
                          onRemove: () => _run(
                            context,
                            ref,
                            (repo) => repo.removeUser(u),
                            '${u.name} was removed.',
                          ),
                        ),

                        const Divider(
                          height: 1,
                          color: ProvaColors.dividerGray,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Runs a repository write and reports the outcome via a snackbar.
  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function(AdminUsersRepository repo) action,
    String successMessage,
  ) async {
    try {
      await action(ref.read(adminUsersRepositoryProvider));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
      }
    } on FirebaseException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Action failed: ${e.message ?? e.code}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }
}

// ===========================================================================
// TABLE HEADER
// ===========================================================================

class _UsersTableHeader extends StatelessWidget {
  const _UsersTableHeader();

  static const _headerStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: ProvaColors.subtitleGray,
    letterSpacing: 0.5,
  );

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: _kNameFlex,
            child: Padding(
              padding: EdgeInsets.only(left: _kNameExtraInset),
              child: Text('NAME', style: _headerStyle),
            ),
          ),

          Expanded(
            flex: _kRoleFlex,
            child: Padding(
              padding: EdgeInsets.only(left: _kRoleHeaderInset),
              child: Text('ROLE', style: _headerStyle),
            ),
          ),

          Expanded(
            flex: _kScopeFlex,
            child: Text('SCOPE', style: _headerStyle),
          ),

          Expanded(
            flex: _kStatusFlex,
            child: Text('STATUS', style: _headerStyle),
          ),

          SizedBox(width: _kActionColumnWidth),
        ],
      ),
    );
  }
}

// ===========================================================================
// TABLE ROW
// ===========================================================================

class _UsersTableRow extends StatefulWidget {
  const _UsersTableRow({
    super.key,
    required this.user,
    required this.isSelf,
    required this.onRoleChanged,
    required this.onRoleAccepted,
    required this.onRoleRejected,
    required this.onRemove,
  });

  final AdminUser user;
  final bool isSelf;
  final ValueChanged<String> onRoleChanged;
  final ValueChanged<String> onRoleAccepted;
  final VoidCallback onRoleRejected;
  final VoidCallback onRemove;

  @override
  State<_UsersTableRow> createState() => _UsersTableRowState();
}

class _UsersTableRowState extends State<_UsersTableRow> {
  late String _displayRole = widget.user.displayRoleLabel;

  @override
  void didUpdateWidget(covariant _UsersTableRow oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Keep the locally-optimistic selection in sync when the underlying
    // document changes (e.g. another admin edits the same user).
    if (oldWidget.user.role != widget.user.role ||
        oldWidget.user.status != widget.user.status) {
      _displayRole = widget.user.displayRoleLabel;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final isDeleted = user.isDeleted;

    final items = {
      _displayRole,
      ...AdminRole.assignableLabels,
    }.toList();

    return Opacity(
      // Deleted rows stay visible for auditing but are visually muted.
      opacity: isDeleted ? _kDeletedRowOpacity : 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: _kNameFlex,
              child: Padding(
                padding: const EdgeInsets.only(left: _kNameExtraInset),
                child: Text(
                  widget.isSelf ? '${user.name} (you)' : user.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color:
                        isDeleted ? ProvaColors.subtitleGray : null,
                  ),
                ),
              ),
            ),

            Expanded(
              flex: _kRoleFlex,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _buildRoleCell(user, isDeleted, items),
              ),
            ),

            Expanded(
              flex: _kScopeFlex,
              child: Text(
                user.scope,
                style: TextStyle(
                  fontSize: 13,
                  color: isDeleted ? ProvaColors.subtitleGray : null,
                ),
              ),
            ),

            Expanded(
              flex: _kStatusFlex,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _StatusCell(status: user.status),
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(right: _kRemoveExtraInset),
              child: SizedBox(
                width: _kActionColumnWidth,
                child: TextButton(
                  // Already-deleted accounts (and your own) can't be
                  // removed again.
                  onPressed: (widget.isSelf || isDeleted)
                      ? null
                      : _confirmRemove,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                    disabledForegroundColor:
                        ProvaColors.subtitleGray.withOpacity(0.5),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Remove'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleCell(
    AdminUser user,
    bool isDeleted,
    List<String> items,
  ) {
    // A deleted account has no actionable role: render the last known
    // role as static gray text — no dropdown, no Accept/Reject.
    if (isDeleted) {
      return Padding(
        padding: const EdgeInsets.only(left: _kRoleExtraInset),
        child: Text(
          AdminRole.labelFor(user.role),
          style: const TextStyle(
            fontSize: 13,
            color: ProvaColors.subtitleGray,
          ),
        ),
      );
    }

    if (user.isPending) {
      return _PendingRoleCell(
        roleLabel: _displayRole,
        onAccept: () => widget.onRoleAccepted(_displayRole),
        onReject: _confirmReject,
      );
    }

    return _RoleSelector(
      value: _displayRole,
      items: items,
      onChanged: (newRole) {
        if (newRole == _displayRole) return;

        if (widget.isSelf) {
          _denySelfAction('You cannot change your own role.');
          return;
        }

        _confirmRoleChange(newRole);
      },
    );
  }

  void _denySelfAction(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: confirmColor,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );

    return result == true;
  }

  Future<void> _confirmRoleChange(String newRole) async {
    final confirmed = await _confirm(
      title: 'Change role?',
      body: "Change ${widget.user.name}'s role "
          "from $_displayRole to $newRole? "
          "This changes what they can access immediately.",
      confirmLabel: 'Change role',
      confirmColor: ProvaColors.green,
    );

    if (confirmed && mounted) {
      setState(() {
        _displayRole = newRole;
      });

      widget.onRoleChanged(newRole);
    }
  }

  Future<void> _confirmReject() async {
    final confirmed = await _confirm(
      title: 'Reject request?',
      body: "Reject ${widget.user.name}'s access request? "
          "Their account will be marked as deleted.",
      confirmLabel: 'Reject',
      confirmColor: Colors.red.shade700,
    );

    if (confirmed && mounted) {
      widget.onRoleRejected();
    }
  }

  Future<void> _confirmRemove() async {
    final confirmed = await _confirm(
      title: 'Remove user?',
      body: "Remove ${widget.user.name}? Their status will "
          "be set to deleted and they will lose access immediately.",
      confirmLabel: 'Remove',
      confirmColor: Colors.red.shade700,
    );

    if (confirmed && mounted) {
      widget.onRemove();
    }
  }
}

// ===========================================================================
// PENDING ROLE CELL
// ===========================================================================

/// Role cell for an account awaiting an admin decision: shows the
/// requested role plus Accept / Reject actions.
class _PendingRoleCell extends StatelessWidget {
  const _PendingRoleCell({
    required this.roleLabel,
    required this.onAccept,
    required this.onReject,
  });

  final String roleLabel;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: _kRoleExtraInset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            roleLabel,
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: Colors.orange.shade800,
            ),
          ),

          const SizedBox(height: 4),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DecisionButton(
                label: 'Accept',
                color: ProvaColors.green,
                onTap: onAccept,
              ),

              const SizedBox(width: 4),

              _DecisionButton(
                label: 'Reject',
                color: Colors.red.shade700,
                onTap: onReject,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Accept / Reject action button.
class _DecisionButton extends StatefulWidget {
  const _DecisionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_DecisionButton> createState() => _DecisionButtonState();
}

class _DecisionButtonState extends State<_DecisionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,

      onEnter: (_) {
        setState(() {
          _hovered = true;
        });
      },

      onExit: (_) {
        setState(() {
          _hovered = false;
        });
      },

      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.color.withOpacity(0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: widget.color,
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// ROLE SELECTOR
// ===========================================================================

/// Compact role selector.
///
/// The closed selector intentionally does NOT use PopupMenuButton. This
/// prevents Flutter's internal Material hover/pressed layer from creating
/// an additional rectangular box.
///
/// Closed selector — normal: transparent; enter/hover/press: #F0F0F0;
/// no border; 8px corner radius.
class _RoleSelector extends StatefulWidget {
  const _RoleSelector({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  State<_RoleSelector> createState() => _RoleSelectorState();
}

class _RoleSelectorState extends State<_RoleSelector> {
  bool _hovered = false;

  /// ONLY color used for the closed selector's mouse-over state.
  static const Color _selectorGray = Color(0xFFF0F0F0);

  static const Color _selectedGray = Color(0xFFE0E0E0);

  static const Color _menuHoverGray = Color(0xFFF2F2F2);

  Future<void> _showRoleMenu() async {
    final RenderBox button = context.findRenderObject() as RenderBox;

    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    final Offset topLeft = button.localToGlobal(
      Offset.zero,
      ancestor: overlay,
    );

    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromLTWH(
        topLeft.dx,
        topLeft.dy,
        button.size.width,
        button.size.height,
      ),
      Offset.zero & overlay.size,
    );

    final selected = await showMenu<String>(
      context: context,

      position: position.shift(const Offset(0, 34)),

      elevation: 3,

      color: Colors.white,

      surfaceTintColor: Colors.transparent,

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),

      items: widget.items.map((role) {
        return PopupMenuItem<String>(
          value: role,

          height: 38,

          padding: EdgeInsets.zero,

          child: _RoleMenuOption(
            label: role,
            isSelected: role == widget.value,
            selectedColor: _selectedGray,
            hoverColor: _menuHoverGray,
          ),
        );
      }).toList(),
    );

    if (selected != null && mounted) {
      widget.onChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,

      /// ENTER and HOVER intentionally use the same visual state.
      onEnter: (_) {
        if (!_hovered) {
          setState(() {
            _hovered = true;
          });
        }
      },

      onExit: (_) {
        if (_hovered) {
          setState(() {
            _hovered = false;
          });
        }
      },

      child: GestureDetector(
        behavior: HitTestBehavior.opaque,

        /// Clicking anywhere on the selector opens the role menu.
        onTap: _showRoleMenu,

        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: _hovered ? _selectorGray : Colors.transparent,
            borderRadius: BorderRadius.circular(8),

            /// Intentionally NO border.
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.value,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(width: 6),

              const Icon(
                Icons.keyboard_arrow_down,
                size: 16,
                color: ProvaColors.subtitleGray,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Individual option inside the role menu.
class _RoleMenuOption extends StatefulWidget {
  const _RoleMenuOption({
    required this.label,
    required this.isSelected,
    required this.selectedColor,
    required this.hoverColor,
  });

  final String label;
  final bool isSelected;
  final Color selectedColor;
  final Color hoverColor;

  @override
  State<_RoleMenuOption> createState() => _RoleMenuOptionState();
}

class _RoleMenuOptionState extends State<_RoleMenuOption> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor;

    if (widget.isSelected) {
      backgroundColor = widget.selectedColor;
    } else if (_hovered) {
      backgroundColor = widget.hoverColor;
    } else {
      backgroundColor = Colors.white;
    }

    return MouseRegion(
      onEnter: (_) {
        setState(() {
          _hovered = true;
        });
      },

      onExit: (_) {
        setState(() {
          _hovered = false;
        });
      },

      child: Container(
        width: double.infinity,

        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 9,
        ),

        decoration: BoxDecoration(color: backgroundColor),

        child: Text(
          widget.label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// STATUS CELL
// ===========================================================================

/// Status cell.
///
/// Active and pending accounts get a tinted pill. A DELETED account is
/// deliberately rendered as plain gray text with NO chip — the pill is a
/// "this account is live" affordance, and a removed/rejected account
/// shouldn't carry one.
class _StatusCell extends StatelessWidget {
  const _StatusCell({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    if (status == AccountStatus.deleted) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Text(
          'Deleted',
          style: TextStyle(
            color: ProvaColors.subtitleGray,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      );
    }

    final isActive = status == AccountStatus.active;

    final color =
        isActive ? ProvaColors.green : ProvaColors.subtitleGray;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isActive ? 'Active' : 'Pending',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}