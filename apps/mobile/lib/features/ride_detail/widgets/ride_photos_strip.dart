import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/ride_photo.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/ride_providers.dart';
import '../../../theme/app_theme.dart';

class RidePhotosStrip extends ConsumerWidget {
  const RidePhotosStrip({super.key, required this.rideId});

  final String rideId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ridePhotosProvider(rideId));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (photos) {
        final files = photos
            .where((p) => p.localPath != null && File(p.localPath!).existsSync())
            .toList();
        if (files.isEmpty) return const SizedBox.shrink();
        final l10n = context.l10n;
        return Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.ridePhotosTitle,
                style: GoogleFonts.exo2(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 88,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: files.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final photo = files[i];
                    return GestureDetector(
                      onTap: () => _open(context, photo),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(photo.localPath!),
                          width: 88,
                          height: 88,
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _open(BuildContext context, RidePhoto photo) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: AppTheme.asphalt,
          appBar: AppBar(title: Text(context.l10n.photoTitle)),
          body: Center(
            child: Image.file(File(photo.localPath!), fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
