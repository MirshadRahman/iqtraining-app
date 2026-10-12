import 'package:flutter/material.dart';

/// Everything you are likely to change lives in this file.
class AppConfig {
  static const appName = 'IQ Training';
  static const host = 'iqtraining.co.uk';
  static const baseUrl = 'https://iqtraining.co.uk';

  /// Appended to the webview user agent. The WordPress snippet looks for
  /// "IQTrainingApp" to switch the site into app mode.
  static const userAgentTag = 'IQTrainingApp/1.0';

  /// TODO: replace with the IQ Training brand colour.
  static const brandColor = Color(0xFF0B2545);

  /// First screen, and where blocked pages bounce to.
  static const startPath = '/user-dashboard/my-courses/';
  static const loginPath = '/login/';

  static const tabs = <AppTab>[
    AppTab('My Courses', Icons.school_outlined, '/user-dashboard/my-courses/'),
    AppTab('Dashboard', Icons.dashboard_outlined, '/user-dashboard/'),
    AppTab('Help', Icons.help_outline, '/frequently-asked-questions/'),
  ];

  /// Sales pages that must not open inside the app (store rules on selling
  /// digital content). Exact matches only: LearnDash lessons also live under
  /// /courses/<slug>/, so /courses/ must not be blocked as a prefix.
  static const blockedExactPaths = <String>[
    '/',
    '/courses/',
    '/course-bundles/',
    '/teams-training/',
    '/shop/',
  ];
  static const blockedPathPrefixes = <String>['/product-category/'];

  /// External hosts that must stay inside the webview so the printed
  /// certificate checkout can finish (payment pages and their redirects).
  static const inAppHosts = <String>[
    'paypal.com',
    'stripe.com',
    'stripe.network',
    'klarna.com',
    'worldpay.com',
    'sagepay.com',
    'opayo.co.uk',
  ];

  /// Hides the website header and footer; the app has its own navigation.
  static const hideChromeCss =
      '.elementor-location-header,.elementor-location-footer,'
      '#masthead,header.site-header,footer.site-footer'
      '{display:none!important}';
}

class AppTab {
  const AppTab(this.label, this.icon, this.path);
  final String label;
  final IconData icon;
  final String path;
}
