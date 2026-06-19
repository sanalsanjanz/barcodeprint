import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'package:url_launcher/url_launcher.dart';
// import '../server/print_server.dart';

class DashboardScreen extends StatelessWidget {
  final int port;
  final String localIp;

  const DashboardScreen({super.key, required this.port, required this.localIp});

  @override
  Widget build(BuildContext context) {
    final serverUrl = 'http://$localIp:$port';
    const brandColor = Color(0xFF016F42);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Center(
        child: Container(
          width: 900,
          height: 600,
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              // Left Panel
              Container(
                width: 300,
                decoration: const BoxDecoration(
                  color: brandColor,
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(16),
                  ),
                ),
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'BillEntri',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Billing Made Simple',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            // inset: true,
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: serverUrl,
                        version: QrVersions.auto,
                        size: 200.0,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: brandColor,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: brandColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    InkWell(
                      onTap: () async {
                        final testUrl = Uri.parse('$serverUrl/test');
                        if (await canLaunchUrl(testUrl)) {
                          await launchUrl(testUrl);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.white.withOpacity(0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              serverUrl,
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'monospace',
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.open_in_browser,
                              color: Colors.white,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Scan from BillEntri App',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Right Panel
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.print, color: brandColor, size: 28),
                          SizedBox(width: 12),
                          Text(
                            'Printer Setup Guide',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      _buildStep(
                        1,
                        'Connect barcode printer',
                        'to your PC via USB.',
                      ),
                      const SizedBox(height: 16),
                      _buildStep(
                        2,
                        'Open Control Panel',
                        '> Devices and Printers.',
                      ),
                      const SizedBox(height: 16),
                      _buildStep(
                        3,
                        'Right-click your printer',
                        '(e.g., TSC TTP-244 Pro) and select Printer properties.',
                      ),
                      const SizedBox(height: 16),
                      _buildStep(
                        4,
                        'Go to the Sharing tab',
                        'check Share this printer.',
                      ),
                      const SizedBox(height: 16),
                      _buildStep(
                        5,
                        'Give it the share name',
                        'barcode and click Apply.',
                        highlightText: 'barcode',
                      ),
                      const SizedBox(height: 16),
                      _buildStep(
                        6,
                        'Scan the QR code',
                        'on the left using the BillEntri app and Save. You can now print directly from the Purchase screen!',
                      ),

                      const Spacer(),
                      const Divider(),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Colors.blue,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Currently Supported on Windows Only. The server is running in the background.',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final payload = [
                                {
                                  "companyName": "BillEntri",
                                  "itemName": "Apple",
                                  "barcode": "108011520",
                                  "price": 100.00,
                                  "currency": "Rs.",
                                  "marginLeft": 15,
                                  "marginTop": 15,
                                  "rowGap": 3,
                                  "columnGap": 0
                                },
                                {
                                  "companyName": "BillEntri",
                                  "itemName": "Orange",
                                  "barcode": "115545420",
                                  "price": 180.00,
                                  "currency": "Rs.",
                                  "marginLeft": 15,
                                  "marginTop": 15,
                                  "rowGap": 3,
                                  "columnGap": 0
                                }
                              ];
                              
                              try {
                                final client = HttpClient();
                                final request = await client.postUrl(Uri.parse('http://$localIp:$port/print-bulk'));
                                request.headers.set('content-type', 'application/json');
                                request.write(jsonEncode(payload));
                                final response = await request.close();
                                if (response.statusCode == 200 && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Test print sent successfully!'), backgroundColor: Colors.green),
                                  );
                                }
                              } catch(e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Test print failed: $e'), backgroundColor: Colors.red),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.print, size: 18),
                            label: const Text('Test Print'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: brandColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(
    int number,
    String boldText,
    String normalText, {
    String? highlightText,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Color(0xFF016F42),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                color: Color(0xFF4B5563),
                fontSize: 15,
                height: 1.5,
              ),
              children: [
                TextSpan(
                  text: '$boldText ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (highlightText != null) ...[
                  TextSpan(text: normalText.split(highlightText)[0]),
                  WidgetSpan(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        highlightText,
                        style: const TextStyle(
                          color: Color(0xFF016F42),
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
                    ),
                    alignment: PlaceholderAlignment.middle,
                  ),
                  TextSpan(text: normalText.split(highlightText)[1]),
                ] else
                  TextSpan(text: normalText),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
