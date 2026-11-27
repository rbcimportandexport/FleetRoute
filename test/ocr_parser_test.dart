import 'package:flutter_test/flutter_test.dart';
import 'package:transport_one/src/services/hotel_bill_ocr_service.dart';
import 'package:transport_one/src/services/fuel_bill_ocr_service.dart';
import 'package:transport_one/src/services/bill_ocr_parser_service.dart';

void main() {
  test('ParsedHotelBill accurately parses Highfair Hotel invoice', () {
    const invoiceText = '''
Highfair Hotel  INVOICE
Highfair Hotel
122 Main Street
Highfair
12706
Billed to
John Smith  Invoice number:  INV-1001
12 Crescent Close  Invoice date:  Oct 29, 2024
Fairview  Due date:  Nov 12, 2024
11027
United States
Item #  Description  Unit Price  Qty  Discount(%)  Tax(%)  Amount
1  Junior Suite, 4 nights  150  4  0  10  600.00
2  Drinks from the minibar  4.99  2  0  10  9.98
3  Laundry, one item  20  1  0  10  20.00
Subtotal:  629.98
Tax:  63.00
Total:  \$ 692.98
Please make payment to
Highfair Hotel bank account
123456789xx
12 Queen Street, Highfair
Terms and conditions
Thank you for staying with us!
''';

    final parsed = ParsedHotelBill.parseFromText(invoiceText);
    expect(parsed.hotelName, 'Highfair Hotel');
    expect(parsed.amount, 692.98);
    expect(parsed.dishesSummary, contains('Junior Suite, 4 nights'));
    expect(parsed.dishesSummary, contains('Drinks from the minibar'));
    expect(parsed.dishesSummary, contains('Laundry, one item'));
    expect(parsed.dishesSummary, isNot(contains('Please make payment')));
    expect(parsed.dishesSummary, isNot(contains('bank account')));
    expect(parsed.dishesSummary, isNot(contains('Jeera Rice')));
  });

  test('ParsedHotelBill handles realistic imperfect phone camera OCR order', () {
    const imperfectOcrText = '''
Highfair Hotel
122 Main Street Highfair 12706
INVOICE
Billed to
John Smith
12 Crescent Close
Fairview 11027
United States
Invoice number: INV-1001
Invoice date: Oct 29, 2024
Due date: Nov 12, 2024
Item # Description Unit Price Qty Discount(%) Tax(%) Amount
1 Junior Suite, 4 nights 150 4 0 10 600.00
2 Drinks from the minibar 4.99 2 0 10 9.98
3 Laundry, one item 20 1 0 10 20.00
Subtotal: 629.98
Tax: 63.00
Total: \$ 692.98
Please make payment to
Highfair Hotel bank account
123456789xx
12 Queen Street, Highfair
Terms and conditions
Thank you for staying with us!
''';

    final parsed = ParsedHotelBill.parseFromText(imperfectOcrText);
    expect(parsed.hotelName, 'Highfair Hotel');
    expect(parsed.amount, 692.98);
    expect(parsed.dishesSummary, contains('Junior Suite, 4 nights'));
    expect(parsed.dishesSummary, contains('Drinks from the minibar'));
    expect(parsed.dishesSummary, contains('Laundry, one item'));
    expect(parsed.dishesSummary, isNot(contains('bank account')));
    expect(parsed.dishesSummary, isNot(contains('Please make payment')));
  });

  test('ParsedFuelDetails accurately parses fuel dispenser and slip', () {
    const meterText = '''
Indian Oil
5000.00
55.45
90.17
''';
    final parsed = ParsedFuelDetails.parseFromText(meterText);
    expect(parsed.amount, 5000.00);
    expect(parsed.liters, 55.45);
    expect(parsed.pumpName, contains('Indian Oil'));
  });

  test('ParsedBillDetails accurately parses RBC Furniture Makeup Palace Invoice', () {
    const rbcInvoiceText = '''
Mo. 9276602526
RBC SALON FURNITURE PRIVATE LIMITED
BLOCK NO. 124, HALDHARU-MOTA ROAD, NEAR XPRESS HIGHWAY MOTA GAM SURAT 394345
Debit Memo  Tax Invoice  Original
M/s. : MAKEUP PALACE  Invoice No. : GT/2708
OPP MAHABALI COURIER KHARIVAV ROAD  Date : 03/11/2026
VADODARA - 390001  Mo: 9904720708
GSTIN No. : 24EXOPP0914H1ZC  Place of Supply : 24-Gujarat
Sr.  Product Name  HSN/SAC Code  Qty  Rate  Discount  Taxable Amount  GST%  Tax Amount  Net Amount
1  504-RBC- BED  94021090  1.000  9745.76  9745.76  18.0  1754.24  11500.00
2  140-RBC.  94021090  1.000  2288.13  2288.13  18.0  411.86  2699.99
Total  12033.89  2166.10  14199.99
Round Off  0.01
Grand Total  14,200.00
''';

    final parsed = ParsedBillDetails.extractFromText(rbcInvoiceText);
    expect(parsed.customerName, 'MAKEUP PALACE');
    expect(parsed.customerPhone, '9904720708');
    expect(parsed.totalCartons, 2); // 1.000 + 1.000
    expect(parsed.invoiceNumber, 'GT/2708');
  });

  test('ParsedBillDetails sums item quantities 2.000 + 1.000 = 3 cartons correctly', () {
    const rbcInvoiceWith3Cartons = '''
Mo. 9276602526
RBC SALON FURNITURE PRIVATE LIMITED
BLOCK NO.124,HALDHARU-MOTA ROAD,NEAR XPRESS HIGHWAY MOTA GAM SURAT 394345
Debit Memo Tax Invoice Original
M/s. : MAKEUP PALACE Invoice No. : GT/2804
OPP MAHABALI COURIER KHARIVAV ROAD Date : 20/11/2026
ADDRES :
VADODARA - 390001 Mo: 9904720708
GSTIN No. : 24EXOPP0914H1ZC Place of Supply: 24-Gujarat
Sr. Product Name HSN/SAC Code Qty Rate Discount Taxable Amount GST% Tax Amount Net Amount
1 403-RBC SALON CHAIR 94021090 2.000 7627.11 15254.22 18.0 1372.88 1372.88 17999.98
2 340-RBC SHEMPOO/(M/P) 94021090 1.000 27118.64 27118.64 18.0 2440.68 2440.68 32000.00
GSTIN No.: 24AANCR5693L1ZM Total 42372.86 3813.56 3813.56 49999.98
Round Off 0.02
Grand Total 50,000.00
''';

    final parsed = ParsedBillDetails.extractFromText(rbcInvoiceWith3Cartons);
    expect(parsed.customerName, 'MAKEUP PALACE');
    expect(parsed.customerPhone, '9904720708');
    expect(parsed.totalCartons, 3); // 2.000 + 1.000 = 3!
    expect(parsed.invoiceNumber, 'GT/2804');
  });

  test('ParsedBillDetails parses 3 distinct items (1.000 + 1.000 + 1.000 = 3 cartons) from GT/1040', () {
    const invoiceGT1040 = '''
Mo. 9276602526
RBC SALON FURNITURE PRIVATE LIMITED
132,ARADHANA INDUSTRIAL ESTATE,JOLVA,NEAR GRAM PANCHAYAT JOLWA-394305
Debit Memo Tax Invoice Original
M/s. : MAKEUP PALACE Invoice No. : GT/1040
OPP MAHABALI COURIER KHARIVAV ROAD Date : 21/08/2026
ADDRES :
VADODARA - 390001 Mo: 9904720708
GSTIN No. : 24EXOPP0914H1ZC Place of Supply: 24-Gujarat
Sr. Product Name HSN/SAC Code Qty Rate Discount Taxable Amount GST% Tax Amount Net Amount
1 249-RBC- BARBER CHAIR 94021090 1.000 9745.76 9745.76 18.0 877.12 877.12 11500.00
2 3021 RAMA 94021090 1.000 8050.84 8050.84 18.0 724.58 724.58 9500.00
3 510-RBC (BED). 94021090 1.000 8474.57 8474.57 18.0 762.71 762.71 9999.99
GSTIN No.: 24AANCR5693L1ZM Total 26271.17 2364.41 2364.41 30999.99
Round Off 0.01
Grand Total 31,000.00
''';

    final parsed = ParsedBillDetails.extractFromText(invoiceGT1040);
    expect(parsed.customerName, 'MAKEUP PALACE');
    expect(parsed.customerPhone, '9904720708');
    expect(parsed.totalCartons, 3); // 1.000 + 1.000 + 1.000 = 3!
    expect(parsed.invoiceNumber, 'GT/1040');
  });

  test('ParsedBillDetails accurately parses RAMA SALON FURNITURE (GT/1604) without M/s prefix and 2 cartons', () {
    const invoiceGT1604 = '''
Mo. 9276602526
RBC SALON FURNITURE PRIVATE LIMITED
132,ARADHANA INDUSTRIAL ESTATE,JOLVA,NEAR GRAM PANCHAYAT JOLWA-394305
Debit Memo Tax Invoice Original
M/s. : RAMA SALON FURNITURE Invoice No. : GT/1604
S.NO.31,KALP IND EST,NR.SAHIYA BUSINESS PARK,NIKOL,RING Date : 23/09/2026
ADDRES :
AHMEDABAD - 382350 Mo: 9327908911
GSTIN No. : 24CYTPK6398C1ZW Place of Supply: 24-Gujarat
Sr. Product Name HSN/SAC Code Qty Rate Discount Taxable Amount GST% Tax Amount Net Amount
1 parts 721550 2.000 296.61 593.22 18.0 53.39 53.39 700.00
GSTIN No.: 24AANCR5693L1ZM Total 593.22 53.39 53.39 700.00
Upi Code --->
Total GST : One Hundred Six And Seventy Eight Paise Only
Bill Amount : Seven Hundred Only
Grand Total 700.00
''';

    final parsed = ParsedBillDetails.extractFromText(invoiceGT1604);
    expect(parsed.customerName, 'RAMA SALON FURNITURE');
    expect(parsed.customerPhone, '9327908911');
    expect(parsed.totalCartons, 2); // 2.000 Qty = 2 cartons (NOT 20!)
    expect(parsed.invoiceNumber, 'GT/1604');
  });

  test('ParsedBillDetails accurately parses SWAROOP SALOON - DIPAK (GT/865) and 6 cartons', () {
    const invoiceGT865 = '''
Mo. 9276602526
RBC SALON FURNITURE PRIVATE LIMITED
132,ARADHANA INDUSTRIAL ESTATE,JOLVA,NEAR GRAM PANCHAYAT JOLWA-394305
Debit Memo Tax Invoice Duplicate
M/s. : SWAROOP SALOON - DIPAK Invoice No. : GT/865
VEER DUGA DAS MARG MALL GODAM ROAD Date : 06/08/2026
ADDRES :
Badmer - 344001 Mo: 9782344410
Place of Supply: 08-Rajasthan
Sr. Product Name HSN/SAC Code Qty Rate Discount Taxable Amount GST% Tax Amount Net Amount
1 433-RBC 94021090 4.000 12711.86 50847.44 18.0 9152.54 59999.98
2 916-RBC 39269099 1.000 52542.37 52542.37 18.0 9457.63 62000.00
3 911-RBC-MASSAGER 73269099 1.000 135593.2 135593.22 18.0 24406.78 160000.00
Total 238983.03 43016.95 281999.98
GSTIN No.: 24AANCR5693L1ZM
Round Off 0.02
Grand Total 2,82,000.00
''';

    final parsed = ParsedBillDetails.extractFromText(invoiceGT865);
    expect(parsed.customerName, 'SWAROOP SALOON - DIPAK');
    expect(parsed.customerPhone, '9782344410');
    expect(parsed.totalCartons, 6); // 4.000 + 1.000 + 1.000 = 6 cartons!
    expect(parsed.invoiceNumber, 'GT/865');
  });

  test('ParsedBillDetails handles OCR misread MA : SWAROOP SALOON - DIPAK cleanly and 6 cartons', () {
    const ocrMisreadGT865 = '''
Mo. 9276602526
RBC SALON FURNITURE PRIVATE LIMITED
132,ARADHANA INDUSTRIAL ESTATE,JOLVA,NEAR GRAM PANCHAYAT JOLWA-394305
Debit Memo Tax Invoice Duplicate
MA : SWAROOP SALOON - DIPAK   Invoice No. : GT/865
VEER DUGA DAS MARG MALL GODAM ROAD Date : 06/08/2026
ADDRES :
Badmer - 344001 Mo: 9782344410
Place of Supply: 08-Rajasthan
Sr. Product Name HSN/SAC Code Qty Rate Discount Taxable Amount GST% Tax Amount Net Amount
1 433-RBC 94021090 4.000 12711.86 50847.44 18.0 9152.54 59999.98
2 916-RBC 39269099 1.000 52542.37 52542.37 18.0 9457.63 62000.00
3 911-RBC-MASSAGER 73269099 1.000 135593.2 135593.22 18.0 24406.78 160000.00
Total 238983.03 43016.95 281999.98
GSTIN No.: 24AANCR5693L1ZM
Round Off 0.02
Grand Total 2,82,000.00
''';

    final parsed = ParsedBillDetails.extractFromText(ocrMisreadGT865);
    expect(parsed.customerName, 'SWAROOP SALOON - DIPAK');
    expect(parsed.customerPhone, '9782344410');
    expect(parsed.totalCartons, 6);
    expect(parsed.invoiceNumber, 'GT/865');
  });

  test('ParsedBillDetails normalizes DII OCR misread to DIPAK and computes 6 cartons (not 54!)', () {
    const ocrMisreadDII = '''
Debit Memo Tax Invoice Duplicate
M/s. : SWAROOP SALOON - DII   Invoice No. : GT/865
VEER DUGA DAS MARG MALL GODAM ROAD Date : 06/08/2026
Badmer - 344001 Mo: 9782344410
Sr. Product Name HSN/SAC Code Qty Rate Discount Taxable Amount GST% Tax Amount Net Amount
1 433-RBC 94021090 4.000 12711.86 50847.44 18.0 9152.54 59999.98
2 916-RBC 39269099 1.000 52542.37 52542.37 18.0 9457.63 62000.00
3 911-RBC-MASSAGER 73269099 1.000 135593.2 135593.22 18.0 24406.78 160000.00
Grand Total 2,82,000.00
''';

    final parsed = ParsedBillDetails.extractFromText(ocrMisreadDII);
    expect(parsed.customerName, 'SWAROOP SALOON - DIPAK');
    expect(parsed.customerPhone, '9782344410');
    expect(parsed.totalCartons, 6); // Must be 6, NOT 54 (18+18+18)!
    expect(parsed.invoiceNumber, 'GT/865');
  });
}
