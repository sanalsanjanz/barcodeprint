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

  PrintItem({
    required this.companyName,
    required this.itemName,
    required this.barcode,
    required this.price,
    required this.currency,
  });

  factory PrintItem.fromJson(Map<String, dynamic> json) {
    return PrintItem(
      companyName: json['companyName'] ?? '',
      itemName: json['itemName'] ?? '',
      barcode: json['barcode'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      currency: json['currency'] ?? '',
    );
  }
}

class PrintServer {
  HttpServer? _server;
  final int port;

  String? localIp;

  PrintServer({this.port = 5000});

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
          final leftCompany = left.companyName.length > 25
              ? left.companyName.substring(0, 25)
              : left.companyName;
          final leftSplit = splitText(left.itemName, 16);
          final leftName1 = leftSplit[0];
          final leftName2 = leftSplit[1];
          final leftPrice = '${left.currency} ${left.price}';

          tspl +=
              'TEXT ${getCenteredX(leftCompany, false, "2")},10,"2",0,1,1,"$leftCompany"\n';
          tspl += 'BAR 15,35,280,2\n';
          tspl += 'TEXT 15,45,"3",0,1,1,"$leftName1"\n';
          tspl += 'TEXT 16,45,"3",0,1,1,"$leftName1"\n';

          int leftNextY = 75;
          int leftBarcodeHeight = 55;
          if (leftName2.isNotEmpty) {
            tspl += 'TEXT 15,75,"2",0,1,1,"$leftName2"\n';
            leftNextY = 100;
            leftBarcodeHeight = 40;
          }
          tspl +=
              'BARCODE ${155 - 130},$leftNextY,"128",$leftBarcodeHeight,1,0,2,2,"${left.barcode}"\n';
          final leftPriceX = getRightAlignedX(leftPrice, false, "3");
          tspl += 'TEXT $leftPriceX,155,"3",0,1,1,"$leftPrice"\n';
          tspl += 'TEXT ${leftPriceX + 1},155,"3",0,1,1,"$leftPrice"\n';

          // RIGHT LABEL
          if (right != null) {
            final rightCompany = right.companyName.length > 25
                ? right.companyName.substring(0, 25)
                : right.companyName;
            final rightSplit = splitText(right.itemName, 16);
            final rightName1 = rightSplit[0];
            final rightName2 = rightSplit[1];
            final rightPrice = '${right.currency} ${right.price}';

            tspl +=
                'TEXT ${getCenteredX(rightCompany, true, "2")},10,"2",0,1,1,"$rightCompany"\n';
            tspl += 'BAR 325,35,280,2\n';
            tspl += 'TEXT 325,45,"3",0,1,1,"$rightName1"\n';
            tspl += 'TEXT 326,45,"3",0,1,1,"$rightName1"\n';

            int rightNextY = 75;
            int rightBarcodeHeight = 55;
            if (rightName2.isNotEmpty) {
              tspl += 'TEXT 325,75,"2",0,1,1,"$rightName2"\n';
              rightNextY = 100;
              rightBarcodeHeight = 40;
            }
            tspl +=
                'BARCODE ${465 - 130},$rightNextY,"128",$rightBarcodeHeight,1,0,2,2,"${right.barcode}"\n';
            final rightPriceX = getRightAlignedX(rightPrice, true, "3");
            tspl += 'TEXT $rightPriceX,155,"3",0,1,1,"$rightPrice"\n';
            tspl += 'TEXT ${rightPriceX + 1},155,"3",0,1,1,"$rightPrice"\n';
          }

          tspl += 'PRINT 1\n';
        }

        print("Printing \${items.length} labels");
        await sendToPrinter(tspl);

        return Response.ok(
          jsonEncode({'success': true, 'printed': items.length}),
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
    return fontSize == "3" ? 16 : 11;
  }

  int getCenteredX(String text, bool isRightLabel, String fontSize) {
    final textWidth = text.length * getCharWidth(fontSize);
    final centerTarget = isRightLabel ? 465 : 155;
    final startX = (centerTarget - textWidth / 2).floor();
    return (isRightLabel ? 320 : 10) > startX
        ? (isRightLabel ? 320 : 10)
        : startX;
  }

  int getRightAlignedX(String text, bool isRightLabel, String fontSize) {
    final textWidth = text.length * getCharWidth(fontSize);
    final rightEdgeTarget = isRightLabel ? 605 : 295;
    return (rightEdgeTarget - textWidth).floor();
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

  Future<int> sendToPrinter(String tspl) async {
    if (!Platform.isWindows) {
      print("Warning: Skipping physical print because OS is not Windows.");
      print("TSPL Generated:\\n$tspl");
      return 0;
    }

    try {
      // Create a temporary file in the system temp directory
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}\\temp_label_${DateTime.now().millisecondsSinceEpoch}.tspl');
      await tempFile.writeAsString(tspl);

      // We MUST use cmd /c copy /b because that's how Windows accurately sends raw TSPL commands to printer shares.
      // We wrap the temp file path in quotes in case the user's Temp folder path contains spaces.
      final result = await Process.run('cmd', [
        '/c',
        'copy',
        '/b',
        '"${tempFile.path}"',
        r'\\localhost\bacode',
      ]);
      
      // Clean up the temporary file immediately
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      print('Print command exit code: ${result.exitCode}');
      print('Print stdout: ${result.stdout}');
      if (result.stderr.toString().isNotEmpty) {
        print('Print stderr: ${result.stderr}');
      }
      return result.exitCode;
    } catch (e) {
      print('Printer error: $e');
      return -1;
    }
  }
}
