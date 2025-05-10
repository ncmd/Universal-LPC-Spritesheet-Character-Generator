#!/usr/bin/env lua

-- populate_database.lua
-- Script to populate the SQLite database with LPC character generator data
-- This script efficiently processes all sheet definition files and registers all sprite assets

local sqlite3 = require("lsqlite3")
local json = require("dkjson") -- Using dkjson as it's more commonly available than plain "json"
local lfs = require("lfs")

-- Database file path
local DB_FILE = "lpc_character_generator.db"

-- Cache tables to avoid redundant inserts and speed up lookups
local categories_cache = {}
local component_types_cache = {}
local body_types_cache = {}
local variants_cache = {}
local animations_cache = {}
local components_cache = {}
local authors_cache = {}
local licenses_cache = {}
local tags_cache = {}

-- Initialize database (create it if it doesn't exist)
local function initialize_database()
    -- Check if DB file exists
    local f = io.open(DB_FILE, "r")
    if f then
        f:close()
        os.remove(DB_FILE) -- Remove existing database to start fresh
    end
    
    -- Create new database with schema
    local db = sqlite3.open(DB_FILE)
    local schema = io.open("lpc_character_generator.sql", "r")
    if not schema then
        error("Schema file lpc_character_generator.sql not found")
    end
    
    local sql = schema:read("*all")
    schema:close()
    
    -- Execute schema SQL
    db:exec(sql)
    
    return db
end

-- Helper function to escape single quotes in strings for SQL
local function escape_sql(str)
    if type(str) ~= "string" then return "NULL" end
    return string.gsub(str, "'", "''")
end

-- Helper function to execute SQL with error handling
local function exec_sql(db, sql)
    local result = db:exec(sql)
    if result ~= sqlite3.OK then
        print("SQL error: " .. db:errmsg() .. "\nSQL: " .. sql)
    end
    return result
end

-- Helper function to get ID from a cache table or insert new item
local function get_or_insert_id(db, table_name, cache, name, display_name, extra_fields)
    if cache[name] then
        return cache[name]
    end
    
    -- Check if the item already exists in the database
    local stmt = db:prepare("SELECT id FROM " .. table_name .. " WHERE name = ?")
    stmt:bind(1, name)
    for row in stmt:rows() do
        cache[name] = row[1]
        stmt:finalize()
        return row[1]
    end
    stmt:finalize()
    
    -- Item not found, insert it
    local sql = string.format(
        "INSERT INTO %s (name, display_name%s) VALUES ('%s', '%s'%s)",
        table_name,
        extra_fields and ", " .. extra_fields.names or "",
        escape_sql(name),
        escape_sql(display_name or name:gsub("_", " "):gsub("^%l", string.upper)),
        extra_fields and ", " .. extra_fields.values or ""
    )
    
    if exec_sql(db, sql) == sqlite3.OK then
        local id = db:last_insert_rowid()
        cache[name] = id
        return id
    end
    
    return nil
end

-- Process a single JSON sheet definition file
local function process_sheet_definition(db, filepath)
    local f = io.open(filepath, "rb")
    if not f then
        print("Could not open file: " .. filepath)
        return
    end
    
    local content = f:read("*all")
    f:close()
    
    local data = json.decode(content)
    if not data then
        print("Could not parse JSON from: " .. filepath)
        return
    end
    
    local filename = filepath:match("([^/\\]+)$")
    local name = filename:gsub("%.json$", "")
    
    -- Extract category and type from the name
    local category_name, type_name
    
    -- Special handling for weapons which have category in the middle
    if name:match("^weapon_") then
        category_name = "weapon"
        type_name = name:match("^weapon_([^_]+)")
    else
        -- Normal case: category_type_name.json
        category_name, type_name = name:match("^([^_]+)_([^_]+)")
    end
    
    if not category_name or not type_name then
        category_name = "misc"
        type_name = "general"
    end
    
    -- Get or insert category
    local category_id = get_or_insert_id(db, "categories", categories_cache, category_name, nil)
    
    -- Get or insert component type
    local type_id = get_or_insert_id(
        db, 
        "component_types", 
        component_types_cache, 
        type_name, 
        data.type_name or type_name,
        {names = "category_id", values = category_id}
    )
    
    -- Insert component
    local sql = string.format(
        "INSERT INTO components (name, display_name, type_id, filename, data) VALUES ('%s', '%s', %d, '%s', '%s')",
        escape_sql(name),
        escape_sql(data.name or name:gsub("_", " "):gsub("^%l", string.upper)),
        type_id,
        escape_sql(filepath),
        escape_sql(content)
    )
    exec_sql(db, sql)
    local component_id = db:last_insert_rowid()
    components_cache[name] = component_id
    
    -- Process tags if available
    if data.tags then
        for _, tag in ipairs(data.tags) do
            local tag_id = get_or_insert_id(db, "tags", tags_cache, tag, nil)
            exec_sql(db, string.format(
                "INSERT OR IGNORE INTO component_tags (component_id, tag_id) VALUES (%d, %d)",
                component_id, tag_id
            ))
        end
    end
    
    -- Process variants
    if data.variants then
        for _, variant in ipairs(data.variants) do
            local variant_id = get_or_insert_id(db, "variants", variants_cache, variant, nil)
            exec_sql(db, string.format(
                "INSERT OR IGNORE INTO component_variants (component_id, variant_id) VALUES (%d, %d)",
                component_id, variant_id
            ))
        end
    end
    
    -- Process animations
    if data.animations then
        for _, animation in ipairs(data.animations) do
            local animation_id = get_or_insert_id(db, "animations", animations_cache, animation, nil)
            exec_sql(db, string.format(
                "INSERT OR IGNORE INTO component_animations (component_id, animation_id) VALUES (%d, %d)",
                component_id, animation_id
            ))
        end
    end
    
    -- Process layers
    for i = 1, 10 do  -- Support up to 10 layers
        local layer_key = "layer_" .. i
        if data[layer_key] then
            local layer = data[layer_key]
            
            -- Insert layer
            local custom_animation = layer.custom_animation and ("'" .. escape_sql(layer.custom_animation) .. "'") or "NULL"
            exec_sql(db, string.format(
                "INSERT INTO component_layers (component_id, layer_number, z_position, custom_animation) VALUES (%d, %d, %d, %s)",
                component_id, i, tonumber(layer.zPos) or 0, custom_animation
            ))
            local layer_id = db:last_insert_rowid()
            
            -- Process layer paths for different body types
            for body_type, path in pairs(layer) do
                if body_type ~= "zPos" and body_type ~= "custom_animation" then
                    local body_type_id = get_or_insert_id(db, "body_types", body_types_cache, body_type, nil)
                    exec_sql(db, string.format(
                        "INSERT INTO layer_paths (layer_id, body_type_id, path) VALUES (%d, %d, '%s')",
                        layer_id, body_type_id, escape_sql(path)
                    ))
                end
            end
        end
    end
    
    -- Process credits
    if data.credits then
        for _, credit in ipairs(data.credits) do
            -- Insert credit
            exec_sql(db, string.format(
                "INSERT INTO credits (component_id, file_path, notes) VALUES (%d, '%s', %s)",
                component_id, 
                escape_sql(credit.file or ""), 
                credit.notes and ("'" .. escape_sql(credit.notes) .. "'") or "NULL"
            ))
            local credit_id = db:last_insert_rowid()
            
            -- Process authors
            if credit.authors then
                for _, author in ipairs(credit.authors) do
                    local author_id = get_or_insert_id(db, "authors", authors_cache, author, nil)
                    exec_sql(db, string.format(
                        "INSERT OR IGNORE INTO credit_authors (credit_id, author_id) VALUES (%d, %d)",
                        credit_id, author_id
                    ))
                end
            end
            
            -- Process licenses
            if credit.licenses then
                for _, license in ipairs(credit.licenses) do
                    local license_id = get_or_insert_id(db, "licenses", licenses_cache, license, nil)
                    exec_sql(db, string.format(
                        "INSERT OR IGNORE INTO credit_licenses (credit_id, license_id) VALUES (%d, %d)",
                        credit_id, license_id
                    ))
                end
            end
            
            -- Process URLs
            if credit.urls then
                for _, url in ipairs(credit.urls) do
                    exec_sql(db, string.format(
                        "INSERT INTO credit_urls (credit_id, url) VALUES (%d, '%s')",
                        credit_id, escape_sql(url)
                    ))
                end
            end
        end
    end
end

-- Process all sheet definition files
local function process_sheet_definitions(db, dir)
    print("Processing sheet definitions from directory: " .. dir)
    local count = 0
    
    for file in lfs.dir(dir) do
        if file:match("%.json$") then
            local filepath = dir .. "/" .. file
            print("Processing: " .. filepath)
            process_sheet_definition(db, filepath)
            count = count + 1
            
            -- Commit every 20 files to avoid large transactions
            if count % 20 == 0 then
                db:exec("COMMIT; BEGIN TRANSACTION;")
                print("Processed " .. count .. " files...")
            end
        end
    end
    
    print("Processed a total of " .. count .. " sheet definition files")
end

-- Register asset files by scanning the sprites directory
local function register_asset_files(db, dir)
    print("Scanning for asset files in: " .. dir)
    local count = 0
    
    -- Get all layer paths for lookup
    local layer_paths = {}
    local stmt = db:prepare("SELECT lp.id, lp.path, cl.component_id, bt.name FROM layer_paths lp JOIN component_layers cl ON lp.layer_id = cl.id JOIN body_types bt ON lp.body_type_id = bt.id")
    for row in stmt:rows() do
        local id, path, component_id, body_type = row[1], row[2], row[3], row[4]
        layer_paths[path] = {id = id, component_id = component_id, body_type = body_type}
    end
    stmt:finalize()
    
    -- Function to scan directories recursively
    local function scan_directory(path, current_path)
        current_path = current_path or ""
        
        for file in lfs.dir(path) do
            if file ~= "." and file ~= ".." then
                local full_path = path .. "/" .. file
                local attr = lfs.attributes(full_path)
                
                if attr and attr.mode == "directory" then
                    scan_directory(full_path, current_path .. "/" .. file)
                elseif attr and attr.mode == "file" and file:match("%.png$") then
                    -- Check if this is part of a spritesheet
                    local relative_path = current_path .. "/" .. file
                    
                    -- Parse the path to identify component, animation, variant, etc.
                    local component_path = relative_path:match("^/([^/]+/[^/]+/[^/]+)/")
                    if component_path then
                        local animation = relative_path:match("/([^/]+)/[^/]+%.png$")
                        local variant = file:gsub("%.png$", "")
                        
                        -- Special case for files starting with underscore (palettes, etc.)
                        if variant:sub(1, 1) == "_" then
                            goto continue
                        end
                        
                        -- Find matching layer path
                        for base_path, layer_info in pairs(layer_paths) do
                            if relative_path:find(base_path, 1, true) then
                                -- Get IDs for lookup
                                local variant_id = variants_cache[variant] or 0
                                local animation_id = animations_cache[animation] or 0
                                
                                if variant_id > 0 and animation_id > 0 then
                                    -- Insert asset file reference
                                    exec_sql(db, string.format(
                                        "INSERT OR IGNORE INTO asset_files (layer_path_id, animation_id, variant_id, file_path) VALUES (%d, %d, %d, '%s')",
                                        layer_info.id, animation_id, variant_id, escape_sql(full_path)
                                    ))
                                    count = count + 1
                                    
                                    -- Commit occasionally to avoid large transactions
                                    if count % 100 == 0 then
                                        db:exec("COMMIT; BEGIN TRANSACTION;")
                                        print("Registered " .. count .. " asset files...")
                                    end
                                end
                                
                                break
                            end
                        end
                        
                        ::continue::
                    end
                end
            end
        end
    end
    
    -- Start scanning from the sprites directory
    scan_directory(dir)
    print("Registered a total of " .. count .. " asset files")
end

-- Main function to populate the database
local function populate_database()
    print("Starting database population process...")
    local db = initialize_database()
    
    -- Use transactions for better performance
    db:exec("BEGIN TRANSACTION;")
    
    -- Process all sheet definitions
    process_sheet_definitions(db, "sheet_definitions")
    
    -- Commit changes
    db:exec("COMMIT;")
    db:exec("BEGIN TRANSACTION;")
    
    -- Register asset files
    register_asset_files(db, "spritesheets")
    
    -- Commit final changes
    db:exec("COMMIT;")
    
    -- Optimize database
    print("Optimizing database...")
    db:exec("VACUUM;")
    db:exec("ANALYZE;")
    
    -- Close database connection
    db:close()
    print("Database population completed successfully!")
end

-- Run the main function
populate_database() 