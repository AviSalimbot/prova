// lib/features/auth/presentation/register_screen.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../assessments/data/drive_auth_service.dart';
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
  //
  // This applies identically whether the account is created via
  // email/password (_submit) or Google (_startGoogleSignUp /
  // _completeGoogleSignUp) — both paths read _selectedRole at submit
  // time and send it as the requested role. There's no path that
  // creates an account without one, since the dropdown always has a
  // value (_selectedRole starts non-null and the UI never lets it
  // become null).
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

  // Web-only: fires once the rendered Google iframe button completes a
  // sign-in, since that button has no onPressed callback of its own.
  StreamSubscription<bool>? _googleSignInSub;

  // Gates rendering the Google button until the SDK is initialized —
  // required on web before the iframe button has anything to attach
  // to. ensureReady() never prompts anything itself, unlike
  // trySilentSignIn(), so this is safe to fire immediately.
  late final Future<void> _driveReadyFuture;

  @override
  void initState() {
    super.initState();
    final driveAuth = ref.read(driveAuthServiceProvider);
    _driveReadyFuture = driveAuth.ensureReady();

    if (kIsWeb) {
      _googleSignInSub = driveAuth.onSignInChanged.listen((signedIn) {
        if (signedIn) _completeGoogleSignUp();
      });
    }
  }

  @override
  void dispose() {
    _googleSignInSub?.cancel();
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

      _goToPendingLogin();
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

  /// Native/desktop path: pops Google's interactive account picker,
  /// then completes sign-up with the currently selected requested role.
  /// Mirrors LoginScreen's _startGoogleSignIn shape, but calls
  /// signUpWithGoogle (which errors on an already-existing profile
  /// instead of silently falling through to a pending-notice sign-in).
  Future<void> _startGoogleSignUp() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final driveAuth = ref.read(driveAuthServiceProvider);
      await driveAuth.signInInteractively();
      await ref.read(authRepositoryProvider).signUpWithGoogle(
            _roleValues[_selectedRole]!,
            driveAuth,
          );
      _goToPendingLogin();
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = e.message ?? e.code);
    } on FirebaseException catch (e) {
      if (mounted) {
        setState(
          () => _error =
              'Account was created, but saving the user profile failed: '
              '${e.message ?? e.code}',
        );
      }
    } on Exception catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Web path: called once the rendered Google button's own sign-in
  /// completes (see onSignInChanged listener in initState) — the
  /// account is already authenticated by that point, so this just runs
  /// the Firebase + profile-creation half of the flow with the
  /// currently selected requested role.
  Future<void> _completeGoogleSignUp() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final driveAuth = ref.read(driveAuthServiceProvider);
      await ref.read(authRepositoryProvider).signUpWithGoogle(
            _roleValues[_selectedRole]!,
            driveAuth,
          );
      _goToPendingLogin();
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = e.message ?? e.code);
    } on FirebaseException catch (e) {
      if (mounted) {
        setState(
          () => _error =
              'Account was created, but saving the user profile failed: '
              '${e.message ?? e.code}',
        );
      }
    } on Exception catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goToPendingLogin() {
    // signUp()/signUpWithGoogle() already sign the new account back out
    // — it can't be used until its role is approved. Route to login
    // with a notice instead of relying on authStateProvider to redirect
    // into the app.
    if (!mounted) return;

    ref.read(pendingNoticeProvider.notifier).state =
        'Account created — pending approval\n\n'
        'Your account has been created successfully. An administrator '
        'needs to activate it before you can sign in. You\'ll receive '
        'an email as soon as your account is ready — this usually '
        'doesn\'t take long. Thanks for your patience.';

    context.go('/login');
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

  /// Mirrors LoginScreen's _buildGoogleSection: renders Google's own
  /// iframe button on web (completion handled by the onSignInChanged
  /// listener in initState) or a normal OutlinedButton on native/desktop
  /// that drives the interactive picker directly.
  ///
  /// NOTE: passes `text: 'signup_with'` so the rendered Google button
  /// reads "Sign up with Google" instead of "Sign in with Google" (the
  /// screenshot showed the sign-in label here). This assumes
  /// buildSignInButton() accepts a `text` parameter that's forwarded to
  /// Google Identity Services' renderButton `text` option (valid values:
  /// 'signin_with', 'signup_with', 'continue_with', 'signin'). If
  /// buildSignInButton() doesn't yet take that parameter, it needs a
  /// small addition in drive_auth_service.dart — happy to wire that up
  /// if you share that file.
  Widget _buildGoogleSection() {
    return FutureBuilder<void>(
      future: _driveReadyFuture,
      builder: (context, snapshot) {
        final ready = snapshot.connectionState == ConnectionState.done;

        if (!ready) {
          return const SizedBox(
            height: 40,
            child: Center(
              child: SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        if (kIsWeb) {
          return Center(
            child: ref.read(driveAuthServiceProvider).buildSignInButton(
                  text: 'signup_with',
                ),
          );
        }

        return SizedBox(
          width: double.infinity,
          height: 40,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1A2433),
              side: const BorderSide(color: Color(0xFFD9DEE3)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _loading ? null : _startGoogleSignUp,
            icon: _loading
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF1A2433),
                    ),
                  )
                : Image.network(
                    'https://www.google.com/favicon.ico',
                    width: 16,
                    height: 16,
                  ),
            label: Text(
              'Sign up with Google',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A2433),
              ),
            ),
          ),
        );
      },
    );
  }

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

                  // Role dropdown — required for BOTH the email/password
                  // path and the Google path below. It's placed before
                  // both submit actions and defaults to a real value
                  // (never null), so there's no way to create an account
                  // — via either method — without a requested role.
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

                  const SizedBox(height: 16),

                  // "or" divider between the email/password flow and
                  // Google — both still gate on the same Role dropdown
                  // above, so this isn't a way to skip setting a role.
                  Row(
                    children: [
                      Expanded(
                        child: Divider(color: Colors.grey.shade300),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          'or',
                          style: GoogleFonts.inter(
                            color: Colors.grey,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(color: Colors.grey.shade300),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Continue with Google — creates the account with
                  // whatever role is currently selected above, same as
                  // the email/password button does. Delegates to
                  // _buildGoogleSection so web gets the real Google
                  // iframe button (same as LoginScreen) instead of a
                  // button that can't actually complete auth, and shows
                  // the sign-up-flavored label.
                  _buildGoogleSection(),

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