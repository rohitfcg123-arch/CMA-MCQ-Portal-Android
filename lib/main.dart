import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

const String portalUrl =
    'https://rohitfcg123-arch.github.io/CMA-MCQ-Portal-Android/index.html';

const String webClientId =
    '208738737302-qpv57rh3voh02dtpqs369175ahieb3q7.apps.googleusercontent.com';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CmaMcqPortalApp());
}

class CmaMcqPortalApp extends StatelessWidget {
  const CmaMcqPortalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CMA MCQ Portal',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D3B3E),
        ),
        useMaterial3: true,
      ),
      home: const PortalWebView(),
    );
  }
}

class PortalWebView extends StatefulWidget {
  const PortalWebView({super.key});

  @override
  State<PortalWebView> createState() => _PortalWebViewState();
}

class _PortalWebViewState extends State<PortalWebView> {
  late final WebViewController _controller;
  final GoogleSignIn _googleSignIn = GoogleSignIn(serverClientId: webClientId);

  bool _loading = true;
  bool _hasError = false;
  bool _googleBusy = false;

  static const String _mobileViewportFix = r'''
(function () {
  try {
    var meta = document.querySelector('meta[name="viewport"]');
    if (!meta) {
      meta = document.createElement('meta');
      meta.name = 'viewport';
      document.head.appendChild(meta);
    }
    meta.content =
      'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover';
    document.documentElement.style.width = '100%';
    document.documentElement.style.maxWidth = '100%';
    document.body.style.width = '100%';
    document.body.style.maxWidth = '100%';
    document.body.style.margin = '0';
    document.body.style.overflowX = 'hidden';
  } catch (e) {}
})();
''';

  static const String _nativeGoogleBridge = r'''
(function () {
  try {
    window.__cmaNativeGoogleLogin = function () {
      if (window.NativeGoogleSignIn) {
        window.NativeGoogleSignIn.postMessage('signin');
        return true;
      }
      return false;
    };

    window.__cmaNativeGoogleToken = function (idToken) {
      try {
        var provider = new firebase.auth.GoogleAuthProvider();
        var credential = provider.credential(idToken);
        firebase.auth().signInWithCredential(credential)
          .then(function () {
            var pending = window.__cmaPendingNativePath;
            if (pending && pending !== location.href) {
              window.__cmaPendingNativePath = '';
              location.href = pending;
              return;
            }
            if (typeof closeLogin === 'function') {
              closeLogin();
            }
            var button = document.getElementById('google');
            if (button) {
              button.disabled = false;
              button.textContent = 'G  Continue with Google';
            }
            var paymentButton = document.getElementById('googleBtn');
            if (paymentButton) {
              paymentButton.disabled = false;
              paymentButton.textContent = 'Continue with Google';
            }
          })
          .catch(function (e) {
            console.error('Native Google Firebase sign-in failed', e);
            var msg = document.getElementById('authMsg');
            if (msg) {
              msg.textContent =
                'Google sign-in failed: ' + (e && e.code ? e.code : 'unknown-error');
              msg.className = 'error';
            }
            var button = document.getElementById('google');
            if (button) {
              button.disabled = false;
              button.textContent = 'G  Continue with Google';
            }
          });
      } catch (e) {
        console.error(e);
      }
    };

    var button = document.getElementById('google');
    if (button) {
      button.onclick = function () {
        window.__cmaNativeGoogleLogin();
      };
    }

    var paymentButton = document.getElementById('googleBtn');
    if (paymentButton) {
      paymentButton.onclick = function () {
        window.__cmaNativeGoogleLogin();
      };
    }

    document.addEventListener('click', function (event) {
      var el = event.target;
      while (el && el !== document && el.tagName !== 'A' && el.tagName !== 'BUTTON') {
        el = el.parentElement;
      }
      if (!el || el === document) return;
      if (el.id === 'google' || el.id === 'googleBtn' || el.id === 'googleLogin') {
        event.preventDefault();
        event.stopPropagation();
        window.__cmaNativeGoogleLogin();
      }
    }, true);
    window.dispatchEvent(new Event('cmaNativeBridgeReady'));
  } catch (e) {
    console.error('Native Google bridge setup failed', e);
  }
})();
''';

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  Future<void> _showWebAuthError(String message) async {
    final safe = jsonEncode(message);
    try {
      await _controller.runJavaScript('''
        (function () {
          var msg = document.getElementById('authMsg');
          if (msg) {
            msg.textContent = $safe;
            msg.className = 'error';
          }
        })();
      ''');
    } catch (_) {}
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('CMA-MCQ-Portal-Android/2.0')
      ..setBackgroundColor(const Color(0xFFFAF6EE))
      ..addJavaScriptChannel(
        'NativeGoogleSignIn',
        onMessageReceived: (_) => _startNativeGoogleSignIn(),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _loading = true;
                _hasError = false;
              });
            }
          },
          onPageFinished: (url) async {
            await _controller.runJavaScript(_mobileViewportFix);
            final uri = Uri.tryParse(url);
            if (uri != null && uri.host == 'rohitfcg123-arch.github.io') {
              await _controller.runJavaScript(_nativeGoogleBridge);
            }
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame ?? false) {
              if (mounted) {
                setState(() {
                  _loading = false;
                  _hasError = true;
                });
              }
            }
          },
          onNavigationRequest: (request) async {
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.prevent;
            if (uri.scheme == 'http' || uri.scheme == 'https') {
              return NavigationDecision.navigate;
            }
            try {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } catch (_) {}
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse(portalUrl));
  }

  Future<void> _startNativeGoogleSignIn() async {
    if (_googleBusy) return;
    setState(() => _googleBusy = true);
    try {
      // Use the legacy Android Google Sign-In flow. The 7.x plugin switched
      // Android authentication to Credential Manager; this build deliberately
      // uses the pre-Credential-Manager implementation because the device is
      // hanging after account selection.
      final GoogleSignInAccount? account =
          await _googleSignIn.signIn().timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException(
          'Google account selection did not complete within 20 seconds.',
        ),
      );
      if (account == null) {
        throw GoogleSignInException(
          code: GoogleSignInExceptionCode.canceled,
          description: 'Google account selection was cancelled.',
        );
      }
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception(
          'Google returned no ID token. Check the Android OAuth client, '
          'package name and release SHA-1 in Firebase.',
        );
      }

      final tokenForJs = jsonEncode(idToken);
      await _controller.runJavaScript('''
        (function () {
          if (typeof window.__cmaNativeGoogleToken === 'function') {
            window.__cmaNativeGoogleToken($tokenForJs);
          } else {
            var msg = document.getElementById('authMsg');
            if (msg) {
              msg.textContent =
                'Login bridge is not ready. Please reload the app.';
              msg.className = 'error';
            }
          }
        })();
      ''');
    } on GoogleSignInException catch (e) {
      debugPrint(
        'Native Google Sign-In failed: code=${e.code}, '
        'description=${e.description}, details=${e.details}',
      );
      final message = e.code == GoogleSignInExceptionCode.canceled
          ? 'Google sign-in was cancelled.'
          : 'Google sign-in configuration failed: '
              '${e.description ?? e.code.name}. '
              'Check Android package + SHA-1 in Firebase.';
      await _showWebAuthError(message);
      _showMessage(message);
    } on TimeoutException catch (e) {
      debugPrint('Native Google Sign-In timed out: $e');
      const message =
          'Google account selection timed out. Please try again. '
          'If this repeats, the Android Google OAuth configuration '
          '(package/SHA-1) needs to be checked.';
      await _showWebAuthError(message);
      _showMessage(message);
    } catch (e) {
      debugPrint('Native Google Sign-In failed: $e');
      final message = 'Google sign-in failed: $e';
      await _showWebAuthError(message);
      _showMessage(message);
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    _controller.runJavaScript('''
      (function () {
        var msg = document.getElementById('authMsg');
        if (msg) {
          msg.textContent = ${jsonEncode(message)};
          msg.className = 'error';
        }
      })();
    ''');
  }

  Future<bool> _handleBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return false;
    }
    return true;
  }

  Future<void> _reload() async {
    if (mounted) {
      setState(() {
        _hasError = false;
        _loading = true;
      });
    }
    await _controller.loadRequest(Uri.parse(portalUrl));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _handleBack();
        if (shouldExit && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (_loading || _googleBusy)
                const Align(
                  alignment: Alignment.topCenter,
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              if (_hasError)
                Center(
                  child: Card(
                    margin: const EdgeInsets.all(24),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.wifi_off, size: 46),
                          const SizedBox(height: 12),
                          const Text(
                            'Unable to load CMA MCQ Portal',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Check your internet connection and try again.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _reload,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
