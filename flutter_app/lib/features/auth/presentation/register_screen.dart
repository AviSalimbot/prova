import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/auth_repository.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Labels shown in the dropdown map to the actual role value sent to the
  // backend via _roleValues below — the two are kept separate so the UI
  // copy can change without touching what gets persisted.
  //
  // IMPORTANT: the value selected here is only ever a REQUEST. It is
  // persisted as `requestedRole`; the account itself is always created
  // with role 'pending' + status 'pending' (the only shape the Firestore
  // rules allow a client to self-create). An admin approves it from
  // Administration > Users & Roles.
  final List<String> _roles = const [
    'Researcher / Operator',
    'Course Instructor',
    'Annotator',
  ];

  static const Map<String, String> _roleValues = {
    'Researcher / Operator': 'admin',
    'Course Instructor': 'adjudicator',
    'Annotator': 'annotator',
  };

  String _selectedRole = 'Researcher / Operator';

  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please fill in every field.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(authRepositoryProvider).signUp(
            name,
            email,
            password,
            // Sent as the REQUESTED role — stored in `requestedRole`,
            // not as the account's effective role.
            _roleValues[_selectedRole]!,
          );

      // signUp() already signs the new account back out — it can't be
      // used until its role is approved. Route to login with a notice
      // instead of relying on authStateProvider to redirect into the app.
      if (!mounted) return;

      ref.read(pendingNoticeProvider.notifier).state =
          'Account created — pending approval\n\n'
          'Your account has been created successfully. An administrator '
          'needs to activate it before you can sign in. You\'ll receive '
          'an email as soon as your account is ready — this usually '
          'doesn\'t take long. Thanks for your patience.';

      context.go('/login');
    } on FirebaseAuthException catch (e) {
      // Friendlier copy than the raw exception's toString().
      setState(() => _error = e.message ?? e.code);
    } on FirebaseException catch (e) {
      setState(
        () => _error =
            'Account was created, but saving the user profile failed: '
            '${e.message ?? e.code}',
      );
    } on Exception catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: Colors.grey, fontSize: 13),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD9DEE3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD9DEE3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF3A7A4E), width: 1.5),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F7),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(36),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Same wordmark block as LoginScreen
                  Text(
                    'PROVA',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1A2433),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Cognitive Error Classifier',
                    style: GoogleFonts.inter(color: Colors.grey, fontSize: 11),
                  ),
                  const SizedBox(height: 18),

                  // Heading
                  Text(
                    'Create account',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A2433),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Name
                  _label('Name'),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _nameController,
                    style: GoogleFonts.inter(fontSize: 12),
                    decoration: _fieldDecoration('Full name'),
                    textCapitalization: TextCapitalization.words,
                    enabled: !_loading,
                  ),
                  const SizedBox(height: 14),

                  // Email
                  _label('Email'),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _emailController,
                    style: GoogleFonts.inter(fontSize: 12),
                    decoration: _fieldDecoration('you@example.com'),
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_loading,
                  ),
                  const SizedBox(height: 14),

                  // Password
                  _label('Password'),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _passwordController,
                    style: GoogleFonts.inter(fontSize: 12),
                    decoration: _fieldDecoration('••••••••'),
                    obscureText: true,
                    enabled: !_loading,
                    onSubmitted: (_) {
                      if (!_loading) _submit();
                    },
                  ),
                  const SizedBox(height: 14),

                  // Role dropdown
                  _label('Role'),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    isExpanded: true,

                    // Smaller text inside the closed role field
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF1A2433),
                    ),

                    // Rounded popup dropdown
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(10),

                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Color(0xFFD9DEE3),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Color(0xFFD9DEE3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Color(0xFF3A7A4E),
                          width: 1.5,
                        ),
                      ),
                    ),

                    // Smaller text in the popup options
                    items: _roles
                        .map(
                          (role) => DropdownMenuItem<String>(
                            value: role,
                            child: Text(
                              role,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF1A2433),
                              ),
                            ),
                          ),
                        )
                        .toList(),

                    onChanged: _loading
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _selectedRole = value);
                            }
                          },
                  ),

                  const SizedBox(height: 6),

                  // Makes it explicit that the dropdown is a request, not
                  // an assignment — matches what the rules actually do.
                  Text(
                    'Roles require administrator approval before your '
                    'account becomes active.',
                    style: GoogleFonts.inter(
                      color: Colors.grey,
                      fontSize: 10.5,
                      height: 1.35,
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: GoogleFonts.inter(
                        color: Colors.red,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Create account button — same shape/weight as Sign in
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF3A7A4E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Create account',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // "Already have an account? Sign in" -> back to login
                  Center(
                    child: RichText(
                      text: TextSpan(
                        style: GoogleFonts.inter(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                        children: [
                          const TextSpan(text: 'Already have an account? '),
                          TextSpan(
                            text: 'Sign in',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF3A7A4E),
                              fontWeight: FontWeight.w700,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                if (!_loading) context.go('/login');
                              },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}