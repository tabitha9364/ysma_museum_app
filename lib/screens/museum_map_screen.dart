import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/artwork.dart';
import '../services/app_settings.dart';
import '../services/supabase_service.dart';
import '../services/voice_navigation_service.dart';
import '../utils/colors.dart';
import 'artwork_preview_screen.dart';

class MuseumMapScreen extends StatefulWidget {
  final Artwork? targetArtwork;

  const MuseumMapScreen({super.key, this.targetArtwork});

  @override
  State<MuseumMapScreen> createState() => _MuseumMapScreenState();
}

class _MuseumMapScreenState extends State<MuseumMapScreen>
    with SingleTickerProviderStateMixin {
  static const List<_MuseumZone> _zones = [
    _MuseumZone(
      name: 'Heritage Hall',
      subtitle: 'Masks, spirits and early cultural forms',
      mapPoint: Offset(0.235, 0.225),
      color: Color(0xFF45B6FE),
      icon: Icons.account_balance,
      routePoints: [
        Offset(0.50, 0.88),
        Offset(0.50, 0.68),
        Offset(0.40, 0.56),
        Offset(0.29, 0.45),
        Offset(0.235, 0.225),
      ],
      instruction:
          'Start at the entrance. Walk straight to the central aisle, turn left at the blue wall marker, then enter Heritage Hall.',
    ),
    _MuseumZone(
      name: 'Masters Gallery',
      subtitle: 'Paintings, colour and modern masters',
      mapPoint: Offset(0.56, 0.20),
      color: Color(0xFFFFC107),
      icon: Icons.palette_outlined,
      routePoints: [
        Offset(0.50, 0.88),
        Offset(0.50, 0.68),
        Offset(0.56, 0.50),
        Offset(0.56, 0.20),
      ],
      instruction:
          'Start at the entrance. Continue up the central aisle and keep slightly right. The Masters Gallery is the amber room ahead.',
    ),
    _MuseumZone(
      name: 'Sculpture Court',
      subtitle: 'Bronze, wood and three-dimensional works',
      mapPoint: Offset(0.825, 0.43),
      color: Color(0xFFFF5C8A),
      icon: Icons.view_in_ar_outlined,
      routePoints: [
        Offset(0.50, 0.88),
        Offset(0.50, 0.68),
        Offset(0.66, 0.56),
        Offset(0.825, 0.43),
      ],
      instruction:
          'Start at the entrance. Move through the central aisle, turn right after the amber gallery, and enter Sculpture Court.',
    ),
    _MuseumZone(
      name: 'Performance Wing',
      subtitle: 'Dance, music and living culture',
      mapPoint: Offset(0.25, 0.72),
      color: Color(0xFF4CD964),
      icon: Icons.music_note_outlined,
      routePoints: [
        Offset(0.50, 0.88),
        Offset(0.50, 0.76),
        Offset(0.38, 0.76),
        Offset(0.25, 0.72),
      ],
      instruction:
          'Start at the entrance. Take the left branch of the lower corridor. Performance Wing is beside the green marker.',
    ),
    _MuseumZone(
      name: 'Contemporary Wing',
      subtitle: 'Identity, memory and recent practice',
      mapPoint: Offset(0.74, 0.73),
      color: Color(0xFFA78BFA),
      icon: Icons.auto_awesome,
      routePoints: [
        Offset(0.50, 0.88),
        Offset(0.50, 0.76),
        Offset(0.62, 0.76),
        Offset(0.74, 0.73),
      ],
      instruction:
          'Start at the entrance. Walk forward, take the right branch of the lower corridor, then stop at the purple gallery marker.',
    ),
  ];

  late final AnimationController _routeController;

  List<Artwork> artworks = [];
  bool loading = true;
  int selectedZone = 1;
  Artwork? selectedArtwork;
  String? _lastAutoSpokenDestination;

  @override
  void initState() {
    super.initState();
    _routeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    unawaited(VoiceNavigationService.warmUp());
    loadArtworks();
  }

  @override
  void dispose() {
    _routeController.dispose();
    unawaited(VoiceNavigationService.stop());
    super.dispose();
  }

  Future<void> loadArtworks() async {
    try {
      final data = await SupabaseService.fetchArtworks();

      if (!mounted) return;

      setState(() {
        artworks = data;
        loading = false;
      });

      if (widget.targetArtwork != null) {
        _selectIncomingArtwork(widget.targetArtwork!);
      } else {
        _maybeAutoSpeakRoute();
      }
    } catch (error) {
      debugPrint('Map artworks failed: $error');

      if (!mounted) return;

      setState(() {
        loading = false;
      });
    }
  }

  void _selectIncomingArtwork(Artwork artwork) {
    final match = artworks.where((item) {
      return item.id == artwork.id ||
          _artworkKey(item.title) == _artworkKey(artwork.title);
    }).toList();

    _selectDestination(match.isEmpty ? artwork : match.first);
  }

  void _selectZone(int index) {
    setState(() {
      selectedZone = index;
      selectedArtwork = null;
    });

    _maybeAutoSpeakRoute();
  }

  void _selectDestination(Artwork artwork) {
    setState(() {
      selectedArtwork = artwork;
      selectedZone = _zoneIndexForArtwork(artwork);
    });

    _maybeAutoSpeakRoute();
  }

  int _zoneIndexForArtwork(Artwork artwork) {
    final text = '${artwork.title} ${artwork.artist} ${artwork.tag}'
        .toLowerCase()
        .replaceAll('_', ' ');

    if (text.contains('acrobat') ||
        text.contains('sculpt') ||
        text.contains('bronze') ||
        text.contains('nok') ||
        text.contains('wood')) {
      return 2;
    }

    if (text.contains('music') ||
        text.contains('dance') ||
        text.contains('drum') ||
        text.contains('goje') ||
        text.contains('ayan') ||
        text.contains('celebration')) {
      return 3;
    }

    if (text.contains('mask') ||
        text.contains('masquerade') ||
        text.contains('ancestral') ||
        text.contains('iwin') ||
        text.contains('yoruba') ||
        text.contains('agbom')) {
      return 0;
    }

    if (text.contains('mind') ||
        text.contains('comforter') ||
        text.contains('covid') ||
        text.contains('wonder') ||
        text.contains('veil') ||
        text.contains('legacy')) {
      return 4;
    }

    return 1;
  }

  List<Artwork> _zoneArtworks(int zoneIndex) {
    return [
      for (final artwork in artworks)
        if (_zoneIndexForArtwork(artwork) == zoneIndex) artwork,
    ];
  }

  Offset _artworkPoint(Artwork artwork) {
    final zone = _zones[_zoneIndexForArtwork(artwork)];
    final zoneWorks = _zoneArtworks(_zoneIndexForArtwork(artwork));
    final index = zoneWorks.indexWhere((item) => item.id == artwork.id);
    final safeIndex = index < 0 ? 0 : index;
    const offsets = [
      Offset(-0.055, -0.040),
      Offset(0.052, -0.035),
      Offset(-0.045, 0.046),
      Offset(0.046, 0.050),
      Offset(0.000, 0.000),
      Offset(-0.078, 0.005),
      Offset(0.078, 0.010),
    ];
    final offset = offsets[safeIndex % offsets.length];

    return Offset(
      (zone.mapPoint.dx + offset.dx).clamp(0.12, 0.88).toDouble(),
      (zone.mapPoint.dy + offset.dy).clamp(0.12, 0.86).toDouble(),
    );
  }

  List<Offset> _currentRoutePoints() {
    final zone = _zones[selectedZone];

    if (selectedArtwork == null) {
      return zone.routePoints;
    }

    return [
      ...zone.routePoints.take(zone.routePoints.length - 1),
      _artworkPoint(selectedArtwork!),
    ];
  }

  List<String> _routeSteps() {
    final zone = _zones[selectedZone];

    return [
      'Start at the entrance marker near the bottom of the map.',
      'Follow the highlighted route through the central aisle.',
      zone.instruction,
      if (selectedArtwork != null)
        'Stop at ${selectedArtwork!.title}; it is marked with the pulsing artwork pin.',
    ];
  }

  void _speakRoute({bool showMessage = true}) {
    final destination = selectedArtwork?.title ?? _zones[selectedZone].name;
    if (showMessage) {
      _showMessage('Voice navigation started.');
    }

    unawaited(
      VoiceNavigationService.speak(
        context,
        'Navigating to $destination. ${_routeSteps().join(' ')}',
      ),
    );
  }

  void _maybeAutoSpeakRoute() {
    if (!mounted || !context.read<AppSettings>().voiceNavigation) {
      return;
    }

    final destinationKey = selectedArtwork == null
        ? 'zone:$selectedZone'
        : 'artwork:${selectedArtwork!.id}:${selectedArtwork!.title}';

    if (_lastAutoSpokenDestination == destinationKey) {
      return;
    }

    _lastAutoSpokenDestination = destinationKey;
    _speakRoute(showMessage: false);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _zones[selectedZone];
    final selectedArtworks = _zoneArtworks(selectedZone);
    final routePoints = _currentRoutePoints();
    final voiceNavigationEnabled = context.watch<AppSettings>().voiceNavigation;

    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(context),
              const SizedBox(height: 14),
              Expanded(
                flex: 5,
                child: _mapSurface(
                  selected: selected,
                  routePoints: routePoints,
                ),
              ),
              const SizedBox(height: 12),
              _routePanel(selected, voiceNavigationEnabled),
              const SizedBox(height: 12),
              Expanded(
                flex: 4,
                child: loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : _destinationList(selectedArtworks),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back, color: AppColors.textFor(context)),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Museum Map',
              style: TextStyle(
                color: AppColors.textFor(context),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapSurface({
    required _MuseumZone selected,
    required List<Offset> routePoints,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardFor(context),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: selected.color.withValues(alpha: 0.20),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InteractiveViewer(
        minScale: 1,
        maxScale: 2.7,
        child: AnimatedBuilder(
          animation: _routeController,
          builder: (context, child) {
            return LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _NavigationMapPainter(
                          zones: _zones,
                          selectedZone: selectedZone,
                          routePoints: routePoints,
                          progress: _routeController.value,
                          isDark: AppColors.isDark(context),
                        ),
                      ),
                    ),
                    _entranceBadge(constraints.biggest),
                    for (var i = 0; i < _zones.length; i++)
                      _zonePin(i, constraints.biggest),
                    if (selectedArtwork != null)
                      _artworkPin(selectedArtwork!, constraints.biggest),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _entranceBadge(Size size) {
    return Positioned(
      left: (0.50 * size.width) - 52,
      bottom: 10,
      child: Container(
        width: 104,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.login, size: 15, color: Colors.black),
            SizedBox(width: 5),
            Text(
              'Entrance',
              style: TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _zonePin(int index, Size size) {
    final zone = _zones[index];
    final active = index == selectedZone;
    final pinSize = active ? 58.0 : 50.0;

    return Positioned(
      left: (zone.mapPoint.dx * size.width) - (pinSize / 2),
      top: (zone.mapPoint.dy * size.height) - (pinSize / 2),
      child: GestureDetector(
        onTap: () => _selectZone(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: pinSize,
          height: pinSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? zone.color : AppColors.surfaceFor(context),
            shape: BoxShape.circle,
            border: Border.all(color: zone.color, width: active ? 3 : 2),
            boxShadow: [
              BoxShadow(
                color: zone.color.withValues(alpha: active ? 0.46 : 0.22),
                blurRadius: active ? 24 : 14,
                spreadRadius: active ? 3 : 0,
              ),
            ],
          ),
          child: Icon(
            zone.icon,
            color: active ? Colors.black : zone.color,
            size: active ? 27 : 23,
          ),
        ),
      ),
    );
  }

  Widget _artworkPin(Artwork artwork, Size size) {
    final point = _artworkPoint(artwork);
    final pulse =
        0.86 + (math.sin(_routeController.value * math.pi * 2) * 0.10);

    return Positioned(
      left: (point.dx * size.width) - 29,
      top: (point.dy * size.height) - 29,
      child: Transform.scale(
        scale: pulse,
        child: Container(
          width: 58,
          height: 58,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.50),
                blurRadius: 22,
                spreadRadius: 4,
              ),
            ],
          ),
          child: ClipOval(
            child: CachedNetworkImage(
              imageUrl: artwork.imageUrl,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) =>
                  const Icon(Icons.image_not_supported, color: Colors.black),
            ),
          ),
        ),
      ),
    );
  }

  Widget _routePanel(_MuseumZone selected, bool voiceNavigationEnabled) {
    final destination = selectedArtwork?.title ?? selected.name;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardFor(context),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: selected.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(selected.icon, color: selected.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      destination,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textFor(context),
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      selected.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.mutedTextFor(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => _speakRoute(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.record_voice_over, size: 17),
                label: Text(
                  voiceNavigationEnabled ? 'Repeat' : 'Voice',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _routeMetric(Icons.route, 'Route', 'Entrance to gallery'),
              const SizedBox(width: 8),
              _routeMetric(Icons.directions_walk, 'Walk', '1-3 min'),
              const SizedBox(width: 8),
              _routeMetric(Icons.accessible_forward, 'Access', 'Step-free'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _routeMetric(IconData icon, String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceFor(context),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.subtleTextFor(context),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textFor(context),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
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

  Widget _destinationList(List<Artwork> selectedArtworks) {
    if (artworks.isEmpty) {
      return Center(
        child: Text(
          'Artwork destinations could not be loaded.',
          style: TextStyle(color: AppColors.mutedTextFor(context)),
        ),
      );
    }

    if (selectedArtworks.isEmpty) {
      return Center(
        child: Text(
          'No artworks assigned to this gallery yet.',
          style: TextStyle(color: AppColors.mutedTextFor(context)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose a destination',
          style: TextStyle(
            color: AppColors.textFor(context),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            itemCount: selectedArtworks.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final artwork = selectedArtworks[index];
              final active = selectedArtwork?.id == artwork.id;

              return ListTile(
                onTap: () => _selectDestination(artwork),
                onLongPress: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ArtworkPreviewScreen(artwork: artwork),
                    ),
                  );
                },
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                tileColor: active
                    ? AppColors.primary.withValues(alpha: 0.18)
                    : AppColors.surfaceFor(context),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: artwork.imageUrl,
                    width: 54,
                    height: 54,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => Container(
                      width: 54,
                      height: 54,
                      color: AppColors.cardFor(context),
                      child: Icon(
                        Icons.image_not_supported,
                        color: AppColors.mutedTextFor(context),
                      ),
                    ),
                  ),
                ),
                title: Text(
                  artwork.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textFor(context),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  '${artwork.artist} - ${_zones[_zoneIndexForArtwork(artwork)].name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.mutedTextFor(context),
                    fontSize: 12,
                  ),
                ),
                trailing: IconButton(
                  tooltip: 'Open artwork',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ArtworkPreviewScreen(artwork: artwork),
                      ),
                    );
                  },
                  icon: Icon(
                    active ? Icons.near_me : Icons.arrow_forward_ios,
                    color: active
                        ? AppColors.primary
                        : AppColors.mutedTextFor(context),
                    size: active ? 22 : 16,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _artworkKey(String value) {
    return value
        .toLowerCase()
        .replaceAll('&', 'and')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }
}

class _MuseumZone {
  final String name;
  final String subtitle;
  final Offset mapPoint;
  final Color color;
  final IconData icon;
  final List<Offset> routePoints;
  final String instruction;

  const _MuseumZone({
    required this.name,
    required this.subtitle,
    required this.mapPoint,
    required this.color,
    required this.icon,
    required this.routePoints,
    required this.instruction,
  });
}

class _NavigationMapPainter extends CustomPainter {
  final List<_MuseumZone> zones;
  final int selectedZone;
  final List<Offset> routePoints;
  final double progress;
  final bool isDark;

  const _NavigationMapPainter({
    required this.zones,
    required this.selectedZone,
    required this.routePoints,
    required this.progress,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawFloor(canvas, size);
    _drawCorridors(canvas, size);
    _drawRooms(canvas, size);
    _drawRoute(canvas, size);
  }

  void _drawFloor(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final floorPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? const [Color(0xFF0A2036), Color(0xFF152C43), Color(0xFF0D1D31)]
            : const [Color(0xFFF8FAFC), Color(0xFFE2E8F0), Color(0xFFF1F5F9)],
      ).createShader(rect);

    canvas.drawRect(rect, floorPaint);

    final gridPaint = Paint()
      ..color = isDark ? Colors.white10 : Colors.black12
      ..strokeWidth = 1;

    for (var x = size.width * 0.10; x < size.width; x += size.width * 0.10) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    for (var y = size.height * 0.10; y < size.height; y += size.height * 0.10) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  void _drawCorridors(Canvas canvas, Size size) {
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: isDark ? 0.34 : 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 38
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final corridorPaint = Paint()
      ..color = isDark ? const Color(0xFF223B55) : const Color(0xFFDCE6F1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 32
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final corridorLinePaint = Paint()
      ..color = isDark ? Colors.white24 : const Color(0xFF94A3B8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(size.width * 0.50, size.height * 0.88)
      ..lineTo(size.width * 0.50, size.height * 0.68)
      ..lineTo(size.width * 0.56, size.height * 0.50)
      ..lineTo(size.width * 0.56, size.height * 0.20)
      ..moveTo(size.width * 0.50, size.height * 0.68)
      ..lineTo(size.width * 0.40, size.height * 0.56)
      ..lineTo(size.width * 0.29, size.height * 0.45)
      ..lineTo(size.width * 0.22, size.height * 0.27)
      ..moveTo(size.width * 0.56, size.height * 0.50)
      ..lineTo(size.width * 0.66, size.height * 0.56)
      ..lineTo(size.width * 0.80, size.height * 0.40)
      ..moveTo(size.width * 0.50, size.height * 0.76)
      ..lineTo(size.width * 0.38, size.height * 0.76)
      ..lineTo(size.width * 0.25, size.height * 0.72)
      ..moveTo(size.width * 0.50, size.height * 0.76)
      ..lineTo(size.width * 0.62, size.height * 0.76)
      ..lineTo(size.width * 0.74, size.height * 0.73);

    canvas.drawPath(path.shift(const Offset(0, 5)), shadowPaint);
    canvas.drawPath(path, corridorPaint);
    canvas.drawPath(path, corridorLinePaint);
  }

  void _drawRooms(Canvas canvas, Size size) {
    final roomData = [
      _RoomSpec(
        rect: Rect.fromLTWH(
          size.width * 0.08,
          size.height * 0.10,
          size.width * 0.31,
          size.height * 0.25,
        ),
        zoneIndex: 0,
      ),
      _RoomSpec(
        rect: Rect.fromLTWH(
          size.width * 0.42,
          size.height * 0.06,
          size.width * 0.32,
          size.height * 0.27,
        ),
        zoneIndex: 1,
      ),
      _RoomSpec(
        rect: Rect.fromLTWH(
          size.width * 0.70,
          size.height * 0.31,
          size.width * 0.25,
          size.height * 0.24,
        ),
        zoneIndex: 2,
      ),
      _RoomSpec(
        rect: Rect.fromLTWH(
          size.width * 0.10,
          size.height * 0.61,
          size.width * 0.32,
          size.height * 0.24,
        ),
        zoneIndex: 3,
      ),
      _RoomSpec(
        rect: Rect.fromLTWH(
          size.width * 0.58,
          size.height * 0.62,
          size.width * 0.35,
          size.height * 0.23,
        ),
        zoneIndex: 4,
      ),
    ];

    for (final room in roomData) {
      final zone = zones[room.zoneIndex];
      final active = room.zoneIndex == selectedZone;
      final rrect = RRect.fromRectAndRadius(
        room.rect,
        const Radius.circular(28),
      );
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: isDark ? 0.34 : 0.13)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      final roomPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            zone.color.withValues(alpha: active ? 0.42 : 0.18),
            isDark ? const Color(0xFF182A3D) : Colors.white,
          ],
        ).createShader(room.rect);
      final borderPaint = Paint()
        ..color = active
            ? zone.color.withValues(alpha: 0.95)
            : (isDark ? Colors.white24 : const Color(0xFFCBD5E1))
        ..style = PaintingStyle.stroke
        ..strokeWidth = active ? 3 : 1.4;

      canvas.drawRRect(rrect.shift(const Offset(0, 8)), shadowPaint);
      canvas.drawRRect(rrect, roomPaint);
      canvas.drawRRect(rrect, borderPaint);
    }
  }

  void _drawRoute(Canvas canvas, Size size) {
    if (routePoints.length < 2) return;

    final selected = zones[selectedZone];
    final path = Path();
    final resolvedPoints = routePoints
        .map((point) => _resolve(point, size))
        .toList();

    path.moveTo(resolvedPoints.first.dx, resolvedPoints.first.dy);

    for (final point in resolvedPoints.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final routePaint = Paint()
      ..color = selected.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final innerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path.shift(const Offset(0, 5)), shadowPaint);
    canvas.drawPath(path, routePaint);
    canvas.drawPath(path, innerPaint);

    for (final point in resolvedPoints) {
      final stopPaint = Paint()..color = Colors.white;
      final borderPaint = Paint()
        ..color = selected.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;

      canvas.drawCircle(point, 8, stopPaint);
      canvas.drawCircle(point, 8, borderPaint);
    }

    final dot = _movingPoint(resolvedPoints);
    final pulsePaint = Paint()
      ..color = selected.color.withValues(
        alpha: 0.24 + (0.18 * math.sin(progress * math.pi * 2).abs()),
      );
    final dotPaint = Paint()..color = Colors.black;

    canvas.drawCircle(dot, 19, pulsePaint);
    canvas.drawCircle(dot, 9, Paint()..color = selected.color);
    canvas.drawCircle(dot, 4, dotPaint);
  }

  Offset _movingPoint(List<Offset> points) {
    final segmentCount = points.length - 1;
    final exact = (progress * segmentCount)
        .clamp(0, segmentCount.toDouble())
        .toDouble();
    final segment = exact.floor().clamp(0, segmentCount - 1).toInt();
    final local = exact - segment;

    return Offset.lerp(
          points[segment],
          points[segment + 1],
          local.toDouble(),
        ) ??
        points.last;
  }

  Offset _resolve(Offset point, Size size) {
    return Offset(point.dx * size.width, point.dy * size.height);
  }

  @override
  bool shouldRepaint(covariant _NavigationMapPainter oldDelegate) {
    return oldDelegate.selectedZone != selectedZone ||
        oldDelegate.progress != progress ||
        oldDelegate.isDark != isDark ||
        oldDelegate.routePoints != routePoints;
  }
}

class _RoomSpec {
  final Rect rect;
  final int zoneIndex;

  const _RoomSpec({required this.rect, required this.zoneIndex});
}
