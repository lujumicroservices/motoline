/// Curated Triumph catalog for garage selection (Lean Lab / ride context).
enum BikeFamily {
  naked,
  adventure,
  classic,
  sport,
  cruiser,
  other,
}

class BikeModel {
  const BikeModel({
    required this.id,
    required this.brand,
    required this.name,
    required this.family,
    this.approxCc,
  });

  final String id;
  final String brand;
  final String name;
  final BikeFamily family;
  final int? approxCc;

  String get label => brand == 'Triumph' ? name : '$brand $name';

  String get subtitle {
    final cc = approxCc;
    final fam = switch (family) {
      BikeFamily.naked => 'Naked',
      BikeFamily.adventure => 'Adventure',
      BikeFamily.classic => 'Classic',
      BikeFamily.sport => 'Sport',
      BikeFamily.cruiser => 'Cruiser',
      BikeFamily.other => 'Other',
    };
    if (cc == null) return fam;
    return '$fam · ~$cc cc';
  }
}

/// Triumph-first garage list for the pilot group.
abstract final class TriumphCatalog {
  static const List<BikeModel> all = [
    // Naked
    BikeModel(
      id: 'triumph_trident_660',
      brand: 'Triumph',
      name: 'Trident 660',
      family: BikeFamily.naked,
      approxCc: 660,
    ),
    BikeModel(
      id: 'triumph_street_triple_765',
      brand: 'Triumph',
      name: 'Street Triple 765',
      family: BikeFamily.naked,
      approxCc: 765,
    ),
    BikeModel(
      id: 'triumph_street_triple_rs',
      brand: 'Triumph',
      name: 'Street Triple RS',
      family: BikeFamily.naked,
      approxCc: 765,
    ),
    BikeModel(
      id: 'triumph_speed_triple_1200',
      brand: 'Triumph',
      name: 'Speed Triple 1200',
      family: BikeFamily.naked,
      approxCc: 1160,
    ),
    BikeModel(
      id: 'triumph_speed_400',
      brand: 'Triumph',
      name: 'Speed 400',
      family: BikeFamily.naked,
      approxCc: 398,
    ),
    // Adventure
    BikeModel(
      id: 'triumph_tiger_sport_660',
      brand: 'Triumph',
      name: 'Tiger Sport 660',
      family: BikeFamily.adventure,
      approxCc: 660,
    ),
    BikeModel(
      id: 'triumph_tiger_900',
      brand: 'Triumph',
      name: 'Tiger 900',
      family: BikeFamily.adventure,
      approxCc: 888,
    ),
    BikeModel(
      id: 'triumph_tiger_1200',
      brand: 'Triumph',
      name: 'Tiger 1200',
      family: BikeFamily.adventure,
      approxCc: 1160,
    ),
    BikeModel(
      id: 'triumph_tiger_sport_800',
      brand: 'Triumph',
      name: 'Tiger Sport 800',
      family: BikeFamily.adventure,
      approxCc: 798,
    ),
    // Classic
    BikeModel(
      id: 'triumph_bonneville_t100',
      brand: 'Triumph',
      name: 'Bonneville T100',
      family: BikeFamily.classic,
      approxCc: 900,
    ),
    BikeModel(
      id: 'triumph_bonneville_t120',
      brand: 'Triumph',
      name: 'Bonneville T120',
      family: BikeFamily.classic,
      approxCc: 1200,
    ),
    BikeModel(
      id: 'triumph_scrambler_400',
      brand: 'Triumph',
      name: 'Scrambler 400 X',
      family: BikeFamily.classic,
      approxCc: 398,
    ),
    BikeModel(
      id: 'triumph_scrambler_1200',
      brand: 'Triumph',
      name: 'Scrambler 1200',
      family: BikeFamily.classic,
      approxCc: 1200,
    ),
    BikeModel(
      id: 'triumph_thruxton_rs',
      brand: 'Triumph',
      name: 'Thruxton RS',
      family: BikeFamily.classic,
      approxCc: 1200,
    ),
    // Sport
    BikeModel(
      id: 'triumph_daytona_660',
      brand: 'Triumph',
      name: 'Daytona 660',
      family: BikeFamily.sport,
      approxCc: 660,
    ),
    // Cruiser
    BikeModel(
      id: 'triumph_rocket_3',
      brand: 'Triumph',
      name: 'Rocket 3',
      family: BikeFamily.cruiser,
      approxCc: 2458,
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

  static List<BikeModel> byFamily(BikeFamily family) =>
      [for (final b in all) if (b.family == family) b];
}
