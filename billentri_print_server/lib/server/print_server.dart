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
    );
  }
}

class PrintServer {
  HttpServer? _server;
  final int port;

  String? localIp;

  PrintServer({this.port = 5050});

  static Future<String> getLocalIpAddress() async {
    for (var interface in await NetworkInterface.list()) {
      for (var addr in interface.addresses) {
        if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
          return addr.address;
        }
      }
    }
    return '127.0.0.1';
  }

  Future<void> start() async {
    final router = Router();

    // Health check API
    router.get('/test', (Request request) {
      return Response.ok('OK');
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
            'message': printResult['exitCode'] == 0 ? 'Print command sent successfully' : 'Print command failed on Windows',
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
  int getCharWidth(String fontSize) {
    if (fontSize == "3") return 16;
    if (fontSize == "2") return 11;
    return 8; // Font 1
  }

  int getCenteredX(String text, int centerX, String fontSize) {
    final textWidth = text.length * getCharWidth(fontSize);
    return (centerX - textWidth / 2).floor();
  }

  String generateLabelTspl(PrintItem item, int startX) {
    StringBuffer buf = StringBuffer();
    final centerX = startX + 155 + item.marginLeft.toInt();
    int currentY = 10 + item.marginTop.toInt();

    // 1. Company Name (Font 2, Bold, Uppercase)
    final companyName = item.companyName.toUpperCase();
    int compX = getCenteredX(companyName, centerX, "2");
    buf.write('TEXT $compX,$currentY,"2",0,1,1,"$companyName"\n');
    buf.write('TEXT ${compX + 1},$currentY,"2",0,1,1,"$companyName"\n'); // Bold effect
    currentY += 26 + item.rowGap.toInt();

    // 2. Item Name (Font 1, Split up to 34 chars)
    final nameLines = splitText(item.itemName, 34);
    for (var line in nameLines) {
      if (line.isNotEmpty) {
        buf.write('TEXT ${getCenteredX(line, centerX, "1")},$currentY,"1",0,1,1,"$line"\n');
        currentY += 16 + item.rowGap.toInt();
      }
    }

    // 3. Barcode
    int barcodeHeight = 40;
    int narrow = item.barcode.length > 10 ? 1 : 2;
    int wide = 2;
    int estWidth = (11 * item.barcode.length + 35) * narrow;
    int barcodeX = centerX - (estWidth ~/ 2);
    if (barcodeX < startX + 10) barcodeX = startX + 10;
    
    currentY += 5; // Padding before barcode
    buf.write('BARCODE $barcodeX,$currentY,"128",$barcodeHeight,0,0,$narrow,$wide,"${item.barcode}"\n');
    currentY += barcodeHeight + 8;

    // 4. Barcode Text
    buf.write('TEXT ${getCenteredX(item.barcode, centerX, "2")},$currentY,"2",0,1,1,"${item.barcode}"\n');
    currentY += 22 + item.rowGap.toInt();

    // 5. Price (Font 2, Bold)
    final currency = item.currency.replaceAll('₹', 'Rs.');
    final priceStr = '$currency ${item.price.toStringAsFixed(2)}'; 
    int priceX = getCenteredX(priceStr, centerX, "2");
    buf.write('TEXT $priceX,$currentY,"2",0,1,1,"$priceStr"\n');
    buf.write('TEXT ${priceX + 1},$currentY,"2",0,1,1,"$priceStr"\n'); // Bold effect

    return buf.toString();
  }

  List<String> splitText(String text, int maxLength) {
    if (text.length <= maxLength) return [text, ""];
    int splitIndex = text.lastIndexOf(" ", maxLength);
    if (splitIndex == -1) splitIndex = maxLength;
    final line1 = text.substring(0, splitIndex).trim();
    String line2 = text.substring(splitIndex).trim();
    if (line2.length > maxLength + 5) {
      line2 = line2.substring(0, maxLength + 5);
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
      final tempFile = File('${tempDir.path}\\temp_label_${DateTime.now().millisecondsSinceEpoch}.tspl');
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
