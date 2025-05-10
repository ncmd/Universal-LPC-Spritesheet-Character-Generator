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
]]

-- Load the SQLite3 library
local C = ffi.load("sqlite3")

local Database = {}
Database.__index = Database

function Database.new()
    local self = setmetatable({}, Database)
    self.db = nil
    return self
end

function Database:database_load()
    print("Starting database initialization...")
    
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
    
    local abs_path = save_dir .. "/lpc_assets.db"
    local temp_path = save_dir .. "/lpc_assets_temp.db"
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
                "spritesheets",
                "character_parts",
                "character_templates",
                "character_part_combinations",
                "animations",
                "character_animations"
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
    
    print("Database initialization complete.")
end

function Database:initialize_schema()
    print("Loading schema from lpc_assets.sql...")
    -- Load dump file from source directory
    local dump_sql = love.filesystem.read("lpc_assets.sql")
    if not dump_sql then
        print("ERROR: lpc_assets.sql not found!")
        print("Current directory contents:")
        local items = love.filesystem.getDirectoryItems(".")
        for _, item in ipairs(items) do
            print("  " .. item)
        end
        error("Error: lpc_assets.sql not found in source directory")
    end
    
    print("Found lpc_assets.sql, executing statements...")
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

function Database:execute_sql(sql)
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

function Database:query(sql)
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
                    row[col_name] = C.sqlite3_column_double(stmt, i)
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

function Database:close()
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
        
        C.sqlite3_close(self.db)
        self.db = nil
    end
end

return Database
