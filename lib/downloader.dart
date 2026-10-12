import 'dart:io';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// Downloads a file the webview could not display (certificate PDFs on
/// Android, anything served as an attachment) using the learner's logged-in
/// session, then opens it with the device's viewer.
///
/// Returns null on success, or a message to show the user.
Future<String?> downloadAndOpen(
  InAppWebViewController controller,
  DownloadStartRequest request,
) async {
  final uri = Uri.parse(request.url.toString());
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return 'This file can\'t be downloaded in the app.';
  }
  try {
    final cookies = await CookieManager.instance().getCookies(url: request.url);
    final userAgent =
        await controller.evaluateJavascript(source: 'navigator.userAgent');
    final response = await http.get(uri, headers: {
      if (cookies.isNotEmpty)
        'Cookie': cookies.map((c) => '${c.name}=${c.value}').join('; '),
      if (userAgent is String) 'User-Agent': userAgent,
    }).timeout(const Duration(seconds: 60));

    final type = (response.headers['content-type'] ?? '').toLowerCase();
    if (response.statusCode != 200 || type.startsWith('text/html')) {
      return 'Couldn\'t download the file. Please try again.';
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${_fileName(request, uri, type)}');
    await file.writeAsBytes(response.bodyBytes, flush: true);

    final result = await OpenFilex.open(file.path);
    return result.type == ResultType.done
        ? null
        : 'Downloaded, but no app on this device can open it.';
  } catch (_) {
    return 'Couldn\'t download the file. Check your connection and try again.';
  }
}

String _fileName(DownloadStartRequest request, Uri uri, String contentType) {
  var name = request.suggestedFilename ?? '';
  if (name.isEmpty && uri.pathSegments.isNotEmpty) {
    name = uri.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => '');
  }
  if (name.isEmpty) name = 'download';
  name = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final isPdf = contentType.contains('pdf') ||
      (request.mimeType ?? '').toLowerCase().contains('pdf');
  if (isPdf && !name.toLowerCase().endsWith('.pdf')) name = '$name.pdf';
  return name;
}
