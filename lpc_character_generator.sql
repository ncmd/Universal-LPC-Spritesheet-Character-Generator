-- LPC Character Generator SQLite Schema
-- This schema provides an efficient way to reference all available spritesheets in the repository

-- Enable foreign key constraints
PRAGMA foreign_keys = ON;

-- Categories table - stores the main component categories (body, arms, torso, etc.)
CREATE TABLE categories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL,
    description TEXT
);

-- Component types table - stores the distinct component types within categories
CREATE TABLE component_types (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    display_name TEXT NOT NULL,
    category_id INTEGER NOT NULL,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE,
    UNIQUE(name, category_id)
);

-- Components table - stores individual components like specific clothes, weapons, etc.
CREATE TABLE components (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    display_name TEXT NOT NULL,
    type_id INTEGER NOT NULL,
    filename TEXT NOT NULL, -- Path to the JSON definition file
    data TEXT NOT NULL, -- JSON content of the definition file
    FOREIGN KEY (type_id) REFERENCES component_types(id) ON DELETE CASCADE,
    UNIQUE(name, type_id)
);

-- Tags table - stores available tags for components
CREATE TABLE tags (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE
);

-- Component tags relationship
CREATE TABLE component_tags (
    component_id INTEGER NOT NULL,
    tag_id INTEGER NOT NULL,
    PRIMARY KEY (component_id, tag_id),
    FOREIGN KEY (component_id) REFERENCES components(id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
);

-- Body types table - stores different body types (male, female, muscular, etc.)
CREATE TABLE body_types (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL
);

-- Variants table - stores color/material variants
CREATE TABLE variants (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL
);

-- Animations table - stores available animations
CREATE TABLE animations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL,
    frame_count INTEGER NOT NULL
);

-- Component layers table - stores layer information for components
CREATE TABLE component_layers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    component_id INTEGER NOT NULL,
    layer_number INTEGER NOT NULL,
    z_position INTEGER NOT NULL,
    custom_animation TEXT,
    FOREIGN KEY (component_id) REFERENCES components(id) ON DELETE CASCADE,
    UNIQUE(component_id, layer_number)
);

-- Layer paths table - stores paths to different body types for each layer
CREATE TABLE layer_paths (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    layer_id INTEGER NOT NULL,
    body_type_id INTEGER NOT NULL,
    path TEXT NOT NULL,
    FOREIGN KEY (layer_id) REFERENCES component_layers(id) ON DELETE CASCADE,
    FOREIGN KEY (body_type_id) REFERENCES body_types(id) ON DELETE CASCADE,
    UNIQUE(layer_id, body_type_id)
);

-- Component variants relationship - which variants are available for each component
CREATE TABLE component_variants (
    component_id INTEGER NOT NULL,
    variant_id INTEGER NOT NULL,
    PRIMARY KEY (component_id, variant_id),
    FOREIGN KEY (component_id) REFERENCES components(id) ON DELETE CASCADE,
    FOREIGN KEY (variant_id) REFERENCES variants(id) ON DELETE CASCADE
);

-- Component animations relationship - which animations are available for each component
CREATE TABLE component_animations (
    component_id INTEGER NOT NULL,
    animation_id INTEGER NOT NULL,
    PRIMARY KEY (component_id, animation_id),
    FOREIGN KEY (component_id) REFERENCES components(id) ON DELETE CASCADE,
    FOREIGN KEY (animation_id) REFERENCES animations(id) ON DELETE CASCADE
);

-- Authors table - stores all authors/credits
CREATE TABLE authors (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE
);

-- Licenses table - stores available licenses
CREATE TABLE licenses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    url TEXT
);

-- Credits table - stores credits for components
CREATE TABLE credits (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    component_id INTEGER NOT NULL,
    file_path TEXT NOT NULL,
    notes TEXT,
    FOREIGN KEY (component_id) REFERENCES components(id) ON DELETE CASCADE
);

-- Credit authors relationship
CREATE TABLE credit_authors (
    credit_id INTEGER NOT NULL,
    author_id INTEGER NOT NULL,
    PRIMARY KEY (credit_id, author_id),
    FOREIGN KEY (credit_id) REFERENCES credits(id) ON DELETE CASCADE,
    FOREIGN KEY (author_id) REFERENCES authors(id) ON DELETE CASCADE
);

-- Credit licenses relationship
CREATE TABLE credit_licenses (
    credit_id INTEGER NOT NULL,
    license_id INTEGER NOT NULL,
    PRIMARY KEY (credit_id, license_id),
    FOREIGN KEY (credit_id) REFERENCES credits(id) ON DELETE CASCADE,
    FOREIGN KEY (license_id) REFERENCES licenses(id) ON DELETE CASCADE
);

-- Credit URLs
CREATE TABLE credit_urls (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    credit_id INTEGER NOT NULL,
    url TEXT NOT NULL,
    FOREIGN KEY (credit_id) REFERENCES credits(id) ON DELETE CASCADE
);

-- Asset files table - stores references to actual image files in the filesystem
CREATE TABLE asset_files (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    layer_path_id INTEGER NOT NULL,
    animation_id INTEGER NOT NULL,
    variant_id INTEGER NOT NULL,
    file_path TEXT NOT NULL,
    FOREIGN KEY (layer_path_id) REFERENCES layer_paths(id) ON DELETE CASCADE,
    FOREIGN KEY (animation_id) REFERENCES animations(id) ON DELETE CASCADE,
    FOREIGN KEY (variant_id) REFERENCES variants(id) ON DELETE CASCADE,
    UNIQUE(layer_path_id, animation_id, variant_id)
);

-- Create indexes for performance
CREATE INDEX idx_components_type_id ON components(type_id);
CREATE INDEX idx_component_layers_component_id ON component_layers(component_id);
CREATE INDEX idx_layer_paths_layer_id ON layer_paths(layer_id);
CREATE INDEX idx_layer_paths_body_type_id ON layer_paths(body_type_id);
CREATE INDEX idx_component_variants_component_id ON component_variants(component_id);
CREATE INDEX idx_component_variants_variant_id ON component_variants(variant_id);
CREATE INDEX idx_component_animations_component_id ON component_animations(component_id);
CREATE INDEX idx_component_animations_animation_id ON component_animations(animation_id);
CREATE INDEX idx_credit_authors_credit_id ON credit_authors(credit_id);
CREATE INDEX idx_credit_licenses_credit_id ON credit_licenses(credit_id);
CREATE INDEX idx_asset_files_layer_path_id ON asset_files(layer_path_id);
CREATE INDEX idx_asset_files_animation_id ON asset_files(animation_id);
CREATE INDEX idx_asset_files_variant_id ON asset_files(variant_id);

-- Insert basic categories
INSERT INTO categories (name, display_name, description) VALUES
('arms', 'Arms', 'Arm components'),
('backpack', 'Backpack', 'Backpack items'),
('bauldron', 'Bauldron', 'Shoulder armor'),
('beards', 'Beards', 'Facial hair'),
('body', 'Body', 'Base body components'),
('cape', 'Cape', 'Capes and cloaks'),
('dress', 'Dress', 'Full dresses'),
('eyes', 'Eyes', 'Eye components'),
('facial', 'Facial', 'Facial features'),
('feet', 'Feet', 'Footwear'),
('hair', 'Hair', 'Hairstyles'),
('hat', 'Hat', 'Headwear'),
('head', 'Head', 'Head components'),
('legs', 'Legs', 'Leg wear'),
('neck', 'Neck', 'Neck accessories'),
('quiver', 'Quiver', 'Arrow quivers'),
('shadow', 'Shadow', 'Character shadows'),
('shield', 'Shield', 'Shields'),
('shoulders', 'Shoulders', 'Shoulder accessories'),
('tools', 'Tools', 'Held tools'),
('torso', 'Torso', 'Torso clothing'),
('weapon', 'Weapon', 'Weapons'),
('wings', 'Wings', 'Character wings'),
('wrists', 'Wrists', 'Wrist accessories'),
('wound', 'Wound', 'Character wounds');

-- Insert basic body types
INSERT INTO body_types (name, display_name) VALUES
('male', 'Male'),
('female', 'Female'),
('muscular', 'Muscular'),
('pregnant', 'Pregnant'),
('teen', 'Teen');

-- Insert basic animations
INSERT INTO animations (name, display_name, frame_count) VALUES
('spellcast', 'Spellcast', 7),
('thrust', 'Thrust', 8),
('walk', 'Walk', 9),
('slash', 'Slash', 6),
('shoot', 'Shoot', 13),
('hurt', 'Hurt', 6),
('watering', 'Watering', 13),
('idle', 'Idle', 1),
('jump', 'Jump', 7),
('run', 'Run', 8),
('sit', 'Sit', 5),
('emote', 'Emote', 4),
('climb', 'Climb', 4),
('combat', 'Combat', 1),
('1h_slash', '1H Slash', 6),
('1h_backslash', '1H Backslash', 6),
('1h_halfslash', '1H Halfslash', 6);

-- Helper function to populate the database
-- This is a Lua script that would be used to read the sheet_definitions directory
-- and populate the database with the components, variants, etc.
-- The script would use the SQLite database created with this schema.

/*
-- The following Lua code can be saved separately to populate the database:

local function populate_database()
    local sqlite3 = require("lsqlite3")
    local json = require("json")
    local lfs = require("lfs")
    
    local db = sqlite3.open("lpc_character_generator.db")
    
    -- Function to read all sheet definitions and insert them into the database
    local function process_sheet_definitions(dir)
        for file in lfs.dir(dir) do
            if file:match("%.json$") then
                local filepath = dir .. "/" .. file
                local f = io.open(filepath, "rb")
                local content = f:read("*all")
                f:close()
                
                local data = json.decode(content)
                -- Parse the JSON data and insert into the database
                -- This would involve multiple INSERT statements for the component
                -- and its associated data (variants, animations, layers, etc.)
                -- ...
            end
        end
    end
    
    -- Process all sheet definitions
    process_sheet_definitions("sheet_definitions")
    
    -- Function to scan the spritesheets directory and register all assets
    local function register_assets(dir)
        -- Traverse the spritesheets directory recursively
        -- For each image file found, determine its category, component, variant, animation
        -- and insert a record into the asset_files table
        -- ...
    end
    
    -- Register all assets
    register_assets("spritesheets")
    
    db:close()
end

populate_database()
*/

-- Views for common queries

-- View to get all available components with their types and categories
CREATE VIEW view_available_components AS
SELECT 
    c.id AS component_id,
    c.name AS component_name,
    c.display_name AS component_display_name,
    ct.name AS type_name,
    ct.display_name AS type_display_name,
    cat.name AS category_name,
    cat.display_name AS category_display_name
FROM components c
JOIN component_types ct ON c.type_id = ct.id
JOIN categories cat ON ct.category_id = cat.id;

-- View to get all variants available for each component
CREATE VIEW view_component_variants AS
SELECT 
    c.id AS component_id,
    c.name AS component_name,
    v.id AS variant_id,
    v.name AS variant_name,
    v.display_name AS variant_display_name
FROM components c
JOIN component_variants cv ON c.id = cv.component_id
JOIN variants v ON cv.variant_id = v.id;

-- View to get all animations available for each component
CREATE VIEW view_component_animations AS
SELECT 
    c.id AS component_id,
    c.name AS component_name,
    a.id AS animation_id,
    a.name AS animation_name,
    a.display_name AS animation_display_name,
    a.frame_count
FROM components c
JOIN component_animations ca ON c.id = ca.component_id
JOIN animations a ON ca.animation_id = a.id;

-- View to get all layers for each component
CREATE VIEW view_component_layers AS
SELECT 
    c.id AS component_id,
    c.name AS component_name,
    cl.layer_number,
    cl.z_position,
    cl.custom_animation,
    lp.path,
    bt.name AS body_type_name,
    bt.display_name AS body_type_display_name
FROM components c
JOIN component_layers cl ON c.id = cl.component_id
JOIN layer_paths lp ON cl.id = lp.layer_id
JOIN body_types bt ON lp.body_type_id = bt.id;

-- View to get all credits for each component
CREATE VIEW view_component_credits AS
SELECT 
    c.id AS component_id,
    c.name AS component_name,
    cr.file_path,
    cr.notes,
    a.name AS author_name,
    l.name AS license_name,
    l.url AS license_url,
    cu.url AS credit_url
FROM components c
JOIN credits cr ON c.id = cr.component_id
JOIN credit_authors ca ON cr.id = ca.credit_id
JOIN authors a ON ca.author_id = a.id
JOIN credit_licenses cl ON cr.id = cl.credit_id
JOIN licenses l ON cl.license_id = l.id
LEFT JOIN credit_urls cu ON cr.id = cu.credit_id;

-- View to get all asset files for a specific component, variant, and animation
CREATE VIEW view_asset_files AS
SELECT 
    c.id AS component_id,
    c.name AS component_name,
    v.id AS variant_id,
    v.name AS variant_name,
    a.id AS animation_id,
    a.name AS animation_name,
    bt.id AS body_type_id,
    bt.name AS body_type_name,
    cl.layer_number,
    af.file_path
FROM components c
JOIN component_layers cl ON c.id = cl.component_id
JOIN layer_paths lp ON cl.id = lp.layer_id
JOIN body_types bt ON lp.body_type_id = bt.id
JOIN asset_files af ON lp.id = af.layer_path_id
JOIN variants v ON af.variant_id = v.id
JOIN animations a ON af.animation_id = a.id; 