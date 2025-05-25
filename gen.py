
import os
import sqlite3

DB_FILE = "lpc_character_generator.sqlite"
ASSETS_DIR = "spritesheets/"

# Base schema (see previous message)
SCHEMA = """
CREATE TABLE IF NOT EXISTS animations (
    id INTEGER PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,
    direction_count INTEGER NOT NULL DEFAULT 4,
    frame_count INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS layers (
    id INTEGER PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,
    render_order INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS assets (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    layer_id INTEGER NOT NULL,
    gender TEXT CHECK(gender IN ('male', 'female', 'unisex')) DEFAULT 'unisex',
    file_path TEXT NOT NULL,
    FOREIGN KEY (layer_id) REFERENCES layers(id)
);

CREATE TABLE IF NOT EXISTS asset_animations (
    asset_id INTEGER NOT NULL,
    animation_id INTEGER NOT NULL,
    frame_path_template TEXT NOT NULL,
    PRIMARY KEY (asset_id, animation_id),
    FOREIGN KEY (asset_id) REFERENCES assets(id),
    FOREIGN KEY (animation_id) REFERENCES animations(id)
);

CREATE TABLE IF NOT EXISTS palettes (
    id INTEGER PRIMARY KEY,
    name TEXT UNIQUE NOT NULL,
    type TEXT CHECK(type IN ('skin', 'hair', 'clothes')) NOT NULL,
    file_path TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS characters (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS character_assets (
    character_id INTEGER,
    asset_id INTEGER,
    PRIMARY KEY (character_id, asset_id),
    FOREIGN KEY (character_id) REFERENCES characters(id),
    FOREIGN KEY (asset_id) REFERENCES assets(id)
);

ALTER TABLE layers ADD COLUMN draw_order INTEGER;
UPDATE layers SET draw_order = 
  CASE name
    WHEN 'body' THEN 1
    WHEN 'torso' THEN 2
    WHEN 'legs' THEN 3
    WHEN 'feet' THEN 4
    WHEN 'hair' THEN 5
    WHEN 'head' THEN 6
    WHEN 'eyes' THEN 7
    WHEN 'accessory' THEN 8
    ELSE 99
  END;

"""

# Known animations (can be extended)
ANIMATIONS = {
    "walk": (4, 9),
    "thrust": (4, 8),
    "shoot": (4, 13),
    "cast": (4, 7),
    "slash": (4, 6),
    "spellcast": (4, 7),
    "hurt": (1, 6)
}

LAYER_ORDER = [
    "body", "feet", "legs", "torso", "head", "hair", "helmet", "cloak", "weapon", "shield"
]

def init_db():
    conn = sqlite3.connect(DB_FILE)
    cur = conn.cursor()
    cur.executescript(SCHEMA)

    # Insert animations
    for name, (dirs, frames) in ANIMATIONS.items():
        cur.execute("INSERT OR IGNORE INTO animations (name, direction_count, frame_count) VALUES (?, ?, ?)",
                    (name, dirs, frames))

    # Insert layers
    for i, layer in enumerate(LAYER_ORDER):
        cur.execute("INSERT OR IGNORE INTO layers (name, render_order) VALUES (?, ?)", (layer, i))

    conn.commit()
    return conn, cur

def find_layer(name):
    for i, layer in enumerate(LAYER_ORDER):
        if layer in name.lower():
            return layer
    return None

def scan_assets(conn, cur):
    print("📁 Scanning assets...")
    asset_entries = []
    animation_entries = []

    # Cache layer and animation IDs
    cur.execute("SELECT id, name FROM layers")
    layer_ids = {name: id for id, name in cur.fetchall()}

    cur.execute("SELECT id, name FROM animations")
    anim_ids = {name: id for id, name in cur.fetchall()}

    asset_cache = set()

    total_files = sum(len(files) for _, _, files in os.walk(ASSETS_DIR))
    file_count = 0

    for root, _, files in os.walk(ASSETS_DIR):
        for file in files:
            file_count += 1
            if file_count % 500 == 0:
                print(f"🔍 Processed {file_count}/{total_files} files...")

            if not file.endswith(".png"):
                continue

            rel_path = os.path.relpath(os.path.join(root, file), ASSETS_DIR)
            asset_name = os.path.splitext(file)[0]
            animation = next((a for a in anim_ids if a in rel_path.lower()), None)
            layer = find_layer(rel_path)

            if not animation or not layer:
                continue

            layer_id = layer_ids[layer]
            anim_id = anim_ids[animation]

            key = (asset_name, rel_path)
            if key not in asset_cache:
                asset_entries.append((asset_name, layer_id, rel_path))
                asset_cache.add(key)

            animation_entries.append((asset_name, rel_path, anim_id))

    print(f"🧱 Inserting {len(asset_entries)} unique assets...")
    conn.execute("BEGIN TRANSACTION")
    for name, layer_id, path in asset_entries:
        cur.execute("INSERT OR IGNORE INTO assets (name, layer_id, file_path) VALUES (?, ?, ?)",
                    (name, layer_id, path))
    conn.execute("COMMIT")

    print("📥 Fetching asset IDs...")
    cur.execute("SELECT id, name, file_path FROM assets")
    asset_id_map = {(name, path): id for id, name, path in cur.fetchall()}

    print(f"🎞 Linking {len(animation_entries)} asset-animation pairs...")
    conn.execute("BEGIN TRANSACTION")
    for name, path, anim_id in animation_entries:
        asset_id = asset_id_map.get((name, path))
        if asset_id:
            cur.execute(
                "INSERT OR IGNORE INTO asset_animations (asset_id, animation_id, frame_path_template) VALUES (?, ?, ?)",
                (asset_id, anim_id, path)
            )
    conn.execute("COMMIT")
    print("✅ Done scanning and inserting.")

def main():
    conn, cur = init_db()
    scan_assets(conn, cur)
    conn.close()
    print(f"✅ Database created: {DB_FILE}")

if __name__ == "__main__":
    main()
