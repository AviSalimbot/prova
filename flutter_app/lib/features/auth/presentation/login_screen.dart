// lib/features/auth/presentation/login_screen.dart
import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../assessments/data/drive_auth_service.dart';
import '../../assessments/presentation/drive_connect.dart';
import '../data/auth_repository.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  bool _loading = false;
  bool _connectingDrive = false;

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
        if (signedIn) _completeGoogleSignIn();
      });
    }
  }

  @override
  void dispose() {
    _googleSignInSub?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitPassword() async {
    ref.read(pendingNoticeProvider.notifier).state = null;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref.read(authRepositoryProvider).signIn(
            _emailController.text.trim(),
            _passwordController.text,
          );

      // Email/password sign-in doesn't touch Drive on its own — chain
      // the same connect step Google sign-in gets for free, so both
      // paths land in the app already Drive-connected where possible.
      if (mounted) {
        setState(() => _connectingDrive = true);
        await ensureDriveConnected(context, ref);
      }
    } on Exception catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _connectingDrive = false;
        });
      }
    }
  }

  /// Native/desktop path: pops Google's interactive account picker,
  /// then completes the unified sign-in.
  Future<void> _startGoogleSignIn() async {
    ref.read(pendingNoticeProvider.notifier).state = null;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final driveAuth = ref.read(driveAuthServiceProvider);
      await driveAuth.signInInteractively();
      await ref.read(authRepositoryProvider).signInWithGoogle(driveAuth);
    } on Exception catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Web path: called once the rendered Google button's own sign-in
  /// completes (see onSignInChanged listener in initState) — the
  /// account is already authenticated by that point, so this just
  /// runs the Firebase + profile-approval half of the flow.
  Future<void> _completeGoogleSignIn() async {
    if (!mounted) return;
    ref.read(pendingNoticeProvider.notifier).state = null;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final driveAuth = ref.read(driveAuthServiceProvider);
      await ref.read(authRepositoryProvider).signInWithGoogle(driveAuth);
    } on Exception catch (e) {
      if (mounted) setState(() => _error = e.toString());
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
          // Google's own rendered button (an iframe) — completion is
          // handled by the onSignInChanged listener set up in
          // initState, not by anything here.
          return Center(
            child: ref.read(driveAuthServiceProvider).buildSignInButton(),
          );
        }

        return SizedBox(
          width: double.infinity,
          height: 40,
          child: OutlinedButton.icon(
            onPressed: _loading ? null : _startGoogleSignIn,
            icon: const Icon(Icons.login, size: 18),
            label: Text(
              'Continue with Google',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1A2433),
              side: const BorderSide(color: Color(0xFFD9DEE3)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Reactive, not a one-shot read: this rebuilds the moment
    // RegisterScreen sets the notice, even if this LoginScreen was
    // already on screen (e.g. from an earlier router redirect) rather
    // than freshly built by RegisterScreen's own navigation call.
    final notice = ref.watch(pendingNoticeProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F7),
      body: Center(
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
                Text(
                  'Sign in',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A2433),
                  ),
                ),
                const SizedBox(height: 14),

                // Email/password fields now come FIRST, matching
                // RegisterScreen's layout (fields -> primary submit ->
                // divider -> Google section).
                Text(
                  'Email',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700, fontSize: 12),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _emailController,
                  style: GoogleFonts.inter(fontSize: 14),
                  decoration: _fieldDecoration('you@example.com'),
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_loading,
                ),
                const SizedBox(height: 14),
                Text(
                  'Password',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700, fontSize: 12),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _passwordController,
                  style: GoogleFonts.inter(fontSize: 14),
                  decoration: _fieldDecoration('••••••••'),
                  obscureText: true,
                  enabled: !_loading,
                  onSubmitted: (_) {
                    if (!_loading) _submitPassword();
                  },
                ),
                if (_error != null || notice != null) ...[
                  const SizedBox(height: 8),
                  Text(_error ?? notice!,
                      style: GoogleFonts.inter(
                          color: const Color(0xFFB86A1E), fontSize: 11)),
                ],
                const SizedBox(height: 16),

                // Primary "Sign in" button
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
                    onPressed: _loading ? null : _submitPassword,
                    child: _loading
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              if (_connectingDrive) ...[
                                const SizedBox(width: 10),
                                Text(
                                  'Connecting Drive…',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ],
                          )
                        : Text(
                            'Sign in',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // "or" divider — now sits between the email/password
                // flow and Google, same position as RegisterScreen.
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'or',
                        style: GoogleFonts.inter(color: Colors.grey, fontSize: 11),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade300)),
                  ],
                ),

                const SizedBox(height: 16),

                // Google sign-in section moved below the primary button.
                _buildGoogleSection(),

                const SizedBox(height: 12),
                Center(
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.inter(color: Colors.grey, fontSize: 12),
                      children: [
                        const TextSpan(text: 'No account? '),
                        TextSpan(
                          text: 'Sign up',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF3A7A4E),
                            fontWeight: FontWeight.w700,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => context.go('/register'),
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
    );
  }
}