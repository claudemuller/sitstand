class Options {
  final String name = "options";
  int standMins;
  int sitMins;
  bool enableNotifications;
  bool enableMessaging;

  static const int _twentyMins = 20;

  Options({
    this.standMins = _twentyMins,
    this.sitMins = _twentyMins,
    this.enableNotifications = false,
    this.enableMessaging = true,
  });

  @override
  String toString() {
    return 'Options(standMillis: $standMins, sitMins: $sitMins, enableNotifications: $enableNotifications, enableMessaging: $enableMessaging)';
  }

  factory Options.fromJson(Map<String, dynamic> json) {
    return Options(
      standMins: json['standMins'],
      sitMins: json['sitMins'],
      enableNotifications: json['enableNotifications'] ?? false,
      enableMessaging: json['enableMessaging'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'standMins': standMins,
      'sitMins': sitMins,
      'enableNotifications': enableNotifications,
      'enableMessaging': enableMessaging,
    };
  }
}
