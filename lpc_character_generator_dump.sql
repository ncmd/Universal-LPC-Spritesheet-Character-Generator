PRAGMA foreign_keys=OFF;
BEGIN TRANSACTION;
CREATE TABLE categories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL,
    description TEXT
);
INSERT INTO categories VALUES(1,'arms','Arms','Arm components');
INSERT INTO categories VALUES(2,'backpack','Backpack','Backpack items');
INSERT INTO categories VALUES(3,'bauldron','Bauldron','Shoulder armor');
INSERT INTO categories VALUES(4,'beards','Beards','Facial hair');
INSERT INTO categories VALUES(5,'body','Body','Base body components');
INSERT INTO categories VALUES(6,'cape','Cape','Capes and cloaks');
INSERT INTO categories VALUES(7,'dress','Dress','Full dresses');
INSERT INTO categories VALUES(8,'eyes','Eyes','Eye components');
INSERT INTO categories VALUES(9,'facial','Facial','Facial features');
INSERT INTO categories VALUES(10,'feet','Feet','Footwear');
INSERT INTO categories VALUES(11,'hair','Hair','Hairstyles');
INSERT INTO categories VALUES(12,'hat','Hat','Headwear');
INSERT INTO categories VALUES(13,'head','Head','Head components');
INSERT INTO categories VALUES(14,'legs','Legs','Leg wear');
INSERT INTO categories VALUES(15,'neck','Neck','Neck accessories');
INSERT INTO categories VALUES(16,'quiver','Quiver','Arrow quivers');
INSERT INTO categories VALUES(17,'shadow','Shadow','Character shadows');
INSERT INTO categories VALUES(18,'shield','Shield','Shields');
INSERT INTO categories VALUES(19,'shoulders','Shoulders','Shoulder accessories');
INSERT INTO categories VALUES(20,'tools','Tools','Held tools');
INSERT INTO categories VALUES(21,'torso','Torso','Torso clothing');
INSERT INTO categories VALUES(22,'weapon','Weapon','Weapons');
INSERT INTO categories VALUES(23,'wings','Wings','Character wings');
INSERT INTO categories VALUES(24,'wrists','Wrists','Wrist accessories');
INSERT INTO categories VALUES(25,'wound','Wound','Character wounds');
CREATE TABLE component_types (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    display_name TEXT NOT NULL,
    category_id INTEGER NOT NULL,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE,
    UNIQUE(name, category_id)
);
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
CREATE TABLE tags (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE
);
CREATE TABLE component_tags (
    component_id INTEGER NOT NULL,
    tag_id INTEGER NOT NULL,
    PRIMARY KEY (component_id, tag_id),
    FOREIGN KEY (component_id) REFERENCES components(id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
);
CREATE TABLE body_types (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL
);
INSERT INTO body_types VALUES(1,'male','Male');
INSERT INTO body_types VALUES(2,'female','Female');
INSERT INTO body_types VALUES(3,'muscular','Muscular');
INSERT INTO body_types VALUES(4,'pregnant','Pregnant');
INSERT INTO body_types VALUES(5,'teen','Teen');
CREATE TABLE variants (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL
);
CREATE TABLE animations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL,
    frame_count INTEGER NOT NULL
);
INSERT INTO animations VALUES(1,'spellcast','Spellcast',7);
INSERT INTO animations VALUES(2,'thrust','Thrust',8);
INSERT INTO animations VALUES(3,'walk','Walk',9);
INSERT INTO animations VALUES(4,'slash','Slash',6);
INSERT INTO animations VALUES(5,'shoot','Shoot',13);
INSERT INTO animations VALUES(6,'hurt','Hurt',6);
INSERT INTO animations VALUES(7,'watering','Watering',13);
INSERT INTO animations VALUES(8,'idle','Idle',1);
INSERT INTO animations VALUES(9,'jump','Jump',7);
INSERT INTO animations VALUES(10,'run','Run',8);
INSERT INTO animations VALUES(11,'sit','Sit',5);
INSERT INTO animations VALUES(12,'emote','Emote',4);
INSERT INTO animations VALUES(13,'climb','Climb',4);
INSERT INTO animations VALUES(14,'combat','Combat',1);
INSERT INTO animations VALUES(15,'1h_slash','1H Slash',6);
INSERT INTO animations VALUES(16,'1h_backslash','1H Backslash',6);
INSERT INTO animations VALUES(17,'1h_halfslash','1H Halfslash',6);
CREATE TABLE component_layers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    component_id INTEGER NOT NULL,
    layer_number INTEGER NOT NULL,
    z_position INTEGER NOT NULL,
    custom_animation TEXT,
    FOREIGN KEY (component_id) REFERENCES components(id) ON DELETE CASCADE,
    UNIQUE(component_id, layer_number)
);
CREATE TABLE layer_paths (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    layer_id INTEGER NOT NULL,
    body_type_id INTEGER NOT NULL,
    path TEXT NOT NULL,
    FOREIGN KEY (layer_id) REFERENCES component_layers(id) ON DELETE CASCADE,
    FOREIGN KEY (body_type_id) REFERENCES body_types(id) ON DELETE CASCADE,
    UNIQUE(layer_id, body_type_id)
);
CREATE TABLE component_variants (
    component_id INTEGER NOT NULL,
    variant_id INTEGER NOT NULL,
    PRIMARY KEY (component_id, variant_id),
    FOREIGN KEY (component_id) REFERENCES components(id) ON DELETE CASCADE,
    FOREIGN KEY (variant_id) REFERENCES variants(id) ON DELETE CASCADE
);
CREATE TABLE component_animations (
    component_id INTEGER NOT NULL,
    animation_id INTEGER NOT NULL,
    PRIMARY KEY (component_id, animation_id),
    FOREIGN KEY (component_id) REFERENCES components(id) ON DELETE CASCADE,
    FOREIGN KEY (animation_id) REFERENCES animations(id) ON DELETE CASCADE
);
CREATE TABLE authors (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE
);
CREATE TABLE licenses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    url TEXT
);
CREATE TABLE credits (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    component_id INTEGER NOT NULL,
    file_path TEXT NOT NULL,
    notes TEXT,
    FOREIGN KEY (component_id) REFERENCES components(id) ON DELETE CASCADE
);
CREATE TABLE credit_authors (
    credit_id INTEGER NOT NULL,
    author_id INTEGER NOT NULL,
    PRIMARY KEY (credit_id, author_id),
    FOREIGN KEY (credit_id) REFERENCES credits(id) ON DELETE CASCADE,
    FOREIGN KEY (author_id) REFERENCES authors(id) ON DELETE CASCADE
);
CREATE TABLE credit_licenses (
    credit_id INTEGER NOT NULL,
    license_id INTEGER NOT NULL,
    PRIMARY KEY (credit_id, license_id),
    FOREIGN KEY (credit_id) REFERENCES credits(id) ON DELETE CASCADE,
    FOREIGN KEY (license_id) REFERENCES licenses(id) ON DELETE CASCADE
);
CREATE TABLE credit_urls (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    credit_id INTEGER NOT NULL,
    url TEXT NOT NULL,
    FOREIGN KEY (credit_id) REFERENCES credits(id) ON DELETE CASCADE
);
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
DELETE FROM sqlite_sequence;
INSERT INTO sqlite_sequence VALUES('categories',25);
INSERT INTO sqlite_sequence VALUES('body_types',5);
INSERT INTO sqlite_sequence VALUES('animations',17);
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
COMMIT;
