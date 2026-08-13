/// Curated Triumph catalog for garage selection (Lean Lab / ride context).
enum BikeFamily {
  naked,
  adventure,
  classic,
  sport,
  cruiser,
  offroad,
  other,
}

class BikeModel {
  const BikeModel({
    required this.id,
    required this.brand,
    required this.name,
    required this.family,
    this.approxCc,
    this.yearFrom,
    this.yearTo,
    this.year,
    this.aliases = const [],
  });

  final String id;
  final String brand;
  final String name;
  final BikeFamily family;
  final int? approxCc;
  /// First model year of this generation. Null = unknown.
  final int? yearFrom;
  /// Last model year. Null = still current.
  final int? yearTo;
  /// Year the rider picked in the garage wizard.
  final int? year;
  final List<String> aliases;

  String get label => '$brand $name';

  String get years {
    final from = yearFrom;
    if (from == null) return '';
    final to = yearTo;
    if (to == null) return '$from–';
    if (to == from) return '$from';
    return '$from–$to';
  }

  String get subtitle {
    final fam = switch (family) {
      BikeFamily.naked => 'Naked',
      BikeFamily.adventure => 'Adventure',
      BikeFamily.classic => 'Classic',
      BikeFamily.sport => 'Sport',
      BikeFamily.cruiser => 'Cruiser',
      BikeFamily.offroad => 'Off-road',
      BikeFamily.other => 'Other',
    };
    final parts = <String>[];
    if (year != null) {
      parts.add('$year');
    } else if (years.isNotEmpty) {
      parts.add(years);
    }
    if (family != BikeFamily.other) parts.insert(0, fam);
    if (approxCc != null) parts.add('~$approxCc cc');
    if (parts.isEmpty) return fam;
    return parts.join(' · ');
  }

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return label.toLowerCase().contains(q) ||
        subtitle.toLowerCase().contains(q) ||
        years.contains(q) ||
        aliases.any((a) => a.toLowerCase().contains(q) || q.contains(a.toLowerCase()));
  }
}

/// Full current + recent Triumph range. Existing garage ids stay valid.
abstract final class TriumphCatalog {
  static const List<BikeModel> all = [
    // —— Naked / roadster ——
    BikeModel(
      id: 'triumph_speed_400',
      brand: 'Triumph',
      name: 'Speed 400',
      family: BikeFamily.naked,
      approxCc: 398,
      yearFrom: 2024,
    ),
    BikeModel(
      id: 'triumph_tracker_400',
      brand: 'Triumph',
      name: 'Tracker 400',
      family: BikeFamily.naked,
      approxCc: 398,
      yearFrom: 2026,
    ),
    BikeModel(
      id: 'triumph_trident_660',
      brand: 'Triumph',
      name: 'Trident 660',
      family: BikeFamily.naked,
      approxCc: 660,
      yearFrom: 2021,
    ),
    BikeModel(
      id: 'triumph_trident_800',
      brand: 'Triumph',
      name: 'Trident 800',
      family: BikeFamily.naked,
      approxCc: 800,
      yearFrom: 2026,
    ),
    BikeModel(
      id: 'triumph_street_triple_765',
      brand: 'Triumph',
      name: 'Street Triple 765',
      family: BikeFamily.naked,
      approxCc: 765,
      yearFrom: 2017,
    ),
    BikeModel(
      id: 'triumph_street_triple_765_r',
      brand: 'Triumph',
      name: 'Street Triple 765 R',
      family: BikeFamily.naked,
      approxCc: 765,
      yearFrom: 2017,
    ),
    BikeModel(
      id: 'triumph_street_triple_rs',
      brand: 'Triumph',
      name: 'Street Triple 765 RS',
      family: BikeFamily.naked,
      approxCc: 765,
      yearFrom: 2017,
    ),
    BikeModel(
      id: 'triumph_street_triple_765_rx',
      brand: 'Triumph',
      name: 'Street Triple 765 RX',
      family: BikeFamily.naked,
      approxCc: 765,
      yearFrom: 2026,
    ),
    BikeModel(
      id: 'triumph_street_triple_765_moto2',
      brand: 'Triumph',
      name: 'Street Triple 765 Moto2 Edition',
      family: BikeFamily.naked,
      approxCc: 765,
      yearFrom: 2023,
    ),
    BikeModel(
      id: 'triumph_street_triple_675',
      brand: 'Triumph',
      name: 'Street Triple 675',
      family: BikeFamily.naked,
      approxCc: 675,
      yearFrom: 2007,
      yearTo: 2017,
    ),
    BikeModel(
      id: 'triumph_speed_triple_1200',
      brand: 'Triumph',
      name: 'Speed Triple 1200 RS',
      family: BikeFamily.naked,
      approxCc: 1160,
      yearFrom: 2021,
      aliases: ['street triple 1200 rs', 'street triple 1200'],
    ),
    BikeModel(
      id: 'triumph_speed_triple_1200_rx',
      brand: 'Triumph',
      name: 'Speed Triple 1200 RX',
      family: BikeFamily.naked,
      approxCc: 1160,
      yearFrom: 2026,
      yearTo: 2026,
      aliases: ['street triple 1200 rx', 'street triple 1200'],
    ),
    BikeModel(
      id: 'triumph_speed_triple_1200_rr',
      brand: 'Triumph',
      name: 'Speed Triple 1200 RR',
      family: BikeFamily.naked,
      approxCc: 1160,
      yearFrom: 2022,
      yearTo: 2024,
    ),
    BikeModel(
      id: 'triumph_speed_triple_1050',
      brand: 'Triumph',
      name: 'Speed Triple 1050',
      family: BikeFamily.naked,
      approxCc: 1050,
      yearFrom: 2005,
      yearTo: 2020,
    ),

    // —— Adventure ——
    BikeModel(
      id: 'triumph_tiger_sport_660',
      brand: 'Triumph',
      name: 'Tiger Sport 660',
      family: BikeFamily.adventure,
      approxCc: 660,
      yearFrom: 2022,
    ),
    BikeModel(
      id: 'triumph_tiger_sport_800',
      brand: 'Triumph',
      name: 'Tiger Sport 800',
      family: BikeFamily.adventure,
      approxCc: 798,
      yearFrom: 2025,
    ),
    BikeModel(
      id: 'triumph_tiger_sport_800_tour',
      brand: 'Triumph',
      name: 'Tiger Sport 800 Tour',
      family: BikeFamily.adventure,
      approxCc: 798,
      yearFrom: 2026,
    ),
    BikeModel(
      id: 'triumph_tiger_850_sport',
      brand: 'Triumph',
      name: 'Tiger 850 Sport',
      family: BikeFamily.adventure,
      approxCc: 888,
      yearFrom: 2021,
      yearTo: 2024,
    ),
    BikeModel(
      id: 'triumph_tiger_900',
      brand: 'Triumph',
      name: 'Tiger 900',
      family: BikeFamily.adventure,
      approxCc: 888,
      yearFrom: 2020,
    ),
    BikeModel(
      id: 'triumph_tiger_900_gt',
      brand: 'Triumph',
      name: 'Tiger 900 GT',
      family: BikeFamily.adventure,
      approxCc: 888,
      yearFrom: 2020,
    ),
    BikeModel(
      id: 'triumph_tiger_900_gt_pro',
      brand: 'Triumph',
      name: 'Tiger 900 GT Pro',
      family: BikeFamily.adventure,
      approxCc: 888,
      yearFrom: 2020,
    ),
    BikeModel(
      id: 'triumph_tiger_900_rally',
      brand: 'Triumph',
      name: 'Tiger 900 Rally',
      family: BikeFamily.adventure,
      approxCc: 888,
      yearFrom: 2020,
    ),
    BikeModel(
      id: 'triumph_tiger_900_rally_pro',
      brand: 'Triumph',
      name: 'Tiger 900 Rally Pro',
      family: BikeFamily.adventure,
      approxCc: 888,
      yearFrom: 2020,
    ),
    BikeModel(
      id: 'triumph_tiger_1200',
      brand: 'Triumph',
      name: 'Tiger 1200',
      family: BikeFamily.adventure,
      approxCc: 1160,
      yearFrom: 2022,
    ),
    BikeModel(
      id: 'triumph_tiger_1200_gt',
      brand: 'Triumph',
      name: 'Tiger 1200 GT',
      family: BikeFamily.adventure,
      approxCc: 1160,
      yearFrom: 2022,
    ),
    BikeModel(
      id: 'triumph_tiger_1200_gt_pro',
      brand: 'Triumph',
      name: 'Tiger 1200 GT Pro',
      family: BikeFamily.adventure,
      approxCc: 1160,
      yearFrom: 2022,
    ),
    BikeModel(
      id: 'triumph_tiger_1200_gt_explorer',
      brand: 'Triumph',
      name: 'Tiger 1200 GT Explorer',
      family: BikeFamily.adventure,
      approxCc: 1160,
      yearFrom: 2022,
    ),
    BikeModel(
      id: 'triumph_tiger_1200_rally_pro',
      brand: 'Triumph',
      name: 'Tiger 1200 Rally Pro',
      family: BikeFamily.adventure,
      approxCc: 1160,
      yearFrom: 2022,
    ),
    BikeModel(
      id: 'triumph_tiger_1200_rally_explorer',
      brand: 'Triumph',
      name: 'Tiger 1200 Rally Explorer',
      family: BikeFamily.adventure,
      approxCc: 1160,
      yearFrom: 2022,
    ),
    BikeModel(
      id: 'triumph_tiger_800',
      brand: 'Triumph',
      name: 'Tiger 800',
      family: BikeFamily.adventure,
      approxCc: 800,
      yearFrom: 2010,
      yearTo: 2020,
    ),

    // —— Modern classic / scrambler ——
    BikeModel(
      id: 'triumph_scrambler_400',
      brand: 'Triumph',
      name: 'Scrambler 400 X',
      family: BikeFamily.classic,
      approxCc: 398,
      yearFrom: 2024,
    ),
    BikeModel(
      id: 'triumph_scrambler_400_xc',
      brand: 'Triumph',
      name: 'Scrambler 400 XC',
      family: BikeFamily.classic,
      approxCc: 398,
      yearFrom: 2026,
    ),
    BikeModel(
      id: 'triumph_scrambler_900',
      brand: 'Triumph',
      name: 'Scrambler 900',
      family: BikeFamily.classic,
      approxCc: 900,
      yearFrom: 2019,
    ),
    BikeModel(
      id: 'triumph_scrambler_1200',
      brand: 'Triumph',
      name: 'Scrambler 1200',
      family: BikeFamily.classic,
      approxCc: 1200,
      yearFrom: 2019,
    ),
    BikeModel(
      id: 'triumph_scrambler_1200_x',
      brand: 'Triumph',
      name: 'Scrambler 1200 X',
      family: BikeFamily.classic,
      approxCc: 1200,
      yearFrom: 2024,
    ),
    BikeModel(
      id: 'triumph_scrambler_1200_xe',
      brand: 'Triumph',
      name: 'Scrambler 1200 XE',
      family: BikeFamily.classic,
      approxCc: 1200,
      yearFrom: 2019,
    ),
    BikeModel(
      id: 'triumph_bonneville_t100',
      brand: 'Triumph',
      name: 'Bonneville T100',
      family: BikeFamily.classic,
      approxCc: 900,
      yearFrom: 2017,
    ),
    BikeModel(
      id: 'triumph_bonneville_t120',
      brand: 'Triumph',
      name: 'Bonneville T120',
      family: BikeFamily.classic,
      approxCc: 1200,
      yearFrom: 2016,
    ),
    BikeModel(
      id: 'triumph_bonneville_t120_black',
      brand: 'Triumph',
      name: 'Bonneville T120 Black',
      family: BikeFamily.classic,
      approxCc: 1200,
      yearFrom: 2016,
    ),
    BikeModel(
      id: 'triumph_bonneville_bobber',
      brand: 'Triumph',
      name: 'Bonneville Bobber',
      family: BikeFamily.classic,
      approxCc: 1200,
      yearFrom: 2017,
    ),
    BikeModel(
      id: 'triumph_speedmaster',
      brand: 'Triumph',
      name: 'Bonneville Speedmaster',
      family: BikeFamily.classic,
      approxCc: 1200,
      yearFrom: 2018,
    ),
    BikeModel(
      id: 'triumph_speed_twin_900',
      brand: 'Triumph',
      name: 'Speed Twin 900',
      family: BikeFamily.classic,
      approxCc: 900,
      yearFrom: 2019,
    ),
    BikeModel(
      id: 'triumph_speed_twin_1200',
      brand: 'Triumph',
      name: 'Speed Twin 1200',
      family: BikeFamily.classic,
      approxCc: 1200,
      yearFrom: 2019,
    ),
    BikeModel(
      id: 'triumph_speed_twin_1200_rs',
      brand: 'Triumph',
      name: 'Speed Twin 1200 RS',
      family: BikeFamily.classic,
      approxCc: 1200,
      yearFrom: 2025,
    ),
    BikeModel(
      id: 'triumph_speed_twin_1200_cafe',
      brand: 'Triumph',
      name: 'Speed Twin 1200 Café Racer',
      family: BikeFamily.classic,
      approxCc: 1200,
      yearFrom: 2026,
    ),
    BikeModel(
      id: 'triumph_thruxton_rs',
      brand: 'Triumph',
      name: 'Thruxton RS',
      family: BikeFamily.classic,
      approxCc: 1200,
      yearFrom: 2020,
      yearTo: 2024,
    ),
    BikeModel(
      id: 'triumph_thruxton_400',
      brand: 'Triumph',
      name: 'Thruxton 400',
      family: BikeFamily.classic,
      approxCc: 398,
      yearFrom: 2026,
    ),

    // —— Sport ——
    BikeModel(
      id: 'triumph_daytona_660',
      brand: 'Triumph',
      name: 'Daytona 660',
      family: BikeFamily.sport,
      approxCc: 660,
      yearFrom: 2024,
    ),
    BikeModel(
      id: 'triumph_daytona_675',
      brand: 'Triumph',
      name: 'Daytona 675',
      family: BikeFamily.sport,
      approxCc: 675,
      yearFrom: 2006,
      yearTo: 2018,
    ),
    BikeModel(
      id: 'triumph_daytona_765',
      brand: 'Triumph',
      name: 'Daytona 765 Moto2',
      family: BikeFamily.sport,
      approxCc: 765,
      yearFrom: 2020,
      yearTo: 2020,
    ),

    // —— Cruiser ——
    BikeModel(
      id: 'triumph_rocket_3',
      brand: 'Triumph',
      name: 'Rocket 3',
      family: BikeFamily.cruiser,
      approxCc: 2458,
      yearFrom: 2020,
    ),
    BikeModel(
      id: 'triumph_rocket_3_storm_r',
      brand: 'Triumph',
      name: 'Rocket 3 Storm R',
      family: BikeFamily.cruiser,
      approxCc: 2458,
      yearFrom: 2024,
    ),
    BikeModel(
      id: 'triumph_rocket_3_storm_gt',
      brand: 'Triumph',
      name: 'Rocket 3 Storm GT',
      family: BikeFamily.cruiser,
      approxCc: 2458,
      yearFrom: 2024,
    ),

    // —— Off-road ——
    BikeModel(
      id: 'triumph_tf_250_x',
      brand: 'Triumph',
      name: 'TF 250-X',
      family: BikeFamily.offroad,
      approxCc: 250,
      yearFrom: 2024,
    ),
    BikeModel(
      id: 'triumph_tf_250_e',
      brand: 'Triumph',
      name: 'TF 250-E',
      family: BikeFamily.offroad,
      approxCc: 250,
      yearFrom: 2025,
    ),
    BikeModel(
      id: 'triumph_tf_250_c',
      brand: 'Triumph',
      name: 'TF 250-C',
      family: BikeFamily.offroad,
      approxCc: 250,
      yearFrom: 2026,
    ),
    BikeModel(
      id: 'triumph_tf_450_x',
      brand: 'Triumph',
      name: 'TF 450-X',
      family: BikeFamily.offroad,
      approxCc: 450,
      yearFrom: 2025,
    ),
    BikeModel(
      id: 'triumph_tf_450_e',
      brand: 'Triumph',
      name: 'TF 450-E',
      family: BikeFamily.offroad,
      approxCc: 450,
      yearFrom: 2025,
    ),
    BikeModel(
      id: 'triumph_tf_450_c',
      brand: 'Triumph',
      name: 'TF 450-C',
      family: BikeFamily.offroad,
      approxCc: 450,
      yearFrom: 2026,
    ),
    BikeModel(
      id: 'triumph_tf_450_rc',
      brand: 'Triumph',
      name: 'TF 450-RC',
      family: BikeFamily.offroad,
      approxCc: 450,
      yearFrom: 2025,
    ),

    // Fallbacks
    BikeModel(
      id: 'triumph_other',
      brand: 'Triumph',
      name: 'Other Triumph',
      family: BikeFamily.other,
    ),
    BikeModel(
      id: 'other_bike',
      brand: 'Other',
      name: 'Other brand',
      family: BikeFamily.other,
    ),
  ];

  static BikeModel? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final b in all) {
      if (b.id == id) return b;
    }
    return null;
  }

  static List<BikeModel> byFamily(BikeFamily family, {String query = ''}) => [
        for (final b in all)
          if (b.family == family && b.matches(query)) b,
      ];
}
