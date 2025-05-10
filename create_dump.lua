#!/usr/bin/env lua

-- create_dump.lua
-- Script to create an SQLite dump file from the populated LPC character generator database

local sqlite3 = require("lsqlite3")
local DB_FILE = "lpc_character_generator.db"
local DUMP_FILE = "lpc_character_generator_dump.sql"

-- Check if database file exists
local db_exists = io.open(DB_FILE, "r")
if not db_exists then
    print("Error: Database file '" .. DB_FILE .. "' not found.")
    print("Please run populate_database.lua first to create and populate the database.")
    os.exit(1)
end
db_exists:close()

-- Open database connection
local db = sqlite3.open(DB_FILE)
if not db then
    print("Error: Failed to open database file '" .. DB_FILE .. "'.")
    os.exit(1)
end

-- Create dump file
local dump = io.open(DUMP_FILE, "w")
if not dump then
    print("Error: Failed to create dump file '" .. DUMP_FILE .. "'.")
    db:close()
    os.exit(1)
end

print("Creating SQLite dump file...")

-- Begin transaction and disable foreign keys for faster import
dump:write("PRAGMA foreign_keys=OFF;\n")
dump:write("BEGIN TRANSACTION;\n\n")

-- Get database schema
dump:write("-- Schema\n")
local schema_stmt = db:prepare("SELECT sql FROM sqlite_master WHERE sql IS NOT NULL AND type != 'index' ORDER BY type DESC, name")
for row in schema_stmt:rows() do
    if row[1] then
        dump:write(row[1] .. ";\n")
    end
end
schema_stmt:finalize()

-- Get indexes
dump:write("\n-- Indexes\n")
local index_stmt = db:prepare("SELECT sql FROM sqlite_master WHERE type = 'index' AND sql IS NOT NULL")
for row in index_stmt:rows() do
    if row[1] then
        dump:write(row[1] .. ";\n")
    end
end
index_stmt:finalize()

-- Helper function to escape string values
local function escape_value(val)
    if val == nil then
        return "NULL"
    elseif type(val) == "string" then
        -- Escape quotes and special characters
        val = val:gsub("'", "''")
        return "'" .. val .. "'"
    else
        return tostring(val)
    end
end

-- Get a list of all tables (excluding sqlite_ tables)
local tables = {}
local tables_stmt = db:prepare("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'view_%' ORDER BY name")
for row in tables_stmt:rows() do
    table.insert(tables, row[1])
end
tables_stmt:finalize()

-- Dump data from each table
dump:write("\n-- Table Data\n")
for _, table_name in ipairs(tables) do
    dump:write("\n-- Table: " .. table_name .. "\n")
    
    -- Get column names
    local columns = {}
    local columns_stmt = db:prepare("PRAGMA table_info(" .. table_name .. ")")
    for row in columns_stmt:rows() do
        table.insert(columns, row[1]) -- column name
    end
    columns_stmt:finalize()
    
    -- Check if table has data
    local count_stmt = db:prepare("SELECT COUNT(*) FROM " .. table_name)
    local count = 0
    for row in count_stmt:rows() do
        count = row[1]
    end
    count_stmt:finalize()
    
    if count > 0 then
        -- Get and format data
        local data_stmt = db:prepare("SELECT * FROM " .. table_name)
        for row in data_stmt:rows() do
            local values = {}
            for i=1, #row do
                table.insert(values, escape_value(row[i]))
            end
            dump:write(string.format("INSERT INTO %s VALUES(%s);\n", 
                table_name, table.concat(values, ", ")))
        end
        data_stmt:finalize()
    else
        dump:write("-- Table is empty\n")
    end
end

-- Commit transaction and enable foreign keys
dump:write("\nCOMMIT;\n")
dump:write("PRAGMA foreign_keys=ON;\n")

-- Close files
dump:close()
db:close()

print("Done! SQLite dump created successfully: " .. DUMP_FILE)
print("The dump file can be used to recreate the database with the command:")
print("sqlite3 new_database.db < " .. DUMP_FILE) 