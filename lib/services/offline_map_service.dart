import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:archive/archive.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:bkk_transit_planner/core/utils/logger.dart';

class OfflineMapStatus {
  final bool isInstalled;
  final int fileSizeBytes;
  final DateTime? lastModified;

  const OfflineMapStatus({
    required this.isInstalled,
    required this.fileSizeBytes,
    this.lastModified,
  });

  String get formattedSize {
    if (fileSizeBytes <= 0) return '0 MB';
    final mb = fileSizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class OfflineMapService {
  static const String _metaFileName = 'offline_bangkok_meta.json';
  static const String _bundleAssetPath =
      'assets/data/bangkok_vector_offline.tar.gz';

  static OfflineMapService? _instance;
  static OfflineMapService get instance => _instance ??= OfflineMapService._();
  OfflineMapService._();

  http.Client? _activeClient;
  bool _isDownloading = false;
  bool get isDownloading => _isDownloading;

  // FNV-1a 64-bit hash matching flutter_map_vector_tiles DiskCache
  static String fnv1a(String input) {
    var hash = (0xcbf29ce4 << 32) | 0x84222325;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash *= 0x100000001b3;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  Future<Directory> getVectorTileCacheDir() async {
    final supportDir = await getApplicationSupportDirectory();
    final dir = Directory(
      '${supportDir.path}${Platform.pathSeparator}flutter_map_vector_tiles',
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _getMetaFile() async {
    final supportDir = await getApplicationSupportDirectory();
    return File('${supportDir.path}${Platform.pathSeparator}$_metaFileName');
  }

  Future<({int totalBytes, int fileCount, DateTime? latestMod})>
      _scanDiskCache() async {
    final cacheDir = await getVectorTileCacheDir();
    int totalBytes = 0;
    int fileCount = 0;
    DateTime? latestMod;

    if (await cacheDir.exists()) {
      await for (final entity in cacheDir.list(recursive: true)) {
        if (entity is File && entity.path.endsWith('.bin')) {
          try {
            final stat = await entity.stat();
            totalBytes += stat.size;
            fileCount++;
            if (latestMod == null || stat.modified.isAfter(latestMod)) {
              latestMod = stat.modified;
            }
          } catch (e) {
            AppLogger.debug('Failed to stat cached file $entity: $e');
          }
        }
      }
    }

    return (
      totalBytes: totalBytes,
      fileCount: fileCount,
      latestMod: latestMod,
    );
  }

  /// Automatically unpacks bundled offline map on first app launch
  Future<void> initOfflineMapFromAssets() async {
    try {
      final diskStats = await _scanDiskCache();
      if (diskStats.fileCount >= 100) {
        return; // Already initialized or downloaded
      }

      final cacheDir = await getVectorTileCacheDir();
      AppLogger.info(
        'Extracting bundled Bangkok offline vector map from $_bundleAssetPath...',
      );

      final byteData = await rootBundle.load(_bundleAssetPath);
      final bytes = byteData.buffer.asUint8List();

      final gzipDecoder = GZipDecoder();
      final decompressedTar = gzipDecoder.decodeBytes(bytes);
      final tarDecoder = TarDecoder();
      final archive = tarDecoder.decodeBytes(decompressedTar);

      int totalBytes = 0;
      int tileCount = 0;

      for (final file in archive.files) {
        if (file.isFile) {
          final outPath =
              '${cacheDir.path}${Platform.pathSeparator}${file.name.replaceAll('/', Platform.pathSeparator)}';
          final outFile = File(outPath);
          await outFile.parent.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>, flush: false);
          totalBytes += file.size;
          tileCount++;
        }
      }

      final metaFile = await _getMetaFile();
      await metaFile.writeAsString(
        jsonEncode({
          'isInstalled': true,
          'sizeBytes': totalBytes,
          'tileCount': tileCount,
          'timestamp': DateTime.now().toIso8601String(),
          'source': 'bundled_asset',
        }),
      );

      AppLogger.success(
        'Unpacked bundled Bangkok offline map ($tileCount files, ${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB)',
      );
    } catch (e) {
      AppLogger.error('Failed to unpack bundled offline map: $e', error: e);
    }
  }

  Future<OfflineMapStatus> getStatus() async {
    try {
      final diskStats = await _scanDiskCache();
      if (diskStats.fileCount >= 50 && diskStats.totalBytes > 0) {
        return OfflineMapStatus(
          isInstalled: true,
          fileSizeBytes: diskStats.totalBytes,
          lastModified: diskStats.latestMod ?? DateTime.now(),
        );
      }

      final metaFile = await _getMetaFile();
      if (await metaFile.exists()) {
        final content = await metaFile.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        final size = json['sizeBytes'] as int? ?? 0;
        final timestampStr = json['timestamp'] as String?;
        final timestamp =
            timestampStr != null ? DateTime.tryParse(timestampStr) : null;

        if (size > 0) {
          return OfflineMapStatus(
            isInstalled: true,
            fileSizeBytes: size,
            lastModified: timestamp,
          );
        }
      }
    } catch (e) {
      AppLogger.error('Failed to get offline map status: $e', error: e);
    }
    return const OfflineMapStatus(isInstalled: false, fileSizeBytes: 0);
  }

  Future<bool> isOfflineMapAvailable() async {
    final status = await getStatus();
    return status.isInstalled;
  }

  static int _lonToX(double lon, int zoom) {
    return ((lon + 180.0) / 360.0 * math.pow(2, zoom)).floor();
  }

  static int _latToY(double lat, int zoom) {
    final rad = lat * math.pi / 180.0;
    final n = math.log(math.tan(rad) + (1.0 / math.cos(rad)));
    return ((1.0 - n / math.pi) / 2.0 * math.pow(2, zoom)).floor();
  }

  List<({int z, int x, int y})> _generateBangkokTileCoordinates() {
    final tiles = <({int z, int x, int y})>[];

    // Bangkok Metro Bounding Box (Matches generate_bundle.dart)
    const minLat = 13.45;
    const maxLat = 14.15;
    const minLon = 100.20;
    const maxLon = 100.85;

    for (int z = 10; z <= 14; z++) {
      final minX = _lonToX(minLon, z);
      final maxX = _lonToX(maxLon, z);
      final minY = _latToY(maxLat, z);
      final maxY = _latToY(minLat, z);

      for (int x = minX; x <= maxX; x++) {
        for (int y = minY; y <= maxY; y++) {
          tiles.add((z: z, x: x, y: y));
        }
      }
    }

    return tiles;
  }

  Future<bool> downloadOrUpdate({
    void Function(int current, int total, double progress)? onProgress,
    void Function(bool success, String? error)? onComplete,
  }) async {
    if (_isDownloading) {
      onComplete?.call(false, 'Download is already in progress');
      return false;
    }

    _isDownloading = true;
    _activeClient = http.Client();

    try {
      AppLogger.info('Pre-caching OpenFreeMap vector styles and TileJSON...');

      // 1. Preload styles so style.json and sprite sheets are stored in disk cache
      try {
        final lightStyle = await vt.StyleReader(
          uri: 'https://tiles.openfreemap.org/styles/liberty',
          httpClient: _activeClient,
        ).read();
        lightStyle.dispose();

        final darkStyle = await vt.StyleReader(
          uri: 'https://tiles.openfreemap.org/styles/dark',
          httpClient: _activeClient,
        ).read();
        darkStyle.dispose();
      } catch (e) {
        AppLogger.warning('Style preload warning: $e');
      }

      // 2. Fetch TileJSON to resolve live vector tile URL template
      final planetRes = await _activeClient!.get(
        Uri.parse('https://tiles.openfreemap.org/planet'),
      );

      if (planetRes.statusCode != 200) {
        throw HttpException(
          'Failed to resolve OpenFreeMap TileJSON: ${planetRes.statusCode}',
        );
      }

      final planetJson = jsonDecode(planetRes.body) as Map<String, dynamic>;
      final tilesList = planetJson['tiles'] as List<dynamic>?;
      if (tilesList == null || tilesList.isEmpty) {
        throw const FormatException(
          'No vector tile endpoints found in TileJSON',
        );
      }

      final urlTemplate = tilesList.first.toString();
      AppLogger.info('Resolved OpenFreeMap tile template: $urlTemplate');

      // 3. Generate Bangkok tile coordinates (Zooms 10 to 14)
      final allTiles = _generateBangkokTileCoordinates();
      final totalTiles = allTiles.length;
      final cacheDir = await getVectorTileCacheDir();

      AppLogger.info(
        'Checking and updating $totalTiles Bangkok vector tiles into ${cacheDir.path}...',
      );

      int completedCount = 0;
      const concurrency = 8;
      int index = 0;

      Future<void> worker() async {
        while (true) {
          if (!_isDownloading) break;
          if (index >= totalTiles) break;
          final currentIdx = index++;
          final tile = allTiles[currentIdx];

          final tileUrl = urlTemplate
              .replaceAll('{z}', '${tile.z}')
              .replaceAll('{x}', '${tile.x}')
              .replaceAll('{y}', '${tile.y}');

          final cacheKey = '$urlTemplate/${tile.z}/${tile.x}/${tile.y}';
          final hash = fnv1a(cacheKey);
          final tileFile = File(
            '${cacheDir.path}${Platform.pathSeparator}$hash.bin',
          );

          try {
            // Check if already exists on disk and is non-empty
            final fileExists = await tileFile.exists();
            if (!fileExists || await tileFile.length() == 0) {
              final res = await _activeClient!.get(Uri.parse(tileUrl));
              if (res.statusCode == 200) {
                final bytes = res.bodyBytes;
                final tmpFile = File('${tileFile.path}.tmp');
                await tmpFile.writeAsBytes(bytes, flush: false);
                await tmpFile.rename(tileFile.path);
              }
            }
          } catch (e) {
            // Ignore single transient tile failure
          }

          completedCount++;
          final progress = (completedCount / totalTiles).clamp(0.0, 1.0);
          onProgress?.call(completedCount, totalTiles, progress);
        }
      }

      final workers = List.generate(concurrency, (_) => worker());
      await Future.wait(workers);

      // Measure real on-disk cache size
      final diskStats = await _scanDiskCache();

      // Save metadata with accurate measured size
      final metaFile = await _getMetaFile();
      await metaFile.writeAsString(
        jsonEncode({
          'isInstalled': true,
          'sizeBytes': diskStats.totalBytes,
          'tileCount': diskStats.fileCount,
          'timestamp': DateTime.now().toIso8601String(),
          'source': 'live_update',
        }),
      );

      _isDownloading = false;
      _activeClient?.close();
      _activeClient = null;

      // Invalidate memory cache so map repaints immediately without zooming in/out
      vt.VectorTileLayer.clearMemoryCache();

      AppLogger.success(
        'Bangkok offline map update complete: ${diskStats.fileCount} tiles, ${(diskStats.totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
      );
      onComplete?.call(true, null);
      return true;
    } catch (e) {
      _isDownloading = false;
      _activeClient?.close();
      _activeClient = null;

      final isOfflineNetworkError = e is SocketException ||
          e is http.ClientException ||
          e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup');

      if (isOfflineNetworkError) {
        AppLogger.warning('Cannot update offline map: Device is offline');
      } else {
        AppLogger.error('Failed to update Bangkok offline map: $e', error: e);
      }
      onComplete?.call(
        false,
        isOfflineNetworkError ? 'No internet connection' : e.toString(),
      );
      return false;
    }
  }

  void cancelDownload() {
    if (_isDownloading) {
      _isDownloading = false;
      _activeClient?.close();
      _activeClient = null;
    }
  }

  Future<bool> deleteOfflineMap() async {
    try {
      final cacheDir = await getVectorTileCacheDir();
      if (await cacheDir.exists()) {
        await for (final entity in cacheDir.list(recursive: true)) {
          if (entity is File && entity.path.endsWith('.bin')) {
            try {
              await entity.delete();
            } catch (e) {
              AppLogger.warning('Failed to delete offline map tile $entity: $e');
            }
          }
        }
      }

      final metaFile = await _getMetaFile();
      if (await metaFile.exists()) {
        await metaFile.delete();
      }

      vt.VectorTileLayer.clearMemoryCache();
      AppLogger.info('Deleted local Bangkok vector map cache.');
      return true;
    } catch (e) {
      AppLogger.error('Failed to delete offline map: $e', error: e);
    }
    return false;
  }
}
