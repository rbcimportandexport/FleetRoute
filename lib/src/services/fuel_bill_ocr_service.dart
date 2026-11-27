import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ParsedFuelDetails {
  final double amount;
  final double liters;
  final double ratePerLiter;
  final String pumpName;

  const ParsedFuelDetails({
    required this.amount,
    required this.liters,
    required this.ratePerLiter,
    required this.pumpName,
  });

  /// Extracts text using Google ML Kit on-device Text Recognizer
  static Future<ParsedFuelDetails> parseFromPhoto(Uint8List bytes) async {
    String ocrText = '';
    File? tempFile;

    try {
      final tempDir = Directory.systemTemp;
      tempFile = File(
          '${tempDir.path}/ocr_fuel_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(bytes);

      final inputImage = InputImage.fromFilePath(tempFile.path);
      final textRecognizer =
          TextRecognizer(script: TextRecognitionScript.latin);
      final recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      ocrText = _reconstructVisualRows(recognizedText);
      if (ocrText.trim().isEmpty) {
        ocrText = recognizedText.text;
      }
      debugPrint('[FUEL_OCR] Extracted text: \n$ocrText');
    } catch (e) {
      debugPrint('[FUEL_OCR] Error recognizing text: $e');
    } finally {
      if (tempFile != null && await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }

    if (ocrText.trim().isNotEmpty) {
      return parseFromText(ocrText);
    }

    return const ParsedFuelDetails(
      amount: 0.0,
      liters: 0.0,
      ratePerLiter: 0.0,
      pumpName: '',
    );
  }

  static String _reconstructVisualRows(RecognizedText recognizedText) {
    final allLines = <TextLine>[];
    for (final block in recognizedText.blocks) {
      allLines.addAll(block.lines);
    }
    if (allLines.isEmpty) return '';

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
      final rowText =
          row.map((l) => l.text.trim()).where((t) => t.isNotEmpty).join('  ');
      if (rowText.isNotEmpty) buffer.writeln(rowText);
    }
    return buffer.toString();
  }

  /// Parses text from Fuel Receipt or Dispenser Machine Screen
  static ParsedFuelDetails parseFromText(String text) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    double amount = 0.0;
    double liters = 0.0;
    double rate = 0.0;
    String pump = '';

    // 1. Petrol Pump / Fuel Station Brand & Name
    final pumpPatterns = [
      RegExp(
          r'(?:Indian\s*Oil|IOCL|Bharat\s*Petroleum|BPCL|Hindustan\s*Petroleum|HPCL|Nayara|Reliance|Shell|Essar).*',
          caseSensitive: false),
      RegExp(
          r'.*?(?:Fuel|Petroleum|Filling\s*Station|Auto\s*Service|Kisan\s*Seva).*',
          caseSensitive: false),
    ];
    for (final line in lines) {
      for (final p in pumpPatterns) {
        final match = p.firstMatch(line);
        if (match != null) {
          pump = match.group(0)?.trim() ?? '';
          break;
        }
      }
      if (pump.isNotEmpty) break;
    }

    // 2. Amount Extraction (Rupees / Rs / Total / Sale)
    final amountPatterns = [
      RegExp(
          r'(?:sale|total\s*sale|total\s*amount|amount|amt|net\s*amt|rupees|rs\.?|inr)\s*[:\-\s]*[$₹\s]*([0-9]+(?:\.[0-9]{1,2})?)',
          caseSensitive: false),
      RegExp(r'(?:₹|rs\.?)\s*([0-9]+(?:\.[0-9]{1,2})?)', caseSensitive: false),
    ];

    for (final p in amountPatterns) {
      final match = p.firstMatch(text);
      if (match != null) {
        final val = double.tryParse(match.group(1) ?? '0');
        if (val != null && val > 0) {
          amount = val;
          break;
        }
      }
    }

    // 3. Volume / Liters Extraction (Ltr / Litre / Volume / Qty)
    final volumePatterns = [
      RegExp(
          r'(?:volume|vol|qty|quantity|litres?|liters?|ltrs?)\s*[:\-\s]*([0-9]+(?:\.[0-9]{1,3})?)',
          caseSensitive: false),
      RegExp(r'([0-9]+(?:\.[0-9]{1,3})?)\s*(?:ltrs?|litres?|liters?|l)\b',
          caseSensitive: false),
    ];

    for (final p in volumePatterns) {
      final match = p.firstMatch(text);
      if (match != null) {
        final val = double.tryParse(match.group(1) ?? '0');
        if (val != null && val > 0 && val != amount) {
          liters = val;
          break;
        }
      }
    }

    // 4. Rate per Liter Extraction
    final rateMatch = RegExp(
            r'(?:rate|price|unit\s*price|rsp)\s*[:\-\s]*[$₹\s]*([0-9]+(?:\.[0-9]{1,2})?)',
            caseSensitive: false)
        .firstMatch(text);
    if (rateMatch != null) {
      rate = double.tryParse(rateMatch.group(1) ?? '0') ?? 0.0;
    }

    // 5. Digital Fuel Dispenser Meter Screen Fallback:
    // On dispenser meter screens, usually there are 2 or 3 large numbers:
    // Top/Main: Total Amount (e.g. 5000.00)
    // Middle: Volume / Liters (e.g. 55.45)
    // Bottom: Rate per Litre (e.g. 90.17)
    if (amount <= 0 || liters <= 0) {
      final numbers = <double>[];
      for (final line in lines) {
        final matches =
            RegExp(r'\b([0-9]{2,6}(?:\.[0-9]{1,3})?)\b').allMatches(line);
        for (final m in matches) {
          final val = double.tryParse(m.group(1) ?? '0');
          if (val != null && val > 5.0 && val < 500000.0) {
            numbers.add(val);
          }
        }
      }

      if (numbers.isNotEmpty) {
        // Find the largest number as total amount
        double maxVal = 0.0;
        int maxIdx = 0;
        for (int i = 0; i < numbers.length; i++) {
          if (numbers[i] > maxVal) {
            maxVal = numbers[i];
            maxIdx = i;
          }
        }
        if (amount <= 0) {
          amount = maxVal;
        }
        if (liters <= 0 && numbers.length > 1) {
          // On a dispenser screen (top-to-bottom): Amount -> Liters -> Rate.
          // Prefer the number immediately following Amount (or not matching typical ₹85-115 rate if multiple exist)
          final candidates = <double>[];
          for (int i = 0; i < numbers.length; i++) {
            if (i != maxIdx && numbers[i] < amount && numbers[i] < 1500) {
              candidates.add(numbers[i]);
            }
          }
          if (candidates.length >= 2) {
            // Top-to-bottom: first candidate after amount is Volume/Liters, second is Rate
            liters = candidates.first;
            if (rate <= 0) rate = candidates[1];
          } else if (candidates.isNotEmpty) {
            liters = candidates.first;
          }
        }
      }
    }

    return ParsedFuelDetails(
      amount: amount,
      liters: liters,
      ratePerLiter: rate,
      pumpName: pump,
    );
  }
}
