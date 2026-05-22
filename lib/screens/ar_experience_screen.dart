import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/artwork.dart';
import '../utils/colors.dart';
import 'artwork_detail_screen.dart';

class ARExperienceScreen extends StatefulWidget {
  final Artwork artwork;

  const ARExperienceScreen({
    super.key,
    required this.artwork,
  });

  @override
  State<ARExperienceScreen> createState() => _ARExperienceScreenState();
}

class _ARExperienceScreenState extends State<ARExperienceScreen>
    with TickerProviderStateMixin {
  late final AnimationController loopController;
  late final AnimationController revealController;
  Timer? revealDelayTimer;

  @override
  void initState() {
    super.initState();
    loopController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
    revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    revealDelayTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        revealController.forward();
      }
    });

    HapticFeedback.lightImpact();
  }

  @override
  void dispose() {
    revealDelayTimer?.cancel();
    loopController.dispose();
    revealController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final artwork = widget.artwork;

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: Listenable.merge([loopController, revealController]),
        builder: (context, child) {
          final progress = loopController.value;
          final reveal = Curves.easeOutCubic.transform(revealController.value);

          return LayoutBuilder(
            builder: (context, constraints) {
              final compactHeight = constraints.maxHeight < 720;
              final imageWidth =
                  math.min(constraints.maxWidth * 0.72, 310).toDouble();
              final imageHeight = imageWidth * 1.28;

              return Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0, -0.28),
                          radius: 1.08,
                          colors: [
                            const Color(0xFF233B56),
                            AppColors.background,
                            Colors.black,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _ARAtmospherePainter(progress: progress),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Expanded(
                            child: Text(
                              'Artwork AR',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Open information',
                            onPressed: () => _openDetail(0),
                            icon: const Icon(
                              Icons.info_outline,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: compactHeight ? 76 : 92,
                    left: 16,
                    right: 16,
                    child: Opacity(
                      opacity: reveal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _hudChip(
                            icon: Icons.auto_awesome,
                            label: 'MATCH LOCKED',
                            value: artwork.tag.isEmpty
                                ? 'Collection'
                                : artwork.tag,
                            color: AppColors.primary,
                          ),
                          _hudChip(
                            icon: Icons.place_outlined,
                            label: 'ZONE',
                            value: artwork.location.isEmpty
                                ? 'Gallery'
                                : artwork.location,
                            color: const Color(0xFF45B6FE),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned.fill(
                    top: compactHeight ? 126 : 148,
                    bottom: compactHeight ? 196 : 222,
                    child: Center(
                      child: Transform.translate(
                        offset: Offset(0, 24 * (1 - reveal)),
                        child: Transform.scale(
                          scale: 0.88 + (reveal * 0.12),
                          child: Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001)
                              ..rotateX(-0.05)
                              ..rotateY(math.sin(progress * math.pi * 2) * 0.04),
                            child: SizedBox(
                              width: imageWidth,
                              height: imageHeight,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _HologramFramePainter(
                                        progress: progress,
                                      ),
                                    ),
                                  ),
                                  Positioned.fill(
                                    child: Padding(
                                      padding: const EdgeInsets.all(22),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(24),
                                        child: CachedNetworkImage(
                                          imageUrl: artwork.imageUrl,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) =>
                                              Container(
                                            color: Colors.white10,
                                            child: const Center(
                                              child: CircularProgressIndicator(
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ),
                                          errorWidget: (context, url, error) =>
                                              Container(
                                            color: Colors.white10,
                                            child: const Icon(
                                              Icons.image_not_supported,
                                              color: Colors.white54,
                                              size: 42,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 34,
                                    right: 34,
                                    bottom: 34,
                                    child: _glassLabel(
                                      title: artwork.title,
                                      subtitle: _subtitle(artwork),
                                    ),
                                  ),
                                  Positioned(
                                    top: imageHeight * 0.24,
                                    right: -18,
                                    child: _miniBeacon(
                                      progress: progress,
                                      label: artwork.year.isEmpty
                                          ? 'Date unknown'
                                          : artwork.year,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Transform.translate(
                      offset: Offset(0, 28 * (1 - reveal)),
                      child: Opacity(
                        opacity: reveal,
                        child: _storyPanel(artwork),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _hudChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Flexible(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 166),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.34),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.56)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.26),
              blurRadius: 22,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glassLabel({
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniBeacon({
    required double progress,
    required String label,
  }) {
    final scale = 1 + (math.sin(progress * math.pi * 2) * 0.08);

    return Transform.scale(
      scale: scale,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.45),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _storyPanel(Artwork artwork) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF13283E).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.view_in_ar,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      artwork.artist.isEmpty ? 'YSMA Collection' : artwork.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Live overlay generated from this artwork',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            artwork.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              height: 1.35,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _panelButton(
                  icon: Icons.menu_book,
                  label: 'Read story',
                  onTap: () => _openDetail(0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _panelButton(
                  icon: Icons.volume_up,
                  label: 'Audio guide',
                  onTap: () => _openDetail(1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _panelButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primary, size: 18),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetail(int tab) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArtworkDetailScreen(
          artwork: widget.artwork,
          initialTab: tab,
        ),
      ),
    );
  }

  String _subtitle(Artwork artwork) {
    final parts = [
      if (artwork.artist.trim().isNotEmpty) artwork.artist.trim(),
      if (artwork.year.trim().isNotEmpty) artwork.year.trim(),
    ];

    if (parts.isEmpty) {
      return 'YSMA Museum';
    }

    return parts.join(' - ');
  }
}

class _ARAtmospherePainter extends CustomPainter {
  final double progress;

  const _ARAtmospherePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.055)
      ..strokeWidth = 1;
    final amberPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final horizon = size.height * (0.54 + math.sin(progress * math.pi * 2) * 0.01);

    for (var i = 0; i < 12; i++) {
      final y = horizon + (i * i * 4.2);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (var i = -8; i <= 8; i++) {
      final x = size.width / 2 + (i * size.width * 0.08);
      canvas.drawLine(
        Offset(size.width / 2, horizon),
        Offset(x, size.height),
        gridPaint,
      );
    }

    final ringCenter = Offset(size.width / 2, size.height * 0.45);
    for (var i = 0; i < 4; i++) {
      final radius = size.width * (0.24 + i * 0.12) +
          (math.sin(progress * math.pi * 2 + i) * 5);
      canvas.drawCircle(ringCenter, radius, amberPaint);
    }

    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.22);
    for (var i = 0; i < 26; i++) {
      final phase = progress * math.pi * 2 + i * 0.9;
      final x = (size.width * (0.08 + ((i * 37) % 84) / 100)) +
          math.sin(phase) * 8;
      final y = (size.height * (0.12 + ((i * 23) % 70) / 100)) +
          math.cos(phase * 0.8) * 10;
      canvas.drawCircle(Offset(x, y), 1.2 + (i % 3) * 0.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ARAtmospherePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _HologramFramePainter extends CustomPainter {
  final double progress;

  const _HologramFramePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final glowPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    final framePaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.86)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final cyanPaint = Paint()
      ..color = const Color(0xFF45B6FE).withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final rrect = RRect.fromRectAndRadius(
      rect.deflate(12),
      const Radius.circular(30),
    );
    canvas.drawRRect(rrect, glowPaint);
    canvas.drawRRect(rrect, framePaint);

    final corner = size.width * 0.16;
    final inset = 10.0;

    void cornerBracket(Offset start, bool flipX, bool flipY) {
      final xDir = flipX ? -1.0 : 1.0;
      final yDir = flipY ? -1.0 : 1.0;
      canvas.drawLine(
        start,
        start + Offset(corner * xDir, 0),
        framePaint,
      );
      canvas.drawLine(
        start,
        start + Offset(0, corner * yDir),
        framePaint,
      );
    }

    cornerBracket(Offset(inset, inset), false, false);
    cornerBracket(Offset(size.width - inset, inset), true, false);
    cornerBracket(Offset(inset, size.height - inset), false, true);
    cornerBracket(Offset(size.width - inset, size.height - inset), true, true);

    final scanY = 24 + ((size.height - 48) * progress);
    final scanPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          AppColors.primary.withValues(alpha: 0.95),
          const Color(0xFF45B6FE).withValues(alpha: 0.85),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, scanY - 10, size.width, 20));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(24, scanY, size.width - 48, 4),
        const Radius.circular(20),
      ),
      scanPaint,
    );

    for (var i = 0; i < 7; i++) {
      final y = 34 + i * ((size.height - 68) / 6);
      canvas.drawLine(
        Offset(26, y),
        Offset(size.width - 26, y),
        cyanPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HologramFramePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
