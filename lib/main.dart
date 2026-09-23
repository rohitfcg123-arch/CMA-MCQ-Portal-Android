import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

const String portalUrl =
    'https://rohitfcg123-arch.github.io/snackssangam.github.io/index.html';

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
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  bool _loading = true;
  bool _hasError = false;
  bool _googleBusy = false;
  bool _googleInitialized = false;

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
      }
    };

    window.__cmaNativeGoogleToken = function (idToken) {
      try {
        var provider = new firebase.auth.GoogleAuthProvider();
        var credential = provider.credential(idToken);
        firebase.auth().signInWithCredential(credential)
          .then(function () {
            var button = document.getElementById('google');
            if (button) {
              button.disabled = false;
              button.textContent = 'G  Continue with Google';
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

    var googleLogin = document.getElementById('googleLogin');
    if (googleLogin) {
      googleLogin.onclick = function () {
        window.__cmaNativeGoogleLogin();
      };
    }
  } catch (e) {
    console.error('Native Google bridge setup failed', e);
  }
})();
''';

  @override
  void initState() {
    super.initState();
    _initializeGoogle();
    _initializeWebView();
  }

  Future<void> _initializeGoogle() async {
    try {
      await _googleSignIn.initialize(
        serverClientId: webClientId,
      );
      _googleInitialized = true;
    } catch (e) {
      debugPrint('Google Sign-In initialization failed: $e');
    }
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
    if (!_googleInitialized) await _initializeGoogle();
    if (!_googleInitialized) {
      _showMessage('Google Sign-In could not be initialized. Please try again.');
      return;
    }

    setState(() => _googleBusy = true);
    try {
      final GoogleSignInAccount account =
          await _googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Google did not return an ID token.');
      }
      final tokenForJs = jsonEncode(idToken);
      await _controller.runJavaScript(
        'window.__cmaNativeGoogleToken($tokenForJs);',
      );
    } catch (e) {
      debugPrint('Native Google Sign-In failed: $e');
      final message = e.toString().toLowerCase().contains('cancel')
          ? 'Google sign-in was cancelled.'
          : 'Google sign-in failed. Please try again.';
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
