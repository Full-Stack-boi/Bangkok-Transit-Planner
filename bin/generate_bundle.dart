import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;

// FNV-1a 64-bit hash
String fnv1a(String input) {
  var hash = (0xcbf29ce4 << 32) | 0x84222325;
  for (final unit in input.codeUnits) {
    hash ^= unit;
    hash *= 0x100000001b3;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

int lonToX(double lon, int zoom) {
  return ((lon + 180.0) / 360.0 * math.pow(2, zoom)).floor();
}

int latToY(double lat, int zoom) {
  final rad = lat * math.pi / 180.0;
  final n = math.log(math.tan(rad) + (1.0 / math.cos(rad)));
  return ((1.0 - n / math.pi) / 2.0 * math.pow(2, zoom)).floor();
}

Future<void> main() async {
  final client = http.Client();
  print('Fetching OpenFreeMap TileJSON...');
  final planetRes = await client.get(Uri.parse('https://tiles.openfreemap.org/planet'));
  if (planetRes.statusCode != 200) {
    print('Failed to fetch TileJSON: ${planetRes.statusCode}');
    exit(1);
  }

  final planetJson = jsonDecode(planetRes.body) as Map<String, dynamic>;
  final tilesList = planetJson['tiles'] as List<dynamic>;
  final urlTemplate = tilesList.first.toString();
  print('Resolved tile URL template: $urlTemplate');

  // Bangkok Bounding Box
  const minLat = 13.45;
  const maxLat = 14.15;
  const minLon = 100.20;
  const maxLon = 100.85;

  final tiles = <({int z, int x, int y})>[];
  for (int z = 10; z <= 14; z++) {
    final minX = lonToX(minLon, z);
    final maxX = lonToX(maxLon, z);
    final minY = latToY(maxLat, z);
    final maxY = latToY(minLat, z);

    for (int x = minX; x <= maxX; x++) {
      for (int y = minY; y <= maxY; y++) {
        tiles.add((z: z, x: x, y: y));
      }
    }
  }

  print('Total Bangkok tiles to fetch: ${tiles.length}');

  final archive = Archive();
  int downloaded = 0;
  int totalBytes = 0;
  const concurrency = 16;
  int index = 0;

  Future<void> worker() async {
    while (true) {
      if (index >= tiles.length) break;
      final currentIdx = index++;
      final tile = tiles[currentIdx];

      final tileUrl = urlTemplate
          .replaceAll('{z}', '${tile.z}')
          .replaceAll('{x}', '${tile.x}')
          .replaceAll('{y}', '${tile.y}');

      final cacheKey = '$urlTemplate/${tile.z}/${tile.x}/${tile.y}';
      final filename = '${fnv1a(cacheKey)}.bin';

      try {
        final res = await client.get(Uri.parse(tileUrl));
        if (res.statusCode == 200) {
          final bytes = res.bodyBytes;
          archive.addFile(ArchiveFile(filename, bytes.length, bytes));
          totalBytes += bytes.length;
        }
      } catch (e) {
        print('Error tile $tile: $e');
      }

      downloaded++;
      if (downloaded % 100 == 0 || downloaded == tiles.length) {
        print('Downloaded $downloaded / ${tiles.length} (${(totalBytes / (1024 * 1024)).toStringAsFixed(2)} MB)');
      }
    }
  }

  final workers = List.generate(concurrency, (_) => worker());
  await Future.wait(workers);

  // Add styles and TileJSON into the archive under style/
  print('Fetching styles...');
  for (final styleName in ['liberty', 'dark']) {
    final styleUrl = 'https://tiles.openfreemap.org/styles/$styleName';
    final styleRes = await client.get(Uri.parse(styleUrl));
    if (styleRes.statusCode == 200) {
      final styleBytes = styleRes.bodyBytes;
      final hash = fnv1a(styleUrl);
      archive.addFile(ArchiveFile('style/$hash.bin', styleBytes.length, styleBytes));

      // Also sprites
      final styleJson = jsonDecode(styleRes.body) as Map<String, dynamic>;
      final spriteBase = styleJson['sprite'] as String?;
      if (spriteBase != null) {
        for (final ext in ['.json', '.png', '@2x.json', '@2x.png']) {
          final spriteUrl = '$spriteBase$ext';
          try {
            final sRes = await client.get(Uri.parse(spriteUrl));
            if (sRes.statusCode == 200) {
              final sBytes = sRes.bodyBytes;
              final sHash = fnv1a(spriteUrl);
              archive.addFile(ArchiveFile('style/$sHash.bin', sBytes.length, sBytes));
            }
          } catch (_) {}
        }
      }
    }
  }

  // Also TileJSON
  final planetHash = fnv1a('https://tiles.openfreemap.org/planet');
  archive.addFile(ArchiveFile('style/$planetHash.bin', planetRes.bodyBytes.length, planetRes.bodyBytes));

  print('Compressing archive with Tar + GZip...');
  final tarEncoder = TarEncoder();
  final tarBytes = tarEncoder.encode(archive);
  final gzipEncoder = GZipEncoder();
  final compressed = gzipEncoder.encode(tarBytes);

  final outFile = File('assets/data/bangkok_vector_offline.tar.gz');
  await outFile.parent.create(recursive: true);
  await outFile.writeAsBytes(compressed);

  print('SUCCESS: Saved compressed offline map to assets/data/bangkok_vector_offline.tar.gz');
  print('Total raw size: ${(totalBytes / (1024 * 1024)).toStringAsFixed(2)} MB');
  print('Compressed asset size: ${(compressed.length / (1024 * 1024)).toStringAsFixed(2)} MB');

  client.close();
}
