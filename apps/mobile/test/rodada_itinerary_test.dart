import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:motoline/features/rodadas/rodada_itinerary.dart';

void main() {
  test('itinerary line is start then stops then finish, skipping nulls', () {
    const start = LatLng(20, -103);
    const a = LatLng(20.1, -103.1);
    const b = LatLng(20.2, -103.2);
    const finish = LatLng(21, -104);

    expect(
      rodadaItineraryLine(start: start, stops: [a, b], finish: finish),
      [start, a, b, finish],
    );
    expect(rodadaItineraryLine(start: start), [start]);
    expect(rodadaItineraryLine(finish: finish, stops: [a]), [a, finish]);
    expect(rodadaItineraryLine(), isEmpty);
  });

  test('nextStopSortOrder is max plus one', () {
    expect(nextStopSortOrder(const <int>[]), 0);
    expect(nextStopSortOrder(const [0]), 1);
    expect(nextStopSortOrder(const [0, 2, 1]), 3);
    expect(nextStopSortOrder(const [4]), 5);
  });
}
