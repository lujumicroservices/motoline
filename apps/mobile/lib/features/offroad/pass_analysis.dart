import 'session_model.dart';

/// Sector time vs the session best (valid flying sectors only).
class SectorDelta {
  const SectorDelta({
    required this.name,
    required this.timeS,
    required this.bestS,
    required this.partial,
    this.note,
    this.bestPassId,
  });

  final String name;
  final double timeS;
  final double? bestS;
  final bool partial;
  final String? note;
  final String? bestPassId;

  /// Positive = slower than best. Null if no comparable best.
  double? get deltaS =>
      bestS == null || partial ? null : timeS - bestS!;

  bool get isBest => deltaS != null && deltaS!.abs() < 0.05;
}

class PaceFactor {
  const PaceFactor({
    required this.kind, // good | bad | info
    required this.title,
    required this.body,
  });
  final String kind;
  final String title;
  final String body;
}

/// Compares one pass to the best sectors / stats of the same training day.
class PassAnalysis {
  PassAnalysis(this.session, this.pass)
      : sectors = _sectors(session, pass),
        factors = _factors(session, pass);

  final TrainingSession session;
  final TrainingPass pass;
  final List<SectorDelta> sectors;
  final List<PaceFactor> factors;

  TrainingPass get fastestPass => session.passes.reduce(
        (a, b) => a.durationS <= b.durationS ? a : b,
      );

  double get durationDeltaS => pass.durationS - fastestPass.durationS;

  /// Sum of sector deltas where comparable (excludes partial / stopped).
  double get comparableDeltaS => sectors
      .where((s) => s.deltaS != null)
      .fold(0.0, (a, s) => a + s.deltaS!);

  static List<SectorDelta> _sectors(TrainingSession session, TrainingPass pass) {
    return [
      for (final s in pass.sectors)
        SectorDelta(
          name: s.name,
          timeS: s.timeS,
          bestS: _bestSector(session, s.name),
          partial: s.partial || _invalidNote(s.note),
          note: s.note,
          bestPassId: _bestSectorPass(session, s.name),
        ),
    ];
  }

  static bool _invalidNote(String? note) {
    if (note == null || note.isEmpty) return false;
    final n = note.toLowerCase();
    return n.contains('standing') ||
        n.contains('stopped') ||
        n.contains('partial') ||
        n.contains('not a flying');
  }

  static double? _bestSector(TrainingSession session, String name) {
    double? best;
    for (final p in session.passes) {
      for (final s in p.sectors) {
        if (s.name != name) continue;
        if (s.partial || _invalidNote(s.note)) continue;
        if (best == null || s.timeS < best) best = s.timeS;
      }
    }
    return best;
  }

  static String? _bestSectorPass(TrainingSession session, String name) {
    String? id;
    double? best;
    for (final p in session.passes) {
      for (final s in p.sectors) {
        if (s.name != name) continue;
        if (s.partial || _invalidNote(s.note)) continue;
        if (best == null || s.timeS < best) {
          best = s.timeS;
          id = p.id;
        }
      }
    }
    return id;
  }

  static List<PaceFactor> _factors(TrainingSession session, TrainingPass pass) {
    final out = <PaceFactor>[];
    final fastest = session.passes.reduce(
      (a, b) => a.durationS <= b.durationS ? a : b,
    );
    final cleanest = session.passes.reduce(
      (a, b) => a.pctOutside <= b.pctOutside ? a : b,
    );
    final deltas = _sectors(session, pass);
    final comparable = deltas.where((d) => d.deltaS != null).toList();

    if (pass.id == fastest.id) {
      out.add(const PaceFactor(
        kind: 'good',
        title: 'Pasada más rápida del día',
        body: 'Esta es la referencia de ritmo. Los deltas de las otras se miden contra ella.',
      ));
    } else {
      final d = pass.durationS - fastest.durationS;
      out.add(PaceFactor(
        kind: 'bad',
        title: '+${d.toStringAsFixed(1)} s vs ${fastest.id}',
        body: 'Terminó ${d.toStringAsFixed(1)} s más lento que la pasada más rápida '
            '(${(fastest.durationS / 60).toStringAsFixed(1)} min).',
      ));
    }

    // Biggest sector losses / gains
    if (comparable.isNotEmpty) {
      final worst = comparable.reduce((a, b) => a.deltaS! >= b.deltaS! ? a : b);
      final best = comparable.reduce((a, b) => a.deltaS! <= b.deltaS! ? a : b);
      if (worst.deltaS! > 0.3) {
        out.add(PaceFactor(
          kind: 'bad',
          title: '${worst.name}: +${worst.deltaS!.toStringAsFixed(2)} s',
          body: 'Ahí se fue la mayor parte del tiempo. Mejor del día: '
              '${worst.bestS!.toStringAsFixed(2)} s (${worst.bestPassId}).',
        ));
      }
      if (best.deltaS! <= 0.05) {
        out.add(PaceFactor(
          kind: 'good',
          title: '${best.name}: mejor del día',
          body: '${best.timeS.toStringAsFixed(2)} s — referencia para las otras pasadas.',
        ));
      } else if (best.deltaS! < 1.0 && best != worst) {
        out.add(PaceFactor(
          kind: 'good',
          title: '${best.name}: cerca del mejor (+${best.deltaS!.toStringAsFixed(2)} s)',
          body: 'El sector más competitivo de esta pasada.',
        ));
      }
    }

    for (final s in pass.sectors) {
      if (s.partial || _invalidNote(s.note)) {
        out.add(PaceFactor(
          kind: 'bad',
          title: '${s.name} no válido para comparar',
          body: s.note ?? 'Sector parcial o con parada.',
        ));
      }
    }

    // Speed
    final vmaxBest = session.passes.map((p) => p.vmaxKmh).reduce((a, b) => a > b ? a : b);
    if (pass.vmaxKmh >= vmaxBest - 0.5) {
      out.add(PaceFactor(
        kind: 'good',
        title: 'Velocidad punta alta (${pass.vmaxKmh.toStringAsFixed(0)} km/h)',
        body: 'Llegó al tope del día. El ritmo punta no fue el freno.',
      ));
    } else if (pass.vmaxKmh < vmaxBest - 3) {
      out.add(PaceFactor(
        kind: 'bad',
        title: 'Punta ${ (vmaxBest - pass.vmaxKmh).toStringAsFixed(0) } km/h más baja',
        body: 'Máx ${pass.vmaxKmh.toStringAsFixed(0)} vs ${vmaxBest.toStringAsFixed(0)} km/h del día. '
            'Menos velocidad de llegada a las zonas rápidas.',
      ));
    }

    final vavgBest = session.passes.map((p) => p.vavgKmh).reduce((a, b) => a > b ? a : b);
    if (pass.vavgKmh < vavgBest - 1.5) {
      out.add(PaceFactor(
        kind: 'bad',
        title: 'Media más baja (${pass.vavgKmh.toStringAsFixed(1)} km/h)',
        body: 'Mejor media del día: ${vavgBest.toStringAsFixed(1)} km/h. '
            'Sugiere más tiempo a media gas o más frenos largos.',
      ));
    } else if (pass.vavgKmh >= vavgBest - 0.3) {
      out.add(PaceFactor(
        kind: 'good',
        title: 'Buena velocidad media',
        body: '${pass.vavgKmh.toStringAsFixed(1)} km/h en movimiento — ritmo sostenido.',
      ));
    }

    // Line
    if (pass.pctOutside <= cleanest.pctOutside + 0.3) {
      out.add(PaceFactor(
        kind: 'good',
        title: 'Línea limpia (${(100 - pass.pctOutside).toStringAsFixed(1)} % en pista)',
        body: 'Poco tiempo fuera del corredor. El mapeo aguanta esta trazada.',
      ));
    } else if (pass.pctOutside > cleanest.pctOutside + 2) {
      out.add(PaceFactor(
        kind: 'bad',
        title: 'Más fuera del corredor (${pass.pctOutside.toStringAsFixed(1)} %)',
        body: 'Mejor del día: ${cleanest.pctOutside.toStringAsFixed(1)} % fuera. '
            'Salidas hasta ${pass.outsideMaxM.toStringAsFixed(1)} m — posible línea ancha o ruido GPS.',
      ));
    }

    // Braking
    if (pass.brakingZones > 0) {
      final hard = pass.brakes.isEmpty
          ? null
          : pass.brakes.reduce((a, b) => a.peakG >= b.peakG ? a : b);
      if (hard != null && hard.peakG >= 0.28) {
        out.add(PaceFactor(
          kind: hard.sector == 'S3' || hard.lapM > 1200 ? 'bad' : 'info',
          title: 'Frenada fuerte ${hard.peakG.toStringAsFixed(2)} g en ${hard.sector}',
          body: 'De ${hard.vIn.toStringAsFixed(0)} a ${hard.vOut.toStringAsFixed(0)} km/h '
              'a ${hard.lapM.toStringAsFixed(0)} m de arco. '
              '${hard.sector == 'S3' || hard.lapM > 1200 ? 'Cerca de meta: llegada tarde a la siguiente zona.' : 'Revisa si podías entrarla más suave.'}',
        ));
      }
      final zonesBest = session.passes
          .map((p) => p.brakingZones)
          .reduce((a, b) => a <= b ? a : b);
      if (pass.brakingZones > zonesBest + 1) {
        out.add(PaceFactor(
          kind: 'info',
          title: '${pass.brakingZones} zonas de frenada',
          body: 'Patrón ${pass.brakingZonesPerSector} (S1/S2/S3). '
              'Más toques que la pasada más limpia del día ($zonesBest).',
        ));
      }
    }

    // Lean
    final leanBest = session.passes.map((p) => p.leanMax).reduce((a, b) => a > b ? a : b);
    if (pass.leanMax >= leanBest - 0.5) {
      out.add(PaceFactor(
        kind: 'good',
        title: 'Inclinación punta ${pass.leanMax.toStringAsFixed(0)}° (${pass.maxleanSector})',
        body: 'Usó el cuerpo/chasis al máximo del día en ${pass.maxleanSector}.',
      ));
    }

    return out;
  }
}
