import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../models/artwork.dart';

class AudioCacheService {
  static const int _maxConcurrentDownloads = 4;

  static final CacheManager _cacheManager = CacheManager(
    Config(
      'ysma_artwork_audio_cache',
      stalePeriod: const Duration(days: 90),
      maxNrOfCacheObjects: 140,
    ),
  );

  static final Set<String> _queuedUrls = <String>{};
  static final Map<String, Future<File?>> _activeDownloads =
      <String, Future<File?>>{};

  static Future<void> preloadArtworkAudio(Iterable<Artwork> artworks) async {
    final urls = <String>{
      for (final artwork in artworks)
        if (_isCacheableNetworkUrl(artwork.audioUrl)) artwork.audioUrl.trim(),
    }.where((url) => !_queuedUrls.contains(url)).toList(growable: false);

    if (urls.isEmpty) {
      return;
    }

    _queuedUrls.addAll(urls);

    for (var index = 0; index < urls.length; index += _maxConcurrentDownloads) {
      final batch = urls.skip(index).take(_maxConcurrentDownloads);
      await Future.wait(batch.map(_downloadForPreload));
    }
  }

  static Future<File?> cachedAudioFile(String rawUrl) async {
    final url = rawUrl.trim();

    if (!_isCacheableNetworkUrl(url)) {
      return null;
    }

    final cached = await _cacheManager.getFileFromCache(url);
    if (cached != null && await cached.file.exists()) {
      return cached.file;
    }

    return _activeDownloads.putIfAbsent(url, () async {
      try {
        final file = await _cacheManager.getSingleFile(url);
        return await file.exists() ? file : null;
      } catch (error) {
        debugPrint('Audio cache failed for $url: $error');
        _queuedUrls.remove(url);
        return null;
      } finally {
        _activeDownloads.remove(url);
      }
    });
  }

  static Future<void> _downloadForPreload(String url) async {
    await cachedAudioFile(url);
  }

  static bool _isCacheableNetworkUrl(String rawUrl) {
    final url = rawUrl.trim();
    final uri = Uri.tryParse(url);

    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }
}
