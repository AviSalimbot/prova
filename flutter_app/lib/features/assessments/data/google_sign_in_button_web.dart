import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// The actual rendered Google button (an iframe Google controls).
/// This file's import of web_only.dart only compiles on web, which is
/// exactly why it's split out behind the conditional import in
/// drive_auth_service.dart rather than imported there directly.
///
/// [text] selects the button's label copy ('signin_with', 'signup_with',
/// 'continue_with', 'signin') and is mapped to GSIButtonText below.
Widget renderGoogleSignInButton({String text = 'signin_with'}) {
  return web.renderButton(
    configuration: web.GSIButtonConfiguration(
      text: _toButtonText(text),
    ),
  );
}

web.GSIButtonText _toButtonText(String text) {
  switch (text) {
    case 'signup_with':
      return web.GSIButtonText.signupWith;
    case 'continue_with':
      return web.GSIButtonText.continueWith;
    case 'signin':
      return web.GSIButtonText.signin;
    case 'signin_with':
    default:
      return web.GSIButtonText.signinWith;
  }
}