import 'dart:convert';

import 'package:flutter/services.dart';

import 'triumph_catalog.dart';

class BikeMakeEntry {
  const BikeMakeEntry({required this.name, required this.models});

  final String name;
  final List<BikeModelEntry> models;
}

class BikeModelEntry {
  const BikeModelEntry({
    required this.name,
    required this.yearFrom,
    required this.yearTo,
  });

  final String name;
  final int yearFrom;
  final int yearTo;

  bool inYear(int year) => year >= yearFrom && year <= yearTo;
}

/// Multi-brand garage catalog: manufacturer → year → model.
class BikeCatalog {
  BikeCatalog._(this.makes);

  final List<BikeMakeEntry> makes;

  static BikeCatalog? _instance;
  static const otherMake = 'Other';
  static const yearMin = 1990;
  static const yearMax = 2026;

  static const pinnedMakes = [
    'Honda',
    'Yamaha',
    'Kawasaki',
    'Suzuki',
    'Italika',
    'Bajaj',
    'Triumph',
    'BMW',
    'Ducati',
    'KTM',
    'Harley-Davidson',
    'Aprilia',
    'Indian',
    'Royal Enfield',
    'Husqvarna',
    'Benelli',
    'CFMoto',
    'Vento',
    'TVS',
    'Hero',
    'Zero',
  ];

  static Future<BikeCatalog> load() async {
    final existing = _instance;
    if (existing != null) return existing;
    final loaded = await _read();
    _instance = loaded;
    return loaded;
  }

  static BikeCatalog get instance => _instance ?? BikeCatalog._(_fromTriumphOnly());

  static String idFor(String brand, int year, String model) =>
      'm|$brand|$year|$model';

  static BikeModel? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    if (id.startsWith('m|')) {
      final parts = id.split('|');
      if (parts.length >= 4) {
        final year = int.tryParse(parts[2]);
        final name = parts.sublist(3).join('|');
        return BikeModel(
          id: id,
          brand: parts[1],
          name: name,
          family: BikeFamily.other,
          year: year,
          yearFrom: year,
          yearTo: year,
        );
      }
    }
    return TriumphCatalog.byId(id);
  }

  static Future<BikeCatalog> _read() async {
    try {
      final raw = await rootBundle.loadString('assets/bikes/catalog.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final makes = <BikeMakeEntry>[];
      for (final row in json['makes'] as List<dynamic>? ?? const []) {
        if (row is! Map<String, dynamic>) continue;
        final name = (row['name'] as String?)?.trim() ?? '';
        if (name.isEmpty) continue;
        final models = <BikeModelEntry>[];
        for (final m in row['models'] as List<dynamic>? ?? const []) {
          if (m is! Map<String, dynamic>) continue;
          final n = (m['n'] as String?)?.trim() ?? '';
          final a = (m['a'] as num?)?.toInt();
          final b = (m['b'] as num?)?.toInt() ?? a;
          if (n.isEmpty || a == null) continue;
          models.add(BikeModelEntry(name: n, yearFrom: a, yearTo: b ?? a));
        }
        if (models.isNotEmpty) {
          makes.add(BikeMakeEntry(name: name, models: models));
        }
      }
      return BikeCatalog._(_withCurated(makes));
    } catch (_) {
      return BikeCatalog._(_withCurated(_fromTriumphOnly()));
    }
  }

  static List<BikeMakeEntry> _fromTriumphOnly() => [];

  static const _curated = <String, List<BikeModelEntry>>{
    'Italika': [
      BikeModelEntry(name: 'FT 125', yearFrom: 2010, yearTo: 2026),
      BikeModelEntry(name: 'FT 150', yearFrom: 2010, yearTo: 2026),
      BikeModelEntry(name: 'FT 250', yearFrom: 2012, yearTo: 2026),
      BikeModelEntry(name: 'DT 125', yearFrom: 2012, yearTo: 2026),
      BikeModelEntry(name: 'DT 150', yearFrom: 2012, yearTo: 2026),
      BikeModelEntry(name: 'DT 200', yearFrom: 2015, yearTo: 2026),
      BikeModelEntry(name: 'DT 250', yearFrom: 2016, yearTo: 2026),
      BikeModelEntry(name: '125Z', yearFrom: 2014, yearTo: 2026),
      BikeModelEntry(name: '150Z', yearFrom: 2014, yearTo: 2026),
      BikeModelEntry(name: '200Z', yearFrom: 2016, yearTo: 2026),
      BikeModelEntry(name: '250Z', yearFrom: 2016, yearTo: 2026),
      BikeModelEntry(name: 'Vort-X 200', yearFrom: 2018, yearTo: 2026),
      BikeModelEntry(name: 'Vort-X 300', yearFrom: 2020, yearTo: 2026),
      BikeModelEntry(name: 'WS 150', yearFrom: 2014, yearTo: 2026),
      BikeModelEntry(name: 'WS 175', yearFrom: 2016, yearTo: 2026),
      BikeModelEntry(name: 'DM 150', yearFrom: 2015, yearTo: 2026),
      BikeModelEntry(name: 'DM 250', yearFrom: 2016, yearTo: 2026),
      BikeModelEntry(name: 'Vitalia 125', yearFrom: 2016, yearTo: 2026),
      BikeModelEntry(name: 'Vitalia 150', yearFrom: 2016, yearTo: 2026),
      BikeModelEntry(name: 'AT 110', yearFrom: 2012, yearTo: 2026),
      BikeModelEntry(name: 'AT 125', yearFrom: 2012, yearTo: 2026),
      BikeModelEntry(name: 'TC 200', yearFrom: 2018, yearTo: 2026),
      BikeModelEntry(name: 'TC 250', yearFrom: 2018, yearTo: 2026),
      BikeModelEntry(name: 'Sport 250', yearFrom: 2015, yearTo: 2026),
      BikeModelEntry(name: 'W 150', yearFrom: 2014, yearTo: 2026),
      BikeModelEntry(name: 'RT 200 GP', yearFrom: 2018, yearTo: 2026),
      BikeModelEntry(name: '150 SZ', yearFrom: 2018, yearTo: 2026),
      BikeModelEntry(name: '200 SZ', yearFrom: 2018, yearTo: 2026),
    ],
    'Vento': [
      BikeModelEntry(name: 'Ghost 150', yearFrom: 2015, yearTo: 2026),
      BikeModelEntry(name: 'Nitrox 250', yearFrom: 2016, yearTo: 2026),
      BikeModelEntry(name: 'Crossfire 250', yearFrom: 2016, yearTo: 2026),
      BikeModelEntry(name: 'Tornado 250', yearFrom: 2015, yearTo: 2026),
      BikeModelEntry(name: 'Rocketman 250', yearFrom: 2016, yearTo: 2026),
      BikeModelEntry(name: 'Ligero 150', yearFrom: 2014, yearTo: 2026),
      BikeModelEntry(name: 'Triton 250', yearFrom: 2018, yearTo: 2026),
      BikeModelEntry(name: 'Workman 150', yearFrom: 2014, yearTo: 2026),
      BikeModelEntry(name: 'Hellcat 250', yearFrom: 2018, yearTo: 2026),
    ],
    'Bajaj': [
      BikeModelEntry(name: 'Pulsar 150', yearFrom: 2010, yearTo: 2026),
      BikeModelEntry(name: 'Pulsar NS160', yearFrom: 2017, yearTo: 2026),
      BikeModelEntry(name: 'Pulsar NS200', yearFrom: 2012, yearTo: 2026),
      BikeModelEntry(name: 'Pulsar N160', yearFrom: 2022, yearTo: 2026),
      BikeModelEntry(name: 'Pulsar N250', yearFrom: 2021, yearTo: 2026),
      BikeModelEntry(name: 'Pulsar RS200', yearFrom: 2015, yearTo: 2026),
      BikeModelEntry(name: 'Dominar 250', yearFrom: 2020, yearTo: 2026),
      BikeModelEntry(name: 'Dominar 400', yearFrom: 2017, yearTo: 2026),
    ],
    'TVS': [
      BikeModelEntry(name: 'Apache RTR 160', yearFrom: 2012, yearTo: 2026),
      BikeModelEntry(name: 'Apache RTR 200', yearFrom: 2016, yearTo: 2026),
      BikeModelEntry(name: 'Apache RR 310', yearFrom: 2018, yearTo: 2026),
      BikeModelEntry(name: 'Raider 125', yearFrom: 2021, yearTo: 2026),
      BikeModelEntry(name: 'Ntorq 125', yearFrom: 2018, yearTo: 2026),
    ],
    'Hero': [
      BikeModelEntry(name: 'Xpulse 200', yearFrom: 2019, yearTo: 2026),
      BikeModelEntry(name: 'Xtreme 160R', yearFrom: 2020, yearTo: 2026),
    ],
  };

  static List<BikeMakeEntry> _withCurated(List<BikeMakeEntry> makes) {
    var next = makes;
    next = _mergeMake(next, 'Triumph', [
      for (final b in TriumphCatalog.all)
        if (b.brand == 'Triumph' && b.family != BikeFamily.other)
          BikeModelEntry(
            name: b.name,
            yearFrom: b.yearFrom ?? yearMin,
            yearTo: b.yearTo ?? yearMax,
          ),
    ]);
    for (final e in _curated.entries) {
      next = _mergeMake(next, e.key, e.value);
    }
    next.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return next;
  }

  static List<BikeMakeEntry> _mergeMake(
    List<BikeMakeEntry> makes,
    String brand,
    List<BikeModelEntry> extra,
  ) {
    final key = brand.toLowerCase();
    final idx = makes.indexWhere((m) => m.name.toLowerCase() == key);
    if (idx < 0) return [...makes, BikeMakeEntry(name: brand, models: extra)];
    final existing = makes[idx];
    final seen = {for (final m in existing.models) m.name.toLowerCase()};
    final merged = [
      ...existing.models,
      for (final m in extra)
        if (!seen.contains(m.name.toLowerCase())) m,
    ];
    return [
      for (var i = 0; i < makes.length; i++)
        if (i == idx) BikeMakeEntry(name: existing.name, models: merged) else makes[i],
    ];
  }

  List<String> makeNames({String query = ''}) {
    final q = query.trim().toLowerCase();
    final names = [for (final m in makes) m.name];
    final pinned = [
      for (final p in pinnedMakes)
        if (names.any((n) => n.toLowerCase() == p.toLowerCase())) p,
    ];
    final rest = [
      for (final n in names)
        if (!pinned.any((p) => p.toLowerCase() == n.toLowerCase())) n,
    ];
    final ordered = [...pinned, ...rest, if (!names.contains(otherMake)) otherMake];
    if (q.isEmpty) return ordered;
    return [for (final n in ordered) if (n.toLowerCase().contains(q)) n];
  }

  BikeMakeEntry? _make(String name) {
    final key = name.toLowerCase();
    for (final m in makes) {
      if (m.name.toLowerCase() == key) return m;
    }
    return null;
  }

  List<int> yearsFor(String make, {String query = ''}) {
    final entry = _make(make);
    final years = <int>{};
    if (entry == null) {
      for (var y = yearMax; y >= yearMin; y--) {
        years.add(y);
      }
    } else {
      for (final m in entry.models) {
        for (var y = m.yearTo; y >= m.yearFrom; y--) {
          years.add(y);
        }
      }
    }
    final sorted = years.toList()..sort((a, b) => b.compareTo(a));
    final q = query.trim();
    if (q.isEmpty) return sorted;
    return [for (final y in sorted) if ('$y'.contains(q)) y];
  }

  List<String> modelsFor(String make, int year, {String query = ''}) {
    final entry = _make(make);
    final names = <String>{};
    if (entry != null) {
      for (final m in entry.models) {
        if (m.inYear(year)) names.add(m.name);
      }
    }
    final list = names.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return list;
    return [for (final n in list) if (n.toLowerCase().contains(q)) n];
  }

  BikeModel pick(String brand, int year, String model) {
    BikeModel? match;
    for (final b in TriumphCatalog.all) {
      if (b.brand.toLowerCase() == brand.toLowerCase() &&
          b.name.toLowerCase() == model.toLowerCase()) {
        match = b;
        break;
      }
    }
    return BikeModel(
      id: idFor(brand, year, model),
      brand: brand,
      name: model,
      family: match?.family ?? BikeFamily.other,
      approxCc: match?.approxCc,
      year: year,
      yearFrom: year,
      yearTo: year,
    );
  }
}
