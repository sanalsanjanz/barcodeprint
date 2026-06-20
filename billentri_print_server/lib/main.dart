import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:system_tray/system_tray.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'server/print_server.dart';
import 'ui/dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager early so the window can appear immediately.
  await windowManager.ensureInitialized();

  final WindowOptions windowOptions = const WindowOptions(
    size: Size(1000, 700),
    center: true,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );

  // Show the window right away – don't block on server startup.
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // Setup auto-start (fire-and-forget – not on the critical path).
  _setupLaunchAtStartup();

  // Create the server instance and a notifier the UI can listen to.
  final printServer = PrintServer(port: 5050);
  final serverState = ValueNotifier<ServerReadyState>(ServerReadyState.starting);

  // Launch the UI immediately with the loading state.
  runApp(MyApp(printServer: printServer, serverState: serverState));

  // Start the server in the background; update the notifier when done.
  _startServerInBackground(printServer, serverState);
}

/// Starts the HTTP server with retries without blocking the UI.
/// If the port is already bound (a previous instance is still running in the
/// system tray), we skip trying to start a new server and go straight to the
/// dashboard – the existing server is already healthy.
Future<void> _startServerInBackground(
  PrintServer server,
  ValueNotifier<ServerReadyState> state,
) async {
  int retryCount = 0;
  while (retryCount < 30) {
    try {
      await server.start();
      print('Print server started successfully.');
      state.value = ServerReadyState.ready;
      return;
    } catch (e) {
      // ── Port already in use ──────────────────────────────────────────────
      // A previous instance is running in the system tray and already owns
      // the port.  The server is healthy – just reuse it.
      if (_isAddressInUse(e)) {
        print('Port already bound by a previous instance – reusing existing server.');
        // Populate localIp so the dashboard shows the correct address.
        server.localIp = await PrintServer.getLocalIpAddress();
        state.value = ServerReadyState.ready;
        return;
      }

      retryCount++;
      print('Failed to start print server (attempt $retryCount): $e');
      if (retryCount < 30) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }
  state.value = ServerReadyState.failed;
}

/// Returns true when [e] indicates the TCP port is already occupied.
bool _isAddressInUse(Object e) {
  if (e is SocketException) {
    final msg = e.message.toLowerCase();
    final code = e.osError?.errorCode ?? 0;
    // WSAEADDRINUSE = 10048 (Windows), EADDRINUSE = 98 (Linux), 48 (macOS)
    if (code == 10048 || code == 98 || code == 48) return true;
    if (msg.contains('address already in use') ||
        msg.contains('only one usage of each socket')) return true;
  }
  // Fallback: check the string representation
  final str = e.toString().toLowerCase();
  return str.contains('address already in use') ||
      str.contains('only one usage of each socket');
}

/// Fire-and-forget – runs after the window is already visible.
void _setupLaunchAtStartup() async {
  try {
    launchAtStartup.setup(
      appName: 'BillEntriBarcodeService',
      appPath: Platform.resolvedExecutable,
    );
    await launchAtStartup.enable();
  } catch (e) {
    print('Warning: Failed to configure launch at startup: $e');
  }
}

enum ServerReadyState { starting, ready, failed }

// ─────────────────────────────────────────────────────────────────────────────

class MyApp extends StatefulWidget {
  final PrintServer printServer;
  final ValueNotifier<ServerReadyState> serverState;

  const MyApp({Key? key, required this.printServer, required this.serverState})
    : super(key: key);

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
    // When the user clicks the X button, hide to tray instead of quitting.
    await windowManager.hide();
    await windowManager.setSkipTaskbar(true);
  }

  Future<void> initSystemTray() async {
    String path =
        Platform.isWindows ? 'assets/app_icon.ico' : 'assets/app_icon.png';

    try {
      await _systemTray.initSystemTray(
        title: "BillEntri Print Server",
        iconPath: '',
        toolTip: "BillEntri Print Server Running",
      );
    } catch (e) {
      print(
        'Warning: System tray failed to initialize (likely due to missing iconPath): $e',
      );
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
      home: ValueListenableBuilder<ServerReadyState>(
        valueListenable: widget.serverState,
        builder: (context, state, _) {
          if (state == ServerReadyState.ready) {
            return DashboardScreen(
              port: widget.printServer.port,
              localIp: widget.printServer.localIp ?? '127.0.0.1',
            );
          }
          return _StartingScreen(failed: state == ServerReadyState.failed);
        },
      ),
    );
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    widget.printServer.stop();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Shown immediately while the HTTP server is binding in the background.
class _StartingScreen extends StatefulWidget {
  final bool failed;
  const _StartingScreen({this.failed = false});

  @override
  State<_StartingScreen> createState() => _StartingScreenState();
}

class _StartingScreenState extends State<_StartingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const brandColor = Color(0xFF016F42);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.failed)
              const Icon(Icons.error_outline, color: Colors.red, size: 56)
            else
              SizedBox(
                width: 56,
                height: 56,
                child: CircularProgressIndicator(
                  valueColor: _controller.drive(
                    ColorTween(begin: brandColor, end: brandColor),
                  ),
                  strokeWidth: 3,
                  color: brandColor,
                ),
              ),
            const SizedBox(height: 24),
            Text(
              widget.failed
                  ? 'Failed to start server.\nPlease restart the application.'
                  : 'Starting BillEntri Print Server…',
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF374151),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
