import 'dart:io';
import 'dart:typed_data';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_saver/file_saver.dart';
import 'package:permission_handler/permission_handler.dart';

class ResponseExportUtil {
  static Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) return true;

    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version.sdkInt;

    if (sdkInt >= 33) {
      // Android 13 and above: No permission needed for Downloads
      return true;
    } else if (sdkInt >= 29) {
      // Android 10 and above: No permission needed for Downloads
      return true;
    } else {
      // Below Android 10: Request regular storage permission
      final status = await Permission.storage.request();
      return status.isGranted;
    }
  }

  static Future<String> getPublicDownloadPath() async {
    if (Platform.isAndroid) {
      final directory = await getExternalStorageDirectory();
      if (directory != null) {
        return directory.path;
      }
      // Fallback to app-specific directory
      final appDir = await getApplicationDocumentsDirectory();
      return appDir.path;
    } else {
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    }
  }

  static Future<String> exportToExcel({
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final hasPermission = await requestStoragePermission();
        if (!hasPermission) {
          throw Exception('Storage permission is required to save the file');
        }
      }

      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Responses'];

      // Add headers with styling
      for (var i = 0; i < headers.length; i++) {
        var cell = sheetObject.cell(CellIndex.indexByColumnRow(
          columnIndex: i,
          rowIndex: 0,
        ));
        cell.value = headers[i];
        cell.cellStyle = CellStyle(
          bold: true,
          horizontalAlign: HorizontalAlign.Center,
        );
      }

      // Add rows
      for (var i = 0; i < rows.length; i++) {
        for (var j = 0; j < rows[i].length; j++) {
          sheetObject.cell(CellIndex.indexByColumnRow(
            columnIndex: j,
            rowIndex: i + 1,
          )).value = rows[i][j];
        }
      }

      // Auto-fit column widths
      for (var i = 0; i < headers.length; i++) {
        sheetObject.setColWidth(i, 20.0);
      }

      final fileName = 'participant_requirement_response.xlsx';
      final bytes = excel.encode();
      if (bytes == null) throw Exception('Failed to encode Excel file');

      if (kIsWeb) {
        await FileSaver.instance.saveFile(
          name: fileName,
          bytes: Uint8List.fromList(bytes),
          ext: 'xlsx',
          mimeType: MimeType.microsoftExcel,
        );
        return 'File downloaded successfully';
      } else if (Platform.isAndroid) {
        // Use MediaStore API for Android
        final result = await FileSaver.instance.saveAs(
          name: fileName.replaceAll('.xlsx', ''),
          bytes: Uint8List.fromList(bytes),
          ext: 'xlsx',
          mimeType: MimeType.microsoftExcel,
        );
        return result ?? 'File saved successfully';
      } else {
        final downloadPath = await getPublicDownloadPath();
        final filePath = '$downloadPath/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(bytes);
        return filePath;
      }
    } catch (e) {
      debugPrint('Error in exportToExcel: $e');
      rethrow;
    }
  }
}
