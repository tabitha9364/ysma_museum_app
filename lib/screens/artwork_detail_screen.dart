import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../models/artwork.dart';
import '../services/app_settings.dart';
import '../services/audio_cache_service.dart';
import '../services/supabase_service.dart';
import '../services/user_preferences.dart';
import '../utils/colors.dart';

class ArtworkDetailScreen extends StatefulWidget {
  final Artwork artwork;
  final int initialTab;

  const ArtworkDetailScreen({
    super.key,
    required this.artwork,
    this.initialTab = 0,
  });

  @override
  State<ArtworkDetailScreen> createState() => _ArtworkDetailScreenState();
}

class _ArtworkDetailScreenState extends State<ArtworkDetailScreen> {
  static AudioPlayer? _activePlayer;

  final AudioPlayer player = AudioPlayer();
  late final Future<void> _audioSetupFuture;

  late int selectedTab;

  Duration duration = Duration.zero;
  Duration position = Duration.zero;

  bool isPlaying = false;
  bool audioReady = false;
  bool relatedLoading = true;
  List<Artwork> relatedArtworks = [];

  @override
  void initState() {
    super.initState();
    selectedTab = widget.initialTab;
    _audioSetupFuture = setupAudio();
    loadRelatedArtworks();
  }

  Future<void> setupAudio() async {
    final audioUrl = widget.artwork.audioUrl.trim();

    if (audioUrl.isEmpty) {
      return;
    }

    try {
      final cachedAudio = await AudioCacheService.cachedAudioFile(audioUrl);

      if (cachedAudio != null) {
        await player.setFilePath(cachedAudio.path);
      } else {
        await player.setUrl(audioUrl);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        audioReady = true;
      });

      if (selectedTab == 1 && context.read<AppSettings>().autoPlayAudio) {
        unawaited(playAudio());
      }

      player.durationStream.listen((value) {
        if (!mounted) {
          return;
        }

        setState(() {
          duration = value ?? Duration.zero;
        });
      });

      player.positionStream.listen((value) {
        if (!mounted) {
          return;
        }

        setState(() {
          position = value;
        });
      });

      player.playerStateStream.listen((state) {
        if (!mounted) {
          return;
        }

        setState(() {
          isPlaying = state.playing;
        });
      });
    } catch (error) {
      debugPrint('Audio setup failed: $error');
    }
  }

  Future<void> loadRelatedArtworks() async {
    try {
      final artworks = await SupabaseService.fetchArtworks();
      final related = artworks.where((artwork) {
        return artwork.id != widget.artwork.id && _relatedScore(artwork) > 0;
      }).toList()..sort((a, b) => _relatedScore(b).compareTo(_relatedScore(a)));

      if (!mounted) {
        return;
      }

      setState(() {
        relatedArtworks = related.take(8).toList();
        relatedLoading = false;
      });
    } catch (error) {
      debugPrint('Related artworks failed: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        relatedLoading = false;
      });
    }
  }

  int _relatedScore(Artwork artwork) {
    var score = 0;

    if (artwork.artist.trim().toLowerCase() ==
        widget.artwork.artist.trim().toLowerCase()) {
      score += 4;
    }

    if (artwork.year.trim().isNotEmpty &&
        artwork.year.trim() == widget.artwork.year.trim()) {
      score += 2;
    }

    if (artwork.tag.trim().toLowerCase() ==
        widget.artwork.tag.trim().toLowerCase()) {
      score += 1;
    }

    return score;
  }

  Future<void> playAudio() async {
    if (!audioReady) {
      await _audioSetupFuture;

      if (!audioReady) {
        _showMessage('Audio is not available for this artwork yet.');
        return;
      }
    }

    await _claimAudioFocus();
    await player.play();
  }

  Future<void> pauseAudio() async {
    await player.pause();

    if (_activePlayer == player) {
      _activePlayer = null;
    }
  }

  Future<void> _claimAudioFocus() async {
    final activePlayer = _activePlayer;

    if (activePlayer != null && activePlayer != player) {
      await activePlayer.pause();
    }

    _activePlayer = player;
  }

  Future<void> skipForward() async {
    final target = position + const Duration(seconds: 10);
    final safeTarget = target > duration && duration != Duration.zero
        ? duration
        : target;

    await player.seek(safeTarget);
  }

  Future<void> skipBackward() async {
    final target = position - const Duration(seconds: 10);
    await player.seek(target.isNegative ? Duration.zero : target);
  }

  Future<void> shareArtwork() async {
    await Clipboard.setData(
      ClipboardData(
        text:
            '${widget.artwork.title} by ${widget.artwork.artist}\n${widget.artwork.imageUrl}',
      ),
    );

    await UserPreferences.addRecentActivity(
      type: 'share',
      artworkTitle: widget.artwork.title,
    );

    if (!mounted) {
      return;
    }

    _showMessage('Artwork details copied for sharing.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void dispose() {
    if (_activePlayer == player) {
      _activePlayer = null;
    }

    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SizedBox.expand(
            child: CachedNetworkImage(
              imageUrl: widget.artwork.imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey.shade900,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.amber),
                ),
              ),
              errorWidget: (context, url, error) {
                return Container(
                  color: Colors.grey.shade900,
                  child: const Center(
                    child: Icon(
                      Icons.image_not_supported,
                      color: Colors.white54,
                      size: 50,
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  IconButton(
                    tooltip: 'Share artwork',
                    icon: const Icon(Icons.share, color: Colors.white),
                    onPressed: shareArtwork,
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxPanelHeight = constraints.maxHeight * 0.43;

                return Container(
                  width: double.infinity,
                  constraints: BoxConstraints(maxHeight: maxPanelHeight),
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  decoration: BoxDecoration(
                    color: AppColors.cardFor(context),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.artwork.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textFor(context),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _tabStrip(),
                      const SizedBox(height: 12),
                      Flexible(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: _selectedTabContent(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _scrollableTab({required Key key, required Widget child}) {
    return SingleChildScrollView(
      key: key,
      physics: const BouncingScrollPhysics(),
      child: child,
    );
  }

  Widget _selectedTabContent() {
    final settings = context.watch<AppSettings>();

    if (selectedTab == 0) {
      return _scrollableTab(
        key: const ValueKey('description'),
        child: Text(
          widget.artwork.description,
          style: TextStyle(
            color: AppColors.mutedTextFor(context),
            fontSize: 14 + (settings.textScale * 8),
            height: 1.5,
          ),
        ),
      );
    }

    if (selectedTab == 1) {
      return SingleChildScrollView(
        key: const ValueKey('audio'),
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formatTime(position),
                  style: TextStyle(color: AppColors.mutedTextFor(context)),
                ),
                Text(
                  formatTime(duration),
                  style: TextStyle(color: AppColors.mutedTextFor(context)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                activeTrackColor: AppColors.primary,
                inactiveTrackColor: AppColors.isDark(context)
                    ? Colors.white30
                    : Colors.black26,
                thumbColor: AppColors.primary,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                min: 0,
                max: duration.inSeconds.toDouble(),
                value: duration.inSeconds == 0
                    ? 0
                    : position.inSeconds
                          .clamp(0, duration.inSeconds)
                          .toDouble(),
                onChanged: (value) async {
                  await player.seek(Duration(seconds: value.toInt()));
                },
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.replay_10,
                    color: Colors.amber,
                    size: 35,
                  ),
                  onPressed: skipBackward,
                ),
                GestureDetector(
                  onTap: () {
                    if (isPlaying) {
                      pauseAudio();
                    } else {
                      playAudio();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.black,
                      size: 40,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.forward_10,
                    color: Colors.amber,
                    size: 35,
                  ),
                  onPressed: skipForward,
                ),
              ],
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      key: const ValueKey('related'),
      child: _relatedContent(),
    );
  }

  Widget _tabStrip() {
    return SizedBox(
      height: 46,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.panelGreyFor(context),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          children: [
            _tab('Description', 0),
            _tab('Audio', 1),
            _tab('Related', 2),
          ],
        ),
      ),
    );
  }

  Widget _tab(String text, int index) {
    final active = selectedTab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedTab = index;
          });

          if (index == 1 && context.read<AppSettings>().autoPlayAudio) {
            unawaited(playAudio());
          }
        },
        child: Container(
          height: double.infinity,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: active ? Colors.amber : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              text,
              maxLines: 1,
              softWrap: false,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: active ? Colors.black : AppColors.mutedTextFor(context),
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _relatedContent() {
    if (relatedLoading) {
      return const SizedBox(
        height: 90,
        child: Center(child: CircularProgressIndicator(color: Colors.amber)),
      );
    }

    if (relatedArtworks.isEmpty) {
      return Text(
        'No related artworks yet.',
        style: TextStyle(color: AppColors.mutedTextFor(context)),
      );
    }

    return SizedBox(
      height: 126,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: relatedArtworks.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final artwork = relatedArtworks[index];

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ArtworkDetailScreen(artwork: artwork),
                ),
              );
            },
            child: SizedBox(
              width: 104,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: artwork.imageUrl,
                      height: 76,
                      width: 104,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    artwork.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textFor(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _relatedReason(artwork),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.mutedTextFor(context),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _relatedReason(Artwork artwork) {
    if (artwork.artist.trim().toLowerCase() ==
        widget.artwork.artist.trim().toLowerCase()) {
      return artwork.artist;
    }

    if (artwork.year.trim().isNotEmpty &&
        artwork.year.trim() == widget.artwork.year.trim()) {
      return artwork.year;
    }

    return artwork.tag;
  }

  String formatTime(Duration value) {
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');

    return '$minutes:$seconds';
  }
}
