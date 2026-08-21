import 'package:latlong2/latlong.dart';

/// Google encoded polyline (Valhalla `polyline6` = precision 6).
List<LatLng> decodePolyline(String encoded, {int precision = 6}) {
  if (encoded.isEmpty) return const [];
  final factor = _factor(precision);
  final points = <LatLng>[];
  var index = 0;
  var lat = 0;
  var lng = 0;
  while (index < encoded.length) {
    final dlat = _nextDelta(encoded, index);
    index = dlat.index;
    lat += dlat.value;
    if (index >= encoded.length) break;
    final dlng = _nextDelta(encoded, index);
    index = dlng.index;
    lng += dlng.value;
    points.add(LatLng(lat / factor, lng / factor));
  }
  return points;
}

String encodePolyline(List<LatLng> points, {int precision = 6}) {
  if (points.isEmpty) return '';
  final factor = _factor(precision);
  final buf = StringBuffer();
  var prevLat = 0;
  var prevLng = 0;
  for (final p in points) {
    final lat = (p.latitude * factor).round();
    final lng = (p.longitude * factor).round();
    _writeDelta(buf, lat - prevLat);
    _writeDelta(buf, lng - prevLng);
    prevLat = lat;
    prevLng = lng;
  }
  return buf.toString();
}

List<LatLng> mergeEncodedShapes(Iterable<String> shapes, {int precision = 6}) {
  final out = <LatLng>[];
  for (final shape in shapes) {
    final decoded = decodePolyline(shape, precision: precision);
    if (decoded.isEmpty) continue;
    if (out.isEmpty) {
      out.addAll(decoded);
    } else {
      out.addAll(decoded.skip(1));
    }
  }
  return out;
}

double _factor(int precision) {
  var f = 1.0;
  for (var i = 0; i < precision; i++) {
    f *= 10;
  }
  return f;
}

({int value, int index}) _nextDelta(String encoded, int index) {
  var result = 0;
  var shift = 0;
  var b = 0;
  do {
    b = encoded.codeUnitAt(index++) - 63;
    result |= (b & 0x1f) << shift;
    shift += 5;
  } while (b >= 0x20);
  final delta = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
  return (value: delta, index: index);
}

void _writeDelta(StringBuffer buf, int value) {
  var v = value < 0 ? ~(value << 1) : (value << 1);
  while (v >= 0x20) {
    buf.writeCharCode((0x20 | (v & 0x1f)) + 63);
    v >>= 5;
  }
  buf.writeCharCode(v + 63);
}
