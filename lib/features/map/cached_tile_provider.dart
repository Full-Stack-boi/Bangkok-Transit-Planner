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
import 'package:flutter/services.dart' show rootBundle;
import '../../models/station.dart';
import 'package:bkk_transit_planner/core/utils/logger.dart';

/// Custom tile provider that caches map tiles locally on disk and uses
/// HTTP Headers (ETag / Last-Modified) to check for updates asynchronously.
class CachedTileProvider extends TileProvider {
  CachedTileProvider();

  static String? _resolvedCachePath;
  static bool _isPrefetching = false;
  static bool isPaused = false;
  static const String _bundleVersion = '2026-06-21-v3';
  static final Set<String> _looseTilePaths = {};

  /// Get the local cache directory path for map tiles
  static Future<String> getCachePath() async {
    if (kIsWeb) return '';
    if (_resolvedCachePath != null) return _resolvedCachePath!;
    final supportDir = await getApplicationSupportDirectory();
    _resolvedCachePath = '${supportDir.path}/map_tiles';
    
    final bundleFile = File('$_resolvedCachePath/map_tiles.bundle');
    final versionFile = File('$_resolvedCachePath/map_tiles.bundle.ver');
    
    bool needsCopy = false;
    if (!await bundleFile.exists()) {
      needsCopy = true;
    } else {
      if (!await versionFile.exists()) {
        needsCopy = true;
      } else {
        final cachedVersion = await versionFile.readAsString();
        if (cachedVersion.trim() != _bundleVersion) {
          needsCopy = true;
        }
      }
    }
    
    if (needsCopy) {
      AppLogger.info('Bundle needs copy or update. Copying from assets...', tag: 'MapCache');
      try {
        await copyBundleAsset('assets/map_tiles.bundle', bundleFile.path);
        await versionFile.parent.create(recursive: true);
        await versionFile.writeAsString(_bundleVersion, flush: true);
      } catch (e) {
        AppLogger.error('Failed to copy/update bundle: $e', tag: 'MapCache', error: e);
      }
    }
    
    // Auto initialize MapBundleManager once target directory path is resolved
    await MapBundleManager.instance.init(bundleFile.path);
    
    // Scan updates folder to populate in-memory loose file path tracker
    try {
      _looseTilePaths.clear();
      final updatesDir = Directory('$_resolvedCachePath/updates');
      if (await updatesDir.exists()) {
        final entities = updatesDir.listSync(recursive: true);
        for (final entity in entities) {
          if (entity is File && entity.path.endsWith('.png')) {
            _looseTilePaths.add(entity.path);
          }
        }
      }
    } catch (e) {
      AppLogger.error('Failed to populate loose tile paths: $e', tag: 'MapCache');
    }
    
    return _resolvedCachePath!;
  }

  /// Generates a stable and readable folder name from a URL template.
  /// Using String.hashCode is unstable for persistent storage because it can
  /// change across runs, compilations, or platform environments.
  static String getFolderHash(String urlTemplate) {
    if (urlTemplate.contains('dark_all')) {
      return 'dark_all';
    } else if (urlTemplate.contains('voyager') || urlTemplate.contains('rastertiles')) {
      return 'voyager';
    } else {
      // Fallback: sanitize URL template to make it a safe directory name
      return urlTemplate
          .replaceAll('://', '_')
          .replaceAll('/', '_')
          .replaceAll('{', '')
          .replaceAll('}', '')
          .replaceAll('.', '_')
          .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
    }
  }

  /// Copies the map tiles bundle binary asset directly to the local disk cache
  static Future<void> copyBundleAsset(String assetPath, String targetPath) async {
    try {
      AppLogger.info('Copying map tiles bundle from $assetPath to $targetPath...', tag: 'MapCache');
      final file = File(targetPath);
      await file.parent.create(recursive: true);

      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

      await file.writeAsBytes(bytes, flush: true);
      AppLogger.success('Bundle asset copied successfully (${bytes.length} bytes).', tag: 'MapCache');
    } catch (e) {
      AppLogger.error('Failed to copy bundle asset: $e', tag: 'MapCache', error: e);
      rethrow;
    }
  }

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return MemoryImage(Uint8List.fromList(<int>[
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49,
        0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06,
        0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44,
        0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D,
        0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
        0x60, 0x82,
      ]));
    }
    
    final url = getTileUrl(coordinates, options);
    if (kIsWeb) {
      return NetworkImage(url);
    }
    final folderHash = getFolderHash(options.urlTemplate ?? 'default');
    final cacheDir = _resolvedCachePath;
    if (cacheDir == null) {
      // Safe fallback if not initialized
      return NetworkImage(url);
    }
    
    // Writable updates go to updates/ folder. The bundle provides base tiles.
    final tileFile = File('$cacheDir/updates/$folderHash/${coordinates.z}/${coordinates.x}/${coordinates.y}.png');
    final metaFile = File('$cacheDir/updates/$folderHash/${coordinates.z}/${coordinates.x}/${coordinates.y}.meta');

    if (kDebugMode) {
      AppLogger.info('getImage URL: $url, Path: ${tileFile.path}', tag: 'MapTile');
    }

    return CachedTileImageProvider(
      url: url,
      tileFile: tileFile,
      metaFile: metaFile,
      z: coordinates.z.toInt(),
      x: coordinates.x.toInt(),
      y: coordinates.y.toInt(),
      cacheDir: cacheDir,
      folderHash: folderHash,
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
  /// Result codes for tile prefetching
  static const int _tileSuccess = 0;
  static const int _tileUnmodified = 1;
  static const int _tileErrorHttp = 2;
  static const int _tileErrorNetwork = 3;

  /// Prefetch map tiles for the Bangkok transit network in the background.
  /// Loops through all stations and downloads tiles for zoom levels 12 to 15 (with surrounding padding).
  static Future<void> prefetchBangkokTiles(
    List<Station> stations, {
    void Function(int total)? onStart,
    void Function(int current, int success, int cached, int error)? onProgress,
    void Function(bool completed, bool lostConnection)? onFinish,
  }) async {
    if (kIsWeb) return;
    if (_isPrefetching) {
      AppLogger.info('Already running. Skipping start.', tag: 'Prefetch');
      return;
    }
    _isPrefetching = true;
    isPaused = false;
    bool completed = false;
    bool lostConnection = false;

    try {
      final cacheDir = await getCachePath();
      AppLogger.info('Starting background map prefetch for ${stations.length} stations in Bangkok...', tag: 'Prefetch');

      // Three-tier bounding box definitions
      const bMinLat = 13.10;
      const bMaxLat = 14.70;
      const bMinLng = 99.50;
      const bMaxLng = 101.50;
      
      const tMinLat = 13.51;
      const tMaxLat = 13.99;
      const tMinLng = 100.35;
      const tMaxLng = 100.81;

      final double devicePixelRatio = ui.PlatformDispatcher.instance.views.isNotEmpty
          ? ui.PlatformDispatcher.instance.views.first.devicePixelRatio
          : 1.0;
      final String rValue = devicePixelRatio > 1.0 ? '@2x' : '';

      final targets = [
        {
          'template': 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}$rValue.png',
          'hash': getFolderHash('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'),
        },
        {
          'template': 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}$rValue.png',
          'hash': getFolderHash('https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png'),
        }
      ];

      final tilesToFetch = <String>{};

      // 1. Broad BBox Low Zooms (10-12)
      for (int z = 10; z <= 12; z++) {
        final xMin = lonToTileX(bMinLng, z);
        final xMax = lonToTileX(bMaxLng, z);
        final yMin = latToTileY(bMaxLat, z);
        final yMax = latToTileY(bMinLat, z);
        for (int tx = xMin; tx <= xMax; tx++) {
          for (int ty = yMin; ty <= yMax; ty++) {
            for (final target in targets) {
              tilesToFetch.add('${target['hash']}:$z:$tx:$ty:${target['template']}');
            }
          }
        }
      }

      // 2. Transit BBox Medium/High Zooms (13-15)
      for (int z = 13; z <= 15; z++) {
        final xMin = lonToTileX(tMinLng, z);
        final xMax = lonToTileX(tMaxLng, z);
        final yMin = latToTileY(tMaxLat, z);
        final yMax = latToTileY(tMinLat, z);
        for (int tx = xMin; tx <= xMax; tx++) {
          for (int ty = yMin; ty <= yMax; ty++) {
            for (final target in targets) {
              tilesToFetch.add('${target['hash']}:$z:$tx:$ty:${target['template']}');
            }
          }
        }
      }

      // 3. Station Centers Zoom (16-17)
      for (final station in stations) {
        if (station.lat < bMinLat || station.lat > bMaxLat || station.lng < bMinLng || station.lng > bMaxLng) {
          continue;
        }

        for (int z in [16, 17]) {
          final tx = lonToTileX(station.lng, z);
          final ty = latToTileY(station.lat, z);
          for (final target in targets) {
            tilesToFetch.add('${target['hash']}:$z:$tx:$ty:${target['template']}');
          }
        }
      }

      AppLogger.info('Deduplicated total tiles to fetch: ${tilesToFetch.length}', tag: 'Prefetch');
      onStart?.call(tilesToFetch.length);

      int successCount = 0;
      int cachedCount = 0;
      int errorCount = 0;
      int index = 0;
      int consecutiveNetworkErrors = 0;

      final workerSemaphore = _Semaphore(12); // Up to 12 concurrent workers
      final List<Future<void>> tasks = [];

      for (final tileInfo in tilesToFetch) {
        if (isPaused) {
          break;
        }
        await workerSemaphore.acquire();
        tasks.add(Future(() async {
          try {
            if (isPaused) return;

            final parts = tileInfo.split(':');
            final folderHash = parts[0];
            final z = int.parse(parts[1]);
            final x = int.parse(parts[2]);
            final y = int.parse(parts[3]);
            final urlTemplate = parts.sublist(4).join(':');

            final url = urlTemplate
                .replaceAll('{z}', z.toString())
                .replaceAll('{x}', x.toString())
                .replaceAll('{y}', y.toString());

            final tileFile = File('$cacheDir/$folderHash/$z/$x/$y.png');
            final metaFile = File('$cacheDir/$folderHash/$z/$x/$y.meta');

            if (await tileFile.exists() || MapBundleManager.instance.hasTile(folderHash, z, x, y)) {
              cachedCount++;
            } else {
              final status = await _downloadTileStatus(url, tileFile, metaFile);
              if (status == _tileSuccess || status == _tileUnmodified) {
                successCount++;
                consecutiveNetworkErrors = 0;
              } else if (status == _tileErrorHttp) {
                errorCount++;
                consecutiveNetworkErrors = 0;
              } else if (status == _tileErrorNetwork) {
                errorCount++;
                consecutiveNetworkErrors++;
                if (consecutiveNetworkErrors >= 3) {
                  AppLogger.error('Lost internet connection (3 consecutive network errors). Pausing prefetch.', tag: 'Prefetch');
                  isPaused = true;
                  lostConnection = true;
                }
              }
            }
          } catch (e) {
            errorCount++;
          } finally {
            index++;
            onProgress?.call(index, successCount, cachedCount, errorCount);
            if (index % 100 == 0 || index == tilesToFetch.length) {
              AppLogger.info('Progress: $index/${tilesToFetch.length} (Cached: $cachedCount, Downloaded: $successCount, Fail: $errorCount)', tag: 'Prefetch');
            }
            workerSemaphore.release();
          }
        }));
      }

      await Future.wait(tasks);

      AppLogger.success('Finished. Total: ${tilesToFetch.length}, Cached/Verified: $cachedCount, New Downloaded: $successCount, Errors: $errorCount', tag: 'Prefetch');
      if (!isPaused && index == tilesToFetch.length) {
        completed = true;
      }
    } catch (e) {
      AppLogger.error('Fatal error in prefetcher: $e', tag: 'Prefetch', error: e);
    } finally {
      _isPrefetching = false;
      onFinish?.call(completed, lostConnection);
    }
  }

  /// Downloads/Validates a tile using ETag/Last-Modified headers. Returns status code.
  static Future<int> _downloadTileStatus(
    String url,
    File tileFile,
    File metaFile,
  ) async {
    try {
      final Map<String, String> headers = {
        'User-Agent': 'com.bkktransit.bkk_transit_planner',
      };
      if (await metaFile.exists()) {
        try {
          final metaJson = jsonDecode(await metaFile.readAsString());
          final etag = metaJson['etag'];
          final lastModified = metaJson['lastModified'];
          if (etag != null) headers['If-None-Match'] = etag;
          if (lastModified != null) headers['If-Modified-Since'] = lastModified;
        } catch (_) {}
      }

      final response = await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        await tileFile.parent.create(recursive: true);
        await tileFile.writeAsBytes(bytes);
        _looseTilePaths.add(tileFile.path);

        final etag = response.headers['etag'];
        final lastModified = response.headers['last-modified'];
        
        await metaFile.parent.create(recursive: true);
        await metaFile.writeAsString(jsonEncode({
          'etag': etag,
          'lastModified': lastModified,
        }));
        return _tileSuccess;
      } else if (response.statusCode == 304) {
        return _tileUnmodified;
      } else {
        return _tileErrorHttp;
      }
    } on SocketException catch (_) {
      return _tileErrorNetwork;
    } on HttpException catch (_) {
      return _tileErrorNetwork;
    } on TimeoutException catch (_) {
      return _tileErrorNetwork;
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('ClientException') || errStr.contains('SocketException') || errStr.contains('Failed host lookup')) {
        return _tileErrorNetwork;
      }
      return _tileErrorHttp;
    }
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
  final int z;
  final int x;
  final int y;
  final String cacheDir;
  final String folderHash;

  CachedTileImageProvider({
    required this.url,
    required this.tileFile,
    required this.metaFile,
    required this.z,
    required this.x,
    required this.y,
    required this.cacheDir,
    required this.folderHash,
  });

  @override
  Future<CachedTileImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<CachedTileImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(CachedTileImageProvider key, ImageDecoderCallback decode) {
    final completer = Completer<ImageInfo>();
    _loadAsync(key, decode, completer);
    return OneFrameImageStreamCompleter(completer.future);
  }

  Future<void> _loadAsync(
    CachedTileImageProvider key,
    ImageDecoderCallback decode,
    Completer<ImageInfo> completer,
  ) async {
    try {
      // 1. Check updates folder (loose downloaded tiles) first
      final fileExists = CachedTileProvider._looseTilePaths.contains(key.tileFile.path);
      if (kDebugMode) {
        AppLogger.info('Loading tile (${key.z}, ${key.x}, ${key.y}). Loose file exists: $fileExists, Path: ${key.tileFile.path}', tag: 'MapTile');
      }

      if (fileExists) {
        final length = await key.tileFile.length();
        if (length == 0) {
          try {
            await key.tileFile.delete();
            CachedTileProvider._looseTilePaths.remove(key.tileFile.path);
          } catch (_) {}
        } else {
          final Uint8List bytes = await key.tileFile.readAsBytes();
          _validateCacheInBackground(key);
          
          try {
            final codec = await decode(await ui.ImmutableBuffer.fromUint8List(bytes));
            final frame = await codec.getNextFrame();
            completer.complete(ImageInfo(image: frame.image, scale: 1.0));
            if (kDebugMode) {
              AppLogger.success('Successfully decoded tile (${key.z}, ${key.x}, ${key.y}) from updates folder.', tag: 'MapTile');
            }
            return;
          } catch (e, stackTrace) {
            AppLogger.error('Error decoding tile (${key.z}, ${key.x}, ${key.y}) from updates: $e\n$stackTrace', tag: 'MapTile', error: e);
            try {
              await key.tileFile.delete();
              CachedTileProvider._looseTilePaths.remove(key.tileFile.path);
            } catch (_) {}
          }
        }
      }

      // 2. Check binary bundle second
      final bundleBytes = await MapBundleManager.instance.readTile(key.folderHash, key.z, key.x, key.y);
      if (bundleBytes != null && bundleBytes.isNotEmpty) {
        try {
          final codec = await decode(await ui.ImmutableBuffer.fromUint8List(bundleBytes));
          final frame = await codec.getNextFrame();
          completer.complete(ImageInfo(image: frame.image, scale: 1.0));
          if (kDebugMode) {
            AppLogger.success('Successfully decoded tile (${key.z}, ${key.x}, ${key.y}) from bundle.', tag: 'MapTile');
          }
          return;
        } catch (e, stackTrace) {
          AppLogger.error('Error decoding tile (${key.z}, ${key.x}, ${key.y}) from bundle: $e\n$stackTrace', tag: 'MapTile', error: e);
        }
      }

      // 3. Cache miss: Perform network request
      if (kDebugMode) {
        AppLogger.info('Cache miss for tile (${key.z}, ${key.x}, ${key.y}). Fetching from network: ${key.url}', tag: 'MapTile');
      }
      final bytes = await _downloadTile(key);
      if (bytes != null && bytes.isNotEmpty) {
        try {
          final codec = await decode(await ui.ImmutableBuffer.fromUint8List(bytes));
          final frame = await codec.getNextFrame();
          completer.complete(ImageInfo(image: frame.image, scale: 1.0));
          if (kDebugMode) {
            AppLogger.success('Successfully decoded tile (${key.z}, ${key.x}, ${key.y}) from network.', tag: 'MapTile');
          }
          return;
        } catch (e, stackTrace) {
          AppLogger.error('Error decoding tile (${key.z}, ${key.x}, ${key.y}) from network: $e\n$stackTrace', tag: 'MapTile', error: e);
        }
      }

      // 4. Fallback: try to crop/scale from an ancestor tile in the updates folder
      if (kDebugMode) {
        AppLogger.info('Attempting ancestor fallback for tile (${key.z}, ${key.x}, ${key.y})...', tag: 'MapTile');
      }
      final fallbackImage = await _fallbackFromAncestor(key);
      if (fallbackImage != null) {
        completer.complete(ImageInfo(image: fallbackImage, scale: 1.0));
        return;
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error in _loadAsync for tile (${key.z}, ${key.x}, ${key.y}): $e\n$stackTrace', tag: 'MapTile', error: e);
    }

    // 5. Hard fallback: transparent 1x1 png
    try {
      final codec = await ui.instantiateImageCodec(_kTransparentImageBytes);
      final frame = await codec.getNextFrame();
      completer.complete(ImageInfo(image: frame.image, scale: 1.0));
    } catch (e, stackTrace) {
      completer.completeError(e, stackTrace);
    }
  }

  /// Searches the local cache for the nearest ancestor tile (from z-1 down to 10)
  Future<ui.Image?> _fallbackFromAncestor(CachedTileImageProvider key) async {
    int currentZ = key.z - 1;
    int currentX = key.x;
    int currentY = key.y;

    while (currentZ >= 10) {
      currentX = currentX >> 1;
      currentY = currentY >> 1;
      final file = File('${key.cacheDir}/${key.folderHash}/$currentZ/$currentX/$currentY.png');
      if (await file.exists()) {
        try {
          return await _cropAndScaleAncestor(file, currentZ, currentX, currentY, key.z, key.x, key.y);
        } catch (e) {
          AppLogger.error('Failed to crop ancestor tile ($currentZ, $currentX, $currentY) for child (${key.z}, ${key.x}, ${key.y}): $e', error: currentZ);
        }
      }
      currentZ--;
    }
    return null;
  }

  /// Decodes parent tile, calculates the child bounds within the parent, crops and scales it on a canvas.
  Future<ui.Image> _cropAndScaleAncestor(
    File file,
    int parentZ,
    int parentX,
    int parentY,
    int childZ,
    int childX,
    int childY,
  ) async {
    final parentBytes = await file.readAsBytes();
    final buffer = await ui.ImmutableBuffer.fromUint8List(parentBytes);
    final codec = await ui.instantiateImageCodecFromBuffer(buffer);
    final frame = await codec.getNextFrame();
    final ui.Image parentImage = frame.image;

    final pictureRecorder = ui.PictureRecorder();
    final canvas = ui.Canvas(pictureRecorder);

    final int dz = childZ - parentZ;
    final int scale = 1 << dz;
    final double subSize = 256.0 / scale;

    final double srcX = (childX - (parentX << dz)) * subSize;
    final double srcY = (childY - (parentY << dz)) * subSize;

    final srcRect = ui.Rect.fromLTWH(srcX, srcY, subSize, subSize);
    final dstRect = const ui.Rect.fromLTWH(0, 0, 256, 256);

    final paint = ui.Paint()
      ..filterQuality = ui.FilterQuality.medium
      ..isAntiAlias = true;

    canvas.drawImageRect(parentImage, srcRect, dstRect, paint);

    final picture = pictureRecorder.endRecording();
    final croppedImage = await picture.toImage(256, 256);

    parentImage.dispose();
    // Do NOT dispose croppedImage because it is passed back and used in ImageInfo

    return croppedImage;
  }

  /// Downloads the tile, saves it to disk with metadata, and returns the raw bytes
  Future<Uint8List?> _downloadTile(CachedTileImageProvider key) async {
    try {
      final response = await http.get(
        Uri.parse(key.url),
        headers: {
          'User-Agent': 'com.bkktransit.bkk_transit_planner',
        },
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        
        // Write to disk
        await key.tileFile.parent.create(recursive: true);
        await key.tileFile.writeAsBytes(bytes);
        CachedTileProvider._looseTilePaths.add(key.tileFile.path);

        // Store ETag/Last-Modified metadata
        final etag = response.headers['etag'];
        final lastModified = response.headers['last-modified'];
        
        await key.metaFile.parent.create(recursive: true);
        await key.metaFile.writeAsString(jsonEncode({
          'etag': etag,
          'lastModified': lastModified,
        }));

        return bytes;
      }
    } catch (e) {
      AppLogger.error('Network download failed for tile: ${key.url} ($e)', error: e);
    }
    return null;
  }

  /// Perform asynchronous HTTP Headers verification in the background
  Future<void> _validateCacheInBackground(CachedTileImageProvider key) async {
    try {
      if (await key.metaFile.exists()) {
        final lastMod = await key.metaFile.lastModified();
        if (DateTime.now().difference(lastMod).inDays < 7) {
          // Skip verification if checked within the last 7 days
          return;
        }
      }
    } catch (_) {
      // If error reading file mod time, proceed with fallback check
    }

    await _bgSemaphore.acquire();
    try {
      final Map<String, String> headers = {
        'User-Agent': 'com.bkktransit.bkk_transit_planner',
      };
      if (await key.metaFile.exists()) {
        try {
          final metaJson = jsonDecode(await key.metaFile.readAsString());
          final etag = metaJson['etag'];
          final lastModified = metaJson['lastModified'];
          if (etag != null) headers['If-None-Match'] = etag;
          if (lastModified != null) headers['If-Modified-Since'] = lastModified;
        } catch (_) {}
      }

      final response = await http.get(Uri.parse(key.url), headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        await key.tileFile.parent.create(recursive: true);
        await key.tileFile.writeAsBytes(bytes);
        CachedTileProvider._looseTilePaths.add(key.tileFile.path);

        final etag = response.headers['etag'];
        final lastModified = response.headers['last-modified'];
        await key.metaFile.writeAsString(jsonEncode({
          'etag': etag,
          'lastModified': lastModified,
        }));
      } else if (response.statusCode == 304) {
        // Tile is still unmodified. Reset the 7-day validation window
        // by updating the metadata file's modification time.
        try {
          await key.metaFile.setLastModified(DateTime.now());
        } catch (_) {}
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
    return other is CachedTileImageProvider &&
        other.folderHash == folderHash &&
        other.z == z &&
        other.x == x &&
        other.y == y;
  }

  @override
  int get hashCode => Object.hash(folderHash, z, x, y);
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

/// Manages random access reads from the compressed binary bundle `map_tiles.bundle`
class MapBundleManager {
  static final MapBundleManager instance = MapBundleManager._();
  MapBundleManager._();

  RandomAccessFile? _bundleFile;
  final Map<String, List<int>> _index = {};
  bool _initialized = false;
  final _FutureChain _lock = _FutureChain();
  final LinkedHashMap<String, Uint8List> _tileBytesCache = LinkedHashMap();
  int _maxCacheLimit = 64;

  void setMaxCacheLimit(int limit) {
    _maxCacheLimit = limit;
    while (_tileBytesCache.length > _maxCacheLimit) {
      _tileBytesCache.remove(_tileBytesCache.keys.first);
    }
  }

  void clearCache() {
    _tileBytesCache.clear();
  }

  Future<void> init(String bundlePath) async {
    if (_initialized) return;
    try {
      final file = File(bundlePath);
      if (!await file.exists()) {
        AppLogger.info('Bundle file not found at $bundlePath. App will fall back to network.', tag: 'MapBundle');
        return;
      }
      _bundleFile = await file.open(mode: FileMode.read);
      
      final int fileLength = await file.length();
      if (fileLength < 4) {
        AppLogger.info('Corrupt bundle: file too short.', tag: 'MapBundle');
        return;
      }
      
      // Read last 4 bytes to get the index offset pointer
      await _bundleFile!.setPosition(fileLength - 4);
      final offsetBytes = await _bundleFile!.read(4);
      if (offsetBytes.length != 4) {
        AppLogger.error('Corrupt bundle: failed to read index offset pointer.', tag: 'MapBundle');
        return;
      }
      final int indexOffset = ByteData.sublistView(Uint8List.fromList(offsetBytes)).getUint32(0, Endian.big);
      
      // Seek to indexOffset and read the compressed index
      final int indexLength = fileLength - 4 - indexOffset;
      if (indexLength <= 0 || indexOffset < 0 || indexOffset >= fileLength) {
        AppLogger.info('Corrupt bundle: invalid index offset ($indexOffset) or length ($indexLength).', tag: 'MapBundle');
        return;
      }
      
      await _bundleFile!.setPosition(indexOffset);
      final compressedBytes = await _bundleFile!.read(indexLength);
      if (compressedBytes.length != indexLength) {
        AppLogger.error('Corrupt bundle: failed to read compressed index data.', tag: 'MapBundle');
        return;
      }
      
      // Decompress index
      final decompressedBytes = gzip.decode(compressedBytes);
      final jsonStr = utf8.decode(decompressedBytes);
      final Map<String, dynamic> rawMap = jsonDecode(jsonStr);
      
      rawMap.forEach((key, value) {
        if (value is List) {
          _index[key] = List<int>.from(value);
        }
      });
      
      _initialized = true;
      AppLogger.success('Initialized successfully. Loaded ${_index.length} tile references.', tag: 'MapBundle');
    } catch (e, stackTrace) {
      AppLogger.error('Initialization failed: $e\n$stackTrace', tag: 'MapBundle', error: e);
      await close();
    }
  }

  bool hasTile(String folderHash, int z, int x, int y) {
    if (!_initialized) return false;
    final key = '$folderHash/$z/$x/$y.webp';
    return _index.containsKey(key);
  }

  Future<Uint8List?> readTile(String folderHash, int z, int x, int y) async {
    if (!_initialized || _bundleFile == null) return null;
    final key = '$folderHash/$z/$x/$y.webp';

    // Check in-memory LRU bytes cache
    final cachedBytes = _tileBytesCache[key];
    if (cachedBytes != null) {
      // Move to end of LinkedHashMap (MRU order)
      _tileBytesCache.remove(key);
      _tileBytesCache[key] = cachedBytes;
      return cachedBytes;
    }

    final range = _index[key];
    if (range == null) return null;
    
    final int offset = range[0];
    final int length = range[1];
    
    try {
      // Synchronize sets and reads to prevent race conditions on RandomAccessFile position
      final bytes = await _lock.synchronized(() async {
        await _bundleFile!.setPosition(offset);
        final readBytes = await _bundleFile!.read(length);
        return readBytes;
      });

      if (bytes.isNotEmpty) {
        // Enforce dynamic limit
        if (_tileBytesCache.length >= _maxCacheLimit) {
          _tileBytesCache.remove(_tileBytesCache.keys.first); // remove oldest
        }
        _tileBytesCache[key] = bytes;
      }
      return bytes;
    } catch (e, stackTrace) {
      AppLogger.error('Error reading tile $key from bundle: $e\n$stackTrace', tag: 'MapBundle', error: key);
      return null;
    }
  }

  Future<void> close() async {
    _initialized = false;
    _index.clear();
    _tileBytesCache.clear();
    try {
      await _bundleFile?.close();
    } catch (_) {}
    _bundleFile = null;
  }
}

class _FutureChain {
  Future<void> _chain = Future.value();
  
  Future<T> synchronized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _chain = _chain.then((_) async {
      try {
        final result = await action();
        completer.complete(result);
      } catch (e, s) {
        completer.completeError(e, s);
      }
    });
    return completer.future;
  }
}
