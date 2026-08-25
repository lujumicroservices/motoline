import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_bootstrap.dart';

class ContentReport {
  const ContentReport({
    required this.id,
    required this.kind,
    required this.reason,
    required this.status,
    required this.createdAt,
    required this.reporterId,
    required this.reporterName,
    required this.targetUserId,
    required this.targetName,
    required this.targetBanned,
    required this.rodadaId,
    this.details,
    this.messageId,
    this.photoId,
    this.messageBody,
    this.photoPath,
  });

  final String id;
  final String kind;
  final String reason;
  final String? details;
  final String status;
  final DateTime createdAt;
  final String reporterId;
  final String reporterName;
  final String targetUserId;
  final String targetName;
  final bool targetBanned;
  final String rodadaId;
  final String? messageId;
  final String? photoId;
  final String? messageBody;
  final String? photoPath;

  bool get isPhoto => kind == 'photo';
  bool get isOpen => status == 'open';

  factory ContentReport.fromMap(Map<String, dynamic> map) {
    return ContentReport(
      id: map['id'] as String,
      kind: map['kind'] as String? ?? '',
      reason: map['reason'] as String? ?? 'other',
      details: map['details'] as String?,
      status: map['status'] as String? ?? 'open',
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now().toUtc(),
      reporterId: map['reporter_id'] as String? ?? '',
      reporterName: map['reporter_name'] as String? ?? '',
      targetUserId: map['target_user_id'] as String? ?? '',
      targetName: map['target_name'] as String? ?? '',
      targetBanned: map['target_banned'] == true,
      rodadaId: map['rodada_id'] as String? ?? '',
      messageId: map['message_id'] as String?,
      photoId: map['photo_id'] as String?,
      messageBody: map['message_body'] as String?,
      photoPath: map['photo_path'] as String?,
    );
  }
}

class ContentModerationRepository {
  ContentModerationRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  static const guidelinesPrefKey = 'ugc_guidelines_accepted_v1';

  SupabaseClient get _supabase => _client ?? SupabaseBootstrap.client;

  static Future<bool> hasAcceptedGuidelines() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(guidelinesPrefKey) ?? false;
  }

  static Future<void> acceptGuidelines() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(guidelinesPrefKey, true);
  }

  Future<void> report({
    required String kind,
    String? messageId,
    String? photoId,
    required String reason,
    String? details,
  }) async {
    if (!SupabaseBootstrap.isReady) {
      throw StateError('Cloud not configured');
    }
    final data = await _supabase.rpc(
      'report_rodada_content',
      params: {
        'p_kind': kind,
        'p_message_id': messageId,
        'p_photo_id': photoId,
        'p_reason': reason,
        'p_details': details,
      },
    );
    _throwIfRpcFailed(data);
  }

  Future<List<ContentReport>> listStaffReports({String status = 'open'}) async {
    if (!SupabaseBootstrap.isReady) return const [];
    final rows = await _supabase.rpc(
      'staff_list_content_reports',
      params: {'p_status': status},
    );
    return (rows as List)
        .map((e) => ContentReport.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> resolveReport({
    required String reportId,
    required String action,
  }) async {
    final data = await _supabase.rpc(
      'staff_resolve_report',
      params: {
        'p_report_id': reportId,
        'p_action': action,
      },
    );
    _throwIfRpcFailed(data);
  }

  Future<void> unbanUser(String userId) async {
    final data = await _supabase.rpc(
      'staff_unban_user',
      params: {'p_user_id': userId},
    );
    _throwIfRpcFailed(data);
  }

  void _throwIfRpcFailed(dynamic data) {
    if (data is Map && data['ok'] == false) {
      throw StateError('${data['error'] ?? 'error'}');
    }
  }
}

bool isUgcBannedError(Object e) {
  final text = '$e'.toLowerCase();
  return text.contains('ugc_banned');
}
