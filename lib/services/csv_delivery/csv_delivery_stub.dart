/// Fallback implementation used only if neither dart:io nor dart:html is
/// available (shouldn't happen on any real Flutter target).
Future<void> deliverCsv(String csvContent, String fileName, String shareText) async {
  throw UnsupportedError('CSV export is not supported on this platform.');
}
