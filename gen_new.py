#!/usr/bin/env python3
"""
LPC Spritesheet Database Generator

This script scans JSON files in the sheet_definitions folder from the
Universal LPC Spritesheet Character Generator repository and generates:
1. An SQLite database schema (.sql file)
2. SQL insertion statements for the data
3. Creates and populates an SQLite database

The script handles the complex nested structure of the JSON files including, variants, animations, and layer information.

Usage:
    python lpc_db_generator.py

Requirements:
    - Python 3.6+
    - The sheet_definitions folder must be in the same directory as this script
"""

import json
import os
import sqlite3
import glob
from pathlib import Path
import re

# Configuration
SHEET_DEFINITIONS_DIR = "sheet_definitions"
OUTPUT_SCHEMA_FILE = "lpc_spritesheet_schema.sql"
OUTPUT_DB_FILE = "lpc_spritesheet.db"


def sanitize_string(s):
    """Sanitize a string for use in SQL statements"""
    if s is None:
        return None
    return s.replace("'", "''")


def create_schema():
    """Create the SQL schema based on the structure of the JSON files"""
    schema = """
-- LPC Spritesheet Database Schema
-- Generated automatically from sheet_definitions JSON files

PRAGMA foreign_keys = ON;

-- Main sheet table
CREATE TABLE IF NOT EXISTS sheets (
    sheet_id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    type_name TEXT NOT NULL,
    match_body_color BOOLEAN
);

-- Layer table
CREATE TABLE IF NOT EXISTS layers (
    layer_id INTEGER PRIMARY KEY AUTOINCREMENT,
    sheet_id INTEGER NOT NULL,
    layer_name TEXT NOT NULL,
    z_position INTEGER NOT NULL,
    FOREIGN KEY (sheet_id) REFERENCES sheets(sheet_id) ON DELETE CASCADE
);

-- Layer paths table (for body types, etc.)
CREATE TABLE IF NOT EXISTS layer_paths (
    path_id INTEGER PRIMARY KEY AUTOINCREMENT,
    layer_id INTEGER NOT NULL,
    path_type TEXT NOT NULL,
    path_value TEXT NOT NULL,
    FOREIGN KEY (layer_id) REFERENCES layers(layer_id) ON DELETE CASCADE
);

-- Variants table
CREATE TABLE IF NOT EXISTS variants (
    variant_id INTEGER PRIMARY KEY AUTOINCREMENT,
    sheet_id INTEGER NOT NULL,
    variant_name TEXT NOT NULL,
    FOREIGN KEY (sheet_id) REFERENCES sheets(sheet_id) ON DELETE CASCADE
);

-- Animations table
CREATE TABLE IF NOT EXISTS animations (
    animation_id INTEGER PRIMARY KEY AUTOINCREMENT,
    sheet_id INTEGER NOT NULL,
    animation_name TEXT NOT NULL,
    FOREIGN KEY (sheet_id) REFERENCES sheets(sheet_id) ON DELETE CASCADE
);

-- Files (optional) to track actual PNG files in the repository
CREATE TABLE IF NOT EXISTS files (
    file_id INTEGER PRIMARY KEY AUTOINCREMENT,
    sheet_id INTEGER NOT NULL,
    file_path TEXT NOT NULL UNIQUE,
    FOREIGN KEY (sheet_id) REFERENCES sheets(sheet_id) ON DELETE CASCADE
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_layer_sheet_id ON layers(sheet_id);
CREATE INDEX IF NOT EXISTS idx_layer_paths_layer_id ON layer_paths(layer_id);
CREATE INDEX IF NOT EXISTS idx_variants_sheet_id ON variants(sheet_id);
CREATE INDEX IF NOT EXISTS idx_animations_sheet_id ON animations(sheet_id);
CREATE INDEX IF NOT EXISTS idx_files_sheet_id ON files(sheet_id);
"""
    return schema


def process_json_files():
    """Process all JSON files in the sheet_definitions directory and generate SQL INSERT statements"""
    if not os.path.isdir(SHEET_DEFINITIONS_DIR):
        print(f"Error: {SHEET_DEFINITIONS_DIR} directory not found!")
        return None
    
    # List to store all insert statements
    all_inserts = []
    
    # Get list of JSON files
    json_files = glob.glob(os.path.join(SHEET_DEFINITIONS_DIR, "*.json"))
    
    if not json_files:
        print(f"No JSON files found in {SHEET_DEFINITIONS_DIR}")
        return None
    
    print(f"Found {len(json_files)} JSON files in {SHEET_DEFINITIONS_DIR}")
    
    # Process each JSON file
    for file_path in json_files:
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
                file_inserts = process_single_json(data)
                all_inserts.extend(file_inserts)
        except json.JSONDecodeError:
            print(f"Error: Could not parse JSON in {file_path}")
        except Exception as e:
            print(f"Error processing {file_path}: {str(e)}")
    
    return all_inserts


def process_single_json(data):
    """Process a single JSON object and return SQL INSERT statements"""
    inserts = []
    
    # Extract basic sheet info
    name = sanitize_string(data.get('name', ''))
    type_name = sanitize_string(data.get('type_name', ''))
    match_body_color = 1 if data.get('match_body_color', False) else 0
    
    # Insert sheet and get its ID
    sheet_insert = f"""
-- Start a new sheet: {name}
INSERT INTO sheets (name, type_name, match_body_color)
VALUES ('{name}', '{type_name}', {match_body_color});

-- Save the last inserted sheet_id for referencing in child tables
"""
    inserts.append(sheet_insert)
    
    # Process layers
    for layer_name, layer_data in {k: v for k, v in data.items() if k.startswith('layer_')}.items():
        if isinstance(layer_data, dict):
            z_pos = layer_data.get('zPos', 0)
            layer_insert = f"""
-- Insert layer: {layer_name}
INSERT INTO layers (sheet_id, layer_name, z_position)
VALUES ((SELECT MAX(sheet_id) FROM sheets), '{layer_name}', {z_pos});

-- Save the last inserted layer_id for layer paths
"""
            inserts.append(layer_insert)
            
            # Process layer paths
            for path_type, path_value in {k: v for k, v in layer_data.items() if k != 'zPos'}.items():
                path_value_safe = sanitize_string(path_value)
                path_insert = f"""
INSERT INTO layer_paths (layer_id, path_type, path_value)
VALUES ((SELECT MAX(layer_id) FROM layers), '{path_type}', '{path_value_safe}');
"""
                inserts.append(path_insert)
    
    # Process variants
    variants = data.get('variants', [])
    for variant in variants:
        variant_safe = sanitize_string(variant)
        variant_insert = f"""
INSERT INTO variants (sheet_id, variant_name)
VALUES ((SELECT MAX(sheet_id) FROM sheets), '{variant_safe}');
"""
        inserts.append(variant_insert)
    
    # Process animations
    animations = data.get('animations', [])
    for animation in animations:
        animation_safe = sanitize_string(animation)
        animation_insert = f"""
INSERT INTO animations (sheet_id, animation_name)
VALUES ((SELECT MAX(sheet_id) FROM sheets), '{animation_safe}');
"""
        inserts.append(animation_insert)
    
    return inserts


def create_database(schema, inserts):
    """Create an SQLite database with the given schema and inserts"""
    # First, create the schema file
    with open(OUTPUT_SCHEMA_FILE, 'w', encoding='utf-8') as f:
        f.write(schema)
        if inserts:
            f.write("\n-- Data insertion statements\n")
            for insert in inserts:
                f.write(insert)
    
    print(f"Schema and INSERT statements written to {OUTPUT_SCHEMA_FILE}")
    
    # Now create the actual database
    try:
        # Remove existing database if it exists
        if os.path.exists(OUTPUT_DB_FILE):
            os.remove(OUTPUT_DB_FILE)
        
        # Create new database and connect
        conn = sqlite3.connect(OUTPUT_DB_FILE)
        cursor = conn.cursor()
        
        # Execute schema
        cursor.executescript(schema)
        
        # Execute inserts if available
        if inserts:
            # Process each file as a transaction
            cursor.execute("BEGIN TRANSACTION;")
            try:
                for insert in inserts:
                    try:
                        cursor.execute(insert)
                    except sqlite3.Error as e:
                        print(f"Error executing: {insert}\nError: {str(e)}")
                cursor.execute("COMMIT;")
            except sqlite3.Error:
                cursor.execute("ROLLBACK;")
                raise
        
        # Close connection
        conn.close()
        
        print(f"Database created successfully at {OUTPUT_DB_FILE}")
        
    except sqlite3.Error as e:
        print(f"SQLite error: {str(e)}")
    except Exception as e:
        print(f"Error creating database: {str(e)}")


def execute_statements_one_by_one(conn, statements):
    """Execute SQL statements one by one for better error tracking"""
    cursor = conn.cursor()
    for statement in statements:
        if statement.strip():  # Skip empty statements
            try:
                cursor.execute(statement)
                conn.commit()
            except sqlite3.Error as e:
                print(f"Error executing: {statement}\nError: {str(e)}")
                conn.rollback()


def scan_image_files(repo_path, db_file):
    """
    Optional: Scan the actual repository for PNG files and add them to the database
    This is separate as it might take a long time with 200,000+ files
    """
    try:
        conn = sqlite3.connect(db_file)
        cursor = conn.cursor()
        
        # Get all sheet types from the database
        cursor.execute("SELECT sheet_id, type_name FROM sheets")
        sheets = cursor.fetchall()
        
        sheet_types = {sheet[1]: sheet[0] for sheet in sheets}
        
        # Create a pattern to match sheet types in file paths
        pattern = r'(?:' + '|'.join(re.escape(t) for t in sheet_types.keys()) + r')(?:/|$)'
        
        # Find all PNG files
        png_files = glob.glob(os.path.join(repo_path, "**/*.png"), recursive=True)
        print(f"Found {len(png_files)} PNG files")
        
        # Process files in batches for better performance
        batch_size = 1000
        for i in range(0, len(png_files), batch_size):
            batch = png_files[i:i+batch_size]
            inserts = []
            
            for file_path in batch:
                # Get relative path for better storage
                rel_path = os.path.relpath(file_path, repo_path)
                
                # Try to determine which sheet type this belongs to
                match = re.search(pattern, rel_path)
                if match:
                    sheet_type = match.group(0).rstrip('/')
                    sheet_id = sheet_types.get(sheet_type)
                    
                    if sheet_id:
                        inserts.append((sheet_id, rel_path))
            
            # Insert batch
            if inserts:
                cursor.executemany(
                    "INSERT OR IGNORE INTO files (sheet_id, file_path) VALUES (?, ?)",
                    inserts
                )
                conn.commit()
                print(f"Processed {len(inserts)} files (batch {i//batch_size + 1})")
        
        conn.close()
        print("Finished scanning image files")
        
    except sqlite3.Error as e:
        print(f"SQLite error while scanning images: {str(e)}")
    except Exception as e:
        print(f"Error scanning image files: {str(e)}")


def main():
    """Main function to execute the script"""
    print("LPC Spritesheet Database Generator")
    print("==================================")
    
    # Create schema
    schema = create_schema()
    
    # Process JSON files
    inserts = process_json_files()
    
    # Create database
    if inserts:
        create_database(schema, inserts)
        
        # Ask if user wants to scan actual image files (optional)
        scan_repo = input("Do you want to scan the actual repository for PNG files? (y/n) [n]: ").lower()
        if scan_repo == 'y':
            repo_path = input("Enter the path to the LPC repository root: ")
            if os.path.isdir(repo_path):
                scan_image_files(repo_path, OUTPUT_DB_FILE)
            else:
                print(f"Error: Directory {repo_path} not found!")
    else:
        print("No data was processed. Database not created.")


if __name__ == "__main__":
    main()
