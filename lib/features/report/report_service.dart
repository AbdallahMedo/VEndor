  import 'dart:io';
  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'package:excel/excel.dart';
  import 'package:flutter/material.dart';
  import 'package:open_file/open_file.dart';
  import 'package:path_provider/path_provider.dart';
  import 'package:permission_handler/permission_handler.dart';

  class ExcelExportService {
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;

    Future<void> exportFullInventoryReport(BuildContext context) async {
      try {
        if (!await _hasStoragePermission()) {
          _showMessage(context, "Storage permission denied");
          return;
        }

        final excel = Excel.createExcel();
        await _createCategorySheet(excel);
        await _createDeletedItemsSheet(excel);
        await _createDeletedCategoriesSheet(excel);
        await _createSynthesizeSheet(excel);
        await _createBoardsSheet(excel);
        await _createBoardReceivesSheet(excel);
        await _createOnShelfInventorySheet(excel);
        await _createAddedComponentsSheet(excel);
        await _createExtensionLogsSheet(excel);

        final outputPath = await _saveExcelFile(excel);
        _showMessage(context, "File downloaded to: $outputPath");
        await OpenFile.open(outputPath);
      } catch (e) {
        print("Export error: $e");
        _showMessage(context, "Failed to export Excel file");
      }
    }

    Future<void> _createExtensionLogsSheet(Excel excel) async {
      final sheet = excel['ExtensionLogs'];
      sheet.appendRow([
        TextCellValue('Item Name'),
        IntCellValue(0), // Placeholder for quantity header
        TextCellValue('Delivered By'),
        TextCellValue('Reason'),
        TextCellValue('Timestamp'),
        TextCellValue('Document ID'),
      ]);

      try {
        final snapshot = await _firestore
            .collection('vendor_extensions')
            .orderBy('timestamp', descending: true)
            .get();

        if (snapshot.docs.isEmpty) {
          sheet.appendRow([
            TextCellValue('-'),
            IntCellValue(0),
            TextCellValue('-'),
            TextCellValue('-'),
            TextCellValue('-'),
            TextCellValue('-'),
          ]);
          return;
        }

        for (final doc in snapshot.docs) {
          final data = doc.data();
          final item = data['itemName']?.toString() ?? 'Unknown';
          final qty = (data['quantity'] is int)
              ? data['quantity']
              : int.tryParse(data['quantity']?.toString() ?? '') ?? 0;
          final deliveredBy = data['deliveredBy']?.toString() ?? 'Unknown';
          final reason = data['reason']?.toString() ?? '-';
          String timestamp = '-';
          if (data['timestamp'] is Timestamp) {
            timestamp = (data['timestamp'] as Timestamp).toDate().toString();
          }

          sheet.appendRow([
            TextCellValue(item),
            IntCellValue(qty),
            TextCellValue(deliveredBy),
            TextCellValue(reason),
            TextCellValue(timestamp),
            TextCellValue(doc.id),
          ]);
        }
      } catch (e) {
        print("Error exporting extension logs: $e");
        sheet.appendRow([
          TextCellValue('Error'),
          IntCellValue(0),
          TextCellValue('Error'),
          TextCellValue(e.toString()),
          TextCellValue('-'),
          TextCellValue('-'),
        ]);
      }
    }


    Future<void> _createCategorySheet(Excel excel) async {
      final sheet = excel['Categories'];
      sheet.appendRow([
        TextCellValue('Category Name'),
        TextCellValue('Added By'),
        TextCellValue('Created At'),
        TextCellValue('Item Name'),
        IntCellValue(0),
        TextCellValue('Item Added By'),
        TextCellValue('Item Created At'),
      ]);

      final snapshot = await _firestore.collection('categories').get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final categoryName = data['name'] ?? 'Unknown';
        final addedBy = data['addedBy'] ?? 'Unknown';
        final createdAt = _formatTimestamp(data['createdAt']);

        final items = await doc.reference.collection('items').get();
        if (items.docs.isNotEmpty) {
          for (final itemDoc in items.docs) {
            final item = itemDoc.data();
            sheet.appendRow([
              TextCellValue(categoryName),
              TextCellValue(addedBy),
              TextCellValue(createdAt),
              TextCellValue(item['name'] ?? 'Unknown'),
              IntCellValue(item['quantity'] ?? 0),
              TextCellValue(item['addedBy'] ?? 'Unknown'),
              TextCellValue(_formatTimestamp(item['createdAt'])),
            ]);
          }
        } else {
          sheet.appendRow([
            TextCellValue(categoryName),
            TextCellValue(addedBy),
            TextCellValue(createdAt),
            TextCellValue('-'),
            IntCellValue(0),
            TextCellValue('-'),
            TextCellValue('-'),
          ]);
        }
      }
    }
    Future<void> _createAddedComponentsSheet(Excel excel) async {
      final sheet = excel['AddedComponents'];
      sheet.appendRow([
        TextCellValue('Component Name'),
        TextCellValue('Added By'),
        TextCellValue('Quantity'),
        TextCellValue('Added At'),
        TextCellValue('Group ID'),
        TextCellValue('Component ID'),
      ]);

      try {
        final snapshot = await _firestore.collection('added_component').get();

        if (snapshot.docs.isEmpty) {
          sheet.appendRow([
            TextCellValue('-'),
            TextCellValue('-'),
            IntCellValue(0),
            TextCellValue('-'),
            TextCellValue('-'),
            TextCellValue('-'),
          ]);
          return;
        }

        for (final doc in snapshot.docs) {
          final data = doc.data();

          // Defensive read with fallback values
          final itemName = data['itemName']?.toString() ?? 'Unknown';
          final addedBy = data['addedBy']?.toString() ?? 'Unknown';
          final addedQuantity = (data['addedQuantity'] is int)
              ? data['addedQuantity'] as int
              : int.tryParse(data['addedQuantity']?.toString() ?? '') ?? 0;

          // Check timestamp type carefully
          String addedAt = '-';
          if (data['timestamp'] != null) {
            if (data['timestamp'] is Timestamp) {
              addedAt = (data['timestamp'] as Timestamp).toDate().toString();
            } else if (data['timestamp'] is DateTime) {
              addedAt = (data['timestamp'] as DateTime).toString();
            } else {
              addedAt = data['timestamp'].toString();
            }
          }

          final groupId = doc.id;  // Document ID used for Group ID and Component ID

          sheet.appendRow([
            TextCellValue(itemName),
            TextCellValue(addedBy),
            IntCellValue(addedQuantity),
            TextCellValue(addedAt),
            TextCellValue(groupId),
            TextCellValue(groupId),
          ]);
        }
      } catch (e) {
        print("Error fetching added components: $e");
        // Optionally, add a row showing the error in the sheet
        sheet.appendRow([
          TextCellValue('Error fetching data'),
          TextCellValue(e.toString()),
          IntCellValue(0),
          TextCellValue('-'),
          TextCellValue('-'),
          TextCellValue('-'),
        ]);
      }
    }
    Future<void> _createDeletedItemsSheet(Excel excel) async {
      final sheet = excel['DeletedItems'];
      sheet.appendRow([
        TextCellValue('Item Name'),
        TextCellValue('Category Name'),
        TextCellValue('Quantity'),
        TextCellValue('Deleted By'),
        TextCellValue('Deleted At'),
      ]);

      final snapshot = await _firestore
          .collection('deleted_items')
          .orderBy('deletedAt', descending: true)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        sheet.appendRow([
          TextCellValue(data['itemName'] ?? 'Unknown'),
          TextCellValue(data['categoryName'] ?? 'Unknown'),
          TextCellValue(data['deletedQuantity']?.toString() ?? '0'),
          TextCellValue(data['deletedBy'] ?? 'Unknown'),
          TextCellValue(_formatTimestamp(data['deletedAt'])),
        ]);
      }
    }

    Future<void> _createDeletedCategoriesSheet(Excel excel) async {
      final sheet = excel['DeletedCategories'];
      sheet.appendRow([
        TextCellValue('Category Name'),
        TextCellValue('Deleted By'),
        TextCellValue('Deleted At'),
      ]);

      final snapshot = await _firestore
          .collection('deleted_categories')
          .orderBy('deletedAt', descending: true)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        sheet.appendRow([
          TextCellValue(data['categoryName'] ?? 'Unknown'),
          TextCellValue(data['deletedBy'] ?? 'Unknown'),
          TextCellValue(_formatTimestamp(data['deletedAt'])),
        ]);
      }
    }
    Future<void> _createSynthesizeSheet(Excel excel) async {
      final sheet = excel['DefectedItems'];
      sheet.appendRow([
        TextCellValue('Name'),
        TextCellValue('Category Name'),
        TextCellValue('Deleted Quantity'),
        TextCellValue('Requested By'),  // <-- Added this column
        TextCellValue('Deleted By'),
        TextCellValue('Deleted At'),
        TextCellValue('Note'),
      ]);

      final snapshot = await _firestore.collection('deleted_synthesizes').get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        sheet.appendRow([
          TextCellValue(data['name'] ?? 'Unknown'),
          TextCellValue(data['categoryName'] ?? 'Unknown'),
          IntCellValue(data['deletedQuantity'] ?? 0),
          TextCellValue(data['requestedBy'] ?? 'Unknown'),  // <-- Added value here
          TextCellValue(data['deletedBy'] ?? 'Unknown'),
          TextCellValue(_formatTimestamp(data['deletedAt'])),
          TextCellValue(data['note'] ?? '-'),
        ]);
      }
    }


    Future<void> _createBoardsSheet(Excel excel) async {
      final sheet = excel['Boards'];
      sheet.appendRow([
        TextCellValue('Board Name'),
        TextCellValue('Added By'),
        TextCellValue('Created At'),
        TextCellValue('Component (Item) Name'),
        IntCellValue(0),
      ]);

      final snapshot = await _firestore.collection('boards').get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final boardName = data['boardName'] ?? data['name'] ?? 'Unknown';
        final addedBy = data['addedBy'] ?? 'Unknown';
        final createdAt = _formatTimestamp(data['createdAt']);

        final components = data['components'] as List<dynamic>?;
        if (components != null && components.isNotEmpty) {
          for (final comp in components) {
            sheet.appendRow([
              TextCellValue(boardName),
              TextCellValue(addedBy),
              TextCellValue(createdAt),
              TextCellValue(comp['itemName'] ?? 'Unknown'),
              IntCellValue(comp['quantity'] ?? 0),
            ]);
          }
        } else {
          sheet.appendRow([
            TextCellValue(boardName),
            TextCellValue(addedBy),
            TextCellValue(createdAt),
            TextCellValue('-'),
            IntCellValue(0),
          ]);
        }
      }
    }

    Future<void> _createBoardReceivesSheet(Excel excel) async {
      // Create or access the "BoardDelivered" sheet in the Excel file
      final sheet = excel['BoardDelivered'];

      // Add header row including the new "Note" column
      sheet.appendRow([
        TextCellValue('Board Name'),
        TextCellValue('Quantity Received'),
        TextCellValue('Delivered By'),
        TextCellValue('Received At'),
        TextCellValue('Received By'), // New column for notes
      ]);

      // Fetch all board receive logs from Firestore
      final snapshot = await _firestore
          .collection('board_receives')
          .orderBy('timestamp', descending: true)
          .get();

      // If no documents found, append a placeholder row
      if (snapshot.docs.isEmpty) {
        sheet.appendRow([
          TextCellValue('-'),
          IntCellValue(0),
          TextCellValue('No received boards data available'),
          TextCellValue('-'),
          TextCellValue('-'), // Placeholder for note
        ]);
      } else {
        // Loop through each document and append its data
        for (final doc in snapshot.docs) {
          final data = doc.data();

          sheet.appendRow([
            TextCellValue(data['boardName'] ?? 'Unknown'),
            IntCellValue(data['quantity'] ?? 0),
            TextCellValue(data['recievedBy'] ?? 'Unknown'),
            TextCellValue(_formatTimestamp(data['timestamp'])),
            TextCellValue(data['note'] ?? '-'), // Add the note field here
          ]);
        }
      }
    }

    Future<void> _createOnShelfInventorySheet(Excel excel) async {
      final sheet = excel['OnShelfInventory'];
      sheet.appendRow([
        TextCellValue('Type'),
        TextCellValue('Name'),
        TextCellValue('Quantity/Details'),
      ]);

      final snapshot = await _firestore.collection('boards').get();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final boardName = data['boardName'] ?? data['name'] ?? 'Unknown';
        final count = data['selectionCount'];
        sheet.appendRow([
          TextCellValue('Board'),
          TextCellValue(boardName),
          IntCellValue(count is int ? count : int.tryParse(count.toString()) ?? 0),
        ]);
      }
    }

    Future<void> downloadCategorySheet(BuildContext context) async {
      await _handleSheetDownload(context, 'Categories_Report.xlsx', _createCategorySheet);
    }

    Future<void> downloadDeletedItemsSheet(BuildContext context) async {
      await _handleSheetDownload(context, 'DeletedItems_Report.xlsx', _createDeletedItemsSheet);
    }

    Future<void> downloadDeletedCategoriesSheet(BuildContext context) async {
      await _handleSheetDownload(context, 'DeletedCategories_Report.xlsx', _createDeletedCategoriesSheet);
    }

    Future<void> downloadSynthesizeSheet(BuildContext context) async {
      await _handleSheetDownload(context, 'DefectedItems_Report.xlsx', _createSynthesizeSheet);
    }

    Future<void> downloadBoardsSheet(BuildContext context) async {
      await _handleSheetDownload(context, 'Boards_Report.xlsx', _createBoardsSheet);
    }

    Future<void> downloadBoardReceivesSheet(BuildContext context) async {
      await _handleSheetDownload(context, 'BoardDelivered_Report.xlsx', _createBoardReceivesSheet);
    }

    Future<void> downloadOnShelfInventorySheet(BuildContext context) async {
      await _handleSheetDownload(context, 'OnShelfInventory_Report.xlsx', _createOnShelfInventorySheet);
    }

    Future<void> downloadAddedComponentsSheet(BuildContext context) async {
      await _handleSheetDownload(context, 'AddedComponents_Report.xlsx', _createAddedComponentsSheet);
    }
    Future<void> downloadExtensionsLogsSheet(BuildContext context) async {
      await _handleSheetDownload(context, 'Extensions_logs.xlsx', _createExtensionLogsSheet);
    }

    Future<void> _handleSheetDownload(
        BuildContext context,
        String fileName,
        Future<void> Function(Excel) sheetBuilder,
        ) async {
      try {
        if (!await _hasStoragePermission()) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Storage permission denied")),
            );
          }
          return;
        }

        final excel = Excel.createExcel();
        await sheetBuilder(excel);

        final directory = await _getSaveDirectory();
        if (directory == null) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Download directory not available")),
            );
          }
          return;
        }

        final path = "${directory.path}/$fileName";
        final bytes = excel.save();
        final file = File(path)..createSync(recursive: true);
        await file.writeAsBytes(bytes!);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Downloaded to: $path")),
          );
        }

        await OpenFile.open(path);
      } catch (e) {
        print("Download error: $e");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to download: $fileName")),
          );
        }
      }
    }




    Future<String> _saveExcelFile(Excel excel) async {
      final directory = await _getSaveDirectory();
      if (directory == null) throw Exception("Download directory not available");

      final now = DateTime.now();
      final formattedDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final path = "${directory.path}/inventory_report_$formattedDate.xlsx";

      final bytes = excel.save();
      final file = File(path)..createSync(recursive: true);
      await file.writeAsBytes(bytes!);
      return path;
    }

    Future<Directory?> _getSaveDirectory() async {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        return await getDownloadsDirectory();
      } else if (Platform.isAndroid) {
        final dirs = await getExternalStorageDirectories(type: StorageDirectory.downloads);
        return dirs?.first;
      } else if (Platform.isIOS) {
        return await getApplicationDocumentsDirectory();
      }
      return null;
    }

    String _formatTimestamp(dynamic timestamp) {
      return (timestamp is Timestamp) ? timestamp.toDate().toString() : 'Unknown';
    }

    Future<bool> _hasStoragePermission() async {
      if (await Permission.manageExternalStorage.isGranted) return true;
      return (await Permission.manageExternalStorage.request()).isGranted;
    }

    void _showMessage(BuildContext context, String message) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }
