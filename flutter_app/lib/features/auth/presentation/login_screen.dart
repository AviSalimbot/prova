import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

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

  Future<void> _submit() async {
    // Clear any pending-approval notice as soon as the person tries to
    // sign in again — if they're still not approved, signIn() throws
    // AccountPendingException and _error will show the same message.
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
      // Router redirects automatically once authStateProvider emits.
      // If the account's role is still 'pending', signIn() itself signs
      // the session back out and throws AccountPendingException, so
      // authStateProvider never emits and we fall into the catch below.
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
                ),
                if (_error != null || notice != null) ...[
                  const SizedBox(height: 8),
                  Text(_error ?? notice!,
                      style: GoogleFonts.inter(
                          color: const Color(0xFFB86A1E), fontSize: 11)),
                ],
                const SizedBox(height: 16),
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
                            'Sign in',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
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
                            // CHANGED: was a no-op TODO, now routes to /register
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