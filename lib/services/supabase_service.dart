import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/artwork.dart';

class SupabaseService {

  static final supabase = Supabase.instance.client;

  // FETCH ALL ARTWORKS
  static Future<List<Artwork>> fetchArtworks() async {

    final response = await supabase
        .from('artworks')
        .select()
        .order('id');

    return (response as List)
        .map((json) => Artwork.fromJson(json))
        .toList();
  }
}
