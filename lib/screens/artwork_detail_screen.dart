import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/artwork.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ArtworkDetailScreen extends StatefulWidget {
  final Artwork artwork;
  final int initialTab;

  const ArtworkDetailScreen({
    super.key,
    required this.artwork,
    this.initialTab = 0,
  });

  @override
  State<ArtworkDetailScreen> createState() =>
      _ArtworkDetailScreenState();
}

class _ArtworkDetailScreenState
    extends State<ArtworkDetailScreen> {

  late int selectedTab;

  final AudioPlayer player = AudioPlayer();

  Duration duration = Duration.zero;
  Duration position = Duration.zero;

  bool isPlaying = false;

  @override
  void initState() {
    super.initState();

    selectedTab = widget.initialTab;

    setupAudio();
  }

  // 🔥 SETUP AUDIO
  void setupAudio() async {

    // LOAD AUDIO URL
    await player.setUrl(widget.artwork.audioUrl);

    // TOTAL DURATION
    player.durationStream.listen((d) {
      setState(() {
        duration = d ?? Duration.zero;
      });
    });

    // CURRENT POSITION
    player.positionStream.listen((p) {
      setState(() {
        position = p;
      });
    });

    // PLAY STATE
    player.playerStateStream.listen((state) {
      setState(() {
        isPlaying = state.playing;
      });
    });
  }

  // ▶ PLAY / RESUME
  void playAudio() async {
    await player.play();
  }

  // ⏸ PAUSE
  void pauseAudio() async {
    await player.pause();
  }

  // ⏩ FORWARD 10s
  void skipForward() async {
    final newPosition =
        position + const Duration(seconds: 10);

    await player.seek(newPosition);
  }

  // ⏪ BACKWARD 10s
  void skipBackward() async {
    final newPosition =
        position - const Duration(seconds: 10);

    await player.seek(newPosition);
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.black,

      body: Stack(
        children: [

          // 🖼 IMAGE
          SizedBox.expand(
            child: CachedNetworkImage(
              imageUrl: widget.artwork.imageUrl,
              fit: BoxFit.cover,

              placeholder: (context, url) => Container(
                color: Colors.grey.shade900,
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.amber,
                  ),
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

          // 🔙 TOP BAR
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16),

              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,

                children: [

                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),

                  const Icon(
                    Icons.share,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),

          // 📦 BOTTOM PANEL
          Align(
            alignment: Alignment.bottomCenter,

            child: Container(
              padding: const EdgeInsets.all(20),

              decoration: const BoxDecoration(
                color: Color(0xFF1E2F45),

                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
              ),

              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [

                  // TITLE
                  Text(
                    widget.artwork.title,

                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // TABS
                  Row(
                    children: [
                      _tab("Description", 0),
                      _tab("Audio", 1),
                      _tab("Related", 2),
                    ],
                  ),

                  const SizedBox(height: 15),

                  // DESCRIPTION TAB
                  if (selectedTab == 0)
                    Text(
                      widget.artwork.description,

                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),

                  // AUDIO TAB
                  if (selectedTab == 1)
                    Column(
                      children: [

                        // TIME
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .spaceBetween,

                          children: [

                            Text(
                              formatTime(position),

                              style: const TextStyle(
                                color: Colors.white70,
                              ),
                            ),

                            Text(
                              formatTime(duration),

                              style: const TextStyle(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // 🎚 SLIDER
                        // 🎚 SLIDER WITH GREY BACKGROUND
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 12,
                              ),
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
                                await player.seek(
                                  Duration(seconds: value.toInt()),
                                );
                              },

                              activeColor: Colors.amber,
                              inactiveColor: Colors.white70,
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // 🎵 CONTROLS
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .spaceEvenly,

                          children: [

                            // BACKWARD
                            IconButton(
                              icon: const Icon(
                                Icons.replay_10,
                                color: Colors.amber,
                                size: 35,
                              ),

                              onPressed:
                                  skipBackward,
                            ),

                            // PLAY / PAUSE
                            GestureDetector(
                              onTap: () {

                                if (isPlaying) {
                                  pauseAudio();
                                } else {
                                  playAudio();
                                }
                              },

                              child: Container(
                                padding:
                                    const EdgeInsets
                                        .all(18),

                                decoration:
                                    const BoxDecoration(
                                  color: Colors.amber,
                                  shape:
                                      BoxShape.circle,
                                ),

                                child: Icon(
                                  isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow,

                                  color: Colors.black,
                                  size: 40,
                                ),
                              ),
                            ),

                            // FORWARD
                            IconButton(
                              icon: const Icon(
                                Icons.forward_10,
                                color: Colors.amber,
                                size: 35,
                              ),

                              onPressed:
                                  skipForward,
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🔘 TAB BUTTON
  Widget _tab(String text, int index) {

    final active = selectedTab == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedTab = index;
        });
      },

      child: Container(
        margin: const EdgeInsets.only(right: 10),

        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 8,
        ),

        decoration: BoxDecoration(
          color:
              active
                  ? Colors.amber
                  : Colors.white10,

          borderRadius:
              BorderRadius.circular(20),
        ),

        child: Text(
          text,

          style: TextStyle(
            color:
                active
                    ? Colors.black
                    : Colors.white70,
          ),
        ),
      ),
    );
  }

  // ⏱ FORMAT TIME
  String formatTime(Duration d) {

    final minutes =
        d.inMinutes
            .remainder(60)
            .toString()
            .padLeft(2, '0');

    final seconds =
        d.inSeconds
            .remainder(60)
            .toString()
            .padLeft(2, '0');

    return "$minutes:$seconds";
  }
}