#!/usr/bin/env lua

-- Simple test script to verify database functionality
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
    local db_file = "test_database.db"
    local dump_file = "lpc_character_generator_dump.sql"
    
    print("Creating test database from dump file...")
    os.execute("sqlite3 " .. db_file .. " < " .. dump_file)
    
    print("\nTesting database queries...")
    
    -- Test categories
    print("\n1. Categories:")
    local categories = query_database(db_file, "SELECT id, name, display_name FROM categories LIMIT 10")
    for _, category in ipairs(categories) do
        print("  " .. category)
    end
    
    -- Test component types
    print("\n2. Component Types (for category 'torso'):")
    local category_id = query_database(db_file, "SELECT id FROM categories WHERE name = 'torso'")[1]
    if category_id then
        local component_types = query_database(db_file, 
            "SELECT id, name, display_name FROM component_types WHERE category_id = " .. category_id .. " LIMIT 5")
        for _, comp_type in ipairs(component_types) do
            print("  " .. comp_type)
        end
    end
    
    -- Test components
    print("\n3. Components (for type 'clothes'):")
    local type_id = query_database(db_file, "SELECT id FROM component_types WHERE name = 'clothes' LIMIT 1")[1]
    if type_id then
        local components = query_database(db_file, 
            "SELECT id, name, display_name FROM components WHERE type_id = " .. type_id .. " LIMIT 5")
        for _, component in ipairs(components) do
            print("  " .. component)
        end
    end
    
    -- Test variants
    print("\n4. Variants (for component 'torso_clothes_blouse'):")
    local component_id = query_database(db_file, "SELECT id FROM components WHERE name = 'torso_clothes_blouse' LIMIT 1")[1]
    if component_id then
        local variants = query_database(db_file, 
            "SELECT v.id, v.name, v.display_name FROM variants v " ..
            "JOIN component_variants cv ON v.id = cv.variant_id " ..
            "WHERE cv.component_id = " .. component_id .. " LIMIT 5")
        for _, variant in ipairs(variants) do
            print("  " .. variant)
        end
    end
    
    -- Test animations
    print("\n5. Animations (for component 'torso_clothes_blouse'):")
    if component_id then
        local animations = query_database(db_file, 
            "SELECT a.id, a.name, a.display_name, a.frame_count FROM animations a " ..
            "JOIN component_animations ca ON a.id = ca.animation_id " ..
            "WHERE ca.component_id = " .. component_id .. " LIMIT 5")
        for _, animation in ipairs(animations) do
            print("  " .. animation)
        end
    end
    
    -- Test body types
    print("\n6. Body Types:")
    local body_types = query_database(db_file, "SELECT id, name, display_name FROM body_types LIMIT 5")
    for _, body_type in ipairs(body_types) do
        print("  " .. body_type)
    end
    
    -- Test asset files
    print("\n7. Asset Files (sample query):")
    local asset_query = [[
        SELECT af.file_path, cl.z_position, cl.layer_number
        FROM asset_files af
        JOIN layer_paths lp ON af.layer_path_id = lp.id
        JOIN component_layers cl ON lp.layer_id = cl.id
        LIMIT 5
    ]]
    local assets = query_database(db_file, asset_query)
    for _, asset in ipairs(assets) do
        print("  " .. asset)
    end
    
    print("\nTest completed successfully!")
    
    -- Clean up
    os.remove(db_file)
    print("Test database removed.")
end

-- Run the test
test_database() 