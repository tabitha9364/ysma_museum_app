import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/artwork.dart';

class ArtworkService {
  static final _client = Supabase.instance.client;

  static Future<List<Artwork>> loadArtworks() async {
    final response = await _client
        .from('artworks')
        .select()
        .order('id');

    return (response as List)
        .map((json) => Artwork.fromJson(json))
        .toList();
  }
}
