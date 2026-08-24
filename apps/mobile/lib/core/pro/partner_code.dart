/// Partner Pro codes (`PRO-7K4M2Q`), distinct from rodada join codes.
String normalizePartnerProCode(String raw) {
  var s = raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
  s = s.replaceAll(RegExp(r'[^A-Z0-9-]'), '');
  if (RegExp(r'^PRO-[A-Z0-9]{6}$').hasMatch(s)) return s;
  if (RegExp(r'^[A-Z0-9]{6}$').hasMatch(s)) return 'PRO-$s';
  return s;
}

bool isPartnerProCodeShape(String normalized) {
  return RegExp(r'^PRO-[A-Z0-9]{6}$').hasMatch(normalized);
}
