/// Organizer chips for Valhalla motorcycle costing.
class RoutePrefs {
  const RoutePrefs({
    this.avoidTolls = false,
    this.allowHighway = true,
    this.allowStreet = true,
    this.allowOffroad = false,
  });

  static const defaults = RoutePrefs();

  final bool avoidTolls;
  final bool allowHighway;
  final bool allowStreet;
  final bool allowOffroad;

  bool get hasAnyRoadChip => allowHighway || allowStreet || allowOffroad;

  RoutePrefs copyWith({
    bool? avoidTolls,
    bool? allowHighway,
    bool? allowStreet,
    bool? allowOffroad,
  }) {
    return RoutePrefs(
      avoidTolls: avoidTolls ?? this.avoidTolls,
      allowHighway: allowHighway ?? this.allowHighway,
      allowStreet: allowStreet ?? this.allowStreet,
      allowOffroad: allowOffroad ?? this.allowOffroad,
    );
  }

  Map<String, dynamic> toMap() => {
        'avoid_tolls': avoidTolls,
        'allow_highway': allowHighway,
        'allow_street': allowStreet,
        'allow_offroad': allowOffroad,
      };

  factory RoutePrefs.fromMap(Map<String, dynamic>? map) {
    if (map == null) return defaults;
    return RoutePrefs(
      avoidTolls: map['avoid_tolls'] == true,
      allowHighway: map['allow_highway'] != false,
      allowStreet: map['allow_street'] != false,
      allowOffroad: map['allow_offroad'] == true,
    );
  }

  /// Valhalla `costing_options.motorcycle`. Empty map = engine defaults.
  Map<String, dynamic> toValhallaMotorcycle() {
    if (!hasAnyRoadChip) return const {};

    double useHighways = 0.5;
    if (!allowHighway) {
      useHighways = 0.1;
    } else if (!allowStreet) {
      useHighways = 1.0;
    }

    return {
      'use_tolls': avoidTolls ? 0.0 : 0.5,
      'use_highways': useHighways,
      'use_tracks': allowOffroad ? 0.8 : 0.0,
      'use_trails': allowOffroad ? 0.6 : 0.0,
      'exclude_unpaved': !allowOffroad,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is RoutePrefs &&
        other.avoidTolls == avoidTolls &&
        other.allowHighway == allowHighway &&
        other.allowStreet == allowStreet &&
        other.allowOffroad == allowOffroad;
  }

  @override
  int get hashCode =>
      Object.hash(avoidTolls, allowHighway, allowStreet, allowOffroad);
}
