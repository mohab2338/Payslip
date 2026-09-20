// ignore_for_file: deprecated_member_use
import 'dart:html' as html;

/// Web implementation: there's no filesystem or native share sheet, so we
/// build the CSV as a Blob and trigger a normal browser download instead.
Future<void> deliverCsv(String csvContent, String fileName, String shareText) async {
  final bytes = html.Blob([csvContent], 'text/csv');
  final url = html.Url.createObjectUrlFromBlob(bytes);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}
