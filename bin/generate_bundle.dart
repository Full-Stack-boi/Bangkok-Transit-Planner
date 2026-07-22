import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

int lonToTileX(double lon, int zoom) {
  return ((lon + 180.0) / 360.0 * (1 << zoom)).floor();
}

int latToTileY(double lat, int zoom) {
  final latRad = lat * pi / 180.0;
  return ((1.0 - (log(tan(latRad) + 1.0 / cos(latRad)) / pi)) /
          2.0 *
          (1 << zoom))
      .floor();
}

class TileTarget {
  final String name;
  final int z;
  final int x;
  final int y;
  final String pathTemplate;

  TileTarget({
    required this.name,
    required this.z,
    required this.x,
    required this.y,
    required this.pathTemplate,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TileTarget &&
          name == other.name &&
          z == other.z &&
          x == other.x &&
          y == other.y);

  @override
  int get hashCode => Object.hash(name, z, x, y);
}

class DownloadedTile {
  final String key;
  final Uint8List bytes;

  DownloadedTile({required this.key, required this.bytes});
}

void main() async {
  print(
    '=== Bangkok Transit Offline Map Tile Bundle Generator (Dart CLI - Fast) ===',
  );

  final stationsFile = File('assets/data/stations.json');
  if (!await stationsFile.exists()) {
    print(
      'Error: assets/data/stations.json not found. Please run from project root.',
    );
    exit(1);
  }

  final stationsJson = jsonDecode(await stationsFile.readAsString()) as List;
  print('Loaded ${stationsJson.length} stations.');

  // 1. Bounding Boxes & Targets
  const bMinLat = 13.10, bMaxLat = 14.70;
  const bMinLng = 99.50, bMaxLng = 101.50;

  const tMinLat = 13.51, tMaxLat = 13.99;
  const tMinLng = 100.35, tMaxLng = 100.81;

  final styleTemplates = [
    {'name': 'dark_all', 'path': '/dark_all/{z}/{x}/{y}@2x.png'},
    {'name': 'voyager', 'path': '/rastertiles/voyager/{z}/{x}/{y}@2x.png'},
  ];

  final Set<TileTarget> tilesToFetch = {};

  // Tier 1: Low Zooms (10-12) over Broad BBox
  for (int z = 10; z <= 12; z++) {
    final xMin = lonToTileX(bMinLng, z);
    final xMax = lonToTileX(bMaxLng, z);
    final yMin = latToTileY(bMaxLat, z);
    final yMax = latToTileY(bMinLat, z);
    for (int tx = xMin; tx <= xMax; tx++) {
      for (int ty = yMin; ty <= yMax; ty++) {
        for (final style in styleTemplates) {
          tilesToFetch.add(
            TileTarget(
              name: style['name']!,
              z: z,
              x: tx,
              y: ty,
              pathTemplate: style['path']!,
            ),
          );
        }
      }
    }
  }

  // Tier 2: Medium/High Zooms (13-15) over Transit BBox
  for (int z = 13; z <= 15; z++) {
    final xMin = lonToTileX(tMinLng, z);
    final xMax = lonToTileX(tMaxLng, z);
    final yMin = latToTileY(tMaxLat, z);
    final yMax = latToTileY(tMinLat, z);
    for (int tx = xMin; tx <= xMax; tx++) {
      for (int ty = yMin; ty <= yMax; ty++) {
        for (final style in styleTemplates) {
          tilesToFetch.add(
            TileTarget(
              name: style['name']!,
              z: z,
              x: tx,
              y: ty,
              pathTemplate: style['path']!,
            ),
          );
        }
      }
    }
  }

  // Tier 3: Ultra-High Zooms (16-17) at Station Centers
  for (final station in stationsJson) {
    final lat = (station['lat'] as num).toDouble();
    final lng = (station['lng'] as num).toDouble();
    if (lat < bMinLat || lat > bMaxLat || lng < bMinLng || lng > bMaxLng) {
      continue;
    }

    for (final z in [16, 17]) {
      final tx = lonToTileX(lng, z);
      final ty = latToTileY(lat, z);
      for (final style in styleTemplates) {
        tilesToFetch.add(
          TileTarget(
            name: style['name']!,
            z: z,
            x: tx,
            y: ty,
            pathTemplate: style['path']!,
          ),
        );
      }
    }
  }

  print('Total deduplicated tiles to download: ${tilesToFetch.length}');

  final client = http.Client();
  final headers = {'User-Agent': 'com.bkktransit.bkk_transit_planner'};

  final List<DownloadedTile> downloadedTiles = [];
  int completed = 0;
  int success = 0;
  int errors = 0;
  final startTime = DateTime.now();

  const maxConcurrent = 40;
  final queue = List<TileTarget>.from(tilesToFetch);
  final subdomains = ['a', 'b', 'c', 'd'];
  int subdomainIdx = 0;

  Future<void> worker() async {
    while (queue.isNotEmpty) {
      final tile = queue.removeLast();
      subdomainIdx = (subdomainIdx + 1) % subdomains.length;
      final sub = subdomains[subdomainIdx];

      final tilePath = tile.pathTemplate
          .replaceAll('{z}', tile.z.toString())
          .replaceAll('{x}', tile.x.toString())
          .replaceAll('{y}', tile.y.toString());

      final url = 'https://$sub.basemaps.cartocdn.com$tilePath';

      try {
        final res = await client
            .get(Uri.parse(url), headers: headers)
            .timeout(const Duration(seconds: 8));

        if (res.statusCode == 200) {
          final key = '${tile.name}/${tile.z}/${tile.x}/${tile.y}.webp';
          downloadedTiles.add(DownloadedTile(key: key, bytes: res.bodyBytes));
          success++;
        } else {
          errors++;
        }
      } catch (_) {
        errors++;
      } finally {
        completed++;
        if (completed % 250 == 0 || completed == tilesToFetch.length) {
          final elapsedSec =
              DateTime.now().difference(startTime).inMilliseconds / 1000.0;
          final speed = elapsedSec > 0 ? completed / elapsedSec : 0.0;
          print(
            'Progress: $completed/${tilesToFetch.length} ($success succeeded, $errors errors) - ${speed.toStringAsFixed(1)} tiles/sec',
          );
        }
      }
    }
  }

  print(
    'Downloading tiles in high-speed parallel mode (40 workers, domain sharding)...',
  );
  final workers = List.generate(maxConcurrent, (_) => worker());
  await Future.wait(workers);
  client.close();

  final elapsedMin =
      DateTime.now().difference(startTime).inMilliseconds / 60000.0;
  print('Downloads completed in ${elapsedMin.toStringAsFixed(2)} minutes.');
  print('Successful downloads: $success, Errors: $errors');

  // 2. Assemble Bundle
  print('Assembling assets/map_tiles.bundle...');
  final bundleFile = File('assets/map_tiles.bundle');
  await bundleFile.parent.create(recursive: true);

  final realIndex = <String, List<int>>{};
  int currentOffset = 0;

  final sink = bundleFile.openWrite();

  for (final tile in downloadedTiles) {
    final size = tile.bytes.length;
    realIndex[tile.key] = [currentOffset, size];
    sink.add(tile.bytes);
    currentOffset += size;
  }

  // Serialize and compress index map
  final indexJsonBytes = utf8.encode(jsonEncode(realIndex));
  final compressedIndexBytes = gzip.encode(indexJsonBytes);
  final indexOffset = currentOffset;

  print(
    'Compressed index size: ${compressedIndexBytes.length} bytes, starting at offset: $indexOffset',
  );

  // Write compressed index
  sink.add(compressedIndexBytes);

  // Write 4-byte Big Endian uint32 indexOffset pointer at end of file
  final offsetBuffer = ByteData(4);
  offsetBuffer.setUint32(0, indexOffset, Endian.big);
  sink.add(offsetBuffer.buffer.asUint8List());

  await sink.flush();
  await sink.close();

  final finalSize = await bundleFile.length();
  print('Bundle file created successfully: ${bundleFile.path}');
  print(
    'Final bundle size: ${(finalSize / (1024 * 1024)).toStringAsFixed(2)} MB',
  );
}
