#!/usr/bin/env lua

-- Test script to verify the populated database functionality
-- This doesn't require Love2D, just the sqlite3 command line tool

local function execute_sql(db_file, sql)
    local cmd = string.format("sqlite3 %s \"%s\"", db_file, sql)
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()
    return result
end

local function query_database(db_file, sql)
    local result = execute_sql(db_file, sql)
    local lines = {}
    for line in result:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end
    return lines
end

-- Main test function
local function test_database()
    local db_file = "lpc_character_generator.db"
    
    print("Testing populated database...")
    
    -- Test categories
    print("\n1. Categories:")
    local categories = query_database(db_file, "SELECT id, name, display_name FROM categories LIMIT 10")
    for _, category in ipairs(categories) do
        print("  " .. category)
    end
    
    -- Test component types
    print("\n2. Component Types (for category 'torso'):")
    local component_types = query_database(db_file, 
        "SELECT ct.id, ct.name, ct.display_name FROM component_types ct " ..
        "JOIN categories c ON ct.category_id = c.id " ..
        "WHERE c.name = 'torso'")
    for _, comp_type in ipairs(component_types) do
        print("  " .. comp_type)
    end
    
    -- Test components
    print("\n3. Components (for type 'clothes'):")
    local components = query_database(db_file, 
        "SELECT c.id, c.name, c.display_name FROM components c " ..
        "JOIN component_types ct ON c.type_id = ct.id " ..
        "WHERE ct.name = 'clothes'")
    for _, component in ipairs(components) do
        print("  " .. component)
    end
    
    -- Test variants
    print("\n4. Variants (for component 'torso_clothes_blouse'):")
    local variants = query_database(db_file, 
        "SELECT v.id, v.name, v.display_name FROM variants v " ..
        "JOIN component_variants cv ON v.id = cv.variant_id " ..
        "JOIN components c ON cv.component_id = c.id " ..
        "WHERE c.name = 'torso_clothes_blouse'")
    for _, variant in ipairs(variants) do
        print("  " .. variant)
    end
    
    -- Test animations
    print("\n5. Animations (for component 'torso_clothes_blouse'):")
    local animations = query_database(db_file, 
        "SELECT a.id, a.name, a.display_name, a.frame_count FROM animations a " ..
        "JOIN component_animations ca ON a.id = ca.animation_id " ..
        "JOIN components c ON ca.component_id = c.id " ..
        "WHERE c.name = 'torso_clothes_blouse'")
    for _, animation in ipairs(animations) do
        print("  " .. animation)
    end
    
    -- Test body types
    print("\n6. Body Types:")
    local body_types = query_database(db_file, "SELECT id, name, display_name FROM body_types")
    for _, body_type in ipairs(body_types) do
        print("  " .. body_type)
    end
    
    -- Test asset files
    print("\n7. Asset Files:")
    local assets = query_database(db_file, 
        "SELECT af.file_path, cl.z_position, cl.layer_number " ..
        "FROM asset_files af " ..
        "JOIN layer_paths lp ON af.layer_path_id = lp.id " ..
        "JOIN component_layers cl ON lp.layer_id = cl.id")
    for _, asset in ipairs(assets) do
        print("  " .. asset)
    end
    
    -- Test component layers and paths
    print("\n8. Component Layers and Paths:")
    local layers = query_database(db_file, 
        "SELECT c.name as component, cl.layer_number, cl.z_position, lp.path, bt.name as body_type " ..
        "FROM component_layers cl " ..
        "JOIN components c ON cl.component_id = c.id " ..
        "JOIN layer_paths lp ON cl.id = lp.layer_id " ..
        "JOIN body_types bt ON lp.body_type_id = bt.id")
    for _, layer in ipairs(layers) do
        print("  " .. layer)
    end
    
    print("\nTest completed successfully!")
end

-- Run the test
test_database() 