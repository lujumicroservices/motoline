import 'package:supabase_flutter/supabase_flutter.dart';

/// PostgREST silently caps each response (often 1000 rows). Page until done.
Future<List<Map<String, dynamic>>> pagedSelect({
  required SupabaseClient client,
  required String table,
  required String orderBy,
  String columns = '*',
  String? eqColumn,
  Object? eqValue,
  int pageSize = 1000,
}) async {
  final out = <Map<String, dynamic>>[];
  var from = 0;
  while (true) {
    var query = client.from(table).select(columns);
    if (eqColumn != null && eqValue != null) {
      query = query.eq(eqColumn, eqValue);
    }
    final rows = await query.order(orderBy).range(from, from + pageSize - 1);
    final page = (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    out.addAll(page);
    if (page.length < pageSize) break;
    from += pageSize;
    if (from > 250000) break;
  }
  return out;
}
