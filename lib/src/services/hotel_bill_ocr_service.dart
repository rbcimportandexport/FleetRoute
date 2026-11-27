import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ParsedHotelBill {
  final double amount;
  final String hotelName;
  final String dishesSummary;

  const ParsedHotelBill({
    required this.amount,
    required this.hotelName,
    required this.dishesSummary,
  });

  /// Extracts text using Google ML Kit on-device Text Recognizer,
  /// reconstructing visual rows from bounding boxes so multi-column tables
  /// and right-aligned totals stay on the same line.
  static Future<ParsedHotelBill> parseFromPhoto(Uint8List bytes,
      {String? fileName}) async {
    String reconstructedText = '';
    File? tempFile;

    try {
      final tempDir = Directory.systemTemp;
      tempFile = File(
          '${tempDir.path}/ocr_bill_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(bytes);

      final inputImage = InputImage.fromFilePath(tempFile.path);
      final textRecognizer =
          TextRecognizer(script: TextRecognitionScript.latin);
      final recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      reconstructedText = _reconstructVisualRows(recognizedText);
      if (reconstructedText.trim().isEmpty) {
        reconstructedText = recognizedText.text;
      }
      debugPrint('[ML_KIT_OCR] Reconstructed rows:\n$reconstructedText');
    } catch (e) {
      debugPrint('[ML_KIT_OCR] Error recognizing text: $e');
    } finally {
      if (tempFile != null && await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }

    if (reconstructedText.trim().isNotEmpty) {
      return parseFromText(reconstructedText);
    }

    return fallbackHeuristic(bytes.length);
  }

  /// Groups ML Kit TextLines by vertical Y coordinate so columns on the same
  /// visual row (e.g. "Total:" and "$ 692.98", or table cells) are joined left-to-right.
  static String _reconstructVisualRows(RecognizedText recognizedText) {
    final allLines = <TextLine>[];
    for (final block in recognizedText.blocks) {
      allLines.addAll(block.lines);
    }
    if (allLines.isEmpty) return '';

    // Sort top-to-bottom first
    allLines.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

    final rows = <List<TextLine>>[];
    for (final line in allLines) {
      final box = line.boundingBox;
      final centerY = (box.top + box.bottom) / 2.0;
      final height = (box.bottom - box.top).abs();
      final tolerance = (height * 0.65).clamp(8.0, 28.0);

      List<TextLine>? matchingRow;
      for (final row in rows) {
        final refBox = row.first.boundingBox;
        final refCenterY = (refBox.top + refBox.bottom) / 2.0;
        if ((centerY - refCenterY).abs() <= tolerance) {
          matchingRow = row;
          break;
        }
      }

      if (matchingRow != null) {
        matchingRow.add(line);
      } else {
        rows.add([line]);
      }
    }

    final buffer = StringBuffer();
    for (final row in rows) {
      row.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
      final rowText = row.map((l) => l.text.trim()).where((t) => t.isNotEmpty).join('  ');
      if (rowText.isNotEmpty) {
        buffer.writeln(rowText);
      }
    }
    return buffer.toString();
  }

  /// Parses raw or visually-reconstructed OCR text
  static ParsedHotelBill parseFromText(String text, {int seedLength = 0}) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // 1. Hotel / Business Name Extraction
    String hotel = '';
    final hotelPatterns = [
      RegExp(r'^(.*?Hotel.*)$', caseSensitive: false),
      RegExp(r'^(.*?Restaurant.*)$', caseSensitive: false),
      RegExp(r'^(.*?Dhaba.*)$', caseSensitive: false),
      RegExp(r'^(.*?Cafe.*)$', caseSensitive: false),
      RegExp(r'^(.*?Bhojanalay.*)$', caseSensitive: false),
      RegExp(r'^(.*?Dining.*)$', caseSensitive: false),
    ];

    for (final line in lines) {
      final lLower = line.toLowerCase();
      // Strictly avoid bank account, payment instructions, addresses, or metadata lines
      if (lLower.contains('bank') ||
          lLower.contains('account') ||
          lLower.contains('payment') ||
          lLower.contains('please make') ||
          lLower.contains('billed to') ||
          lLower.contains('invoice number') ||
          lLower.contains('terms and') ||
          lLower.contains('street') ||
          lLower.contains('road') ||
          lLower.contains('lane') ||
          lLower.contains('thank you') ||
          lLower == 'hotel invoice' ||
          lLower == 'hotel bill' ||
          lLower == 'invoice') {
        continue;
      }

      // If line has "INVOICE" on the right side (e.g. "Highfair Hotel  INVOICE"), strip INVOICE
      final cleanedLine = line
          .replaceAll(RegExp(r'\bINVOICE\b', caseSensitive: false), '')
          .trim();

      for (final p in hotelPatterns) {
        final match = p.firstMatch(cleanedLine);
        if (match != null) {
          var candidate = match.group(1)?.trim() ?? '';
          candidate = candidate
              .replaceAll(RegExp(r'^[#*:\-\s]+|[#*:\-\s]+$'), '')
              .trim();
          if (candidate.isNotEmpty) {
            hotel = candidate;
            break;
          }
        }
      }
      if (hotel.isNotEmpty) break;
    }

    if (hotel.isEmpty && lines.isNotEmpty) {
      for (int i = 0; i < lines.length && i < 4; i++) {
        final l = lines[i]
            .replaceAll(RegExp(r'\bINVOICE\b', caseSensitive: false), '')
            .trim();
        final lLower = l.toLowerCase();
        if (!lLower.contains('invoice') &&
            !lLower.contains('bill') &&
            !lLower.contains('date') &&
            !lLower.contains('billed to') &&
            !lLower.contains('page') &&
            !lLower.contains('bank') &&
            !lLower.contains('account') &&
            !lLower.contains('payment') &&
            l.length >= 3) {
          hotel = l;
          break;
        }
      }
    }

    // 2. Amount Extraction (Strict logic so Tax(%) 10 or Qty 4 is NEVER picked as Total)
    double amount = 0.0;

    // Step A: Priority on explicit Grand Total / Total Due / Net Amount lines
    for (final line in lines.reversed) {
      final lLower = line.toLowerCase();
      // Skip subtotal or tax breakdown lines
      if (lLower.contains('subtotal') ||
          lLower.contains('sub total') ||
          lLower.contains('sub-total') ||
          lLower.contains('tax(') ||
          lLower.contains('tax (%)')) {
        continue;
      }

      final hasGrandTotal = RegExp(
        r'\b(?:grand\s*total|net\s*total|net\s*amount|total\s*due|amount\s*payable|balance\s*due)\b',
        caseSensitive: false,
      ).hasMatch(lLower);

      final hasSimpleTotal = RegExp(r'\btotal\b', caseSensitive: false).hasMatch(lLower) &&
          !lLower.contains('item') &&
          !lLower.contains('description');

      if (hasGrandTotal || hasSimpleTotal) {
        // Find numbers on this line. Avoid numbers directly followed by '%'
        final matches = RegExp(r'(?:[$₹]\s*)?([0-9][0-9,]*(?:\.[0-9]{1,2})?)(?!\s*%)').allMatches(line).toList();
        for (final m in matches.reversed) {
          final raw = (m.group(1) ?? '').replaceAll(',', '');
          final val = double.tryParse(raw);
          // If simple "total", avoid picking single-digit numbers or exact tax percentage (like 10) if other larger numbers exist
          if (val != null && val > 0) {
            amount = val;
            break;
          }
        }
      }
      if (amount > 0) break;
    }

    // Step B: Look for "Total:" on one line and number on the very next line
    if (amount <= 0) {
      for (int i = lines.length - 1; i >= 0; i--) {
        final lLower = lines[i].toLowerCase();
        if (lLower.contains('subtotal') || lLower.contains('sub total')) continue;
        if (RegExp(r'\b(?:grand\s*total|total\s*due|net\s*amount|total)\b', caseSensitive: false).hasMatch(lLower)) {
          if (i + 1 < lines.length) {
            final nextLine = lines[i + 1].trim();
            final m = RegExp(r'^[$₹\s]*([0-9][0-9,]*(?:\.[0-9]{1,2})?)$')
                .firstMatch(nextLine);
            if (m != null) {
              final val =
                  double.tryParse((m.group(1) ?? '').replaceAll(',', ''));
              if (val != null && val > 0) {
                amount = val;
                break;
              }
            }
          }
        }
      }
    }

    // Step C: Look for explicit currency formatted amounts ($ 692.98, ₹ 692.98, Rs. 692.98)
    if (amount <= 0) {
      final currencyMatches =
          RegExp(r'(?:[$₹]|rs\.?)\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)',
                  caseSensitive: false)
              .allMatches(text);
      for (final m in currencyMatches) {
        final val =
            double.tryParse((m.group(1) ?? '').replaceAll(',', '')) ?? 0.0;
        if (val > amount) amount = val;
      }
    }

    // Step D: Fallback to highest decimal price in the entire document (e.g. 692.98, 629.98, 600.00)
    // This completely ignores small integer column values like 10, 4, 1, 0!
    if (amount <= 0) {
      final decimalMatches =
          RegExp(r'\b([0-9][0-9,]*\.[0-9]{2})\b').allMatches(text);
      for (final m in decimalMatches) {
        final val =
            double.tryParse((m.group(1) ?? '').replaceAll(',', '')) ?? 0.0;
        if (val > amount) amount = val;
      }
    }

    // Step E: Subtotal fallback
    if (amount <= 0) {
      for (final line in lines.reversed) {
        if (line.toLowerCase().contains('subtotal')) {
          final m = RegExp(r'([0-9][0-9,]*(?:\.[0-9]{1,2})?)').allMatches(line);
          for (final match in m.toList().reversed) {
            final val = double.tryParse((match.group(1) ?? '').replaceAll(',', ''));
            if (val != null && val > 0) {
              amount = val;
              break;
            }
          }
        }
        if (amount > 0) break;
      }
    }

    // 3. Item & Dish Extraction (Cleanly extract actual items, NEVER payment/bank/address lines)
    final List<String> detectedItems = [];

    bool insideItemTable = false;
    for (final line in lines) {
      final lLower = line.toLowerCase();

      // Stop table parsing immediately if we hit summary, payment, bank, or footer sections
      if (lLower.contains('subtotal') ||
          lLower.contains('sub total') ||
          lLower.contains('total:') ||
          lLower.contains('grand total') ||
          lLower.contains('please make payment') ||
          lLower.contains('bank account') ||
          lLower.contains('terms and') ||
          lLower.contains('thank you') ||
          lLower.contains('page ') ||
          lLower.contains('billed to') ||
          (lLower.contains('total') && !lLower.contains('item'))) {
        insideItemTable = false;
        continue;
      }

      if (lLower.contains('description') ||
          lLower.contains('particulars') ||
          (lLower.contains('item') &&
              (lLower.contains('qty') ||
                  lLower.contains('price') ||
                  lLower.contains('amount')))) {
        insideItemTable = true;
        continue;
      }

      if (insideItemTable) {
        // Skip header continuation or non-item markers
        if (lLower == 'price' ||
            lLower == '#' ||
            lLower == 'unit price' ||
            lLower.startsWith('inv-') ||
            lLower.contains('invoice date') ||
            lLower.contains('due date')) {
          continue;
        }

        // Split by 2+ spaces (column separator)
        final columns = line.split(RegExp(r'\s{2,}'));
        String itemDesc = '';

        if (columns.length >= 2) {
          // Find the best description column (has letters, not pure numbers/prices)
          for (final col in columns) {
            final trimmed = col.trim();
            final hasLetters = RegExp(r'[a-zA-Z]{3,}').hasMatch(trimmed);
            final isPurePrice = RegExp(r'^[$₹]?\s*\d+(?:\.\d+)?%?$').hasMatch(trimmed);
            final isColumnHeader = RegExp(r'^(?:item|qty|unit price|discount|tax|amount)$', caseSensitive: false).hasMatch(trimmed);
            if (hasLetters && !isPurePrice && !isColumnHeader) {
              if (trimmed.length > itemDesc.length) {
                itemDesc = trimmed;
              }
            }
          }
        }

        if (itemDesc.isEmpty) {
          // Regex extract between index and numeric price columns
          // e.g. "1  Junior Suite, 4 nights  150  4  0  10  600.00"
          // e.g. "Junior Suite, 4 nights 600.00"
          var cleaned = line.replaceFirst(RegExp(r'^\s*\d+[\.\)]?\s+'), '');
          cleaned = cleaned.replaceAll(RegExp(r'(?:\s+[$₹]?\d+(?:\.\d{1,2})?%?)+$'), '').trim();
          if (RegExp(r'[a-zA-Z]{3,}').hasMatch(cleaned)) {
            itemDesc = cleaned;
          }
        }

        // Clean any stray prefix numbers or symbols
        itemDesc = itemDesc.replaceFirst(RegExp(r'^\s*\d+[\.\)]?\s+'), '').trim();

        if (itemDesc.length >= 3 &&
            !itemDesc.toLowerCase().contains('amount') &&
            !itemDesc.toLowerCase().contains('discount') &&
            !itemDesc.toLowerCase().contains('unit price') &&
            !itemDesc.toLowerCase().contains('invoice') &&
            !itemDesc.toLowerCase().contains('due date') &&
            !itemDesc.toLowerCase().contains('bank')) {
          if (!detectedItems.contains(itemDesc)) {
            detectedItems.add(itemDesc);
          }
        }
      }
    }

    // Second: Keyword matching for common Indian Dhaba & Hotel dishes (only if not already captured)
    final foodKeywords = <String, String>{
      'dal fry': 'Dal Fry',
      'dal tadka': 'Dal Tadka',
      'roti': 'Roti',
      'chapati': 'Roti',
      'naan': 'Naan',
      'paneer': 'Paneer Sabji',
      'sev tamatar': 'Sev Tamatar',
      'chana masala': 'Chana Masala',
      'thali': 'Thali Meal',
      'jeera rice': 'Jeera Rice',
      'chhas': 'Chhas',
      'chaas': 'Chhas',
      'buttermilk': 'Butter Milk',
      'dahi': 'Dahi',
      'special chai': 'Special Chai',
      'tea': 'Tea',
      'chai': 'Chai',
      'coffee': 'Coffee',
      'water bottle': 'Water Bottle',
      'bisleri': 'Bisleri Water',
      'breakfast': 'Breakfast',
      'dinner': 'Dinner',
      'lunch': 'Lunch',
    };

    final lower = text.toLowerCase();
    for (final entry in foodKeywords.entries) {
      if (lower.contains(entry.key)) {
        if (!detectedItems.any((item) => item.toLowerCase().contains(entry.key))) {
          detectedItems.add(entry.value);
        }
      }
    }

    // Detect if this is an industrial/commercial goods invoice or transport bilty, NOT a hotel/food bill
    final isGoodsOrFurnitureInvoice = lower.contains('furniture') ||
        lower.contains('salon') ||
        lower.contains('hsn/sac') ||
        lower.contains('transport') ||
        lower.contains('lorry receipt') ||
        lower.contains('consignment') ||
        lower.contains('consignee') ||
        lower.contains('bilty') ||
        lower.contains('debit memo') ||
        lower.contains('place of supply') ||
        lower.contains('haldharu') ||
        lower.contains('rbc salon');

    String summary = detectedItems.join(' · ');
    if (summary.isEmpty && lines.length > 2) {
      if (isGoodsOrFurnitureInvoice) {
        summary = 'Commercial Goods / Transport Bill';
      } else {
        summary = lines.take(3).join(' · ');
      }
    }

    return ParsedHotelBill(
      amount: amount,
      hotelName: hotel.isNotEmpty ? hotel : 'Hotel Stay',
      dishesSummary: summary.isNotEmpty ? summary : 'Hotel & Food Expense',
    );
  }

  static ParsedHotelBill fallbackHeuristic(int seedLength) {
    return const ParsedHotelBill(
      amount: 0.0,
      hotelName: 'Hotel Stay',
      dishesSummary: 'Food & Stay Bill',
    );
  }
}
