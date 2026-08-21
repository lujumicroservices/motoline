import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../l10n/l10n_ext.dart';
import '../../providers/ride_providers.dart';
import '../../theme/app_theme.dart';
import '../ride_detail/ride_detail_screen.dart';
import '../rodadas/rodada_providers.dart';
import 'reel_caption.dart';
import 'reel_composer.dart';
import 'reel_pauses.dart';
import 'reel_timeline.dart';

class ReelPreviewScreen extends ConsumerStatefulWidget {
  const ReelPreviewScreen({
    super.key,
    required this.rideId,
    required this.rodadaId,
    this.length = ReelLength.standard,
    this.pauses,
    this.selectedPhotoIds,
    this.replaceWithRideDetail = true,
  });

  final String rideId;
  final String rodadaId;
  final ReelLength length;
  final List<DetectedPause>? pauses;
  final List<String>? selectedPhotoIds;
  final bool replaceWithRideDetail;

  @override
  ConsumerState<ReelPreviewScreen> createState() => _ReelPreviewScreenState();
}

class _ReelPreviewScreenState extends ConsumerState<ReelPreviewScreen> {
  ReelRenderResult? _result;
  Object? _error;
  double _progress = 0;
  bool _busy = true;
  VideoPlayerController? _player;

  @override
  void initState() {
    super.initState();
    unawaited(_render());
  }

  @override
  void dispose() {
    unawaited(_player?.dispose());
    super.dispose();
  }

  Future<void> _render() async {
    setState(() {
      _busy = true;
      _error = null;
      _progress = 0;
    });
    await _player?.dispose();
    _player = null;
    if (!mounted) return;
    try {
      final composer = ReelComposer(
        db: ref.read(rideDatabaseProvider),
        rodadas: ref.read(rodadaRepositoryProvider),
      );
      final l10n = context.l10n;
      final result = await composer.render(
        rideId: widget.rideId,
        rodadaId: widget.rodadaId,
        l10n: l10n,
        length: widget.length,
        pauses: widget.pauses,
        selectedPhotoIds: widget.selectedPhotoIds,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      VideoPlayerController? player;
      if (result.videoPath != null) {
        player = VideoPlayerController.file(File(result.videoPath!));
        await player.initialize();
        await player.setLooping(true);
        await player.play();
      }
      if (!mounted) {
        await player?.dispose();
        return;
      }
      setState(() {
        _result = result;
        _player = player;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _busy = false;
      });
    }
  }

  Future<void> _share() async {
    final result = _result;
    if (result == null) return;
    final l10n = context.l10n;
    final caption = buildReelCaption(
      destination: result.highlights.destination,
      distanceKm: result.highlights.distanceKm,
      maxLeanDeg: result.highlights.maxLeanDeg,
      curveCount: result.highlights.curveCount,
      riderCount: result.highlights.riderCount,
      cta: l10n.reelCta,
    );
    await Clipboard.setData(ClipboardData(text: caption));
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(result.sharePath)],
        text: caption,
        subject: result.highlights.destination,
      ),
    );
    try {
      await ref.read(rodadaRepositoryProvider).uploadReel(
            rodadaId: widget.rodadaId,
            localPath: result.sharePath,
            durationMs: result.durationMs,
            hookKind: result.highlights.hookKind,
          );
    } catch (_) {}
  }

  void _done() {
    if (widget.replaceWithRideDetail) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => RideDetailScreen(rideId: widget.rideId),
        ),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: AppTheme.asphalt,
      appBar: AppBar(
        title: Text(l10n.reelTitle),
        automaticallyImplyLeading: !widget.replaceWithRideDetail,
        actions: [
          TextButton(
            onPressed: _done,
            child: Text(l10n.reelDone),
          ),
        ],
      ),
      body: _busy
          ? _Building(progress: _progress, label: l10n.reelBuilding)
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$_error', textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _render,
                          child: Text(l10n.reelRetry),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(child: _Preview(player: _player, result: _result)),
                    if (_result != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Text(
                          buildReelCaption(
                            destination: _result!.highlights.destination,
                            distanceKm: _result!.highlights.distanceKm,
                            maxLeanDeg: _result!.highlights.maxLeanDeg,
                            curveCount: _result!.highlights.curveCount,
                            riderCount: _result!.highlights.riderCount,
                            cta: l10n.reelCta,
                          ),
                          style: GoogleFonts.rajdhani(
                            color: AppTheme.steel,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _render,
                                child: Text(l10n.reelRetry),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: FilledButton.icon(
                                onPressed: _share,
                                icon: const Icon(Icons.ios_share),
                                label: Text(l10n.reelShare),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _Building extends StatelessWidget {
  const _Building({required this.progress, required this.label});

  final double progress;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: progress <= 0 ? null : progress),
            const SizedBox(height: 16),
            Text(
              label,
              style: GoogleFonts.exo2(color: AppTheme.mist),
            ),
          ],
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.player, required this.result});

  final VideoPlayerController? player;
  final ReelRenderResult? result;

  @override
  Widget build(BuildContext context) {
    final p = player;
    if (p != null && p.value.isInitialized) {
      return Center(
        child: AspectRatio(
          aspectRatio: p.value.aspectRatio,
          child: VideoPlayer(p),
        ),
      );
    }
    final image = result?.imagePath;
    if (image != null && File(image).existsSync()) {
      return Center(
        child: Image.file(File(image), fit: BoxFit.contain),
      );
    }
    return const SizedBox.shrink();
  }
}
