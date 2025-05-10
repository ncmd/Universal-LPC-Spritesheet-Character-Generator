# LPC Character Generator - Love2D Demo

This is a simple Love2D application that demonstrates how to use the LPC character generator database with the Love2D game engine.

## Files

- `lpc_database.lua` - SQLite database module for Love2D that works with the LPC character generator schema
- `main.lua` - Main Love2D application that displays character components
- `lpc_character_generator.sql` - SQLite schema file
- `lpc_character_generator_dump.sql` - SQLite dump file (will be created if not present)

## Requirements

- [Love2D](https://love2d.org/) (version 11.0+)
- SQLite library (typically included with Love2D)

## Usage

1. Place the files in a directory
2. Make sure the `lpc_character_generator.sql` file is in the same directory
3. Run the application with Love2D:
   ```
   love /path/to/directory
   ```

## How It Works

The application demonstrates:

1. Loading the SQLite database schema
2. Querying the database for character components
3. Displaying sprite sheets with proper animation
4. Interactive UI for selecting different components

## Interface

- Left sidebar: Select categories, component types, components, variants, animations, and body types
- Right area: Preview of the selected character component
- Mouse wheel: Scroll the sidebar
- Mouse click: Select items in the sidebar

## Database Integration

The `lpc_database.lua` module provides a clean interface to the SQLite database using LuaJIT's FFI. It handles:

- Database initialization and schema loading
- Prepared statements for common queries
- Helper functions for retrieving character components
- Proper resource cleanup

## Customization

You can modify this demo to:

- Add support for multiple component layers
- Implement character saving/loading
- Add more UI controls for customization
- Export characters as sprite sheets

## Troubleshooting

If you encounter issues:

1. Check if the SQLite library is properly loaded
2. Ensure the schema file is in the correct location
3. Look for error messages in the console
4. Verify that the sprite files exist and are accessible

## Credits

This demo uses the Universal LPC Spritesheet Character Generator assets, which are provided under various open licenses. See the main project repository for full credits and license information. 