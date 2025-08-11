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
    super.initState();
    _initTray();
    _initNotifications();
    _initOptions();
    _startTimer();
  }

  @override
  void dispose() {
    _standInputController.dispose();
    _sitInputController.dispose();
    super.dispose();
  }

  Future<void> _initTray() async {
    await trayManager.setIcon('assets/icon.png');

    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'options', label: 'Options'),
          MenuItem(key: 'exit', label: 'Exit'),
        ],
      ),
    );

    trayManager.addListener(this);
  }

  Future<void> _initNotifications() async {
    const InitializationSettings initSettings = InitializationSettings(
      linux: LinuxInitializationSettings(defaultActionName: 'OK'),
      // windows: WindowsInitializationSettings(
      //   guid: '',
      // ),
      macOS: DarwinInitializationSettings(),
    );

    await notificationsPlugin.initialize(initSettings);
  }

  Future<void> _initOptions() async {
    final prefs = await SharedPreferences.getInstance();
    final String? options = prefs.getString(_options.name);

    if (options == null) return;

    setState(() {
      _options = Options.fromJson(jsonDecode(options));
    });
  }

  void _startTimer() {
    if (_standing) {
      _timer = Timer.periodic(Duration(milliseconds: _options.sitMillis), (
        Timer t,
      ) {
        final String title = "${_options.sitMillis.toString()} Reminder";
        final String body = "Time to switch to standing!";
        _standing = false;

        if (_options.enableNotifications) {
          _showNotification(title, body);
        }
        if (_options.enableMessaging) {
          _showMessageBox(title, body);
        }

        _timer?.cancel();
        _startTimer();
      });
    } else {
      _timer = Timer.periodic(Duration(seconds: _options.standMillis), (
        Timer t,
      ) {
        final String title = "${_options.standMillis.toString()} Reminder";
        final String body = "Time to switch to sitting!";
        _standing = true;

        if (_options.enableNotifications) {
          _showNotification(title, body);
        }
        if (_options.enableMessaging) {
          _showMessageBox(title, body);
        }

        _timer?.cancel();
        _startTimer();
      });
    }
  }

  Future<void> _showNotification(String title, String body) async {
    const NotificationDetails notificationDetails = NotificationDetails(
      linux: LinuxNotificationDetails(),
      // windows: WindowsNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );

    await notificationsPlugin.show(0, title, body, notificationDetails);
  }

  Future<void> _showMessageBox(String title, String body) async {
    if (Platform.isWindows) {
      await Process.run('powershell', [
        '-Command',
        '[System.Windows.Forms.MessageBox]::Show("$body", "$title")',
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
    debugPrint("options: ${jsonEncode(_options.toJson())}");

    // setState(() {
    //   _options.sitMillis = int.parse(_sitInputController.text);
    //   _options.standMillis = int.parse(_standInputController.text);
    // });

    final prefs = await SharedPreferences.getInstance();
    prefs.setString(_options.name, jsonEncode(_options.toJson()));

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
                TextFormField(
                  controller: _standInputController,
                  decoration: const InputDecoration(
                    labelText: 'Standing duration in mins',
                    border: OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    if (value == null || value.isEmpty) {
                      return 'Enter a duration';
                    }
                    return null;
                  },
                  onChanged: (String val) => {
                    setState(() {
                      _options.standMillis = int.parse(val);
                    }),
                  },
                ),

                SizedBox(height: 10),

                TextFormField(
                  controller: _sitInputController,
                  decoration: const InputDecoration(
                    labelText: 'Sitting duration in mins',
                    border: OutlineInputBorder(),
                  ),
                  validator: (String? value) {
                    if (value == null || value.isEmpty) {
                      return 'Enter a duration';
                    }
                    return null;
                  },
                  onChanged: (String val) => {
                    setState(() {
                      _options.sitMillis = int.parse(val);
                    }),
                  },
                ),

                Row(
                  children: [
                    Text("Enable notifications"),
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

                SizedBox(height: 10),

                Row(
                  children: [
                    Text("Enable messaging"),
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
                    Expanded(child: SizedBox(width: 10)),
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
