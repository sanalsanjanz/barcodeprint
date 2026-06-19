import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:system_tray/system_tray.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'server/print_server.dart';
import 'ui/dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Setup auto-start on Windows boot (wrapped in try-catch so it doesn't crash if OS denies permission)
  try {
    launchAtStartup.setup(
      appName: 'BillEntriBarcodeService',
      appPath: Platform.resolvedExecutable,
    );
    await launchAtStartup.enable();
  } catch (e) {
    print('Warning: Failed to configure launch at startup: $e');
  }

  // Initialize window manager
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1000, 700),
    center: true,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // Start the HTTP Print Server
  final printServer = PrintServer(port: 5000);
  try {
    await printServer.start();
  } catch (e) {
    print('Failed to start print server (port might be in use): $e');
  }

  runApp(MyApp(printServer: printServer));
}

class MyApp extends StatefulWidget {
  final PrintServer printServer;

  const MyApp({Key? key, required this.printServer}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WindowListener {
  final AppWindow _appWindow = AppWindow();
  final SystemTray _systemTray = SystemTray();
  final Menu _menu = Menu();

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initPreventClose();
    initSystemTray();
  }

  Future<void> _initPreventClose() async {
    await windowManager.setPreventClose(true);
  }

  @override
  void onWindowClose() async {
    // When the user clicks the X button, hide the window instead of killing the app
    await windowManager.hide();
    await windowManager.setSkipTaskbar(true);
  }

  Future<void> initSystemTray() async {
    String path = Platform.isWindows ? 'assets/app_icon.ico' : 'assets/app_icon.png';
    
    // We try to initialize with icon but if asset not present it might fail. 
    // Usually we need an actual icon in assets. Let's provide a dummy path or use empty for now.
    // In production, ensure you add assets/app_icon.ico and add to pubspec.yaml
    
    try {
      await _systemTray.initSystemTray(
        title: "BillEntri Print Server",
        iconPath: '', // Will show default if empty or fallback
        toolTip: "BillEntri Print Server Running",
      );
    } catch (e) {
      print('Warning: System tray failed to initialize (likely due to missing iconPath): $e');
    }

    await _menu.buildFrom([
      MenuItemLabel(
        label: 'Show Dashboard',
        onClicked: (menuItem) async {
          await windowManager.show();
          await windowManager.focus();
          await windowManager.setSkipTaskbar(false);
        },
      ),
      MenuItemLabel(
        label: 'Hide to System Tray',
        onClicked: (menuItem) async {
          await windowManager.hide();
          await windowManager.setSkipTaskbar(true);
        },
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: 'Exit',
        onClicked: (menuItem) async {
          await widget.printServer.stop();
          exit(0);
        },
      ),
    ]);

    await _systemTray.setContextMenu(_menu);

    _systemTray.registerSystemTrayEventHandler((eventName) {
      if (eventName == kSystemTrayEventClick) {
        windowManager.show();
        windowManager.focus();
        windowManager.setSkipTaskbar(false);
      } else if (eventName == kSystemTrayEventRightClick) {
        _systemTray.popUpContextMenu();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BillEntri Print Server',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF016F42),
        fontFamily: 'Inter',
      ),
      home: DashboardScreen(port: widget.printServer.port, localIp: widget.printServer.localIp ?? '127.0.0.1'),
    );
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    widget.printServer.stop();
    super.dispose();
  }
}
