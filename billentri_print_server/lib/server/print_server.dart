// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

class PrintItem {
  final String companyName;
  final String itemName;
  final String barcode;
  final double price;
  final String currency;

  final double marginLeft;
  final double marginTop;
  final double marginRight;
  final double marginBottom;
  final double rowGap;
  final double columnGap;
  final int barcodeRow;
  final int decimalPlaces;

  // Font settings
  final String companyFont;
  final int companyFontSize;
  final String itemFont;
  final int itemFontSize;
  final String barcodeTextFont;
  final int barcodeTextFontSize;
  final String priceFont;
  final int priceFontSize;

  PrintItem({
    required this.companyName,
    required this.itemName,
    required this.barcode,
    required this.price,
    required this.currency,
    this.marginLeft = 0.0,
    this.marginTop = 0.0,
    this.marginRight = 0.0,
    this.marginBottom = 0.0,
    this.rowGap = 0.0,
    this.columnGap = 0.0,
    this.barcodeRow = 1,
    this.decimalPlaces = 3,
    this.companyFont = "2",
    this.companyFontSize = 1,
    this.itemFont = "1",
    this.itemFontSize = 1,
    this.barcodeTextFont = "1",
    this.barcodeTextFontSize = 1,
    this.priceFont = "2",
    this.priceFontSize = 1,
  });

  factory PrintItem.fromJson(Map<String, dynamic> json) {
    return PrintItem(
      companyName: json['companyName'] ?? '',
      itemName: json['itemName'] ?? '',
      barcode: json['barcode'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      currency: json['currency'] ?? '',
      marginLeft: (json['marginLeft'] ?? 0).toDouble(),
      marginTop: (json['marginTop'] ?? 0).toDouble(),
      marginRight: (json['marginRight'] ?? 0).toDouble(),
      marginBottom: (json['marginBottom'] ?? 0).toDouble(),
      rowGap: (json['rowGap'] ?? 0).toDouble(),
      columnGap: (json['columnGap'] ?? 0).toDouble(),
      barcodeRow: json['barcodeRow'] ?? 1,
      decimalPlaces: json['decimalPlaces'] ?? 3,
      companyFont: json['companyFont']?.toString() ?? "2",
      companyFontSize: json['companyFontSize'] ?? 1,
      itemFont: json['itemFont']?.toString() ?? "1",
      itemFontSize: json['itemFontSize'] ?? 1,
      barcodeTextFont: json['barcodeTextFont']?.toString() ?? "1",
      barcodeTextFontSize: json['barcodeTextFontSize'] ?? 1,
      priceFont: json['priceFont']?.toString() ?? "2",
      priceFontSize: json['priceFontSize'] ?? 1,
    );
  }
}

class PrintServer {
  HttpServer? _server;
  final int port;

  String? localIp;

  PrintServer({this.port = 5050});

  static Future<String> getLocalIpAddress() async {
    try {
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      print(
        'Warning: Could not get local IP address (network might not be ready): $e',
      );
    }
    return '127.0.0.1';
  }

  Future<void> start() async {
    final router = Router();

    // Health check API
    router.get('/test', (Request request) {
      final html = '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>BillEntri Print Server – Connection Successful</title>
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet" />
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

    body {
      font-family: 'Inter', system-ui, sans-serif;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      background: #0a0f1e;
      background-image:
        radial-gradient(ellipse 80% 60% at 50% -10%, rgba(1,111,66,0.35) 0%, transparent 70%),
        radial-gradient(ellipse 50% 40% at 80% 80%, rgba(0,200,120,0.12) 0%, transparent 60%);
      color: #e2e8f0;
      padding: 24px;
    }

    .card {
      background: rgba(255,255,255,0.04);
      border: 1px solid rgba(255,255,255,0.08);
      backdrop-filter: blur(24px);
      border-radius: 24px;
      padding: 56px 48px;
      max-width: 520px;
      width: 100%;
      text-align: center;
      box-shadow:
        0 0 0 1px rgba(1,111,66,0.15),
        0 32px 64px rgba(0,0,0,0.5),
        0 0 80px rgba(1,111,66,0.08);
      animation: fadeUp 0.6s cubic-bezier(0.16,1,0.3,1) both;
    }

    @keyframes fadeUp {
      from { opacity: 0; transform: translateY(24px); }
      to   { opacity: 1; transform: translateY(0); }
    }

    /* ── Animated ring + checkmark ── */
    .check-wrap {
      position: relative;
      width: 96px;
      height: 96px;
      margin: 0 auto 32px;
    }

    .check-ring {
      width: 96px;
      height: 96px;
      border-radius: 50%;
      border: 3px solid rgba(1,111,66,0.25);
      position: absolute;
      inset: 0;
      animation: pulse-ring 2.4s ease-out infinite;
    }

    @keyframes pulse-ring {
      0%   { transform: scale(1);   opacity: 0.6; }
      60%  { transform: scale(1.5); opacity: 0; }
      100% { transform: scale(1.5); opacity: 0; }
    }

    .check-circle {
      width: 96px;
      height: 96px;
      border-radius: 50%;
      background: linear-gradient(135deg, #016F42 0%, #00c97a 100%);
      display: flex;
      align-items: center;
      justify-content: center;
      position: relative;
      box-shadow: 0 0 32px rgba(0,201,122,0.4), 0 8px 24px rgba(0,0,0,0.3);
      animation: pop 0.5s 0.2s cubic-bezier(0.34,1.56,0.64,1) both;
    }

    @keyframes pop {
      from { transform: scale(0.5); opacity: 0; }
      to   { transform: scale(1);   opacity: 1; }
    }

    .check-svg {
      width: 44px;
      height: 44px;
      stroke: #fff;
      stroke-width: 3;
      fill: none;
      stroke-linecap: round;
      stroke-linejoin: round;
    }

    .check-path {
      stroke-dasharray: 52;
      stroke-dashoffset: 52;
      animation: draw 0.5s 0.55s ease forwards;
    }

    @keyframes draw {
      to { stroke-dashoffset: 0; }
    }

    /* ── Brand ── */
    .brand {
      font-size: 13px;
      font-weight: 600;
      letter-spacing: 0.12em;
      text-transform: uppercase;
      color: #00c97a;
      margin-bottom: 12px;
    }

    h1 {
      font-size: 26px;
      font-weight: 700;
      color: #f1f5f9;
      line-height: 1.2;
      margin-bottom: 12px;
    }

    .subtitle {
      font-size: 15px;
      color: #94a3b8;
      line-height: 1.6;
      margin-bottom: 36px;
    }

    /* ── Status pills ── */
    .pills {
      display: flex;
      gap: 12px;
      justify-content: center;
      flex-wrap: wrap;
      margin-bottom: 32px;
    }

    .pill {
      display: flex;
      align-items: center;
      gap: 7px;
      background: rgba(255,255,255,0.05);
      border: 1px solid rgba(255,255,255,0.08);
      border-radius: 100px;
      padding: 7px 16px;
      font-size: 13px;
      font-weight: 500;
      color: #cbd5e1;
    }

    .dot {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: #00c97a;
      box-shadow: 0 0 6px #00c97a;
      animation: blink 2s ease-in-out infinite;
    }

    @keyframes blink {
      0%, 100% { opacity: 1; }
      50%       { opacity: 0.3; }
    }

    /* ── Server info box ── */
    .info-box {
      background: rgba(1,111,66,0.08);
      border: 1px solid rgba(1,111,66,0.2);
      border-radius: 12px;
      padding: 16px 20px;
      text-align: left;
      font-size: 13px;
      color: #94a3b8;
      line-height: 1.8;
    }

    .info-box span { color: #e2e8f0; font-weight: 500; }

    /* ── Footer ── */
    .footer {
      margin-top: 32px;
      font-size: 12px;
      color: #475569;
    }

    @media (max-width: 480px) {
      .card { padding: 40px 24px; }
      h1 { font-size: 22px; }
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="check-wrap">
      <div class="check-ring"></div>
      <div class="check-circle">
        <svg class="check-svg" viewBox="0 0 52 52">
          <polyline class="check-path" points="14,27 22,35 38,17" />
        </svg>
      </div>
    </div>

    <div class="brand">BillEntri Print Server</div>
    <h1>Connection Successful</h1>
    <p class="subtitle">Your print server is online and ready to receive print jobs from the BillEntri app.</p>

    <div class="pills">
      <div class="pill"><span class="dot"></span> Server Online</div>
      <div class="pill"><span class="dot"></span> API Reachable</div>
    </div>

   <div class="footer">Scan the QR code in the BillEntri Print Server dashboard to connect your device.</div>
  </div>
</body>
</html>''';

      return Response.ok(
        html,
        headers: {'content-type': 'text/html; charset=utf-8'},
      );
    });

    // Bulk print API
    router.post('/print-bulk', (Request request) async {
      try {
        final payload = await request.readAsString();
        final List<dynamic> jsonList = jsonDecode(payload);
        final items = jsonList
            .map((e) => PrintItem.fromJson(e as Map<String, dynamic>))
            .toList();

        String tspl = '''
SIZE 77.6 mm,25 mm
GAP 3 mm,0
DENSITY 8
SPEED 4
DIRECTION 1
REFERENCE 0,0
''';

        for (int i = 0; i < items.length; i += 2) {
          final left = items[i];
          final right = (i + 1 < items.length) ? items[i + 1] : null;

          tspl += '\nCLS\n';

          // LEFT LABEL
          tspl += generateLabelTspl(left, 0);

          // RIGHT LABEL
          if (right != null) {
            final rightOffsetX = 310 + right.columnGap.toInt();
            tspl += generateLabelTspl(right, rightOffsetX);
          }

          tspl += 'PRINT 1\n';
        }

        print("Printing \${items.length} labels");
        final printResult = await sendToPrinter(tspl);

        // We fetch the latest console output directly to the response for easy debugging via curl
        return Response.ok(
          jsonEncode({
            'success': printResult['exitCode'] == 0,
            'printed': items.length,
            'exitCode': printResult['exitCode'],
            'stdout': printResult['stdout'],
            'stderr': printResult['stderr'],
            'message': printResult['exitCode'] == 0
                ? 'Print command sent successfully'
                : 'Print command failed on Windows',
          }),
          headers: {'content-type': 'application/json'},
        );
      } catch (error) {
        print(error);
        return Response.internalServerError(
          body: jsonEncode({'success': false, 'error': error.toString()}),
          headers: {'content-type': 'application/json'},
        );
      }
    });

    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(router.call);

    _server = await io.serve(handler, '0.0.0.0', port);
    localIp = await getLocalIpAddress();
    print('BillEntri Print Server Started');
    print('Dashboard / Setup : http://$localIp:$port');
  }

  Future<void> stop() async {
    await _server?.close();
  }

  // --- TSPL HELPER FUNCTIONS ---
  int getCharWidth(String fontSize, int fontSizeMultiplier) {
    int baseWidth = 8;
    if (fontSize == "3") baseWidth = 16;
    if (fontSize == "2") baseWidth = 11;
    return baseWidth * fontSizeMultiplier;
  }

  int getCenteredX(
    String text,
    int centerX,
    String fontSize,
    int fontSizeMultiplier,
  ) {
    final textWidth = text.length * getCharWidth(fontSize, fontSizeMultiplier);
    return (centerX - textWidth / 2).floor();
  }

  String generateLabelTspl(PrintItem item, int startX) {
    StringBuffer buf = StringBuffer();
    final centerX = startX + 155 + item.marginLeft.toInt();
    // Start a bit lower for default top padding
    int currentY = 15 + item.marginTop.toInt();

    // 1. Company Name (Max 2 lines to avoid overflow)
    // Font 2 can fit roughly 26 chars in ~290 dots width
    final companyLines = splitText(item.companyName, 26);
    for (var line in companyLines) {
      int compX = getCenteredX(
        line,
        centerX,
        item.companyFont,
        item.companyFontSize,
      );
      buf.write(
        'TEXT $compX,$currentY,"${item.companyFont}",0,${item.companyFontSize},${item.companyFontSize},"$line"\n',
      );
      buf.write(
        'TEXT ${compX + 1},$currentY,"${item.companyFont}",0,${item.companyFontSize},${item.companyFontSize},"$line"\n',
      ); // Bold effect
      currentY += 26 + item.rowGap.toInt();
    }

    // 2. Item Name (Max 2 lines)
    // Font 1 can fit roughly 36 chars in ~290 dots width
    final nameLines = splitText(item.itemName, 36);
    for (var line in nameLines) {
      buf.write(
        'TEXT ${getCenteredX(line, centerX, item.itemFont, item.itemFontSize)},$currentY,"${item.itemFont}",0,${item.itemFontSize},${item.itemFontSize},"$line"\n',
      );
      currentY += 16 + item.rowGap.toInt();
    }

    // 3. Barcode (Taller & properly centered)
    int barcodeHeight = 60; // Increased height for easier scanning

    // Accurately estimate Code 128 Auto width to ensure proper centering
    int digitsCount = 0, otherCount = 0;
    for (int i = 0; i < item.barcode.length; i++) {
      int code = item.barcode.codeUnitAt(i);
      if (code >= 48 && code <= 57)
        digitsCount++;
      else
        otherCount++;
    }
    // Subset C encodes 2 digits per char.
    int estimatedChars128 = (digitsCount ~/ 2) + (digitsCount % 2) + otherCount;
    int estWidthNarrow1 = 11 * (estimatedChars128 + 2) + 13;

    // Use wide bars if they fit within our ~290 dot padding boundary
    int narrow = (estWidthNarrow1 * 2 < 280) ? 2 : 1;
    int wide = narrow == 1 ? 2 : 3;

    int estWidth = estWidthNarrow1 * narrow;
    int barcodeX = centerX - (estWidth ~/ 2);
    if (barcodeX < startX + 15)
      barcodeX = startX + 15; // Left padding constraint

    currentY += 8; // Extra padding before barcode
    buf.write(
      'BARCODE $barcodeX,$currentY,"128",$barcodeHeight,0,0,$narrow,$wide,"${item.barcode}"\n',
    );
    currentY += barcodeHeight + 10;

    // 4. Barcode Text
    buf.write(
      'TEXT ${getCenteredX(item.barcode, centerX, item.barcodeTextFont, item.barcodeTextFontSize)},$currentY,"${item.barcodeTextFont}",0,${item.barcodeTextFontSize},${item.barcodeTextFontSize},"${item.barcode}"\n',
    );
    currentY += 18 + item.rowGap.toInt();

    // 5. Price (Font 2, Bold)
    final currency = item.currency.replaceAll('₹', 'Rs.');
    String currencyPrefix = currency.endsWith(':') ? currency : '$currency:';
    if (currency.isEmpty) currencyPrefix = '';

    // Use dynamic decimal places (defaults to 3)
    final priceStr =
        '$currencyPrefix${item.price.toStringAsFixed(item.decimalPlaces)}';
    int priceX = getCenteredX(
      priceStr,
      centerX,
      item.priceFont,
      item.priceFontSize,
    );
    buf.write(
      'TEXT $priceX,$currentY,"${item.priceFont}",0,${item.priceFontSize},${item.priceFontSize},"$priceStr"\n',
    );
    buf.write(
      'TEXT ${priceX + 1},$currentY,"${item.priceFont}",0,${item.priceFontSize},${item.priceFontSize},"$priceStr"\n',
    ); // Bold effect

    return buf.toString();
  }

  List<String> splitText(String text, int maxLength) {
    if (text.isEmpty) return [];
    if (text.length <= maxLength) return [text];

    int splitIndex = text.lastIndexOf(" ", maxLength);
    if (splitIndex == -1 || splitIndex == 0) splitIndex = maxLength;

    final line1 = text.substring(0, splitIndex).trim();
    String line2 = text.substring(splitIndex).trim();

    // Add ellipsis if line 2 overflows, ensuring max 2 lines
    if (line2.length > maxLength) {
      line2 = line2.substring(0, maxLength - 2).trimRight() + "..";
    }
    return [line1, line2];
  }

  Future<Map<String, dynamic>> sendToPrinter(String tspl) async {
    if (!Platform.isWindows) {
      print("Warning: Skipping physical print because OS is not Windows.");
      print("TSPL Generated:\\n$tspl");
      return {'exitCode': 0, 'stdout': 'Skipped (Not Windows)', 'stderr': ''};
    }

    try {
      final tempDir = Directory.systemTemp;
      final tempFile = File(
        '${tempDir.path}\\temp_label_${DateTime.now().millisecondsSinceEpoch}.tspl',
      );
      await tempFile.writeAsString(tspl);

      final result = await Process.run('cmd', [
        '/c',
        'copy',
        '/b',
        tempFile.path,
        r'\\localhost\barcode',
      ]);

      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      print('Print command exit code: ${result.exitCode}');
      print('Print stdout: ${result.stdout}');
      if (result.stderr.toString().isNotEmpty) {
        print('Print stderr: ${result.stderr}');
      }
      return {
        'exitCode': result.exitCode,
        'stdout': result.stdout.toString().trim(),
        'stderr': result.stderr.toString().trim(),
      };
    } catch (e) {
      print('Printer error: $e');
      return {'exitCode': -1, 'stdout': '', 'stderr': e.toString()};
    }
  }
}
