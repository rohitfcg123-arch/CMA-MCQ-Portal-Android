import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

const String portalUrl =
    'https://rohitfcg123-arch.github.io/CMA-MCQ-Portal-Android/';

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
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('CMA-MCQ-Portal-Android/1.0')
      ..setBackgroundColor(const Color(0xFFFAF6EE))
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
          onPageFinished: (_) {
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

            // Keep normal web navigation inside the app.
            if (uri.scheme == 'http' || uri.scheme == 'https') {
              return NavigationDecision.navigate;
            }

            // Open WhatsApp, email, phone, etc. using Android's external apps.
            try {
              final launched = await launchUrl(
                uri,
                mode: LaunchMode.externalApplication,
              );
              return launched
                  ? NavigationDecision.prevent
                  : NavigationDecision.navigate;
            } catch (_) {
              return NavigationDecision.navigate;
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(portalUrl));
  }

  Future<bool> _handleBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return false;
    }
    return true;
  }

  Future<void> _reload() async {
    if (mounted) setState(() => _hasError = false);
    await _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _handleBack();
        if (shouldExit && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              WebViewWidget(controller: _controller),
              if (_loading)
                const Align(
                  alignment: Alignment.topCenter,
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    color: Color(0xFFC8A24A),
                    backgroundColor: Color(0xFFE8E0CE),
                  ),
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
