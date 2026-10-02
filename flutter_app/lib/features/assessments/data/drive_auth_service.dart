// import 'package:flutter/foundation.dart' show kIsWeb;
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:google_sign_in/google_sign_in.dart';
// import 'package:http/http.dart' as http;

// import 'google_sign_in_button_stub.dart'
//     if (dart.library.html) 'google_sign_in_button_web.dart';

// /// Read-only Drive access. As of this update, this service ALSO backs
// /// PROVA's "Sign in with Google" login option — see
// /// completeGoogleSignInForApp() — so the same consent flow both
// /// authenticates into PROVA and authorizes Drive, instead of two
// /// separate Google prompts.
// ///
// /// Get this from Firebase Console > Authentication > Sign-in method >
// /// Google > Web SDK configuration. This MUST be the client ID Firebase
// /// itself is configured with — an ID token minted against any other
// /// client ID will be rejected by signInWithCredential with an
// /// audience-mismatch error.
// const _webClientId = '848916890161-iuanv4mmtmls9221fe1shvh7qn5h43qf.apps.googleusercontent.com';

// const _iosClientId = '848916890161-eeuons4mraa590lv0fpeltl7il3h28n0.apps.googleusercontent.com';

// // Widened from drive.readonly: the backend now uploads Cleaned scans
// // under the *signed-in user's* own Drive quota (service accounts have
// // none of their own — see DriveImportService/clean.py notes). Existing
// // read-only usage (downloadPageBytes, import) is unaffected by the
// // wider scope; only the clean-job upload path relies on the extra
// // write permission.
// const _driveScope = 'https://www.googleapis.com/auth/drive';

// class DriveAuthService {
//   // Static, not instance-level: GoogleSignIn.instance is a process-wide
//   // singleton, so initialization state must survive this service being
//   // recreated (e.g. if its Riverpod provider is ever invalidated).
//   static Future<void>? _initFuture;

//   // Full-session restore, run ONCE per app launch — see restoreSession().
//   static Future<bool>? _restoreFuture;

//   GoogleSignInAccount? _currentAccount;

//   // Single-flight guard for the AUTHORIZATION step specifically (the
//   // part that can pop an OAuth consent window). Without this, several
//   // concurrent callers (e.g. a grid of page tiles) could each call
//   // authorizeScopes() independently, opening competing popups that
//   // cancel each other out.
//   GoogleSignInClientAuthorization? _cachedAuthorization;
//   Future<GoogleSignInClientAuthorization>? _authorizationInFlight;

//   /// Single-flight initialization. If two calls race, the second one
//   /// awaits the SAME future instead of calling
//   /// GoogleSignIn.instance.initialize() a second time — which throws
//   /// "Bad state: init() has already been called" since that method isn't
//   /// idempotent.
//   Future<void> _ensureInitialized() {
//     return _initFuture ??= _doInitialize();
//   }

//   Future<void> _doInitialize() async {
//     try {
//       if (kIsWeb) {
//         // google_sign_in_web asserts serverClientId == null — on Web,
//         // the OAuth Web Client ID is passed as `clientId` itself.
//         await GoogleSignIn.instance.initialize(clientId: _webClientId);
//       } else {
//         await GoogleSignIn.instance.initialize(
//           clientId: _iosClientId,
//           serverClientId: _webClientId,
//         );
//       }

//       // Single global listener that tracks whichever sign-in path fired
//       // — the native picker (mobile/desktop) or the rendered Google
//       // button (web) — so getAuthenticatedClient() and
//       // completeGoogleSignInForApp() have a current account regardless
//       // of platform.
//       GoogleSignIn.instance.authenticationEvents.listen((event) {
//         if (event is GoogleSignInAuthenticationEventSignIn) {
//           _currentAccount = event.user;
//         } else if (event is GoogleSignInAuthenticationEventSignOut) {
//           _currentAccount = null;
//           _cachedAuthorization = null;
//         }
//       });
//     } catch (e) {
//       // Defensive fallback: if something else already initialized this
//       // singleton first, treat that as success rather than crashing.
//       if (!e.toString().contains('has already been called')) {
//         _initFuture = null;
//         rethrow;
//       }
//     }
//   }

//   /// Initializes the underlying Google Sign-In SDK without attempting
//   /// any sign-in of its own. Safe to call as soon as a screen needs
//   /// [buildSignInButton] to have something to attach to (the web
//   /// button is an iframe that needs the SDK initialized first) —
//   /// unlike [trySilentSignIn]/[restoreSession], this never triggers
//   /// Google's own one-tap/account-chooser prompt. Call this from
//   /// LoginScreen so the Google button is ready to render before the
//   /// person has clicked anything.
//   Future<void> ensureReady() => _ensureInitialized();

//   /// True once a Google account is available, on any platform.
//   bool get isSignedIn => _currentAccount != null;

//   /// Broadcasts true the moment a sign-in completes, on any platform —
//   /// including via the rendered web button, which has no completion
//   /// callback of its own. Used both by the Drive-reconnect dialog and
//   /// now by LoginScreen's web Google-login path.
//   Stream<bool> get onSignInChanged {
//     return GoogleSignIn.instance.authenticationEvents.map(
//       (event) => event is GoogleSignInAuthenticationEventSignIn,
//     );
//   }

//   /// Attempts to restore a previous session with no interactive popup
//   /// of your own — though on web, Google's own "lightweight"
//   /// authentication step can itself render a dismissible one-tap
//   /// chooser. If it's dismissed or times out, this just returns false;
//   /// it never throws.
//   Future<bool> trySilentSignIn() async {
//     await _ensureInitialized();
//     if (_currentAccount != null) return true;

//     try {
//       _currentAccount =
//           await GoogleSignIn.instance.attemptLightweightAuthentication();
//     } catch (_) {
//       _currentAccount = null;
//     }
//     return _currentAccount != null;
//   }

//   /// Full session restore, run ONCE per app launch. Warms the
//   /// drive AUTHORIZATION from cache only (never prompts) — see
//   /// PagesGrid/AssessmentsScreen for where this is kicked off.
//   Future<bool> restoreSession() {
//     return _restoreFuture ??= _doRestoreSession();
//   }

//   Future<bool> _doRestoreSession() async {
//     final signedIn = await trySilentSignIn();
//     if (!signedIn) return false;

//     try {
//       final cached = await _currentAccount!.authorizationClient
//           .authorizationForScopes([_driveScope]);
//       if (cached != null) _cachedAuthorization = cached;
//     } catch (_) {
//       // Not fatal — the first real Drive call falls back to an
//       // interactive authorizeScopes() prompt.
//     }

//     return true;
//   }

//   /// Native/desktop/mobile ONLY. Pops Google's interactive account
//   /// picker. On web this throws UnimplementedError — use
//   /// [buildSignInButton] there instead.
//   Future<void> signInInteractively() async {
//     await _ensureInitialized();
//     _currentAccount = await GoogleSignIn.instance.authenticate();
//   }

//   /// The platform-appropriate sign-in control. On web this must be
//   /// Google's real rendered button (an iframe, returned as-is — no
//   /// wrapping GestureDetector/InkWell, those can't intercept iframe
//   /// clicks). Elsewhere it's a normal button using the interactive
//   /// picker. Call [ensureReady] before building this.
//   ///
//   /// [text] controls the button's label/copy: 'signin_with' (default),
//   /// 'signup_with', 'continue_with', or 'signin'. On web it's mapped to
//   /// GSIButtonText and forwarded to Google's renderButton; on
//   /// native/desktop it just swaps the fallback button's label.
//   Widget buildSignInButton({String text = 'signin_with'}) {
//     if (kIsWeb) {
//       return renderGoogleSignInButton(text: text);
//     }
//     return ElevatedButton.icon(
//       onPressed: signInInteractively,
//       icon: const Icon(Icons.login),
//       label: Text(
//         text == 'signup_with' ? 'Sign up with Google' : 'Sign in with Google',
//       ),
//     );
//   }

//   /// Signs out of the Google session entirely (not PROVA's Firebase
//   /// session — callers sign that out separately). Clears cached state
//   /// so a future sign-in doesn't replay a stale result.
//   Future<void> signOut() async {
//     await _ensureInitialized();
//     await GoogleSignIn.instance.signOut();
//     _currentAccount = null;
//     _cachedAuthorization = null;
//     _restoreFuture = null;
//   }

//   /// Returns the cached Drive authorization if there is one, otherwise
//   /// runs the (possibly interactive) authorize flow — but only ONCE no
//   /// matter how many callers ask concurrently.
//   Future<GoogleSignInClientAuthorization> _getAuthorization() {
//     final cached = _cachedAuthorization;
//     if (cached != null) return Future.value(cached);

//     return _authorizationInFlight ??= _doAuthorize().then((authorization) {
//       _cachedAuthorization = authorization;
//       _authorizationInFlight = null;
//       return authorization;
//     }, onError: (Object e, StackTrace st) {
//       _authorizationInFlight = null;
//       Error.throwWithStackTrace(e, st);
//     });
//   }

//   Future<GoogleSignInClientAuthorization> _doAuthorize() async {
//     var authorization = await _currentAccount!.authorizationClient
//         .authorizationForScopes([_driveScope]);
//     authorization ??= await _currentAccount!.authorizationClient
//         .authorizeScopes([_driveScope]);
//     return authorization;
//   }

//   Future<http.Client> getAuthenticatedClient() async {
//     await _ensureInitialized();

//     if (_currentAccount == null) {
//       throw StateError(
//         'Not signed in to Google Drive yet — show buildSignInButton() '
//         'and wait for onSignInChanged before calling this.',
//       );
//     }

//     final authorization = await _getAuthorization();
//     return _BearerTokenClient(authorization.accessToken);
//   }

//   /// Returns the raw OAuth access token for the current Drive
//   /// authorization — needed when a request (like the clean-job trigger)
//   /// must forward the token to the backend rather than use it locally.
//   Future<String> getAccessToken() async {
//     await _ensureInitialized();

//     if (_currentAccount == null) {
//       throw StateError(
//         'Not signed in to Google Drive yet — show buildSignInButton() '
//         'and wait for onSignInChanged before calling this.',
//       );
//     }

//     final authorization = await _getAuthorization();
//     return authorization.accessToken;
//   }

//   /// The unification point: called once a Google account is already
//   /// authenticated (via [signInInteractively] on native, or the web
//   /// button + [onSignInChanged] on web — see LoginScreen), this
//   /// returns the ID token Firebase needs for
//   /// GoogleAuthProvider.credential, AND warms the drive
//   /// authorization in the SAME flow. The very first time a given
//   /// Google account grants PROVA Drive access, this may still show a
//   /// second, scope-specific consent screen — Google always separates
//   /// "who are you" from "what can this app access" — but every
//   /// subsequent sign-in for that account reuses the cached grant, so
//   /// login and Drive access become one prompt in practice.
//   Future<String> completeGoogleSignInForApp() async {
//     await _ensureInitialized();

//     final account = _currentAccount;
//     if (account == null) {
//       throw StateError(
//         'No Google account authenticated yet — call signInInteractively() '
//         '(native) or use buildSignInButton() and wait for onSignInChanged '
//         '(web) before calling this.',
//       );
//     }

//     final idToken = account.authentication.idToken;
//     if (idToken == null) {
//       throw StateError(
//         'Google did not return an ID token for this account — check that '
//         '_webClientId matches the Web client ID configured under '
//         'Firebase Console > Authentication > Sign-in method > Google.',
//       );
//     }

//     await _getAuthorization();

//     return idToken;
//   }
// }

// /// Thin http.Client wrapper that stamps every request with a bearer
// /// token. Rolled by hand rather than depending on
// /// extension_google_sign_in_as_googleapis_auth, since that package's API
// /// predates google_sign_in v7's authentication/authorization split.
// class _BearerTokenClient extends http.BaseClient {
//   _BearerTokenClient(this._accessToken);

//   final String _accessToken;
//   final http.Client _inner = http.Client();

//   @override
//   Future<http.StreamedResponse> send(http.BaseRequest request) {
//     request.headers['Authorization'] = 'Bearer $_accessToken';
//     return _inner.send(request);
//   }
// }

// final driveAuthServiceProvider = Provider<DriveAuthService>(
//   (ref) => DriveAuthService(),
// );

// /// Kicks off restoreSession() the moment this provider is first read.
// /// Read this from AssessmentsScreen (an authenticated screen) — NOT
// /// from the app root or LoginScreen, since it can trigger Google's own
// /// account chooser and that's confusing outside a deliberate sign-in
// /// action.
// final driveSessionRestoreProvider = FutureProvider<bool>((ref) {
//   return ref.watch(driveAuthServiceProvider).restoreSession();
// });

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import 'google_sign_in_button_stub.dart'
    if (dart.library.html) 'google_sign_in_button_web.dart';

/// Read-only Drive access. As of this update, this service ALSO backs
/// PROVA's "Sign in with Google" login option — see
/// completeGoogleSignInForApp() — so the same consent flow both
/// authenticates into PROVA and authorizes Drive, instead of two
/// separate Google prompts.
///
/// Get this from Firebase Console > Authentication > Sign-in method >
/// Google > Web SDK configuration. This MUST be the client ID Firebase
/// itself is configured with — an ID token minted against any other
/// client ID will be rejected by signInWithCredential with an
/// audience-mismatch error.
const _webClientId = '848916890161-iuanv4mmtmls9221fe1shvh7qn5h43qf.apps.googleusercontent.com';

const _iosClientId = '848916890161-eeuons4mraa590lv0fpeltl7il3h28n0.apps.googleusercontent.com';

// Widened from drive.readonly: the backend now uploads Cleaned scans
// under the *signed-in user's* own Drive quota (service accounts have
// none of their own — see DriveImportService/clean.py notes). Existing
// read-only usage (downloadPageBytes, import) is unaffected by the
// wider scope; only the clean-job upload path relies on the extra
// write permission.
const _driveScope = 'https://www.googleapis.com/auth/drive';

/// Google access tokens live ~60 minutes, and on web the plugin never
/// refreshes them. We therefore remember WHEN each authorization was
/// obtained and treat it as expired a little early (55 min) so a token is
/// never handed out that is about to die.
const _tokenLifetime = Duration(minutes: 55);

class DriveAuthService {
  // Static, not instance-level: GoogleSignIn.instance is a process-wide
  // singleton, so initialization state must survive this service being
  // recreated (e.g. if its Riverpod provider is ever invalidated).
  static Future<void>? _initFuture;

  // Full-session restore, run ONCE per app launch — see restoreSession().
  static Future<bool>? _restoreFuture;

  GoogleSignInAccount? _currentAccount;

  // Single-flight guard for the AUTHORIZATION step specifically (the
  // part that can pop an OAuth consent window). Without this, several
  // concurrent callers (e.g. a grid of page tiles) could each call
  // authorizeScopes() independently, opening competing popups that
  // cancel each other out.
  GoogleSignInClientAuthorization? _cachedAuthorization;
  Future<GoogleSignInClientAuthorization>? _authorizationInFlight;

  /// When [_cachedAuthorization] was obtained. Used to decide whether the
  /// cached access token is still safe to use (see [_tokenLifetime]).
  DateTime? _authorizedAt;

  /// Single-flight initialization. If two calls race, the second one
  /// awaits the SAME future instead of calling
  /// GoogleSignIn.instance.initialize() a second time — which throws
  /// "Bad state: init() has already been called" since that method isn't
  /// idempotent.
  Future<void> _ensureInitialized() {
    return _initFuture ??= _doInitialize();
  }

  Future<void> _doInitialize() async {
    try {
      if (kIsWeb) {
        // google_sign_in_web asserts serverClientId == null — on Web,
        // the OAuth Web Client ID is passed as `clientId` itself.
        await GoogleSignIn.instance.initialize(clientId: _webClientId);
      } else {
        await GoogleSignIn.instance.initialize(
          clientId: _iosClientId,
          serverClientId: _webClientId,
        );
      }

      // Single global listener that tracks whichever sign-in path fired
      // — the native picker (mobile/desktop) or the rendered Google
      // button (web) — so getAuthenticatedClient() and
      // completeGoogleSignInForApp() have a current account regardless
      // of platform.
      GoogleSignIn.instance.authenticationEvents.listen((event) {
        if (event is GoogleSignInAuthenticationEventSignIn) {
          _currentAccount = event.user;
        } else if (event is GoogleSignInAuthenticationEventSignOut) {
          _currentAccount = null;
          _cachedAuthorization = null;
          _authorizedAt = null;
        }
      });
    } catch (e) {
      // Defensive fallback: if something else already initialized this
      // singleton first, treat that as success rather than crashing.
      if (!e.toString().contains('has already been called')) {
        _initFuture = null;
        rethrow;
      }
    }
  }

  /// Initializes the underlying Google Sign-In SDK without attempting
  /// any sign-in of its own. Safe to call as soon as a screen needs
  /// [buildSignInButton] to have something to attach to (the web
  /// button is an iframe that needs the SDK initialized first) —
  /// unlike [trySilentSignIn]/[restoreSession], this never triggers
  /// Google's own one-tap/account-chooser prompt. Call this from
  /// LoginScreen so the Google button is ready to render before the
  /// person has clicked anything.
  Future<void> ensureReady() => _ensureInitialized();

  /// True once a Google account is available, on any platform.
  bool get isSignedIn => _currentAccount != null;

  /// Broadcasts true the moment a sign-in completes, on any platform —
  /// including via the rendered web button, which has no completion
  /// callback of its own. Used both by the Drive-reconnect dialog and
  /// now by LoginScreen's web Google-login path.
  Stream<bool> get onSignInChanged {
    return GoogleSignIn.instance.authenticationEvents.map(
      (event) => event is GoogleSignInAuthenticationEventSignIn,
    );
  }

  /// Attempts to restore a previous session with no interactive popup
  /// of your own — though on web, Google's own "lightweight"
  /// authentication step can itself render a dismissible one-tap
  /// chooser. If it's dismissed or times out, this just returns false;
  /// it never throws.
  Future<bool> trySilentSignIn() async {
    await _ensureInitialized();
    if (_currentAccount != null) return true;

    try {
      _currentAccount =
          await GoogleSignIn.instance.attemptLightweightAuthentication();
    } catch (_) {
      _currentAccount = null;
    }
    return _currentAccount != null;
  }

  /// Full session restore, run ONCE per app launch. Warms the
  /// drive AUTHORIZATION from cache only (never prompts) — see
  /// PagesGrid/AssessmentsScreen for where this is kicked off.
  Future<bool> restoreSession() {
    return _restoreFuture ??= _doRestoreSession();
  }

  Future<bool> _doRestoreSession() async {
    final signedIn = await trySilentSignIn();
    if (!signedIn) return false;

    try {
      final cached = await _currentAccount!.authorizationClient
          .authorizationForScopes([_driveScope]);
      if (cached != null) {
        _cachedAuthorization = cached;
        _authorizedAt = DateTime.now();
      }
    } catch (_) {
      // Not fatal — the first real Drive call falls back to an
      // interactive authorizeScopes() prompt.
    }

    return true;
  }

  /// Native/desktop/mobile ONLY. Pops Google's interactive account
  /// picker. On web this throws UnimplementedError — use
  /// [buildSignInButton] there instead.
  Future<void> signInInteractively() async {
    await _ensureInitialized();
    _currentAccount = await GoogleSignIn.instance.authenticate();
  }

  /// The platform-appropriate sign-in control. On web this must be
  /// Google's real rendered button (an iframe, returned as-is — no
  /// wrapping GestureDetector/InkWell, those can't intercept iframe
  /// clicks). Elsewhere it's a normal button using the interactive
  /// picker. Call [ensureReady] before building this.
  ///
  /// [text] controls the button's label/copy: 'signin_with' (default),
  /// 'signup_with', 'continue_with', or 'signin'. On web it's mapped to
  /// GSIButtonText and forwarded to Google's renderButton; on
  /// native/desktop it just swaps the fallback button's label.
  Widget buildSignInButton({String text = 'signin_with'}) {
    if (kIsWeb) {
      return renderGoogleSignInButton(text: text);
    }
    return ElevatedButton.icon(
      onPressed: signInInteractively,
      icon: const Icon(Icons.login),
      label: Text(
        text == 'signup_with' ? 'Sign up with Google' : 'Sign in with Google',
      ),
    );
  }

  /// Signs out of the Google session entirely (not PROVA's Firebase
  /// session — callers sign that out separately). Clears cached state
  /// so a future sign-in doesn't replay a stale result.
  Future<void> signOut() async {
    await _ensureInitialized();
    await GoogleSignIn.instance.signOut();
    _currentAccount = null;
    _cachedAuthorization = null;
    _authorizedAt = null;
    _restoreFuture = null;
  }

  /// True when the cached token will still be valid for at least
  /// [needValidFor] from now.
  bool _isFresh(Duration needValidFor) {
    final at = _authorizedAt;
    if (at == null) return false;
    return DateTime.now().difference(at) + needValidFor < _tokenLifetime;
  }

  /// Returns the cached Drive authorization ONLY if it is still fresh
  /// enough; otherwise gets a new one. [forceRefresh] always gets a new
  /// one. All callers share one in-flight request, so a grid of tiles
  /// can't open competing popups.
  ///
  /// [needValidFor] is how long the caller needs the token to keep
  /// working (a long job needs more than a single thumbnail fetch).
  Future<GoogleSignInClientAuthorization> _getAuthorization({
    bool forceRefresh = false,
    Duration needValidFor = const Duration(minutes: 5),
  }) {
    final cached = _cachedAuthorization;
    if (cached != null && !forceRefresh && _isFresh(needValidFor)) {
      return Future.value(cached);
    }

    final refreshing = cached != null || forceRefresh;
    return _authorizationInFlight ??=
        _doAuthorize(refresh: refreshing).then((authorization) {
      _cachedAuthorization = authorization;
      _authorizedAt = DateTime.now();
      _authorizationInFlight = null;
      return authorization;
    }, onError: (Object e, StackTrace st) {
      _authorizationInFlight = null;
      Error.throwWithStackTrace(e, st);
    });
  }

  Future<GoogleSignInClientAuthorization> _doAuthorize({
    required bool refresh,
  }) async {
    final client = _currentAccount!.authorizationClient;

    // On web the plugin never refreshes an access token, so
    // authorizationForScopes() could hand back the SAME dead token.
    // Ask Google for a brand-new one instead. (May briefly show Google's
    // popup, so this must run from a user action such as a button tap.)
    if (refresh && kIsWeb) {
      return client.authorizeScopes([_driveScope]);
    }

    var authorization = await client.authorizationForScopes([_driveScope]);
    authorization ??= await client.authorizeScopes([_driveScope]);
    return authorization;
  }

  Future<http.Client> getAuthenticatedClient() async {
    await _ensureInitialized();

    if (_currentAccount == null) {
      throw StateError(
        'Not signed in to Google Drive yet — show buildSignInButton() '
        'and wait for onSignInChanged before calling this.',
      );
    }

    final authorization = await _getAuthorization();
    return _BearerTokenClient(authorization.accessToken);
  }

  /// Returns the raw OAuth access token for the current Drive
  /// authorization — needed when a request (like the clean-job trigger)
  /// must forward the token to the backend rather than use it locally.
  ///
  /// [needValidFor]: the token is refreshed first if it would expire
  /// before this long from now. [forceRefresh]: always get a new token
  /// (use after the backend reports the token was rejected).
  Future<String> getAccessToken({
    bool forceRefresh = false,
    Duration needValidFor = const Duration(minutes: 5),
  }) async {
    await _ensureInitialized();

    if (_currentAccount == null) {
      throw StateError(
        'Not signed in to Google Drive yet — show buildSignInButton() '
        'and wait for onSignInChanged before calling this.',
      );
    }

    final authorization = await _getAuthorization(
      forceRefresh: forceRefresh,
      needValidFor: needValidFor,
    );
    return authorization.accessToken;
  }

  /// The unification point: called once a Google account is already
  /// authenticated (via [signInInteractively] on native, or the web
  /// button + [onSignInChanged] on web — see LoginScreen), this
  /// returns the ID token Firebase needs for
  /// GoogleAuthProvider.credential, AND warms the drive
  /// authorization in the SAME flow. The very first time a given
  /// Google account grants PROVA Drive access, this may still show a
  /// second, scope-specific consent screen — Google always separates
  /// "who are you" from "what can this app access" — but every
  /// subsequent sign-in for that account reuses the cached grant, so
  /// login and Drive access become one prompt in practice.
  Future<String> completeGoogleSignInForApp() async {
    await _ensureInitialized();

    final account = _currentAccount;
    if (account == null) {
      throw StateError(
        'No Google account authenticated yet — call signInInteractively() '
        '(native) or use buildSignInButton() and wait for onSignInChanged '
        '(web) before calling this.',
      );
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw StateError(
        'Google did not return an ID token for this account — check that '
        '_webClientId matches the Web client ID configured under '
        'Firebase Console > Authentication > Sign-in method > Google.',
      );
    }

    await _getAuthorization();

    return idToken;
  }
}

/// Thin http.Client wrapper that stamps every request with a bearer
/// token. Rolled by hand rather than depending on
/// extension_google_sign_in_as_googleapis_auth, since that package's API
/// predates google_sign_in v7's authentication/authorization split.
class _BearerTokenClient extends http.BaseClient {
  _BearerTokenClient(this._accessToken);

  final String _accessToken;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_accessToken';
    return _inner.send(request);
  }
}

final driveAuthServiceProvider = Provider<DriveAuthService>(
  (ref) => DriveAuthService(),
);

/// Kicks off restoreSession() the moment this provider is first read.
/// Read this from AssessmentsScreen (an authenticated screen) — NOT
/// from the app root or LoginScreen, since it can trigger Google's own
/// account chooser and that's confusing outside a deliberate sign-in
/// action.
final driveSessionRestoreProvider = FutureProvider<bool>((ref) {
  return ref.watch(driveAuthServiceProvider).restoreSession();
});