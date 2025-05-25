import os
import json
import sqlite3

DB_PATH = 'lpc_character_generator.sqlite'  # Adjust to your actual DB
SHEET_DEF_DIR = 'sheet_definitions'

def parse_json_definitions(base_dir):
    entries = []

    for filename in os.listdir(base_dir):
        if not filename.endswith('.json'):
            continue

        filepath = os.path.join(base_dir, filename)
        with open(filepath, 'r', encoding='utf-8') as f:
            try:
                data = json.load(f)
            except Exception as e:
                print(f"Failed to parse {filename}: {e}")
                continue

        type_name = data.get('type_name')
        variants = data.get('variants', [])
        if not type_name:
            continue

        for key, val in data.items():
            if key.startswith("layer_") and isinstance(val, dict):
                z_index = val.get('zPos', 0)
                for gender, path in val.items():
                    if gender == "zPos" or not isinstance(path, str):
                        continue  # skip non-string paths
                    for variant in variants or ["default"]:
                        full_path = os.path.join(path, variant).replace("\\", "/")
                        entries.append({
                            'type_name': type_name,
                            'gender': gender,
                            'variant': variant,
                            'z_index': z_index,
                            'path': full_path
                        })

    return entries

def insert_into_database(entries, db_path):
    conn = sqlite3.connect(db_path)
    c = conn.cursor()

    c.execute('''
        CREATE TABLE IF NOT EXISTS character (
            id INTEGER PRIMARY KEY,
            type_name TEXT,
            gender TEXT,
            variant TEXT,
            z_index INTEGER,
            path TEXT UNIQUE
        )
    ''')

    for e in entries:
        try:
            c.execute('''
                INSERT OR IGNORE INTO character (type_name, gender, variant, z_index, path)
                VALUES (?, ?, ?, ?, ?)
            ''', (e['type_name'], e['gender'], e['variant'], e['z_index'], e['path']))
        except Exception as err:
            print(f"Failed to insert entry {e['path']}: {err}")

    conn.commit()
    conn.close()

def main():
    print("Parsing sprite definitions...")
    entries = parse_json_definitions(SHEET_DEF_DIR)
    print(f"Found {len(entries)} character layer entries.")

    print("Inserting into SQLite...")
    insert_into_database(entries, DB_PATH)
    print("Done.")

if __name__ == "__main__":
    main()
