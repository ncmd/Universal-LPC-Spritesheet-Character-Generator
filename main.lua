-- LPC Character Generator using SQLite Database
-- This demo loads character parts from an SQLite database and renders a random character

-- Constants
local WINDOW_WIDTH = 800
local WINDOW_HEIGHT = 600
local CHARACTER_SCALE = 3
local SPRITE_WIDTH = 64  -- Standard LPC sprite width
local SPRITE_HEIGHT = 64 -- Standard LPC sprite height
local ANIMATION_SPEED = 0.2

-- Database configuration
local DB_FILE = "lpc_spritesheet.db"
local SPRITE_BASE_PATH = "spritesheets/" -- The base path where sprite PNG files are stored

-- Global variables
local conn          -- Database connection
local character = {} -- Character parts
local characterLayers = {} -- Loaded character images by layer
local currentFrame = 1
local animationTimer = 0
local currentAnimation = "idle"
local currentDirection = "south" -- south, west, east, north
local availableAnimations = {"idle", "walk", "run", "jump", "slash"}
local directions = {"south", "west", "east", "north"}
local spaceWasDown = false

-- Animation frame mappings (start, end frames for each animation)
local animationFrames = {
    idle = {1, 4},       -- idle animation uses frames 1-4
    walk = {5, 12},      -- walk animation uses frames 5-12
    run = {13, 20},      -- run animation uses frames 13-20
    jump = {21, 28},     -- jump animation uses frames 21-28
    slash = {29, 36},    -- slash animation uses frames 29-36
    spellcast = {37, 44},-- spellcast animation uses frames 37-44
    thrust = {45, 52},   -- thrust animation uses frames 45-52
    shoot = {53, 60},    -- shoot animation uses frames 53-60
    hurt = {61, 64},     -- hurt animation uses frames 61-64
}

-- Direction frame row mappings
local directionRows = {
    south = 1,
    west = 2,
    east = 3,
    north = 4
}

-- Function to initialize Love2D
function love.load()
    -- Set up window
    love.window.setTitle("LPC Character Generator")
    love.window.setMode(WINDOW_WIDTH, WINDOW_HEIGHT)

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
    local sqlite3 = ffi.load("sqlite3")

    -- Open database
    local db_ptr = ffi.new("sqlite3*[1]")
    local abs_path = DB_FILE
    local result = sqlite3.sqlite3_open(abs_path, db_ptr)

    if result ~= 0 then
        print("Failed to open database: " .. ffi.string(sqlite3.sqlite3_errmsg(db_ptr[0])))
        love.event.quit()
        return
    end

    local db = db_ptr[0]

    -- Create a wrapper for SQLite to mimic the Lua-SQLite interface
    conn = {
        db = db,
        sqlite3 = sqlite3,

        -- Execute a SQL query and return a cursor
        execute = function(self, sql)
            local stmt_ptr = ffi.new("sqlite3_stmt*[1]")
            local result = self.sqlite3.sqlite3_prepare_v2(self.db, sql, #sql, stmt_ptr, nil)

            if result ~= 0 then
                error("SQL error: " .. ffi.string(self.sqlite3.sqlite3_errmsg(self.db)))
            end

            local cursor = {
                stmt = stmt_ptr[0],
                sqlite3 = self.sqlite3,

                -- Fetch the next row
                fetch = function(self, t, mode)
                    local result = self.sqlite3.sqlite3_step(self.stmt)

                    if result ~= 100 then -- SQLITE_ROW = 100
                        return nil
                    end

                    local row = t or {}
                    local num_cols = self.sqlite3.sqlite3_column_count(self.stmt)

                    for i = 0, num_cols - 1 do
                        local name = ffi.string(self.sqlite3.sqlite3_column_name(self.stmt, i))
                        local value

                        local col_type = self.sqlite3.sqlite3_column_type(self.stmt, i)

                        if col_type == 1 then -- SQLITE_INTEGER
                            value = self.sqlite3.sqlite3_column_int(self.stmt, i)
                        elseif col_type == 2 then -- SQLITE_FLOAT
                            value = self.sqlite3.sqlite3_column_double(self.stmt, i)
                        elseif col_type == 3 then -- SQLITE_TEXT
                            value = ffi.string(self.sqlite3.sqlite3_column_text(self.stmt, i))
                        elseif col_type == 4 then -- SQLITE_BLOB
                            -- Not handling blobs in this simplified version
                            value = nil
                        else -- SQLITE_NULL or other
                            value = nil
                        end

                        if mode == "a" then
                            row[name] = value
                        else
                            table.insert(row, value)
                        end
                    end

                    return row
                end,

                -- Close the cursor
                close = function(self)
                    self.sqlite3.sqlite3_finalize(self.stmt)
                end
            }

            return cursor
        end,

        -- Close the connection
        close = function(self)
            self.sqlite3.sqlite3_close(self.db)
        end
    }

    if not conn then
        print("Failed to connect to database!")
        love.event.quit()
        return
    end

    -- Generate a random character
    generateRandomCharacter()

    -- Load character parts as images
    loadCharacterImages()

    print("Character generated successfully!")
end

-- Function to generate a random character from database
function generateRandomCharacter()
    -- Query available sheets
    local cursor = conn:execute("SELECT sheet_id, name, type_name FROM sheets")

    local sheets = {}
    local row = cursor:fetch({}, "a")
    while row do
        table.insert(sheets, row)
        row = cursor:fetch({}, "a")
    end
    cursor:close()

    -- Build character layer by layer
    character = {}

    -- Base body
    local bodySheet = findSheetByType(sheets, "body")
    if bodySheet then
        character.body = {
            sheet_id = bodySheet.sheet_id,
            name = bodySheet.name,
            type = bodySheet.type_name,
            path = getLayerPath(bodySheet.sheet_id)
        }
    end

    -- Add other parts (head, hair, clothes, etc.)
    -- We'll add parts in the right Z-order based on the database
    local cursor = conn:execute([[
        SELECT s.sheet_id, s.name, s.type_name
        FROM sheets s
        WHERE s.type_name != 'body'
        ORDER BY RANDOM()
    ]])

    local addedTypes = {body = true} -- Track added types to avoid duplicates

    local row = cursor:fetch({}, "a")
    while row do
        -- Only add if we don't have this type yet
        if not addedTypes[row.type_name] then
            -- 50% chance to add this part (for more variety)
            if love.math.random() > 0.5 then
                character[row.type_name] = {
                    sheet_id = row.sheet_id,
                    name = row.name,
                    type = row.type_name,
                    path = getLayerPath(row.sheet_id)
                }
                addedTypes[row.type_name] = true
            end
        end

        row = cursor:fetch({}, "a")
    end
    cursor:close()

    -- Ensure we have at least some basic parts
    ensureBasicParts(sheets)

    -- Query available animations for this character
    availableAnimations = {"idle"} -- Default animation is always available

    local cursor = conn:execute([[
        SELECT DISTINCT a.animation_name
        FROM animations a
        JOIN sheets s ON a.sheet_id = s.sheet_id
        WHERE s.type_name = 'body'
    ]])

    local row = cursor:fetch({}, "a")
    while row do
        if row.animation_name ~= "idle" then
            table.insert(availableAnimations, row.animation_name)
        end
        row = cursor:fetch({}, "a")
    end
    cursor:close()

    print("Available animations: " .. table.concat(availableAnimations, ", "))
end

-- Function to make sure we have basic parts for a complete character
function ensureBasicParts(sheets)
    local essentialTypes = {"body", "head", "hair"}

    for _, essentialType in ipairs(essentialTypes) do
        if not character[essentialType] then
            local sheet = findSheetByType(sheets, essentialType)
            if sheet then
                character[essentialType] = {
                    sheet_id = sheet.sheet_id,
                    name = sheet.name,
                    type = sheet.type_name,
                    path = getLayerPath(sheet.sheet_id)
                }
            end
        end
    end
end

-- Find a sheet by its type
function findSheetByType(sheets, typeName)
    local possibleSheets = {}

    for _, sheet in ipairs(sheets) do
        if sheet.type_name == typeName then
            table.insert(possibleSheets, sheet)
        end
    end

    if #possibleSheets > 0 then
        -- Return a random sheet of this type
        return possibleSheets[love.math.random(1, #possibleSheets)]
    end

    return nil
end

-- Get the file path for a sheet layer
function getLayerPath(sheetId)
    local cursor = conn:execute(string.format([[
        SELECT lp.path_value
        FROM layers l
        JOIN layer_paths lp ON l.layer_id = lp.layer_id
        WHERE l.sheet_id = %d
        AND lp.path_type = 'default'
        LIMIT 1
    ]], sheetId))

    local path = nil
    if cursor then
        local row = cursor:fetch({}, "a")
        if row then
            path = row.path_value
        end
        cursor:close()
    end

    -- If no specific path found, try to get from files table
    if not path then
        local cursor = conn:execute(string.format([[
            SELECT file_path
            FROM files
            WHERE sheet_id = %d
            LIMIT 1
        ]], sheetId))

        if cursor then
            local row = cursor:fetch({}, "a")
            if row then
                path = row.file_path
            end
            cursor:close()
        end
    end

    return path
end

-- Function to safely load an image file
function safeLoadImage(path)
    local success, result = pcall(love.graphics.newImage, path)
    if success then
        return result
    else
        print("Failed to load image: " .. path)
        print("Error: " .. tostring(result))
        return nil
    end
end

-- Load character part images
function loadCharacterImages()
    characterLayers = {}

    -- Sort parts by Z-order (this is a basic implementation, ideally use z_position from database)
    local zOrder = {
        body = 10,
        legs = 20,
        feet = 30,
        torso = 40,
        arms = 50,
        hands = 60,
        head = 70,
        eyes = 80,
        nose = 90,
        ears = 100,
        hair = 110,
        facial_hair = 120,
        accessories = 130
    }

    local orderedParts = {}
    for type, part in pairs(character) do
        table.insert(orderedParts, {type = type, part = part, z = zOrder[type] or 500})
    end

    table.sort(orderedParts, function(a, b) return a.z < b.z end)

    -- Load each part
    for _, item in ipairs(orderedParts) do
        local part = item.part

        if part.path then
            -- Construct file path
            local imagePath = SPRITE_BASE_PATH .. part.path
            
            -- Load the actual spritesheet image
            local spriteSheet = safeLoadImage(imagePath)
            
            if spriteSheet then
                -- Create quads for the sprite sheet (each frame of animation)
                local quads = {}
                
                -- Create quads for all rows and frames
                for dir = 1, 4 do  -- 4 directions (south, west, east, north)
                    quads[dir] = {}
                    for frame = 1, 64 do  -- Up to 64 frames per animation (max in our animationFrames)
                        local x = ((frame - 1) % 13) * SPRITE_WIDTH
                        local y = (dir - 1) * SPRITE_HEIGHT
                        quads[dir][frame] = love.graphics.newQuad(
                            x, y, SPRITE_WIDTH, SPRITE_HEIGHT, 
                            spriteSheet:getWidth(), spriteSheet:getHeight()
                        )
                    end
                end
                
                table.insert(characterLayers, {
                    type = item.type,
                    spriteSheet = spriteSheet,
                    quads = quads,
                    z = item.z
                })
                
                print("Added layer: " .. item.type .. " with spritesheet: " .. imagePath)
            else
                -- Fallback to colored rectangle if image loading fails
                print("Using placeholder for: " .. item.type)
                table.insert(characterLayers, {
                    type = item.type,
                    color = getColorForType(item.type),
                    z = item.z,
                    placeholder = true
                })
            end
        end
    end
end

-- Get a color for a specific character part type (used for placeholders)
function getColorForType(partType)
    local colors = {
        body = {0.8, 0.6, 0.5},
        head = {0.8, 0.6, 0.5},
        torso = {0.2, 0.4, 0.8},
        legs = {0.3, 0.3, 0.7},
        feet = {0.4, 0.3, 0.2},
        hair = {0.3, 0.2, 0.1},
        eyes = {0.1, 0.6, 0.9},
        facial_hair = {0.3, 0.2, 0.1},
        accessories = {0.8, 0.8, 0.2},
        arms = {0.2, 0.4, 0.8},
        hands = {0.8, 0.6, 0.5},
        ears = {0.8, 0.6, 0.5},
        nose = {0.8, 0.6, 0.5}
    }

    return colors[partType] or {0.5, 0.5, 0.5}
end

-- Update function
function love.update(dt)
    -- Update animation timer
    animationTimer = animationTimer + dt

    -- Get frame info for current animation
    local anim = animationFrames[currentAnimation] or {1, 1}
    local startFrame, endFrame = anim[1], anim[2]

    -- Calculate frame count
    local frameCount = endFrame - startFrame + 1

    -- Update animation frame
    if frameCount > 1 and animationTimer >= ANIMATION_SPEED then
        currentFrame = currentFrame + 1
        if currentFrame > frameCount then
            currentFrame = 1
        end
        animationTimer = 0
    end

    -- Handle keyboard input for changing animations
    if love.keyboard.isDown("space") and not spaceWasDown then
        -- Cycle through available animations
        local currentIndex = indexOf(availableAnimations, currentAnimation)
        currentIndex = currentIndex % #availableAnimations + 1
        currentAnimation = availableAnimations[currentIndex]
        currentFrame = 1
        animationTimer = 0
        spaceWasDown = true
    elseif not love.keyboard.isDown("space") then
        spaceWasDown = false
    end
end

-- Draw function
function love.draw()
    -- Draw background
    love.graphics.setColor(0.2, 0.2, 0.3)
    love.graphics.rectangle("fill", 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)

    -- Center the character
    local x = WINDOW_WIDTH / 2
    local y = WINDOW_HEIGHT / 2

    -- Draw character parts
    for _, layer in ipairs(characterLayers) do
        drawCharacterPart(layer, x, y)
    end

    -- Draw UI
    drawUI()
end

-- Draw a character part
function drawCharacterPart(layer, x, y)
    -- Calculate animation frame (actual frame in the animation)
    local anim = animationFrames[currentAnimation] or {1, 1}
    local startFrame = anim[1]
    local actualFrame = startFrame + currentFrame - 1
    
    -- Get direction row
    local dirIndex = directionRows[currentDirection] or 1
    
    -- Draw either sprite or placeholder
    if layer.placeholder then
        -- Draw placeholder if no sprite available
        love.graphics.setColor(layer.color)
        
        -- Draw part as a rectangle for placeholder
        local baseWidth = SPRITE_WIDTH * CHARACTER_SCALE * 0.6
        local baseHeight = SPRITE_HEIGHT * CHARACTER_SCALE * 0.6
        
        if layer.type == "body" then
            love.graphics.rectangle("fill", x - baseWidth/2, y - baseHeight/2, baseWidth, baseHeight)
        elseif layer.type == "head" then
            local headSize = baseWidth * 0.5
            love.graphics.circle("fill", x, y - baseHeight/2, headSize/2)
        elseif layer.type == "hair" then
            local headSize = baseWidth * 0.5
            love.graphics.setColor(layer.color[1], layer.color[2], layer.color[3], 0.8)
            love.graphics.circle("fill", x, y - baseHeight/2, headSize/2 * 1.1)
        elseif layer.type == "torso" then
            love.graphics.rectangle("fill", x - baseWidth/2 * 0.8, y - baseHeight/2 * 0.7, baseWidth * 0.8, baseHeight * 0.7)
        elseif layer.type == "legs" then
            love.graphics.rectangle("fill", x - baseWidth/2 * 0.7, y, baseWidth * 0.3, baseHeight * 0.7)
            love.graphics.rectangle("fill", x + baseWidth/2 * 0.4, y, baseWidth * 0.3, baseHeight * 0.7)
        elseif layer.type == "feet" then
            love.graphics.rectangle("fill", x - baseWidth/2 * 0.8, y + baseHeight/2 * 0.6, baseWidth * 0.4, baseHeight * 0.2)
            love.graphics.rectangle("fill", x + baseWidth/2 * 0.4, y + baseHeight/2 * 0.6, baseWidth * 0.4, baseHeight * 0.2)
        elseif layer.type == "arms" then
            if currentAnimation == "slash" then
                -- Raised arm for slashing
                love.graphics.rectangle("fill", x + baseWidth/2 * 0.5, y - baseHeight/2 * 0.5, baseWidth * 0.2, baseHeight * 0.6)
                love.graphics.rectangle("fill", x - baseWidth/2 * 0.7, y - baseHeight/2 * 0.5, baseWidth * 0.2, baseHeight * 0.6)
            else
                -- Normal arms
                love.graphics.rectangle("fill", x + baseWidth/2 * 0.7, y - baseHeight/2 * 0.3, baseWidth * 0.2, baseHeight * 0.6)
                love.graphics.rectangle("fill", x - baseWidth/2 * 0.9, y - baseHeight/2 * 0.3, baseWidth * 0.2, baseHeight * 0.6)
            end
        else
            -- Generic part
            love.graphics.rectangle("fill", x - baseWidth/4, y - baseHeight/4, baseWidth/2, baseHeight/2)
        end
    else
        -- Draw actual sprite from spritesheet
        love.graphics.setColor(1, 1, 1)  -- Reset color to white for proper sprite rendering
        
        -- Draw the sprite with proper scaling
        if layer.spriteSheet and layer.quads and layer.quads[dirIndex] and layer.quads[dirIndex][actualFrame] then
            love.graphics.draw(
                layer.spriteSheet,
                layer.quads[dirIndex][actualFrame],
                x - (SPRITE_WIDTH * CHARACTER_SCALE / 2),  -- Center horizontally
                y - (SPRITE_HEIGHT * CHARACTER_SCALE / 2), -- Center vertically
                0,  -- rotation (none)
                CHARACTER_SCALE,  -- x scale
                CHARACTER_SCALE   -- y scale
            )
        else
            -- If quad is missing, print debug info
            print("Missing quad for " .. layer.type .. " dir:" .. dirIndex .. " frame:" .. actualFrame)
        end
    end
end

-- Draw UI elements
function drawUI()
    love.graphics.setColor(1, 1, 1)

    -- Draw control instructions
    love.graphics.print("Controls:", 20, 20)
    love.graphics.print("R: Generate new random character", 20, 40)
    love.graphics.print("Space: Change animation", 20, 60)
    love.graphics.print("Arrow keys: Change direction", 20, 80)

    -- Draw current character info
    love.graphics.print("Animation: " .. currentAnimation, 20, 120)
    love.graphics.print("Direction: " .. currentDirection, 20, 140)
    
    -- Get frame info for current animation
    local anim = animationFrames[currentAnimation] or {1, 1}
    local startFrame, endFrame = anim[1], anim[2]
    local frameCount = endFrame - startFrame + 1
    
    love.graphics.print("Frame: " .. currentFrame .. "/" .. frameCount, 20, 160)

    -- Draw character composition
    love.graphics.print("Character Parts:", WINDOW_WIDTH - 200, 20)

    local y = 40
    for type, part in pairs(character) do
        love.graphics.print(type .. ": " .. part.name, WINDOW_WIDTH - 200, y)
        y = y + 20
    end
end

-- Handle keyboard input
function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "r" then
        -- Generate new random character
        generateRandomCharacter()
        loadCharacterImages()
    elseif key == "space" then
        -- Change animation (handled in update)
    elseif key == "up" then
        currentDirection = "north"
    elseif key == "down" then
        currentDirection = "south"
    elseif key == "left" then
        currentDirection = "west"
    elseif key == "right" then
        currentDirection = "east"
    end
end

-- Helper function to find index of value in table
function indexOf(table, value)
    for i, v in ipairs(table) do
        if v == value then
            return i
        end
    end
    return 1
end

-- Clean up when quitting
function love.quit()
    if conn then
        conn:close()
    end
end
