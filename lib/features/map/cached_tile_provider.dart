import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../../models/station.dart';

/// Custom tile provider that caches map tiles locally on disk and uses
/// HTTP Headers (ETag / Last-Modified) to check for updates asynchronously.
class CachedTileProvider extends TileProvider {
  CachedTileProvider();

  static String? _resolvedCachePath;
  static bool _isPrefetching = false;
  static final Map<String, String> _hashCache = {};

  /// Get the local cache directory path for map tiles
  static Future<String> getCachePath() async {
    if (kIsWeb) return '';
    if (_resolvedCachePath != null) return _resolvedCachePath!;
    final tempDir = await getTemporaryDirectory();
    _resolvedCachePath = '${tempDir.path}/map_tiles';
    return _resolvedCachePath!;
  }

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final url = getTileUrl(coordinates, options);
    if (kIsWeb) {
      return NetworkImage(url);
    }
    final folderHash = _hashCache.putIfAbsent(options.urlTemplate ?? 'default', () => (options.urlTemplate ?? 'default').hashCode.toString());
    final cacheDir = _resolvedCachePath;
    if (cacheDir == null) {
      // Safe fallback if not initialized
      return NetworkImage(url);
    }
    
    final tileFile = File('$cacheDir/$folderHash/${coordinates.z}/${coordinates.x}/${coordinates.y}.png');
    final metaFile = File('$cacheDir/$folderHash/${coordinates.z}/${coordinates.x}/${coordinates.y}.meta');

    return CachedTileImageProvider(
      url: url,
      tileFile: tileFile,
      metaFile: metaFile,
    );
  }

  /// Converts Longitude to Slippy Map Tile X coordinate
  static int lonToTileX(double lon, int zoom) {
    return ((lon + 180.0) / 360.0 * pow(2, zoom)).floor();
  }

  /// Converts Latitude to Slippy Map Tile Y coordinate
  static int latToTileY(double lat, int zoom) {
    final latRad = lat * pi / 180.0;
    return ((1.0 - (log(tan(latRad) + 1.0 / cos(latRad)) / pi)) / 2.0 * pow(2, zoom)).floor();
  }

  /// Prefetch map tiles for the Bangkok transit network in the background.
  /// Loops through all stations and downloads tiles for zoom levels 12 to 15 (with surrounding padding).
  static Future<void> prefetchBangkokTiles(List<Station> stations) async {
    if (kIsWeb) return;
    if (_isPrefetching) {
      print('[Prefetch] Already running. Skipping start.');
      return;
    }
    _isPrefetching = true;

    try {
      final cacheDir = await getCachePath();
      print('[Prefetch] Starting background map prefetch for ${stations.length} stations in Bangkok...');

      // Bounding box of Bangkok to double check coordinates are in range
      // Lat: 13.50 to 14.10, Lng: 100.30 to 100.80
      const minLat = 13.50;
      const maxLat = 14.10;
      const minLng = 100.30;
      const maxLng = 100.80;

      // Define url templates and folders we want to cache
      final targets = [
        // Dark Mode tiles
        {
          'template': 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
          'hash': 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'.hashCode.toString(),
        },
        // Light Mode tiles
        {
          'template': 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
          'hash': 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png'.hashCode.toString(),
        }
      ];

      // Calculate all distinct tiles we need to download
      // Key format: "hash:z:x:y"
      final tilesToFetch = <String>{};

      for (final station in stations) {
        // Guard coordinates
        if (station.lat < minLat || station.lat > maxLat || station.lng < minLng || station.lng > maxLng) {
          continue;
        }

        // Prefetch zoom levels 12 to 15
        for (int z = 12; z <= 15; z++) {
          final x = lonToTileX(station.lng, z);
          final y = latToTileY(station.lat, z);

          // Add padding of 1 tile surrounding the station to cover panning
          final pad = (z >= 14) ? 1 : 0; // Only pad at closer zoom levels to save bandwidth
          for (int dx = -pad; dx <= pad; dx++) {
            for (int dy = -pad; dy <= pad; dy++) {
              final tx = x + dx;
              final ty = y + dy;

              for (final target in targets) {
                tilesToFetch.add('${target['hash']}:$z:$tx:$ty:${target['template']}');
              }
            }
          }
        }
      }

      print('[Prefetch] Deduplicated total tiles to fetch: ${tilesToFetch.length}');

      int successCount = 0;
      int cachedCount = 0;
      int errorCount = 0;
      int index = 0;

      // Download tiles sequentially in the background to avoid rate limits
      for (final tileInfo in tilesToFetch) {
        index++;
        final parts = tileInfo.split(':');
        final folderHash = parts[0];
        final z = int.parse(parts[1]);
        final x = int.parse(parts[2]);
        final y = int.parse(parts[3]);
        // Reconstruct template URL
        final urlTemplate = parts.sublist(4).join(':');
        
        final url = urlTemplate
            .replaceAll('{z}', z.toString())
            .replaceAll('{x}', x.toString())
            .replaceAll('{y}', y.toString());

        final tileFile = File('$cacheDir/$folderHash/$z/$x/$y.png');
        final metaFile = File('$cacheDir/$folderHash/$z/$x/$y.meta');

        try {
          if (await tileFile.exists()) {
            cachedCount++;
            // Background check for update (send ETag)
            // Do a check in background
            _validateAndDownloadTile(url, tileFile, metaFile, isBackground: true);
          } else {
            // Download fresh tile
            final success = await _validateAndDownloadTile(url, tileFile, metaFile, isBackground: false);
            if (success) {
              successCount++;
            } else {
              errorCount++;
            }
          }
        } catch (e) {
          errorCount++;
        }

        if (index % 100 == 0) {
          print('[Prefetch] Progress: $index/${tilesToFetch.length} (Cached: $cachedCount, Downloaded: $successCount, Fail: $errorCount)');
        }
      }

      print('[Prefetch] Finished. Total: ${tilesToFetch.length}, Cached/Verified: $cachedCount, New Downloaded: $successCount, Errors: $errorCount');
    } catch (e) {
      print('[Prefetch] Fatal error in prefetcher: $e');
    } finally {
      _isPrefetching = false;
    }
  }

  /// Downloads/Validates a tile using ETag/Last-Modified headers. Returns true if successful.
  static Future<bool> _validateAndDownloadTile(
    String url,
    File tileFile,
    File metaFile, {
    required bool isBackground,
  }) async {
    try {
      final Map<String, String> headers = {};
      if (await metaFile.exists()) {
        try {
          final metaJson = jsonDecode(await metaFile.readAsString());
          final etag = metaJson['etag'];
          final lastModified = metaJson['lastModified'];
          if (etag != null) headers['If-None-Match'] = etag;
          if (lastModified != null) headers['If-Modified-Since'] = lastModified;
        } catch (_) {}
      }

      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        await tileFile.parent.create(recursive: true);
        await tileFile.writeAsBytes(bytes);

        final etag = response.headers['etag'];
        final lastModified = response.headers['last-modified'];
        
        await metaFile.parent.create(recursive: true);
        await metaFile.writeAsString(jsonEncode({
          'etag': ?etag,
          'lastModified': ?lastModified,
        }));
        return true;
      } else if (response.statusCode == 304) {
        // Tile is unmodified
        return true;
      }
    } catch (e) {
      if (!isBackground) {
        print('[Prefetch] Failed to download tile $url: $e');
      }
    }
    return false;
  }
}

class _Semaphore {
  final int maxCount;
  int _currentCount = 0;
  final Queue<Completer<void>> _queue = Queue();

  _Semaphore(this.maxCount);

  Future<void> acquire() async {
    if (_currentCount < maxCount) {
      _currentCount++;
      return;
    }
    final completer = Completer<void>();
    _queue.add(completer);
    return completer.future;
  }

  void release() {
    if (_queue.isNotEmpty) {
      final completer = _queue.removeFirst();
      completer.complete();
    } else {
      _currentCount--;
    }
  }
}

final _bgSemaphore = _Semaphore(4);

/// Custom ImageProvider to handle tile caching and background revalidation
class CachedTileImageProvider extends ImageProvider<CachedTileImageProvider> {
  final String url;
  final File tileFile;
  final File metaFile;
  static ui.ImmutableBuffer? _fallbackBuffer;

  CachedTileImageProvider({
    required this.url,
    required this.tileFile,
    required this.metaFile,
  });

  @override
  Future<CachedTileImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<CachedTileImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(CachedTileImageProvider key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      debugLabel: key.url,
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<CachedTileImageProvider>('Image key', key),
      ],
    );
  }

  Future<ui.Codec> _loadAsync(CachedTileImageProvider key, ImageDecoderCallback decode) async {
    try {
      final fileExists = await key.tileFile.exists();

      if (fileExists) {
        // 1. Read cached image bytes from disk
        final Uint8List bytes = await key.tileFile.readAsBytes();
        
        // 2. Trigger asynchronous background check with server (no UI blocking)
        _validateCacheInBackground(key);
        
        // 3. Return decoded image instantly from cache
        return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
      } else {
        // 1. No cache exists. Must perform a blocking network request.
        final bytes = await _downloadTile(key);
        if (bytes != null) {
          return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
        }
      }
    } catch (e) {
      print('Error loading tile image: $e');
    }

    // 2. Fallback: transparent 1x1 png if everything fails (so map doesn't break)
    _fallbackBuffer ??= await ui.ImmutableBuffer.fromUint8List(_kTransparentImageBytes);
    return decode(_fallbackBuffer!);
  }

  /// Downloads the tile, saves it to disk with metadata, and returns the raw bytes
  Future<Uint8List?> _downloadTile(CachedTileImageProvider key) async {
    try {
      final response = await http.get(Uri.parse(key.url));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        
        // Write to disk
        await key.tileFile.parent.create(recursive: true);
        await key.tileFile.writeAsBytes(bytes);

        // Store ETag/Last-Modified metadata
        final etag = response.headers['etag'];
        final lastModified = response.headers['last-modified'];
        
        await key.metaFile.parent.create(recursive: true);
        await key.metaFile.writeAsString(jsonEncode({
          'etag': ?etag,
          'lastModified': ?lastModified,
        }));

        return bytes;
      }
    } catch (e) {
      print('Network download failed for tile: ${key.url} ($e)');
    }
    return null;
  }

  /// Perform asynchronous HTTP Headers verification in the background
  Future<void> _validateCacheInBackground(CachedTileImageProvider key) async {
    await _bgSemaphore.acquire();
    try {
      final Map<String, String> headers = {};
      if (await key.metaFile.exists()) {
        try {
          final metaJson = jsonDecode(await key.metaFile.readAsString());
          final etag = metaJson['etag'];
          final lastModified = metaJson['lastModified'];
          if (etag != null) headers['If-None-Match'] = etag;
          if (lastModified != null) headers['If-Modified-Since'] = lastModified;
        } catch (_) {}
      }

      final response = await http.get(Uri.parse(key.url), headers: headers);

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        await key.tileFile.parent.create(recursive: true);
        await key.tileFile.writeAsBytes(bytes);

        final etag = response.headers['etag'];
        final lastModified = response.headers['last-modified'];
        await key.metaFile.writeAsString(jsonEncode({
          'etag': ?etag,
          'lastModified': ?lastModified,
        }));
      }
    } catch (_) {
      // Ignore background network errors (e.g. user is offline)
    } finally {
      _bgSemaphore.release();
    }
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is CachedTileImageProvider && other.url == url;
  }

  @override
  int get hashCode => url.hashCode;
}

// 1x1 transparent PNG fallback bytes
final Uint8List _kTransparentImageBytes = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
]);
