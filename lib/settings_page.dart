import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sitstand/options.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.title});

  final String title;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with TrayListener {
  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _standInputController = TextEditingController();
  final TextEditingController _sitInputController = TextEditingController();

  Options _options = Options();
  Timer? _timer;
  bool _standing = false;

  @override
  void initState() {
    trayManager.addListener(this);
    super.initState();
    _initTray();
    _initNotifications();
    _initOptions();
  }

  @override
  void dispose() {
    _standInputController.dispose();
    _sitInputController.dispose();
    trayManager.removeListener(this);
    super.dispose();
  }

  Future<void> _initTray() async {
    await trayManager.setIcon(
      Platform.isWindows ? 'images/tray_icon.ico' : 'assets/icon.png',
    );
    // await trayManager.setToolTip('Sitstand');

    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'options', label: 'Options'),
          MenuItem(key: 'exit', label: 'Exit'),
        ],
      ),
    );
  }

  Future<void> _initNotifications() async {
    const InitializationSettings initSettings = InitializationSettings(
      linux: LinuxInitializationSettings(defaultActionName: 'OK'),
      windows: WindowsInitializationSettings(
        guid: '12345678-1234-1234-1234-123456789abc',
        appName: 'Sitstand',
        appUserModelId: 'dxt.rs.sitstand',
      ),
      macOS: DarwinInitializationSettings(),
    );

    await notificationsPlugin.initialize(initSettings);
  }

  Future<void> _initOptions() async {
    final prefs = await SharedPreferences.getInstance();
    final String? options = prefs.getString(_options.name);

    if (options == null) {
      _saveOptions();
      return;
    }

    _options = Options.fromJson(jsonDecode(options));
    _standInputController.text = _options.standMins.toString();
    _sitInputController.text = _options.sitMins.toString();

    _startTimer();
  }

  void _startTimer() {
    if (_standing) {
      _timer = Timer.periodic(
        Duration(milliseconds: _options.sitMins * 10000),
        (Timer t) {
          final String title =
              "${_options.sitMins.toString()} min stand reminder";
          final String body = "Time to switch to standing!";
          _standing = false;

          _options.enableNotifications ? _showNotification(title, body) : null;
          _options.enableMessaging ? _showMessageBox(title, body) : null;

          _timer?.cancel();
          _startTimer();
        },
      );
    } else {
      _timer = Timer.periodic(
        Duration(milliseconds: _options.standMins * 10000),
        (Timer t) {
          final String title =
              "${_options.standMins.toString()} min sit reminder";
          final String body = "Time to switch to sitting!";
          _standing = true;

          _options.enableNotifications ? _showNotification(title, body) : null;
          _options.enableMessaging ? _showMessageBox(title, body) : null;

          _timer?.cancel();
          _startTimer();
        },
      );
    }
  }

  Future<void> _showNotification(String title, String body) async {
    const NotificationDetails notificationDetails = NotificationDetails(
      linux: LinuxNotificationDetails(),
      windows: WindowsNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );

    await notificationsPlugin.show(0, title, body, notificationDetails);
  }

  Future<void> _showMessageBox(String title, String body) async {
    if (Platform.isWindows) {
      await Process.run('powershell', [
        '-Command',
        "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('$body', '$title')",
      ]);
      return;
    }

    if (Platform.isLinux) {
      // Try zenity (GNOME) or kdialog (KDE)
      final result = await Process.run('which', ['zenity']);
      if (result.exitCode == 0) {
        await Process.run('zenity', [
          '--info',
          '--title=$title',
          '--text=$body',
        ]);
      } else {
        // Fallback to kdialog
        await Process.run('kdialog', ['--msgbox', body, '--title', title]);
      }
      return;
    }

    if (Platform.isMacOS) {
      await Process.run('osascript', [
        '-e',
        'display dialog "$body" with title "$title" buttons {"OK"} default button "OK"',
      ]);
      return;
    }
  }

  Future<void> _saveOptions() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(_options.name, jsonEncode(_options.toJson()));

    _startTimer();
    await windowManager.hide();
  }

  @override
  void onTrayIconMouseDown() async {
    await trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'options':
        final trayBounds = await trayManager.getBounds();
        debugPrint("trayBounds: $trayBounds");
        if (trayBounds == null) {
          await windowManager.center();
          await windowManager.show();
          return;
        }

        final windowSize = await windowManager.getSize();
        double x =
            trayBounds.left + (trayBounds.width / 2) - (windowSize.width / 2);
        double y = trayBounds.bottom; // directly under the icon

        await windowManager.setBounds(
          Rect.fromLTWH(x, y, windowSize.width, windowSize.height),
        );
        await windowManager.show();
        await windowManager.focus();
        break;

      case 'exit':
        _timer?.cancel();
        await trayManager.destroy();
        exit(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.inversePrimary,
        title: Text(widget.title),
      ),

      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Stand duration (mins)'),

                    Spacer(),

                    SizedBox(
                      width: 50,
                      height: 30,
                      child: TextFormField(
                        controller: _standInputController,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsetsGeometry.only(
                            left: 10,
                            right: 10,
                            top: 0,
                            bottom: 0,
                          ),
                        ),
                        validator: (String? value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter a duration';
                          }
                          return null;
                        },
                        onChanged: (String val) => {
                          setState(() {
                            _options.standMins = int.parse(val);
                          }),
                        },
                      ),
                    ),

                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.keyboard_arrow_up),
                          padding: EdgeInsets.all(0),
                          constraints: BoxConstraints(),
                          onPressed: () {
                            setState(() {
                              _options.standMins++;
                              _standInputController.text = _options.standMins
                                  .toString();
                            });
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.keyboard_arrow_down),
                          padding: EdgeInsets.all(0),
                          constraints: BoxConstraints(),
                          onPressed: () {
                            setState(() {
                              _options.standMins--;
                              _standInputController.text = _options.standMins
                                  .toString();
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),

                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Sit duration (mins)'),

                    Spacer(),

                    SizedBox(
                      width: 50,
                      height: 30,
                      child: TextFormField(
                        controller: _sitInputController,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsetsGeometry.only(
                            left: 10,
                            right: 10,
                            top: 0,
                            bottom: 0,
                          ),
                        ),
                        validator: (String? value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter a duration';
                          }
                          return null;
                        },
                        onChanged: (String val) => {
                          setState(() {
                            _options.sitMins = int.parse(val);
                          }),
                        },
                      ),
                    ),

                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.keyboard_arrow_up),
                          padding: EdgeInsets.all(0),
                          constraints: BoxConstraints(),
                          onPressed: () {
                            setState(() {
                              _options.sitMins++;
                              _sitInputController.text = _options.standMins
                                  .toString();
                            });
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.keyboard_arrow_down),
                          padding: EdgeInsets.all(0),
                          constraints: BoxConstraints(),
                          onPressed: () {
                            setState(() {
                              _options.sitMins--;
                              _sitInputController.text = _options.standMins
                                  .toString();
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),

                Row(
                  children: [
                    Text("Enable notifications"),
                    Spacer(),
                    Checkbox(
                      value: _options.enableNotifications,
                      onChanged: (bool? val) => {
                        setState(() {
                          _options.enableNotifications = val ?? false;
                        }),
                      },
                    ),
                  ],
                ),

                Row(
                  children: [
                    Text("Enable messaging"),
                    Spacer(),
                    Checkbox(
                      value: _options.enableMessaging,
                      onChanged: (bool? val) => {
                        setState(() {
                          _options.enableMessaging = val ?? false;
                        }),
                      },
                    ),
                  ],
                ),

                SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(child: SizedBox(width: 20, height: 20)),
                    ElevatedButton(
                      onPressed: _saveOptions,
                      child: Icon(Icons.save),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
