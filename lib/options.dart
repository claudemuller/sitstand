class Options {
  final String name = "options";
  int standMillis;
  int sitMillis;
  bool enableNotifications;
  bool enableMessaging;

  static const int _twentyMins = 20 * 60 * 1000;

  Options({
    this.standMillis = _twentyMins,
    this.sitMillis = _twentyMins,
    this.enableNotifications = false,
    this.enableMessaging = true,
  });

  @override
  String toString() {
    return 'Options(standMillis: $standMillis, sitMillis: $sitMillis, enableNotifications: $enableNotifications, enableMessaging: $enableMessaging)';
  }

  factory Options.fromJson(Map<String, dynamic> json) {
    return Options(
      standMillis: json['standMillis'],
      sitMillis: json['sitMillis'],
      enableNotifications: json['enableNotifications'] ?? false,
      enableMessaging: json['enableMessaging'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'standMillis': standMillis,
      'sitMillis': sitMillis,
      'enableNotifications': enableNotifications,
      'enableMessaging': enableMessaging,
    };
  }
}
