import 'package:flutter/material.dart';

/// Non-web platforms never call this — buildSignInButton() branches on
/// kIsWeb before reaching here — but the conditional import below still
/// needs a matching symbol (including the [text] parameter) to compile
/// against on those platforms.
Widget renderGoogleSignInButton({String text = 'signin_with'}) =>
    const SizedBox.shrink();