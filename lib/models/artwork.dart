class Artwork {

  final int id;

  final String title;
  final String artist;
  final String year;
  final String location;
  final String tag;
  final String description;

  // 🔥 SUPABASE IMAGE URL
  final String imageUrl;

  // 🔥 SUPABASE AUDIO URL
  final String audioUrl;

  Artwork({
    required this.id,
    required this.title,
    required this.artist,
    required this.year,
    required this.location,
    required this.tag,
    required this.description,
    required this.imageUrl,
    required this.audioUrl,
  });

  factory Artwork.fromJson(Map<String, dynamic> json) {

    return Artwork(

      id: json['id'] ?? 0,

      title: json['title'] ?? '',
      artist: json['artist'] ?? '',
      year: json['year'] ?? '',
      location: json['location'] ?? '',
      tag: json['tag'] ?? '',
      description: json['description'] ?? '',

      // 🔥 SUPABASE FIELDS
      imageUrl: json['image_url'] ?? '',
      audioUrl: json['audio_url'] ?? '',
    );
  }
}
