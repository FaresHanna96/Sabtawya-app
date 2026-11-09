import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/utils/app_failure.dart';

class PickedWorkbook {
  const PickedWorkbook({required this.name, required this.bytes});

  final String name;
  final List<int> bytes;
}

/// Picking an `.xlsx` to import and handing an exported one to the share sheet.
class FileService {
  const FileService._();

  static const _xlsxMimeType =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  /// Returns null when the user dismisses the picker.
  static Future<PickedWorkbook?> pickWorkbook() async {
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: AppStrings.pickFile,
        type: FileType.custom,
        allowedExtensions: const <String>['xlsx'],
      );
      if (file == null) return null;

      // Read through the picker rather than the path: on iOS and Android the
      // file often lives behind a content URI the app cannot open directly.
      final bytes = await file.readAsBytes();
      return PickedWorkbook(name: file.name, bytes: bytes);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Opens the share sheet so the exported file can be mailed, saved, or opened
  /// in Excel.
  ///
  /// The bytes are handed over directly rather than written here first:
  /// share_plus stages its own temporary copy on Android and iOS, which keeps
  /// this free of platform-specific file handling.
  static Future<void> saveAndShare({
    required String fileName,
    required List<int> bytes,
    String? shareText,
  }) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[
            XFile.fromData(
              Uint8List.fromList(bytes),
              name: fileName,
              mimeType: _xlsxMimeType,
            ),
          ],
          // cross_file ignores the name of an in-memory file off the web.
          fileNameOverrides: <String>[fileName],
          // No caption or subject: iPhone WhatsApp failed to send a file that
          // came with text ("Couldn't send message"); the file name already
          // says what it is.
        ),
      );
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// `اسم-الملف_2026-10-24.xlsx`, safe for every platform.
  static String timestampedName(String base) {
    final now = DateTime.now();
    final stamp = '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final safe = base.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-').trim();
    return '$safe-$stamp.xlsx';
  }
}
