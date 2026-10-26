import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<void> main() async {
  final lines = (await File('TRANSPORT_ONE_FULL_BUG_AUDIT.md').readAsString()).split('\n');
  final doc = pw.Document();
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(32),
    footer: (c) => pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text('Page ${c.pageNumber} / ${c.pagesCount}', style: const pw.TextStyle(fontSize: 8))),
    build: (_) => lines.map((line) {
      if (line.startsWith('# ')) return pw.Padding(padding: const pw.EdgeInsets.only(bottom: 10), child: pw.Text(line.substring(2), style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)));
      if (line.startsWith('## ')) return pw.Padding(padding: const pw.EdgeInsets.only(top: 10, bottom: 5), child: pw.Text(line.substring(3), style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)));
      if (line.startsWith('### ')) return pw.Padding(padding: const pw.EdgeInsets.only(top: 7, bottom: 3), child: pw.Text(line.substring(4), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)));
      if (line.trim().startsWith('```')) return pw.SizedBox(height: 2);
      return pw.Padding(padding: const pw.EdgeInsets.only(bottom: 3), child: pw.Text(line, style: const pw.TextStyle(fontSize: 9.2)));
    }).toList(),
  ));
  await File('TRANSPORT_ONE_FULL_BUG_AUDIT.pdf').writeAsBytes(await doc.save());
}
