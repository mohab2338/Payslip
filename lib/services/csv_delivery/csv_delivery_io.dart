import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Mobile implementation: write the CSV to a temp file and hand it to the
/// OS share sheet, so the person can save it, email it, AirDrop it, etc.
Future<void> deliverCsv(String csvContent, String fileName, String shareText) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsString(csvContent);
  await Share.shareXFiles([XFile(file.path)], text: shareText);
}
