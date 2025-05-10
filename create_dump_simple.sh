#!/bin/bash

# Simple script to create an SQLite dump file from the schema

DB_FILE="lpc_character_generator.db"
SCHEMA_FILE="lpc_character_generator.sql"
DUMP_FILE="lpc_character_generator_dump.sql"

# Check if schema file exists
if [ ! -f "$SCHEMA_FILE" ]; then
    echo "Error: Schema file '$SCHEMA_FILE' not found."
    exit 1
fi

# Remove existing database if it exists
if [ -f "$DB_FILE" ]; then
    echo "Removing existing database..."
    rm "$DB_FILE"
fi

# Create new database from schema
echo "Creating database from schema..."
sqlite3 "$DB_FILE" < "$SCHEMA_FILE"

# Create dump file
echo "Creating dump file..."
sqlite3 "$DB_FILE" .dump > "$DUMP_FILE"

echo "Done! SQLite dump created: $DUMP_FILE"
echo "The dump file can be used to recreate the database with the command:"
echo "sqlite3 new_database.db < $DUMP_FILE"

# Optional: Remove the temporary database
rm "$DB_FILE"

echo "Temporary database removed." 