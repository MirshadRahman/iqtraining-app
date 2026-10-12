import 'config.dart';

enum LinkAction {
  /// Load inside the webview.
  allow,

  /// Hand to the system (browser, mail, phone, other apps).
  external,

  /// A sales page: do not show it, go back to the learner area.
  blocked,
}

String _withSlash(String path) => path.endsWith('/') ? path : '$path/';

bool isInternalHost(String host) {
  final h = host.toLowerCase();
  return h == AppConfig.host || h.endsWith('.${AppConfig.host}');
}

bool _isInAppHost(String host) {
  final h = host.toLowerCase();
  return AppConfig.inAppHosts.any((d) => h == d || h.endsWith('.$d'));
}

bool isBlockedPath(Uri uri) {
  final path = _withSlash(uri.path.isEmpty ? '/' : uri.path);
  // The bare home page is a sales page, but "/?add-to-cart=..." and similar
  // query-driven requests are part of the certificate checkout.
  if (path == '/') return uri.query.isEmpty;
  if (AppConfig.blockedExactPaths.contains(path)) return true;
  return AppConfig.blockedPathPrefixes.any(path.startsWith);
}

/// Decides what to do with a top-level navigation.
///
/// [userClick] is true when the user tapped a link, false for redirects and
/// form posts. External pages reached by redirect (payment, 3-D Secure) stay
/// in the webview; external links the user taps open in the system browser.
LinkAction classifyLink(Uri uri, {required bool userClick}) {
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') {
    const inPage = {'about', 'data', 'blob', 'javascript', 'file'};
    return inPage.contains(scheme) ? LinkAction.allow : LinkAction.external;
  }
  if (isInternalHost(uri.host)) {
    return isBlockedPath(uri) ? LinkAction.blocked : LinkAction.allow;
  }
  if (_isInAppHost(uri.host)) return LinkAction.allow;
  return userClick ? LinkAction.external : LinkAction.allow;
}

/// Which bottom tab a URL belongs to, or null to leave the selection alone.
int? tabIndexFor(Uri uri) {
  if (!isInternalHost(uri.host)) return null;
  final path = _withSlash(uri.path);
  int? best;
  var bestLength = 0;
  for (var i = 0; i < AppConfig.tabs.length; i++) {
    final tabPath = AppConfig.tabs[i].path;
    if (path.startsWith(tabPath) && tabPath.length > bestLength) {
      best = i;
      bestLength = tabPath.length;
    }
  }
  return best;
}
