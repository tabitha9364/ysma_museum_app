import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../models/artwork.dart';
import 'artwork_preview_screen.dart';

String _artworkMatchKey(String value) {
  final normalized = value
      .toLowerCase()
      .trim()
      .replaceFirst(RegExp(r'^\d+\s+'), '')
      .replaceAll('&', 'and')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '');

  const aliases = {
    'ayan': 'ayangodofmusic',
    'ijoafricandances': 'ijoafricadances',
    'ola14': 'olai4',
    'theadanmamasqeurade': 'theadanmamasquerade',
    'theladywiththescarf': 'theladywithscarf',
  };

  return aliases[normalized] ?? normalized;
}

const double _minimumPredictionConfidence = 0.97;
const double _minimumPredictionGap = 0.38;
const double _minimumPredictionAgreement = 0.75;
const double _minimumUnknownMargin = 0.58;
const double _minimumSceneQuality = 0.26;
const int _requiredStableMatches = 2;
const Duration _stableMatchWindow = Duration(seconds: 8);
const Duration _successAnimationDuration = Duration(milliseconds: 1850);
const Duration _successOverlayHoldDuration = Duration(milliseconds: 2550);

class ScanScreen extends StatefulWidget {
  final List<Artwork> artworks;

  const ScanScreen({super.key, required this.artworks});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with TickerProviderStateMixin {
  CameraController? controller;

  bool isCameraReady = false;

  bool isDetecting = false;
  bool showSuccessOverlay = false;
  Artwork? detectedArtwork;
  String scanStatus = 'Align an artwork inside the frame';
  Timer? autoDetectTimer;
  String? _stablePredictionKey;
  int _stablePredictionCount = 0;
  DateTime? _lastStablePredictionAt;

  late AnimationController scanController;
  late AnimationController successController;

  @override
  void initState() {
    super.initState();

    initializeCamera();

    scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    successController = AnimationController(
      vsync: this,
      duration: _successAnimationDuration,
    );
  }

  // INITIALIZE CAMERA
  Future<void> initializeCamera() async {
    final cameras = await availableCameras();

    final backCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    controller = CameraController(
      backCamera,
      ResolutionPreset.low,
      enableAudio: false,
    );

    await controller!.initialize();

    if (!mounted) return;

    setState(() {
      isCameraReady = true;
    });

    _startAutoDetection();
  }

  // REAL AI DETECTION
  void _startAutoDetection() {
    autoDetectTimer?.cancel();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted || !isCameraReady || isDetecting || showSuccessOverlay) {
        return;
      }

      unawaited(detectArtwork(showFeedback: false));
    });

    autoDetectTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted || !isCameraReady || isDetecting || showSuccessOverlay) {
        return;
      }

      unawaited(detectArtwork(showFeedback: false));
    });
  }

  void _setScanStatus(String status) {
    if (!mounted) {
      return;
    }

    setState(() {
      scanStatus = status;
    });
  }

  Future<void> detectArtwork({bool showFeedback = true}) async {
    if (isDetecting) return;

    if (controller == null || !controller!.value.isInitialized) {
      return;
    }

    setState(() {
      isDetecting = true;
      scanStatus = 'Scanning...';
    });

    try {
      // TAKE PICTURE
      final image = await controller!.takePicture();

      // IMAGE BYTES
      final bytes = await image.readAsBytes();

      // AI PREDICTION
      final result = await artworkService.predictWithConfidence(bytes);
      final prediction = result.label;

      debugPrint("AI Prediction: $prediction");
      debugPrint("AI Confidence: ${result.confidence}");
      debugPrint(
        "AI Confidence Gap: ${result.confidence - result.secondConfidence}",
      );
      debugPrint(
        "AI Unknown Margin: ${result.confidence - result.unknownConfidence}",
      );
      debugPrint("AI Crop Agreement: ${result.agreement}");
      debugPrint("AI Scene Quality: ${result.sceneQuality}");
      debugPrint("AI Top Predictions: ${result.topLabels.join(', ')}");
      debugPrint("AI Prediction Key: ${_artworkMatchKey(prediction)}");
      debugPrint("Artwork candidates loaded: ${widget.artworks.length}");

      if (widget.artworks.isEmpty) {
        if (!mounted) return;

        if (showFeedback) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Artwork data is still loading. Go back and try again.",
              ),
            ),
          );
        } else {
          _setScanStatus('Artwork data is still loading...');
        }

        setState(() {
          isDetecting = false;
        });

        return;
      }

      // FIND MATCHING ARTWORK
      final confidenceGap = result.confidence - result.secondConfidence;
      final predictedKey = _artworkMatchKey(prediction);

      if (result.isUnknown ||
          predictedKey == 'unknown' ||
          result.confidence < _minimumPredictionConfidence ||
          confidenceGap < _minimumPredictionGap ||
          result.agreement < _minimumPredictionAgreement ||
          result.confidence - result.unknownConfidence <
              _minimumUnknownMargin ||
          result.sceneQuality < _minimumSceneQuality) {
        if (!mounted) return;

        _resetStablePrediction();

        if (showFeedback) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Artwork not recognized. Please scan again."),
            ),
          );
        } else {
          _setScanStatus(
            'Artwork not recognized. Keep scanning a museum artwork.',
          );
        }

        setState(() {
          isDetecting = false;
        });

        return;
      }

      final matchingArtworks = widget.artworks
          .where((artwork) => _artworkMatchKey(artwork.title) == predictedKey)
          .toList();

      // NO MATCH FOUND
      if (matchingArtworks.isEmpty) {
        debugPrint("No artwork title matched '$prediction'.");
        debugPrint(
          "Available titles: ${widget.artworks.map((artwork) => artwork.title).join(', ')}",
        );

        if (!mounted) return;

        _resetStablePrediction();

        if (showFeedback) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Artwork not recognized: $prediction")),
          );
        } else {
          _setScanStatus('Artwork not recognized yet.');
        }

        setState(() {
          isDetecting = false;
        });

        return;
      }

      // MATCH FOUND
      final matchedArtwork = matchingArtworks.first;

      if (!mounted) return;

      if (!_confirmStablePrediction(predictedKey)) {
        final remaining = _requiredStableMatches - _stablePredictionCount;

        if (showFeedback) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Hold steady on ${matchedArtwork.title}. Confirming artwork...",
              ),
            ),
          );
        } else {
          _setScanStatus(
            remaining <= 1
                ? 'Hold steady. Confirming ${matchedArtwork.title}...'
                : 'Keep the artwork centered for confirmation.',
          );
        }

        setState(() {
          isDetecting = false;
        });

        return;
      }

      // OPEN DETAILS SCREEN
      await showDetectionSuccess(matchedArtwork);
      return;
    } catch (e) {
      debugPrint(e.toString());

      if (!mounted) return;

      if (showFeedback) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Detection failed: $e")));
      } else {
        _setScanStatus('Keep the camera steady and try again.');
      }
    }

    if (!mounted) return;

    setState(() {
      isDetecting = false;
    });
  }

  bool _confirmStablePrediction(String predictionKey) {
    final now = DateTime.now();
    final recent = _lastStablePredictionAt == null
        ? false
        : now.difference(_lastStablePredictionAt!) <= _stableMatchWindow;

    if (_stablePredictionKey == predictionKey && recent) {
      _stablePredictionCount++;
    } else {
      _stablePredictionKey = predictionKey;
      _stablePredictionCount = 1;
    }

    _lastStablePredictionAt = now;
    return _stablePredictionCount >= _requiredStableMatches;
  }

  void _resetStablePrediction() {
    _stablePredictionKey = null;
    _stablePredictionCount = 0;
    _lastStablePredictionAt = null;
  }

  @override
  void dispose() {
    autoDetectTimer?.cancel();
    controller?.dispose();
    scanController.dispose();
    successController.dispose();
    super.dispose();
  }

  Future<void> showDetectionSuccess(Artwork artwork) async {
    autoDetectTimer?.cancel();
    await HapticFeedback.mediumImpact();

    setState(() {
      detectedArtwork = artwork;
      showSuccessOverlay = true;
      isDetecting = false;
      scanStatus = 'Artwork matched';
    });

    successController.forward(from: 0);
    await Future.delayed(_successOverlayHoldDuration);

    if (!mounted) return;

    setState(() {
      showSuccessOverlay = false;
    });

    await Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 520),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, animation, _) =>
            ArtworkPreviewScreen(artwork: artwork),
        transitionsBuilder: (_, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );

          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );

    if (mounted) {
      _resetStablePrediction();
      _startAutoDetection();
    }
  }

  Widget buildSuccessOverlay() {
    final artwork = detectedArtwork;

    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: successController,
          builder: (context, child) {
            final value = successController.value;
            final eased = Curves.easeOutCubic.transform(value);
            final mascotProgress = (value / 0.36).clamp(0.0, 1.0).toDouble();
            final mascotOpacity = value <= 0.20
                ? (value / 0.20).clamp(0.0, 1.0).toDouble()
                : value <= 0.58
                ? 1.0
                : value <= 0.74
                ? (1 - ((value - 0.58) / 0.16)).clamp(0.0, 1.0).toDouble()
                : 0.0;
            final cardProgress = ((value - 0.70) / 0.30)
                .clamp(0.0, 1.0)
                .toDouble();
            final cardEase = Curves.easeOutCubic.transform(cardProgress);
            final cardScale = 0.88 + (cardEase * 0.12);
            final mascotScale = 0.88 + (mascotProgress * 0.28);

            return Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.40),
                      gradient: RadialGradient(
                        radius: 0.78 + (0.18 * eased),
                        colors: [
                          Colors.amber.withValues(alpha: 0.16),
                          Colors.black.withValues(alpha: 0.42),
                          Colors.black.withValues(alpha: 0.68),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Opacity(
                    opacity: cardProgress,
                    child: CustomPaint(
                      painter: _RecognitionBurstPainter(progress: cardProgress),
                    ),
                  ),
                ),
                Center(
                  child: Opacity(
                    opacity: cardProgress,
                    child: Transform.scale(
                      scale: cardScale,
                      child: Container(
                        width: 318,
                        height: 430,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(34),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.96),
                            width: 2.6,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withValues(
                                alpha: 0.48 * cardEase,
                              ),
                              blurRadius: 54,
                              spreadRadius: 8,
                            ),
                            BoxShadow(
                              color: const Color(
                                0xFF45B6FE,
                              ).withValues(alpha: 0.26 * cardEase),
                              blurRadius: 44,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _RecognitionCardPainter(
                                  progress: cardProgress,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 20,
                              left: 20,
                              right: 20,
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(9),
                                    decoration: const BoxDecoration(
                                      color: Colors.amber,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      color: Colors.black,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'MATCH CONFIRMED',
                                          style: TextStyle(
                                            color: Colors.amber,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        Text(
                                          artwork == null
                                              ? 'Artwork detected'
                                              : artwork.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              top: 92,
                              left: 34,
                              right: 34,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: SizedBox(
                                  height: 214,
                                  child: artwork == null
                                      ? Container(color: Colors.white10)
                                      : CachedNetworkImage(
                                          imageUrl: artwork.imageUrl,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) =>
                                              Container(
                                                color: Colors.white10,
                                                child: const Center(
                                                  child:
                                                      CircularProgressIndicator(
                                                        color: Colors.amber,
                                                        strokeWidth: 2,
                                                      ),
                                                ),
                                              ),
                                          errorWidget: (context, url, error) =>
                                              Container(
                                                color: Colors.white10,
                                                child: const Icon(
                                                  Icons.image_not_supported,
                                                  color: Colors.white54,
                                                  size: 36,
                                                ),
                                              ),
                                        ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 28,
                              right: 28,
                              bottom: 68,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _successMetric(
                                      Icons.person_outline,
                                      artwork?.artist ?? 'YSMA',
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _successMetric(
                                      Icons.place_outlined,
                                      artwork?.location ?? 'Gallery',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              left: 34,
                              right: 34,
                              bottom: 42,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: cardEase,
                                  minHeight: 5,
                                  color: Colors.amber,
                                  backgroundColor: Colors.white12,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 15,
                              left: 0,
                              right: 0,
                              child: Opacity(
                                opacity: 0.82,
                                child: Text(
                                  'Building artwork preview...',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: const Alignment(0, -0.10),
                  child: Transform.translate(
                    offset: Offset(0, math.sin(value * math.pi * 2) * 5),
                    child: Opacity(
                      opacity: mascotOpacity,
                      child: Transform.scale(
                        scale: mascotScale,
                        child: _ApprovalMascot(progress: mascotProgress),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _successMetric(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.amber, size: 17),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      body: isCameraReady
          ? Stack(
              children: [
                // CAMERA
                SizedBox.expand(child: CameraPreview(controller!)),

                // DARK OVERLAY
                Container(color: Colors.black.withValues(alpha: 0.25)),

                // TOP BAR
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),

                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,

                      children: [
                        // BACK BUTTON
                        GestureDetector(
                          onTap: () => Navigator.pop(context),

                          child: Container(
                            padding: const EdgeInsets.all(10),

                            decoration: BoxDecoration(
                              color: Colors.black54,

                              borderRadius: BorderRadius.circular(15),
                            ),

                            child: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                          ),
                        ),

                        // TITLE
                        const Text(
                          "Scan Artwork",

                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        // FLASH ICON
                        Container(
                          padding: const EdgeInsets.all(10),

                          decoration: BoxDecoration(
                            color: Colors.black54,

                            borderRadius: BorderRadius.circular(15),
                          ),

                          child: const Icon(
                            Icons.flash_off,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // SCAN FRAME
                Center(
                  child: Container(
                    width: 280,
                    height: 350,

                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.amber, width: 3),

                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withValues(alpha: 0.28),
                          blurRadius: 32,
                          spreadRadius: 3,
                        ),
                        BoxShadow(
                          color: const Color(
                            0xFF45B6FE,
                          ).withValues(alpha: 0.12),
                          blurRadius: 44,
                          spreadRadius: 8,
                        ),
                      ],
                    ),

                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: scanController,
                            builder: (context, child) {
                              return CustomPaint(
                                painter: _ScanHudPainter(
                                  progress: scanController.value,
                                ),
                              );
                            },
                          ),
                        ),

                        // SCAN LINE
                        AnimatedBuilder(
                          animation: scanController,

                          builder: (context, child) {
                            return Positioned(
                              top: scanController.value * 300,

                              left: 0,
                              right: 0,

                              child: Container(
                                height: 4,

                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,

                                      Colors.amber,

                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // INSTRUCTIONS
                if (showSuccessOverlay) buildSuccessOverlay(),

                Positioned(
                  bottom: 140,
                  left: 20,
                  right: 20,

                  child: Column(
                    children: [
                      const Text(
                        "Point camera at artwork",

                        textAlign: TextAlign.center,

                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        "AI recognition will identify the artwork",

                        textAlign: TextAlign.center,

                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),

                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                // DETECT STATUS
                Positioned(
                  bottom: 50,
                  left: 40,
                  right: 40,

                  child: Container(
                    height: 60,

                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.56),

                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.72),
                      ),
                    ),

                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isDetecting)
                          const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.amber,
                              strokeWidth: 2.4,
                            ),
                          )
                        else
                          const Icon(Icons.radar, color: Colors.amber),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            scanStatus,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator(color: Colors.amber)),
    );
  }
}

class _ApprovalMascot extends StatelessWidget {
  final double progress;

  const _ApprovalMascot({required this.progress});

  @override
  Widget build(BuildContext context) {
    final thumbScale =
        0.72 +
        (Curves.elasticOut.transform(progress.clamp(0.0, 1.0).toDouble()) *
            0.28);

    return SizedBox(
      width: 126,
      height: 148,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _ApprovalMascotPainter(progress: progress),
            ),
          ),
          Positioned(
            top: 16,
            right: 0,
            child: Transform.scale(
              scale: thumbScale,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.amber,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.36),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.42),
                      blurRadius: 22,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.thumb_up_alt_rounded,
                  color: Colors.black,
                  size: 27,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.54),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.74)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.22),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Text(
                'Matched',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanHudPainter extends CustomPainter {
  final double progress;

  const _ScanHudPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    final cornerPaint = Paint()
      ..color = Colors.amber.withValues(alpha: 0.92)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final cyanPaint = Paint()
      ..color = const Color(0xFF45B6FE).withValues(alpha: 0.32)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    for (var i = 1; i < 5; i++) {
      final x = size.width * i / 5;
      final y = size.height * i / 5;
      canvas.drawLine(Offset(x, 18), Offset(x, size.height - 18), gridPaint);
      canvas.drawLine(Offset(18, y), Offset(size.width - 18, y), gridPaint);
    }

    final ringCenter = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < 3; i++) {
      final radius = 38 + (i * 42) + math.sin((progress + i) * math.pi) * 4;
      canvas.drawCircle(ringCenter, radius, cyanPaint);
    }

    const inset = 16.0;
    const length = 44.0;
    void drawCorner(Offset start, double xDir, double yDir) {
      canvas.drawLine(start, start + Offset(length * xDir, 0), cornerPaint);
      canvas.drawLine(start, start + Offset(0, length * yDir), cornerPaint);
    }

    drawCorner(const Offset(inset, inset), 1, 1);
    drawCorner(Offset(size.width - inset, inset), -1, 1);
    drawCorner(Offset(inset, size.height - inset), 1, -1);
    drawCorner(Offset(size.width - inset, size.height - inset), -1, -1);

    final targetPaint = Paint()
      ..color = Colors.amber.withValues(alpha: 0.38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final sweepRect = Rect.fromCenter(
      center: ringCenter,
      width: size.width * 0.52,
      height: size.width * 0.52,
    );
    canvas.drawArc(
      sweepRect,
      progress * math.pi * 2,
      math.pi * 0.72,
      false,
      targetPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanHudPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _RecognitionBurstPainter extends CustomPainter {
  final double progress;

  const _RecognitionBurstPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final ringOpacity = ((1 - progress).clamp(0.0, 1.0) as num).toDouble();
    final center = Offset(size.width / 2, size.height / 2);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = Colors.amber.withValues(alpha: ringOpacity * 0.42);

    for (var i = 0; i < 4; i++) {
      final radius = size.width * (0.18 + i * 0.13 + progress * 0.12);
      canvas.drawCircle(center, radius, ringPaint);
    }

    final rayPaint = Paint()
      ..color = Colors.amber.withValues(alpha: 0.20)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 18; i++) {
      final angle = (i / 18 * math.pi * 2) + (progress * math.pi * 0.65);
      final inner = size.width * 0.23;
      final outer = size.width * (0.36 + (i % 4) * 0.035);
      canvas.drawLine(
        center + Offset(math.cos(angle) * inner, math.sin(angle) * inner),
        center + Offset(math.cos(angle) * outer, math.sin(angle) * outer),
        rayPaint,
      );
    }

    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.32);
    for (var i = 0; i < 30; i++) {
      final angle = i * 0.73 + progress * math.pi * 2;
      final radius = size.width * (0.18 + ((i * 17) % 45) / 100);
      final point =
          center +
          Offset(math.cos(angle) * radius, math.sin(angle * 0.9) * radius);
      canvas.drawCircle(point, 1.2 + (i % 3) * 0.45, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RecognitionBurstPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _RecognitionCardPainter extends CustomPainter {
  final double progress;

  const _RecognitionCardPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0x6613283E), Color(0x3313283E), Color(0x551B405F)],
      ).createShader(Offset.zero & size);
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(34),
    );
    canvas.drawRRect(rect, fill);

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..strokeWidth = 1;
    for (var i = 0; i < 8; i++) {
      final y = 88 + i * 28 + math.sin(progress * math.pi * 2 + i) * 2;
      canvas.drawLine(Offset(22, y), Offset(size.width - 22, y), linePaint);
    }

    final shimmerPaint = Paint()
      ..shader =
          LinearGradient(
            colors: [
              Colors.transparent,
              Colors.white.withValues(alpha: 0.16),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromLTWH(
              size.width * progress - size.width * 0.55,
              0,
              size.width * 0.7,
              size.height,
            ),
          );
    canvas.drawRRect(rect, shimmerPaint);
  }

  @override
  bool shouldRepaint(covariant _RecognitionCardPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _ApprovalMascotPainter extends CustomPainter {
  final double progress;

  const _ApprovalMascotPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final bounce = math.sin(progress * math.pi * 2);
    final approval = Curves.elasticOut.transform(
      progress.clamp(0.0, 1.0).toDouble(),
    );
    final centerX = size.width / 2;
    final bodyTop = 58.0 + bounce * 2;

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.amber.withValues(alpha: 0.28),
          const Color(0xFF45B6FE).withValues(alpha: 0.10),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(centerX, 72), width: 112, height: 122),
      glowPaint,
    );

    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF24384D), Color(0xFF13283E)],
      ).createShader(Rect.fromLTWH(28, bodyTop, 70, 58));
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(30, bodyTop, 66, 58),
      const Radius.circular(22),
    );
    canvas.drawRRect(body, bodyPaint);

    final scarfPaint = Paint()..color = Colors.amber;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(42, bodyTop + 14, 42, 9),
        const Radius.circular(9),
      ),
      scarfPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(78, bodyTop + 17)
        ..lineTo(96, bodyTop + 27)
        ..lineTo(80, bodyTop + 31)
        ..close(),
      scarfPaint,
    );

    final headCenter = Offset(centerX - 4, 40 + bounce * 2);
    final headPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFF4C1), Color(0xFFFFC447)],
      ).createShader(Rect.fromCircle(center: headCenter, radius: 31));
    canvas.drawCircle(headCenter, 31, headPaint);

    final facePaint = Paint()..color = const Color(0xFF13283E);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: headCenter + const Offset(0, 3),
          width: 42,
          height: 18,
        ),
        const Radius.circular(11),
      ),
      facePaint,
    );

    final eyePaint = Paint()..color = const Color(0xFF45B6FE);
    canvas.drawCircle(headCenter + const Offset(-11, 3), 3.2, eyePaint);
    canvas.drawCircle(headCenter + const Offset(11, 3), 3.2, eyePaint);

    final smilePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.82)
      ..strokeWidth = 1.7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(
        center: headCenter + const Offset(0, 8),
        width: 17,
        height: 10,
      ),
      0.18,
      math.pi - 0.36,
      false,
      smilePaint,
    );

    final armPaint = Paint()
      ..color = const Color(0xFFFFD66B)
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    final thumbLift = 17 * approval;
    final handCenter = Offset(105, bodyTop + 11 - thumbLift);
    canvas.drawLine(Offset(88, bodyTop + 24), handCenter, armPaint);

    final handPaint = Paint()..color = const Color(0xFFFFD66B);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: handCenter + const Offset(7, 5),
          width: 23,
          height: 16,
        ),
        const Radius.circular(8),
      ),
      handPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: handCenter + const Offset(16, -8),
          width: 11,
          height: 28,
        ),
        const Radius.circular(7),
      ),
      handPaint,
    );
    canvas.drawCircle(handCenter + const Offset(16, -21), 5.5, handPaint);

    final leftArmPaint = Paint()
      ..color = const Color(0xFFFFD66B)
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(36, bodyTop + 23),
      Offset(23, bodyTop + 38 + bounce),
      leftArmPaint,
    );

    final sparklePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.42 + (0.28 * progress));
    for (var i = 0; i < 4; i++) {
      final angle = progress * math.pi * 2 + i * 1.4;
      final point = Offset(
        centerX + math.cos(angle) * (42 + i * 5),
        34 + math.sin(angle) * (28 + i * 3),
      );
      _drawSparkle(canvas, point, 4.2 + i, sparklePaint);
    }
  }

  void _drawSparkle(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx + radius * 0.34, center.dy - radius * 0.34)
      ..lineTo(center.dx + radius, center.dy)
      ..lineTo(center.dx + radius * 0.34, center.dy + radius * 0.34)
      ..lineTo(center.dx, center.dy + radius)
      ..lineTo(center.dx - radius * 0.34, center.dy + radius * 0.34)
      ..lineTo(center.dx - radius, center.dy)
      ..lineTo(center.dx - radius * 0.34, center.dy - radius * 0.34)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ApprovalMascotPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
