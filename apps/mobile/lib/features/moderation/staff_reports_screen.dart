import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n_ext.dart';
import '../../theme/app_theme.dart';
import '../rodadas/rodada_providers.dart';
import 'content_moderation_providers.dart';

class StaffReportsScreen extends ConsumerWidget {
  const StaffReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(staffContentReportsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.ugcStaffQueueTitle),
        actions: [
          IconButton(
            tooltip: l10n.ugcStaffRefresh,
            onPressed: () => ref.invalidate(staffContentReportsProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(child: Text(l10n.ugcStaffQueueEmpty));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final r = list[i];
              final when =
                  DateFormat('d MMM · HH:mm').format(r.createdAt.toLocal());
              return Material(
                color: AppTheme.asphaltElevated,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${r.kind} · ${r.reason} · ${r.status}',
                        style: GoogleFonts.exo2(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.ugcStaffTarget(r.targetName, r.reporterName, when),
                        style: GoogleFonts.rajdhani(
                          color: AppTheme.steel,
                          fontSize: 13,
                        ),
                      ),
                      if (r.messageBody != null &&
                          r.messageBody!.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          r.messageBody!,
                          style: GoogleFonts.rajdhani(fontSize: 15),
                        ),
                      ],
                      if (r.photoPath != null && r.photoPath!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _StaffReportedPhoto(path: r.photoPath!),
                      ],
                      if (r.targetBanned)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            l10n.ugcStaffAlreadyBanned,
                            style: GoogleFonts.rajdhani(
                              color: AppTheme.signal,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      if (r.isOpen) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: () => _act(context, ref, r.id, 'dismiss'),
                              child: Text(l10n.ugcStaffDismiss),
                            ),
                            FilledButton.tonal(
                              onPressed: () => _act(context, ref, r.id, 'hide'),
                              child: Text(l10n.ugcStaffHide),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.signal,
                              ),
                              onPressed: () => _act(context, ref, r.id, 'ban'),
                              child: Text(l10n.ugcStaffBan),
                            ),
                          ],
                        ),
                      ],
                      if (r.targetBanned)
                        TextButton(
                          onPressed: () async {
                            try {
                              await ref
                                  .read(contentModerationRepositoryProvider)
                                  .unbanUser(r.targetUserId);
                              ref.invalidate(staffContentReportsProvider);
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$e')),
                              );
                            }
                          },
                          child: Text(l10n.ugcStaffUnban),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    String reportId,
    String action,
  ) async {
    final l10n = context.l10n;
    try {
      await ref.read(contentModerationRepositoryProvider).resolveReport(
            reportId: reportId,
            action: action,
          );
      ref.invalidate(staffContentReportsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.ugcStaffDone)),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

class _StaffReportedPhoto extends ConsumerWidget {
  const _StaffReportedPhoto({required this.path});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(rodadaPhotoUrlProvider(path));
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: url.when(
        loading: () => Container(
          height: 140,
          color: AppTheme.asphalt,
          child: const Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Text('$e'),
        data: (u) => Image.network(
          u,
          height: 180,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
