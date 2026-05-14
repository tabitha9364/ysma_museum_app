import '../models/artwork.dart';

class ArtworkDetectionService {
  /// Simulates recognition of an artwork from a "scan result"
  /// Later this will be replaced with real AR/image recognition
  static Artwork? detectArtwork({
    required List<Artwork> artworks,
    required String scannedCode,
  }) {
    try {
      // 🔍 MATCH BY ID (simple + reliable for now)
      return artworks.firstWhere(
        (art) => art.id.toString() == scannedCode,
      );
    } catch (e) {
      return null;
    }
  }
}