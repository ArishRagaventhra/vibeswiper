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
      // Android 13 and above: Request media permissions
      final photos = await Permission.photos.request();
      return photos.isGranted;
    } else if (sdkInt >= 30) {
      // Android 11 and 12: Request manage external storage
      final status = await Permission.manageExternalStorage.request();
      return status.isGranted;
    } else {
      // Below Android 11: Request regular storage permission
      final status = await Permission.storage.request();
      return status.isGranted;
    }
  }

  static Future<String> getPublicDownloadPath() async {
    if (Platform.isAndroid) {
      // Get the public Downloads directory path
      Directory? directory;
      
      if (await Permission.manageExternalStorage.isGranted) {
        // Try to get the primary external storage directory
        final List<Directory>? extDirs = await getExternalStorageDirectories();
        if (extDirs != null && extDirs.isNotEmpty) {
          final String path = extDirs[0].path;
          // Navigate up to find the root external storage
          final String rootPath = path.split('Android')[0];
          directory = Directory('$rootPath/Download');
        }
      }
      
      // Fallback to default download directory if couldn't get external storage
      if (directory == null) {
        directory = Directory('/storage/emulated/0/Download');
      }

      // Create directory if it doesn't exist
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      
      return directory.path;
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
