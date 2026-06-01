import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/artwork.dart';
import 'audio_cache_service.dart';

class SupabaseService {
  static final supabase = Supabase.instance.client;

  // FETCH ALL ARTWORKS
  static Future<List<Artwork>> fetchArtworks() async {
    final response = await supabase.from('artworks').select().order('id');

    final artworks = (response as List)
        .map((json) => Artwork.fromJson(json))
        .toList();

    unawaited(AudioCacheService.preloadArtworkAudio(artworks));
    return artworks;
  }
}
