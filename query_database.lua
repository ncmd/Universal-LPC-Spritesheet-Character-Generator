#!/usr/bin/env lua

-- query_database.lua
-- Utility script to demonstrate querying the LPC character generator database

local sqlite3 = require("lsqlite3")
local DB_FILE = "lpc_character_generator.db"

-- Function to print a table of results nicely
local function print_results(rows, headers)
    if #rows == 0 then
        print("No results found")
        return
    end
    
    -- Determine column widths
    local widths = {}
    for i, header in ipairs(headers) do
        widths[i] = #header
    end
    
    for _, row in ipairs(rows) do
        for i, value in ipairs(row) do
            if value and #tostring(value) > widths[i] then
                widths[i] = #tostring(value)
            end
        end
    end
    
    -- Print headers
    local header_line = "| "
    local separator = "+-"
    for i, header in ipairs(headers) do
        header_line = header_line .. string.format("%-" .. widths[i] .. "s | ", header)
        separator = separator .. string.rep("-", widths[i]) .. "-+-"
    end
    
    print(separator)
    print(header_line)
    print(separator)
    
    -- Print rows
    for _, row in ipairs(rows) do
        local line = "| "
        for i, value in ipairs(row) do
            line = line .. string.format("%-" .. widths[i] .. "s | ", tostring(value or "NULL"))
        end
        print(line)
    end
    
    print(separator)
    print(string.format("%d rows", #rows))
end

-- Open the database
local db = sqlite3.open(DB_FILE)
if not db then
    error("Failed to open database. Run populate_database.lua first to create it.")
end

-- Available query examples
local queries = {
    ["categories"] = {
        description = "List all component categories",
        sql = "SELECT id, name, display_name, description FROM categories ORDER BY name",
        headers = {"ID", "Name", "Display Name", "Description"}
    },
    ["components"] = {
        description = "List components by category",
        sql = "SELECT c.id, c.name, c.display_name, ct.name as type_name FROM components c JOIN component_types ct ON c.type_id = ct.id WHERE ct.category_id = ? ORDER BY c.name",
        params = function() 
            print("Enter category ID: ")
            return {tonumber(io.read())}
        end,
        headers = {"ID", "Name", "Display Name", "Type"}
    },
    ["variants"] = {
        description = "List variants for a component",
        sql = "SELECT v.id, v.name, v.display_name FROM variants v JOIN component_variants cv ON v.id = cv.variant_id WHERE cv.component_id = ? ORDER BY v.name",
        params = function() 
            print("Enter component ID: ")
            return {tonumber(io.read())}
        end,
        headers = {"ID", "Name", "Display Name"}
    },
    ["animations"] = {
        description = "List animations for a component",
        sql = "SELECT a.id, a.name, a.display_name, a.frame_count FROM animations a JOIN component_animations ca ON a.id = ca.animation_id WHERE ca.component_id = ? ORDER BY a.name",
        params = function() 
            print("Enter component ID: ")
            return {tonumber(io.read())}
        end,
        headers = {"ID", "Name", "Display Name", "Frame Count"}
    },
    ["component_search"] = {
        description = "Search for components by name",
        sql = "SELECT c.id, c.name, c.display_name, ct.name as type_name, cat.name as category_name FROM components c JOIN component_types ct ON c.type_id = ct.id JOIN categories cat ON ct.category_id = cat.id WHERE c.name LIKE ? ORDER BY c.name",
        params = function() 
            print("Enter search term (use % as wildcard): ")
            return {io.read()}
        end,
        headers = {"ID", "Name", "Display Name", "Type", "Category"}
    },
    ["asset_files"] = {
        description = "List asset files for component/variant/animation",
        sql = [[
            SELECT af.file_path, bt.name as body_type, cl.layer_number
            FROM asset_files af
            JOIN layer_paths lp ON af.layer_path_id = lp.id
            JOIN component_layers cl ON lp.layer_id = cl.id
            JOIN body_types bt ON lp.body_type_id = bt.id
            WHERE cl.component_id = ? AND af.variant_id = ? AND af.animation_id = ?
            ORDER BY cl.z_position
        ]],
        params = function() 
            print("Enter component ID: ")
            local component_id = tonumber(io.read())
            print("Enter variant ID: ")
            local variant_id = tonumber(io.read())
            print("Enter animation ID: ")
            local animation_id = tonumber(io.read())
            return {component_id, variant_id, animation_id}
        end,
        headers = {"File Path", "Body Type", "Layer Number"}
    },
    ["credits"] = {
        description = "List credits for a component",
        sql = [[
            SELECT a.name as author, l.name as license, cr.notes, cu.url
            FROM credits cr
            JOIN credit_authors ca ON cr.id = ca.credit_id
            JOIN authors a ON ca.author_id = a.id
            JOIN credit_licenses cl ON cr.id = cl.credit_id
            JOIN licenses l ON cl.license_id = l.id
            LEFT JOIN credit_urls cu ON cr.id = cu.credit_id
            WHERE cr.component_id = ?
        ]],
        params = function() 
            print("Enter component ID: ")
            return {tonumber(io.read())}
        end,
        headers = {"Author", "License", "Notes", "URL"}
    },
    ["stats"] = {
        description = "Show database statistics",
        sql = [[
            SELECT 
                (SELECT COUNT(*) FROM categories) as categories,
                (SELECT COUNT(*) FROM component_types) as component_types,
                (SELECT COUNT(*) FROM components) as components,
                (SELECT COUNT(*) FROM variants) as variants,
                (SELECT COUNT(*) FROM animations) as animations,
                (SELECT COUNT(*) FROM body_types) as body_types,
                (SELECT COUNT(*) FROM authors) as authors,
                (SELECT COUNT(*) FROM licenses) as licenses,
                (SELECT COUNT(*) FROM asset_files) as asset_files
        ]],
        headers = {"Categories", "Component Types", "Components", "Variants", "Animations", "Body Types", "Authors", "Licenses", "Asset Files"}
    }
}

-- Print available queries
local function show_menu()
    print("\nLPC Character Generator Database Query Tool")
    print("==========================================\n")
    print("Available queries:")
    
    local query_names = {}
    for name, _ in pairs(queries) do
        table.insert(query_names, name)
    end
    
    table.sort(query_names)
    
    for _, name in ipairs(query_names) do
        print(string.format("  %s: %s", name, queries[name].description))
    end
    
    print("\nEnter query name or 'exit' to quit:")
end

-- Main loop
while true do
    show_menu()
    local choice = io.read()
    
    if choice == "exit" then
        break
    end
    
    local query = queries[choice]
    if query then
        local params = {}
        if query.params then
            params = query.params()
        end
        
        -- Execute the query
        local stmt = db:prepare(query.sql)
        if stmt then
            -- Bind parameters
            for i, param in ipairs(params) do
                stmt:bind(i, param)
            end
            
            -- Collect results
            local rows = {}
            for row in stmt:rows() do
                table.insert(rows, row)
            end
            
            -- Print results
            print_results(rows, query.headers)
            
            stmt:finalize()
        else
            print("Error preparing query: " .. db:errmsg())
        end
    else
        print("Unknown query: " .. choice)
    end
end

-- Close the database
db:close()
print("Goodbye!") 