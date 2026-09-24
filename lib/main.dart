import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

const String portalUrl =
    'https://rohitfcg123-arch.github.io/CMA-MCQ-Portal-Android/index.html';
const String appCallbackBase = 'cma-mcq-portal://auth';

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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D3B3E)),
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
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  bool _loading = true;
  bool _hasError = false;
  bool _browserLoginBusy = false;

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

  static const String _browserLoginBridge = r'''
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
            if (typeof closeLogin === 'function') closeLogin();
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
            console.error('Browser Google Firebase sign-in failed', e);
            var msg = document.getElementById('authMsg') ||
                      document.getElementById('message');
            if (msg) {
              msg.textContent =
                'Google sign-in failed: ' + (e && e.code ? e.code : 'unknown-error');
              msg.className = 'error';
            }
          });
      } catch (e) {
        console.error('Browser Google token bridge failed', e);
      }
    };

    ['google', 'googleBtn', 'googleLogin'].forEach(function (id) {
      var button = document.getElementById(id);
      if (button) {
        button.onclick = function () {
          window.__cmaNativeGoogleLogin();
        };
      }
    });

    document.addEventListener('click', function (event) {
      var el = event.target;
      while (el && el !== document &&
             el.tagName !== 'A' && el.tagName !== 'BUTTON') {
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
    console.error('Browser login bridge setup failed', e);
  }
})();
''';

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    _initializeDeepLinks();
  }

  Future<void> _initializeDeepLinks() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        await _handleAppCallback(initialUri);
      }
    } catch (e) {
      debugPrint('Initial app-link read failed: $e');
    }

    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) => _handleAppCallback(uri),
      onError: (Object e) => debugPrint('App-link stream error: $e'),
    );
  }

  Future<void> _handleAppCallback(Uri uri) async {
    if (uri.scheme != 'cma-mcq-portal' || uri.host != 'auth') return;

    final token = uri.queryParameters['id_token'] ??
        (uri.fragment.isNotEmpty
            ? Uri.splitQueryString(uri.fragment)['id_token']
            : null);

    if (token == null || token.isEmpty) {
      _showMessage('Google login returned without a valid sign-in token.');
      return;
    }

    final tokenForJs = jsonEncode(token);
    try {
      await _controller.runJavaScript('''
        (function () {
          if (typeof window.__cmaNativeGoogleToken === 'function') {
            window.__cmaNativeGoogleToken($tokenForJs);
          } else {
            window.__cmaPendingNativePath = '';
            location.reload();
          }
        })();
      ''');
    } catch (e) {
      debugPrint('Could not inject browser login token: $e');
      _showMessage('Could not complete Google login in the app.');
    }
  }

  Future<void> _openBrowserGoogleLogin() async {
    if (_browserLoginBusy) return;
    if (!mounted) return;

    setState(() => _browserLoginBusy = true);
    try {
      final callback =
          '$appCallbackBase?source=android';
      final loginUrl = Uri.parse(portalUrl).replace(
        queryParameters: <String, String>{
          'app_login': '1',
          'return_uri': callback,
        },
      );

      final launched = await launchUrl(
        loginUrl,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        throw Exception('Could not open the website in the browser.');
      }
    } catch (e) {
      _showMessage('Could not open website login: $e');
    } finally {
      if (mounted) {
        setState(() => _browserLoginBusy = false);
      }
    }
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('CMA-MCQ-Portal-Android/3.0')
      ..setBackgroundColor(const Color(0xFFFAF6EE))
      ..addJavaScriptChannel(
        'NativeGoogleSignIn',
        onMessageReceived: (_) => _openBrowserGoogleLogin(),
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
              await _controller.runJavaScript(_browserLoginBridge);
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

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
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
              if (_loading || _browserLoginBusy)
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
