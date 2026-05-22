import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/artwork.dart';
import '../utils/colors.dart';
import 'artwork_preview_screen.dart';

class ArtworkSpotlightScreen extends StatelessWidget {
  final List<Artwork> artworks;

  const ArtworkSpotlightScreen({super.key, required this.artworks});

  @override
  Widget build(BuildContext context) {
    final spotlight = _spotlightArtwork();
    final facts = _funFactsFor(spotlight);
    final source = _sourceFor(spotlight);

    return Scaffold(
      backgroundColor: AppColors.backgroundFor(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.arrow_back,
                      color: AppColors.textFor(context),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Artwork Spotlight',
                      style: TextStyle(
                        color: AppColors.textFor(context),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: AspectRatio(
                        aspectRatio: 0.78,
                        child: CachedNetworkImage(
                          imageUrl: spotlight.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: AppColors.cardFor(context),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.cardFor(context),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Text(
                              'Today',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            spotlight.title,
                            style: TextStyle(
                              color: AppColors.textFor(context),
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${spotlight.artist} - ${spotlight.year}',
                            style: TextStyle(
                              color: AppColors.mutedTextFor(context),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              const Icon(
                                Icons.lightbulb_outline,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Fun facts',
                                style: TextStyle(
                                  color: AppColors.textFor(context),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            source,
                            style: TextStyle(
                              color: AppColors.subtleTextFor(context),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 14),
                          for (final fact in facts)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _factTile(context, fact),
                            ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ArtworkPreviewScreen(
                                      artwork: spotlight,
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: const Icon(Icons.auto_awesome),
                              label: const Text(
                                'Open spotlight artwork',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Artwork _spotlightArtwork() {
    if (artworks.isEmpty) {
      throw StateError('Artwork spotlight needs at least one artwork.');
    }

    final start = DateTime(2026, 1, 1);
    final today = DateTime.now();
    final dayIndex = DateTime(
      today.year,
      today.month,
      today.day,
    ).difference(start).inDays;

    final curated = artworks.where((artwork) {
      return _onlineFactsByTitle.containsKey(_factKey(artwork.title));
    }).toList();
    final source = curated.isEmpty ? artworks : curated;

    return source[dayIndex % source.length];
  }

  Widget _factTile(BuildContext context, String fact) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.lightbulb_outline,
            color: AppColors.primary,
            size: 16,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            fact,
            style: TextStyle(
              color: AppColors.mutedTextFor(context),
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  List<String> _funFactsFor(Artwork artwork) {
    return _onlineFactsByTitle[_factKey(artwork.title)] ??
        const [
          'Curated public-source fun facts are still being added for this artwork.',
        ];
  }

  String _sourceFor(Artwork artwork) {
    return _onlineSourcesByTitle[_factKey(artwork.title)] ??
        'Source: public museum/art references';
  }

  String _factKey(String title) {
    return title
        .toLowerCase()
        .replaceAll('&', 'and')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  static const Map<String, List<String>> _onlineFactsByTitle = {
    'thecomforter': [
      'The painting tells a reverse-care story: the child becomes the emotional comforter for his mother.',
      'Google Arts & Culture notes that the figures are Olawunmi Banjo\'s sister and nephew.',
      'Banjo is largely self-taught and connects this work to emotional realities people often hide.',
      'A dedicated Google Arts & Culture story highlights the meticulous detail, from the boy\'s hair to the mother\'s forehead wrinkles.',
    ],
    'themansmind': [
      'Zinno Orara was born in Benin City and trained at Auchi Polytechnic before building a long painting practice.',
      'Google Arts & Culture identifies the color splashes as symbols of inner chaos, provision, self-realization, and purpose.',
      'Orara\'s public profile notes more than 13 solo exhibitions and international showings.',
      'The artist also holds a degree in philosophy, which fits the reflective theme of the work.',
    ],
    'senseofduty': [
      'Google Arts & Culture describes the scene as a stylized man cradling a child.',
      'The composition includes the uli-inspired agwolagwo motif beside the figure.',
      'Its colour language combines yellow, blue, red and brown.',
      'Adenaike is listed as Nigerian and born in Idanre.',
    ],
    'redsky': [
      'Red Sky is not a normal painted surface; it is built as dense beadwork on board.',
      'David Dale worked with Bruce Onobrakpeya before establishing his own studio practice.',
      'Dale was inducted into the Society of Nigerian Artists Hall of Fame in 2018.',
      'His record notes a first solo exhibition in Agen, France in 1973.',
    ],
    'theacrobat': [
      'Bunmi Babatunde studied sculpture at Yaba College of Technology.',
      'Google Arts & Culture describes Babatunde as known for organic, active sculptural forms.',
      'The figure\'s twisted pose turns balance and movement into the artwork\'s main drama.',
      'Babatunde set up a Lagos studio soon after graduation and has worked across wood, bronze and fiberglass.',
    ],
    'celebration': [
      'The work is connected to Igbo ritualistic dance as a source of influence.',
      'It also reflects Enwonwu\'s interest in Negritude and African cultural identity.',
      'A Google Arts & Culture story notes that Enwonwu became Nigeria\'s first professor of fine art in 1971.',
      'The same source highlights dance as a recurring theme across Enwonwu\'s career.',
    ],
    'iwin': [
      'Susan Wenger was Austrian-born and later became deeply connected to Yoruba spiritual and artistic practice.',
      'Google Arts & Culture describes Iwin as a scene of eerie forest spirits, with a central figure beating a drum.',
      'Wenger became one of the leading figures associated with Osogbo art.',
      'Her life in Nigeria was closely linked to the preservation of Yoruba culture and religion.',
    ],
    'theancestrallineage': [
      'The Ancestral Lineage was created in 2013 by Mufu Onifade.',
      'Google Arts & Culture lists the work as oil on canvas with dimensions of 150 x 90cm.',
      'The title is linked to Alajobi, a Yoruba idea of ancestral lineage.',
      'Onifade is associated with Araism, a painting method developed through years of studio experimentation.',
    ],
  };

  static const Map<String, String> _onlineSourcesByTitle = {
    'thecomforter':
        'Source: Google Arts & Culture, The Comforter and Olawunmi Banjo\'s Comforter story',
    'themansmind': 'Source: Google Arts & Culture, The Man\'s Mind',
    'senseofduty': 'Source: Google Arts & Culture, Sense of Duty',
    'redsky': 'Source: Google Arts & Culture, Red Sky',
    'theacrobat': 'Source: Google Arts & Culture, The Acrobat',
    'celebration': 'Source: Google Arts & Culture, Celebration',
    'iwin': 'Source: Google Arts & Culture, Iwin',
    'theancestrallineage':
        'Source: Google Arts & Culture, The Ancestral Lineage',
  };
}
