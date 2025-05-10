#!/bin/bash

# Simple script to populate the SQLite database with sample data

DB_FILE="lpc_character_generator.db"
DUMP_FILE="lpc_character_generator_dump.sql"

# Check if dump file exists
if [ ! -f "$DUMP_FILE" ]; then
    echo "Error: Dump file '$DUMP_FILE' not found."
    echo "Please run create_dump_simple.sh first to create the dump file."
    exit 1
fi

# Remove existing database if it exists
if [ -f "$DB_FILE" ]; then
    echo "Removing existing database..."
    rm "$DB_FILE"
fi

# Create new database from dump file
echo "Creating database from dump file..."
sqlite3 "$DB_FILE" < "$DUMP_FILE"

# Add sample component types
echo "Adding sample component types..."
sqlite3 "$DB_FILE" <<EOF
-- Add component types for torso category
INSERT INTO component_types (name, display_name, category_id) 
VALUES ('clothes', 'Clothes', (SELECT id FROM categories WHERE name = 'torso'));

INSERT INTO component_types (name, display_name, category_id) 
VALUES ('jacket', 'Jacket', (SELECT id FROM categories WHERE name = 'torso'));

INSERT INTO component_types (name, display_name, category_id) 
VALUES ('chainmail', 'Chainmail', (SELECT id FROM categories WHERE name = 'torso'));

-- Add component types for weapon category
INSERT INTO component_types (name, display_name, category_id) 
VALUES ('sword', 'Sword', (SELECT id FROM categories WHERE name = 'weapon'));

INSERT INTO component_types (name, display_name, category_id) 
VALUES ('bow', 'Bow', (SELECT id FROM categories WHERE name = 'weapon'));
EOF

# Add sample components
echo "Adding sample components..."
sqlite3 "$DB_FILE" <<EOF
-- Add components for clothes type
INSERT INTO components (name, display_name, type_id, filename, data) 
VALUES ('torso_clothes_blouse', 'Blouse', 
        (SELECT id FROM component_types WHERE name = 'clothes'), 
        'sheet_definitions/torso_clothes_blouse.json', 
        '{"name":"Blouse","type_name":"clothes","layer_1":{"zPos":35,"female":"torso/clothes/blouse/female/"}}');

INSERT INTO components (name, display_name, type_id, filename, data) 
VALUES ('torso_clothes_tunic', 'Tunic', 
        (SELECT id FROM component_types WHERE name = 'clothes'), 
        'sheet_definitions/torso_clothes_tunic.json', 
        '{"name":"Tunic","type_name":"clothes","layer_1":{"zPos":35,"male":"torso/clothes/tunic/male/"}}');

-- Add components for sword type
INSERT INTO components (name, display_name, type_id, filename, data) 
VALUES ('weapon_sword_arming', 'Arming Sword', 
        (SELECT id FROM component_types WHERE name = 'sword'), 
        'sheet_definitions/weapon_sword_arming.json', 
        '{"name":"Arming Sword","type_name":"weapon","layer_1":{"zPos":140,"male":"weapon/sword/arming/universal/fg/"}}');
EOF

# Add sample variants
echo "Adding sample variants..."
sqlite3 "$DB_FILE" <<EOF
-- Add variants
INSERT INTO variants (name, display_name) VALUES ('red', 'Red');
INSERT INTO variants (name, display_name) VALUES ('blue', 'Blue');
INSERT INTO variants (name, display_name) VALUES ('green', 'Green');
INSERT INTO variants (name, display_name) VALUES ('black', 'Black');
INSERT INTO variants (name, display_name) VALUES ('white', 'White');
INSERT INTO variants (name, display_name) VALUES ('steel', 'Steel');
INSERT INTO variants (name, display_name) VALUES ('gold', 'Gold');

-- Link variants to components
INSERT INTO component_variants (component_id, variant_id) 
VALUES ((SELECT id FROM components WHERE name = 'torso_clothes_blouse'), 
        (SELECT id FROM variants WHERE name = 'red'));

INSERT INTO component_variants (component_id, variant_id) 
VALUES ((SELECT id FROM components WHERE name = 'torso_clothes_blouse'), 
        (SELECT id FROM variants WHERE name = 'blue'));

INSERT INTO component_variants (component_id, variant_id) 
VALUES ((SELECT id FROM components WHERE name = 'torso_clothes_blouse'), 
        (SELECT id FROM variants WHERE name = 'green'));

INSERT INTO component_variants (component_id, variant_id) 
VALUES ((SELECT id FROM components WHERE name = 'weapon_sword_arming'), 
        (SELECT id FROM variants WHERE name = 'steel'));

INSERT INTO component_variants (component_id, variant_id) 
VALUES ((SELECT id FROM components WHERE name = 'weapon_sword_arming'), 
        (SELECT id FROM variants WHERE name = 'gold'));
EOF

# Add sample animations
echo "Adding sample animations..."
sqlite3 "$DB_FILE" <<EOF
-- Link animations to components
INSERT INTO component_animations (component_id, animation_id) 
VALUES ((SELECT id FROM components WHERE name = 'torso_clothes_blouse'), 
        (SELECT id FROM animations WHERE name = 'walk'));

INSERT INTO component_animations (component_id, animation_id) 
VALUES ((SELECT id FROM components WHERE name = 'torso_clothes_blouse'), 
        (SELECT id FROM animations WHERE name = 'idle'));

INSERT INTO component_animations (component_id, animation_id) 
VALUES ((SELECT id FROM components WHERE name = 'weapon_sword_arming'), 
        (SELECT id FROM animations WHERE name = 'slash'));

INSERT INTO component_animations (component_id, animation_id) 
VALUES ((SELECT id FROM components WHERE name = 'weapon_sword_arming'), 
        (SELECT id FROM animations WHERE name = 'thrust'));
EOF

# Add sample component layers
echo "Adding sample component layers..."
sqlite3 "$DB_FILE" <<EOF
-- Add component layers
INSERT INTO component_layers (component_id, layer_number, z_position, custom_animation) 
VALUES ((SELECT id FROM components WHERE name = 'torso_clothes_blouse'), 1, 35, NULL);

INSERT INTO component_layers (component_id, layer_number, z_position, custom_animation) 
VALUES ((SELECT id FROM components WHERE name = 'weapon_sword_arming'), 1, 140, NULL);

-- Add layer paths
INSERT INTO layer_paths (layer_id, body_type_id, path) 
VALUES (1, (SELECT id FROM body_types WHERE name = 'female'), 'torso/clothes/blouse/female/');

INSERT INTO layer_paths (layer_id, body_type_id, path) 
VALUES (2, (SELECT id FROM body_types WHERE name = 'male'), 'weapon/sword/arming/universal/fg/');
EOF

# Add sample asset files
echo "Adding sample asset files..."
sqlite3 "$DB_FILE" <<EOF
-- Add asset files
INSERT INTO asset_files (layer_path_id, animation_id, variant_id, file_path) 
VALUES (1, (SELECT id FROM animations WHERE name = 'walk'), 
        (SELECT id FROM variants WHERE name = 'red'), 
        'spritesheets/torso/clothes/blouse/female/walk/red.png');

INSERT INTO asset_files (layer_path_id, animation_id, variant_id, file_path) 
VALUES (1, (SELECT id FROM animations WHERE name = 'walk'), 
        (SELECT id FROM variants WHERE name = 'blue'), 
        'spritesheets/torso/clothes/blouse/female/walk/blue.png');

INSERT INTO asset_files (layer_path_id, animation_id, variant_id, file_path) 
VALUES (2, (SELECT id FROM animations WHERE name = 'slash'), 
        (SELECT id FROM variants WHERE name = 'steel'), 
        'spritesheets/weapon/sword/arming/universal/fg/slash/steel.png');
EOF

echo "Done! Database populated with sample data: $DB_FILE"
echo "You can now test the database with the test_database.lua script." 