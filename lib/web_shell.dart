import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config.dart';
import 'downloader.dart';
import 'link_policy.dart';

/// The whole app: one webview, native bottom tabs, and the screens that cover
/// it while loading or offline.
class WebShell extends StatefulWidget {
  const WebShell({super.key});

  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> {
  InAppWebViewController? _web;
  late final PullToRefreshController _pull;

  int _tab = 0;
  double _progress = 0;
  bool _firstLoadDone = false;
  bool _failed = false;
  bool _errorThisLoad = false;
  bool _downloading = false;
  WebUri? _lastUrl;
  bool _bounced = false;

  bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    _pull = PullToRefreshController(
      settings: PullToRefreshSettings(color: AppConfig.brandColor),
      onRefresh: _reload,
    );
  }

  WebUri _site(String path) => WebUri('${AppConfig.baseUrl}$path');

  Future<void> _load(WebUri url) async {
    await _web?.loadUrl(urlRequest: URLRequest(url: url));
  }

  Future<void> _reload() async {
    final web = _web;
    if (web == null) return;
    if (_isIOS) {
      // reload() does nothing on iOS after a failed first load.
      await _load(await web.getUrl() ?? _lastUrl ?? _site(AppConfig.startPath));
    } else {
      await web.reload();
    }
  }

  /// Sends the learner back to their courses when a sales page comes up. If
  /// that bounces again before any page has loaded (logged out and the site
  /// redirects home), go to the login page instead of looping.
  void _bounce() {
    final looping = _bounced;
    _bounced = true;
    _load(_site(looping ? AppConfig.loginPath : AppConfig.startPath));
  }

  bool _isSalesPage(Uri url) => isInternalHost(url.host) && isBlockedPath(url);

  Future<void> _openExternal(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      _toast('Couldn\'t open that link.');
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Applies the link rules. Returns true if the webview should load [uri].
  Future<bool> _route(Uri uri, {required bool userClick}) async {
    switch (classifyLink(uri, userClick: userClick)) {
      case LinkAction.allow:
        return true;
      case LinkAction.external:
        await _openExternal(uri);
        return false;
      case LinkAction.blocked:
        _bounce();
        return false;
    }
  }

  Future<NavigationActionPolicy> _onNavigate(
    InAppWebViewController controller,
    NavigationAction action,
  ) async {
    final uri = action.request.url;
    if (uri == null || !action.isForMainFrame) {
      return NavigationActionPolicy.ALLOW;
    }
    final userClick = _isIOS
        ? action.navigationType == NavigationType.LINK_ACTIVATED
        : (action.hasGesture ?? false) && !(action.isRedirect ?? false);
    return await _route(uri, userClick: userClick)
        ? NavigationActionPolicy.ALLOW
        : NavigationActionPolicy.CANCEL;
  }

  /// Links that ask for a new window (target="_blank") load in this one.
  Future<bool> _onCreateWindow(
    InAppWebViewController controller,
    CreateWindowAction action,
  ) async {
    final uri = action.request.url;
    if (uri != null && await _route(uri, userClick: true)) {
      await _load(uri);
    }
    return false;
  }

  Future<void> _onDownload(
    InAppWebViewController controller,
    DownloadStartRequest request,
  ) async {
    if (_downloading) return;
    setState(() => _downloading = true);
    final problem = await downloadAndOpen(controller, request);
    if (!mounted) return;
    setState(() => _downloading = false);
    if (problem != null) _toast(problem);
  }

  void _onVisited(InAppWebViewController controller, WebUri? url, bool? _) {
    if (url == null) return;
    // Second line of defence for navigations the platform did not ask about.
    if (_isSalesPage(url)) {
      _bounce();
      return;
    }
    final tab = tabIndexFor(url);
    if (tab != null && tab != _tab && mounted) setState(() => _tab = tab);
  }

  Future<void> _onBack() async {
    final web = _web;
    if (web != null && !_failed && await web.canGoBack()) {
      await web.goBack();
    } else {
      await SystemNavigator.pop();
    }
  }

  void _onTab(int index) {
    setState(() => _tab = index);
    _load(_site(AppConfig.tabs[index].path));
  }

  @override
  Widget build(BuildContext context) {
    final styleScript = '(function(){var s=document.createElement("style");'
        's.textContent=${jsonEncode(AppConfig.hideChromeCss)};'
        '(document.head||document.documentElement).appendChild(s);'
        'document.documentElement.classList.add("iq-app");})();';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              InAppWebView(
                initialUrlRequest:
                    URLRequest(url: _site(AppConfig.startPath)),
                initialSettings: InAppWebViewSettings(
                  applicationNameForUserAgent: AppConfig.userAgentTag,
                  useShouldOverrideUrlLoading: true,
                  useOnDownloadStart: true,
                  supportMultipleWindows: true,
                  javaScriptCanOpenWindowsAutomatically: true,
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                  iframeAllowFullscreen: true,
                  allowsBackForwardNavigationGestures: true,
                  thirdPartyCookiesEnabled: true,
                  supportZoom: false,
                  isInspectable: kDebugMode,
                ),
                initialUserScripts: UnmodifiableListView<UserScript>([
                  UserScript(
                    source: styleScript,
                    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                  ),
                ]),
                pullToRefreshController: _pull,
                onWebViewCreated: (controller) => _web = controller,
                shouldOverrideUrlLoading: _onNavigate,
                onCreateWindow: _onCreateWindow,
                // ignore: deprecated_member_use
                onDownloadStartRequest: _onDownload,
                onUpdateVisitedHistory: _onVisited,
                onLoadStart: (controller, url) {
                  _lastUrl = url ?? _lastUrl;
                  _errorThisLoad = false;
                },
                onProgressChanged: (controller, progress) {
                  if (progress == 100) _pull.endRefreshing();
                  if (mounted) setState(() => _progress = progress / 100);
                },
                onLoadStop: (controller, url) {
                  _pull.endRefreshing();
                  if (url != null && !_isSalesPage(url)) _bounced = false;
                  if (!mounted) return;
                  setState(() {
                    if (!_errorThisLoad) {
                      _failed = false;
                      _firstLoadDone = true;
                    }
                  });
                },
                onReceivedError: (controller, request, error) {
                  if (!(request.isForMainFrame ?? false)) return;
                  // Fired when we cancel a navigation ourselves.
                  if (error.type == WebResourceErrorType.CANCELLED) return;
                  _pull.endRefreshing();
                  _errorThisLoad = true;
                  if (mounted) setState(() => _failed = true);
                },
              ),
              if (!_firstLoadDone && !_failed)
                const Positioned.fill(child: _Splash()),
              if (_failed) Positioned.fill(child: _Offline(onRetry: _reload)),
              if ((_firstLoadDone || _failed) && _progress < 1)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 2,
                  ),
                ),
              if (_downloading)
                const Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: _DownloadBanner(),
                ),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: _onTab,
          destinations: [
            for (final tab in AppConfig.tabs)
              NavigationDestination(icon: Icon(tab.icon), label: tab.label),
          ],
        ),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppConfig.brandColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppConfig.appName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 24),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Offline extends StatelessWidget {
  const _Offline({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off, size: 56, color: theme.colorScheme.outline),
              const SizedBox(height: 16),
              Text('You\'re offline', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Check your connection and try again. '
                'Your course progress is saved.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      ),
    );
  }
}

class _DownloadBanner extends StatelessWidget {
  const _DownloadBanner();

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      color: Theme.of(context).colorScheme.inverseSurface,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Downloading…', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
