import os
import sys
import json
import math
import time
import gzip
import struct
import tempfile
import subprocess
from concurrent.futures import ThreadPoolExecutor

# Automatically install required packages if not found
try:
    import requests
    from PIL import Image
except ImportError:
    print("Required packages (requests, Pillow) not found. Installing via pip...")
    try:
        subprocess.check_call([sys.executable, "-m", "pip", "install", "requests", "Pillow"])
        import requests
        from PIL import Image
    except Exception as e:
        print(f"Failed to install dependencies: {e}")
        sys.exit(1)

def lon_to_tile_x(lon, zoom):
    return int(math.floor((lon + 180.0) / 360.0 * (2 ** zoom)))

def lat_to_tile_y(lat, zoom):
    lat_rad = lat * math.pi / 180.0
    return int(math.floor((1.0 - (math.log(math.tan(lat_rad) + 1.0 / math.cos(lat_rad)) / math.pi)) / 2.0 * (2 ** zoom)))

def main():
    print("=== Bangkok Transit Offline Map Tile Bundle Generator ===")
    
    stations_path = 'assets/data/stations.json'
    if not os.path.exists(stations_path):
        print(f"Error: {stations_path} not found. Please run this script from the project root.")
        sys.exit(1)
        
    with open(stations_path, 'r', encoding='utf-8') as f:
        stations = json.load(f)
    print(f"Loaded {len(stations)} stations.")

    # 1. Coordinate Definitions
    # Broad Bounding Box (Surrounding provinces - low detail)
    b_min_lat, b_max_lat = 13.10, 14.70
    b_min_lng, b_max_lng = 99.50, 101.50
    
    # Transit Bounding Box (Bangkok and metro transit zones - high detail)
    t_min_lat, t_max_lat = 13.51, 13.99
    t_min_lng, t_max_lng = 100.35, 100.81

    # Tile styles to fetch
    r_value = '@2x'
    targets = [
        {
            'name': 'dark_all',
            'template': 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}' + r_value + '.png',
        },
        {
            'name': 'voyager',
            'template': 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}' + r_value + '.png',
        }
    ]

    tiles_to_fetch = set()

    # Tier 1: Low Zooms (10-12) over Broad BBox
    for z in range(10, 13):
        x_min = lon_to_tile_x(b_min_lng, z)
        x_max = lon_to_tile_x(b_max_lng, z)
        y_min = lat_to_tile_y(b_max_lat, z)
        y_max = lat_to_tile_y(b_min_lat, z)
        for tx in range(x_min, x_max + 1):
            for ty in range(y_min, y_max + 1):
                for target in targets:
                    tiles_to_fetch.add((target['name'], z, tx, ty, target['template']))

    # Tier 2: Medium/High Zooms (13-15) over Transit BBox
    for z in range(13, 16):
        x_min = lon_to_tile_x(t_min_lng, z)
        x_max = lon_to_tile_x(t_max_lng, z)
        y_min = lat_to_tile_y(t_max_lat, z)
        y_max = lat_to_tile_y(t_min_lat, z)
        for tx in range(x_min, x_max + 1):
            for ty in range(y_min, y_max + 1):
                for target in targets:
                    tiles_to_fetch.add((target['name'], z, tx, ty, target['template']))

    # Tier 3: Ultra-High Zooms (16-17) at Station Centers (pad = 0)
    for station in stations:
        lat = station['lat']
        lng = station['lng']
        if not (b_min_lat <= lat <= b_max_lat and b_min_lng <= lng <= b_max_lng):
            continue
            
        for z in [16, 17]:
            tx = lon_to_tile_x(lng, z)
            ty = lat_to_tile_y(lat, z)
            for target in targets:
                tiles_to_fetch.add((target['name'], z, tx, ty, target['template']))

    total_tiles = len(tiles_to_fetch)
    print(f"Total deduplicated tiles to download & convert: {total_tiles}")

    # Create temporary directory for downloads
    temp_dir = tempfile.mkdtemp()
    print(f"Using temporary directory: {temp_dir}")

    # Downloader function
    headers = {
        'User-Agent': 'com.bkktransit.bkk_transit_planner',
    }
    
    downloaded_tiles = []
    completed = 0
    success = 0
    errors = 0
    start_time = time.time()

    def download_and_convert(tile):
        nonlocal completed, success, errors
        name, z, x, y, template = tile
        url = template.replace('{z}', str(z)).replace('{x}', str(x)).replace('{y}', str(y))
        
        webp_filename = f"{name}_{z}_{x}_{y}.webp"
        webp_path = os.path.join(temp_dir, webp_filename)
        
        try:
            # Download PNG
            response = requests.get(url, headers=headers, timeout=10)
            if response.status_code == 200:
                # Save as PNG first in memory
                from io import BytesIO
                png_io = BytesIO(response.content)
                
                # Convert to WebP using Pillow
                img = Image.open(png_io)
                img.save(webp_path, "WEBP", quality=80)
                
                downloaded_tiles.append((name, z, x, y, webp_path))
                success += 1
            else:
                errors += 1
        except Exception as e:
            errors += 1
        finally:
            completed += 1
            if completed % 100 == 0 or completed == total_tiles:
                elapsed = time.time() - start_time
                speed = completed / elapsed if elapsed > 0 else 0
                print(f"Progress: {completed}/{total_tiles} ({success} succeeded, {errors} errors) - {speed:.1f} tiles/sec")

    # Run downloads in parallel using ThreadPoolExecutor
    print("Downloading and converting tiles in parallel...")
    with ThreadPoolExecutor(max_workers=20) as executor:
        executor.map(download_and_convert, list(tiles_to_fetch))

    print(f"Downloads completed in {(time.time() - start_time) / 60:.1f} minutes.")
    print(f"Successful downloads/conversions: {success}, Errors: {errors}")

    # 2. Assemble Bundle
    print("Assembling map_tiles.bundle...")
    bundle_path = 'assets/map_tiles.bundle'
    os.makedirs(os.path.dirname(bundle_path), exist_ok=True)

    # We compute file offsets relative to 0. Putting the index at the end of the file
    # completely eliminates the circular dependency on compressed index size.
    real_index = {}
    current_offset = 0
    tile_entries = []
    
    for name, z, x, y, webp_path in downloaded_tiles:
        size = os.path.getsize(webp_path)
        key = f"{name}/{z}/{x}/{y}.webp"
        real_index[key] = [current_offset, size]
        tile_entries.append((webp_path, size))
        current_offset += size

    # Serialize and compress the index map
    real_json = json.dumps(real_index).encode('utf-8')
    compressed_index = gzip.compress(real_json)
    index_offset = current_offset # Offset where the index starts in the file

    print(f"Compressed index size: {len(compressed_index)} bytes, starting at offset: {index_offset}")

    # Write bundle binary file
    with open(bundle_path, 'wb') as f_out:
        # 1. Write all tile image data
        written_count = 0
        for webp_path, size in tile_entries:
            with open(webp_path, 'rb') as f_in:
                f_out.write(f_in.read())
            written_count += 1
            if written_count % 1000 == 0 or written_count == len(tile_entries):
                print(f"Appended {written_count} / {len(tile_entries)} tiles to bundle...")

        # 2. Write compressed index bytes
        f_out.write(compressed_index)

        # 3. Write index_offset as 4-byte uint32 Big Endian at the end of the file
        f_out.write(struct.pack('>I', index_offset))

    final_size = os.path.getsize(bundle_path)
    print(f"Bundle file created successfully: {bundle_path}")
    print(f"Final bundle size: {final_size / (1024 * 1024):.2f} MB")

    # Cleanup temporary directory
    print("Cleaning up temporary tile files...")
    for webp_path, size in tile_entries:
        try:
            os.remove(webp_path)
        except Exception:
            pass
    try:
        os.rmdir(temp_dir)
    except Exception:
        pass
    print("Cleanup done!")

if __name__ == '__main__':
    main()
