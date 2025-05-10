local ffi = require("ffi")

-- C definitions for SQLite
ffi.cdef[[
    typedef struct sqlite3 sqlite3;
    typedef struct sqlite3_stmt sqlite3_stmt;

    typedef int (*sqlite3_callback)(void*,int,char**,char**);

    int sqlite3_open(const char *filename, sqlite3 **ppDb);
    int sqlite3_close(sqlite3*);
    int sqlite3_exec(sqlite3*, const char *sql, sqlite3_callback, void*, char **errmsg);
    const char *sqlite3_errmsg(sqlite3*);

    int sqlite3_prepare_v2(sqlite3 *db, const char *zSql, int nByte,
                           sqlite3_stmt **ppStmt, const char **pzTail);
    int sqlite3_step(sqlite3_stmt*);
    int sqlite3_finalize(sqlite3_stmt*);
    int sqlite3_column_count(sqlite3_stmt*);
    const char *sqlite3_column_name(sqlite3_stmt*, int);
    int sqlite3_column_type(sqlite3_stmt*, int);
    const unsigned char *sqlite3_column_text(sqlite3_stmt*, int);
    int sqlite3_column_int(sqlite3_stmt*, int);
    double sqlite3_column_double(sqlite3_stmt*, int);
    
    int sqlite3_bind_int(sqlite3_stmt*, int, int);
    int sqlite3_bind_double(sqlite3_stmt*, int, double);
    int sqlite3_bind_text(sqlite3_stmt*, int, const char*, int n, void(*)(void*));
    int sqlite3_bind_null(sqlite3_stmt*, int);
    int sqlite3_reset(sqlite3_stmt*);
    int sqlite3_clear_bindings(sqlite3_stmt*);
]]

-- Load the SQLite3 library
local C = ffi.load("sqlite3")

local LpcDatabase = {}
LpcDatabase.__index = LpcDatabase

function LpcDatabase.new()
    local self = setmetatable({}, LpcDatabase)
    self.db = nil
    self.prepared_statements = {}
    return self
end

function LpcDatabase:database_load()
    print("Starting LPC database initialization...")
    
    -- Ensure save directory exists
    local save_dir = love.filesystem.getSaveDirectory()
    print("Save directory: " .. save_dir)
    
    if not love.filesystem.getInfo(save_dir) then
        print("Creating save directory...")
        love.filesystem.createDirectory(save_dir)
    end
    
    -- Close any existing connection
    if self.db then
        print("Closing existing database connection...")
        self:close()
    end
    
    local abs_path = save_dir .. "/lpc_character_generator.db"
    local temp_path = save_dir .. "/lpc_character_generator_temp.db"
    print("Database path: " .. abs_path)
    
    -- Check if we need to update the schema
    local needs_update = false
    if love.filesystem.getInfo(abs_path) then
        print("Existing database found, checking schema...")
        -- Open existing database to check schema
        local db_ptr = ffi.new("sqlite3*[1]")
        local rc = C.sqlite3_open(abs_path, db_ptr)
        if rc == 0 then
            self.db = db_ptr[0]
            -- Enable foreign key support and set busy timeout
            print("Configuring database settings...")
            self:execute_sql("PRAGMA foreign_keys = ON")
            self:execute_sql("PRAGMA busy_timeout = 5000")
            
            -- Check required tables
            local required_tables = {
                "categories",
                "component_types",
                "components",
                "variants",
                "animations",
                "body_types"
            }
            
            local existing_tables = {}
            for row in self:query("SELECT name FROM sqlite_master WHERE type='table'") do
                existing_tables[row.name] = true
            end
            
            for _, table_name in ipairs(required_tables) do
                if not existing_tables[table_name] then
                    needs_update = true
                    break
                end
            end
            
            -- Close the connection
            self:close()
        end
    else
        needs_update = true
    end
    
    if needs_update then
        print("Schema needs update, creating new database...")
        -- Create new database in temporary location
        local db_ptr = ffi.new("sqlite3*[1]")
        local rc = C.sqlite3_open(temp_path, db_ptr)
        if rc ~= 0 then
            error("Cannot create temporary database: " .. ffi.string(C.sqlite3_errmsg(db_ptr[0])))
        end
        
        self.db = db_ptr[0]
        print("Temporary database created.")
        
        -- Enable foreign key support
        self:execute_sql("PRAGMA foreign_keys = ON")
        
        -- Initialize schema
        self:initialize_schema()
        
        -- Close the temporary database
        self:close()
        
        -- Replace old database with new one
        if love.filesystem.getInfo(abs_path) then
            print("Removing old database...")
            os.remove(abs_path)
        end
        print("Moving new database into place...")
        os.rename(temp_path, abs_path)
        
        -- Open the final database
        rc = C.sqlite3_open(abs_path, db_ptr)
        if rc ~= 0 then
            error("Cannot open final database: " .. ffi.string(C.sqlite3_errmsg(db_ptr[0])))
        end
        self.db = db_ptr[0]
    else
        print("Schema is up to date, opening existing database...")
        -- Open existing database
        local db_ptr = ffi.new("sqlite3*[1]")
        local rc = C.sqlite3_open(abs_path, db_ptr)
        if rc ~= 0 then
            error("Cannot open database: " .. ffi.string(C.sqlite3_errmsg(db_ptr[0])))
        end
        self.db = db_ptr[0]
        
        -- Enable foreign key support and set busy timeout
        print("Configuring database settings...")
        self:execute_sql("PRAGMA foreign_keys = ON")
        self:execute_sql("PRAGMA busy_timeout = 5000")
    end
    
    -- Prepare commonly used statements
    self:prepare_statements()
    
    print("Database initialization complete.")
end

function LpcDatabase:initialize_schema()
    print("Loading schema from lpc_character_generator_dump.sql...")
    -- Load dump file from source directory
    local dump_sql = love.filesystem.read("lpc_character_generator_dump.sql")
    if not dump_sql then
        print("ERROR: lpc_character_generator_dump.sql not found!")
        print("Current directory contents:")
        local items = love.filesystem.getDirectoryItems(".")
        for _, item in ipairs(items) do
            print("  " .. item)
        end
        error("Error: lpc_character_generator_dump.sql not found in source directory")
    end
    
    print("Found lpc_character_generator_dump.sql, executing statements...")
    -- Split the dump file into individual statements
    local stmt_count = 0
    for stmt in dump_sql:gmatch("[^;]+") do
        local trimmed_stmt = stmt:match("^%s*(.-)%s*$")
        if trimmed_stmt ~= "" then
            stmt_count = stmt_count + 1
            print("Executing statement " .. stmt_count .. ": " .. trimmed_stmt:sub(1, 50) .. "...")
            local success, err = pcall(function()
                self:execute_sql(trimmed_stmt .. ";")
            end)
            if not success then
                print("Error executing SQL statement " .. stmt_count .. ":")
                print("Statement: " .. trimmed_stmt)
                print("Error: " .. tostring(err))
                error("Failed to initialize database: " .. tostring(err))
            end
        end
    end
    print("Database initialization complete. Executed " .. stmt_count .. " statements.")
    
    -- Verify tables were created
    print("Verifying tables...")
    local tables = {}
    for row in self:query("SELECT name FROM sqlite_master WHERE type='table'") do
        table.insert(tables, row.name)
    end
    print("Created tables: " .. table.concat(tables, ", "))
end

function LpcDatabase:prepare_statements()
    -- Prepare commonly used statements for better performance
    self.prepared_statements = {
        get_categories = self:prepare("SELECT id, name, display_name FROM categories ORDER BY display_name"),
        get_component_types = self:prepare("SELECT id, name, display_name FROM component_types WHERE category_id = ? ORDER BY display_name"),
        get_components = self:prepare("SELECT id, name, display_name FROM components WHERE type_id = ? ORDER BY display_name"),
        get_variants = self:prepare("SELECT v.id, v.name, v.display_name FROM variants v JOIN component_variants cv ON v.id = cv.variant_id WHERE cv.component_id = ? ORDER BY v.display_name"),
        get_animations = self:prepare("SELECT a.id, a.name, a.display_name, a.frame_count FROM animations a JOIN component_animations ca ON a.id = ca.animation_id WHERE ca.component_id = ? ORDER BY a.display_name"),
        get_body_types = self:prepare("SELECT id, name, display_name FROM body_types ORDER BY display_name"),
        get_asset_files = self:prepare([[
            SELECT af.file_path, cl.z_position, cl.layer_number
            FROM asset_files af
            JOIN layer_paths lp ON af.layer_path_id = lp.id
            JOIN component_layers cl ON lp.layer_id = cl.id
            WHERE cl.component_id = ? AND af.variant_id = ? AND af.animation_id = ? AND lp.body_type_id = ?
            ORDER BY cl.z_position
        ]]),
        get_component_by_name = self:prepare("SELECT id, name, display_name, type_id FROM components WHERE name = ?"),
        get_variant_by_name = self:prepare("SELECT id, name, display_name FROM variants WHERE name = ?"),
        get_animation_by_name = self:prepare("SELECT id, name, display_name, frame_count FROM animations WHERE name = ?"),
        get_body_type_by_name = self:prepare("SELECT id, name, display_name FROM body_types WHERE name = ?")
    }
end

function LpcDatabase:execute_sql(sql)
    if not sql then
        error("SQL string is nil")
    end
    
    local errmsg = ffi.new("char*[1]")
    local res = C.sqlite3_exec(self.db, sql, nil, nil, errmsg)
    if res ~= 0 then
        error("SQLite error: " .. ffi.string(C.sqlite3_errmsg(self.db)))
    end
    return true
end

function LpcDatabase:prepare(sql)
    if not sql then
        error("SQL string is nil")
    end
    
    local stmt_ptr = ffi.new("sqlite3_stmt*[1]")
    local tail = ffi.new("const char*[1]")
    
    local rc = C.sqlite3_prepare_v2(self.db, sql, #sql, stmt_ptr, tail)
    if rc ~= 0 then
        error("Prepare failed: " .. ffi.string(C.sqlite3_errmsg(self.db)))
    end
    
    return stmt_ptr[0]
end

function LpcDatabase:bind_values(stmt, ...)
    local values = {...}
    for i, value in ipairs(values) do
        local value_type = type(value)
        if value == nil then
            C.sqlite3_bind_null(stmt, i)
        elseif value_type == "number" then
            if math.floor(value) == value then
                C.sqlite3_bind_int(stmt, i, value)
            else
                C.sqlite3_bind_double(stmt, i, value)
            end
        elseif value_type == "string" then
            C.sqlite3_bind_text(stmt, i, value, #value, nil)
        else
            error("Unsupported bind value type: " .. value_type)
        end
    end
end

function LpcDatabase:execute_prepared(stmt, ...)
    -- Reset statement and clear bindings
    C.sqlite3_reset(stmt)
    C.sqlite3_clear_bindings(stmt)
    
    -- Bind values
    self:bind_values(stmt, ...)
    
    -- Execute statement
    local results = {}
    while C.sqlite3_step(stmt) == 100 do -- SQLITE_ROW
        local num_cols = C.sqlite3_column_count(stmt)
        local row = {}
        for i = 0, num_cols - 1 do
            local col_name = ffi.string(C.sqlite3_column_name(stmt, i))
            local col_type = C.sqlite3_column_type(stmt, i)
            if col_type == 1 then -- SQLITE_INTEGER
                row[col_name] = C.sqlite3_column_int(stmt, i)
            elseif col_type == 2 then -- SQLITE_FLOAT
                row[col_name] = C.sqlite3_column_double(stmt, i)
            elseif col_type == 3 then -- SQLITE_TEXT
                row[col_name] = ffi.string(C.sqlite3_column_text(stmt, i))
            else
                row[col_name] = nil
            end
        end
        table.insert(results, row)
    end
    
    return results
end

function LpcDatabase:query(sql)
    if not sql then
        error("SQL string is nil")
    end
    
    local stmt_ptr = ffi.new("sqlite3_stmt*[1]")
    local tail = ffi.new("const char*[1]")
    
    local rc = C.sqlite3_prepare_v2(self.db, sql, #sql, stmt_ptr, tail)
    if rc ~= 0 then
        error("Prepare failed: " .. ffi.string(C.sqlite3_errmsg(self.db)))
    end
    
    local stmt = stmt_ptr[0]
    
    return function()
        if C.sqlite3_step(stmt) == 100 then -- SQLITE_ROW
            local num_cols = C.sqlite3_column_count(stmt)
            local row = {}
            for i = 0, num_cols - 1 do
                local col_name = ffi.string(C.sqlite3_column_name(stmt, i))
                local col_type = C.sqlite3_column_type(stmt, i)
                if col_type == 1 then -- SQLITE_INTEGER
                    row[col_name] = C.sqlite3_column_int(stmt, i)
                elseif col_type == 2 then -- SQLITE_FLOAT
                    row[col_type] = C.sqlite3_column_double(stmt, i)
                elseif col_type == 3 then -- SQLITE_TEXT
                    row[col_name] = ffi.string(C.sqlite3_column_text(stmt, i))
                else
                    row[col_name] = nil
                end
            end
            return row
        else
            C.sqlite3_finalize(stmt)
            return nil
        end
    end
end

-- Helper functions for character generation
function LpcDatabase:get_categories()
    return self:execute_prepared(self.prepared_statements.get_categories)
end

function LpcDatabase:get_component_types(category_id)
    return self:execute_prepared(self.prepared_statements.get_component_types, category_id)
end

function LpcDatabase:get_components(type_id)
    return self:execute_prepared(self.prepared_statements.get_components, type_id)
end

function LpcDatabase:get_variants(component_id)
    return self:execute_prepared(self.prepared_statements.get_variants, component_id)
end

function LpcDatabase:get_animations(component_id)
    return self:execute_prepared(self.prepared_statements.get_animations, component_id)
end

function LpcDatabase:get_body_types()
    return self:execute_prepared(self.prepared_statements.get_body_types)
end

function LpcDatabase:get_asset_files(component_id, variant_id, animation_id, body_type_id)
    return self:execute_prepared(self.prepared_statements.get_asset_files, component_id, variant_id, animation_id, body_type_id)
end

function LpcDatabase:get_component_by_name(name)
    local results = self:execute_prepared(self.prepared_statements.get_component_by_name, name)
    return results[1]
end

function LpcDatabase:get_variant_by_name(name)
    local results = self:execute_prepared(self.prepared_statements.get_variant_by_name, name)
    return results[1]
end

function LpcDatabase:get_animation_by_name(name)
    local results = self:execute_prepared(self.prepared_statements.get_animation_by_name, name)
    return results[1]
end

function LpcDatabase:get_body_type_by_name(name)
    local results = self:execute_prepared(self.prepared_statements.get_body_type_by_name, name)
    return results[1]
end

function LpcDatabase:close()
    if self.db then
        -- Check if there's an active transaction using PRAGMA
        local has_transaction = false
        for row in self:query("PRAGMA transaction_state") do
            has_transaction = row.transaction_state ~= 0
            break
        end
        
        -- Only commit if there's an active transaction
        if has_transaction then
            self:execute_sql("COMMIT")
        end
        
        -- Finalize all prepared statements
        for _, stmt in pairs(self.prepared_statements) do
            C.sqlite3_finalize(stmt)
        end
        self.prepared_statements = {}
        
        C.sqlite3_close(self.db)
        self.db = nil
    end
end

return LpcDatabase 