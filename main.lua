-- LPC Character Generator Demo
-- Using Love2D to display character components from the database

local LpcDatabase = require("lpc_database")

-- Global variables
local db = nil
local categories = {}
local selected_category = nil
local component_types = {}
local selected_component_type = nil
local components = {}
local selected_component = nil
local variants = {}
local selected_variant = nil
local animations = {}
local selected_animation = nil
local body_types = {}
local selected_body_type = nil

local asset_files = {}
local sprites = {}
local current_frame = 1
local animation_timer = 0
local animation_speed = 0.1 -- seconds per frame

-- UI state
local ui = {
    sidebar_width = 300,
    item_height = 30,
    scroll_y = 0,
    max_scroll = 0
}

function love.load()
    love.window.setTitle("LPC Character Generator Demo")
    love.window.setMode(1024, 768)
    
    -- Initialize database
    db = LpcDatabase.new()
    
    -- Check if the dump file exists, if not, create it
    if not love.filesystem.getInfo("lpc_character_generator_dump.sql") then
        -- Copy the schema file to the save directory
        local schema = love.filesystem.read("lpc_character_generator.sql")
        if schema then
            love.filesystem.write("lpc_character_generator_dump.sql", schema)
            print("Created dump file from schema")
        else
            print("Warning: Could not find schema file")
        end
    end
    
    -- Load database
    local success, err = pcall(function()
        db:database_load()
    end)
    
    if not success then
        print("Database load error: " .. tostring(err))
        return
    end
    
    -- Load categories
    categories = db:get_categories()
    
    -- Set default selections
    if #categories > 0 then
        selected_category = categories[1]
        load_component_types()
    end
    
    -- Load fonts
    love.graphics.setNewFont(14)
end

function load_component_types()
    if selected_category then
        component_types = db:get_component_types(selected_category.id)
        selected_component_type = component_types[1]
        load_components()
    end
end

function load_components()
    if selected_component_type then
        components = db:get_components(selected_component_type.id)
        selected_component = components[1]
        load_variants()
    end
end

function load_variants()
    if selected_component then
        variants = db:get_variants(selected_component.id)
        selected_variant = variants[1]
        load_animations()
    end
end

function load_animations()
    if selected_component then
        animations = db:get_animations(selected_component.id)
        selected_animation = animations[1]
        load_body_types()
    end
end

function load_body_types()
    body_types = db:get_body_types()
    selected_body_type = body_types[1]
    load_assets()
end

function load_assets()
    if selected_component and selected_variant and selected_animation and selected_body_type then
        asset_files = db:get_asset_files(
            selected_component.id,
            selected_variant.id,
            selected_animation.id,
            selected_body_type.id
        )
        
        -- Clear existing sprites
        sprites = {}
        
        -- Load sprite images
        for _, asset in ipairs(asset_files) do
            local sprite_path = asset.file_path
            -- Check if file exists in the filesystem
            local file_info = love.filesystem.getInfo(sprite_path)
            if file_info then
                table.insert(sprites, {
                    image = love.graphics.newImage(sprite_path),
                    z_position = asset.z_position,
                    layer_number = asset.layer_number
                })
            else
                print("Warning: Could not find sprite file: " .. sprite_path)
            end
        end
        
        -- Sort sprites by z-position
        table.sort(sprites, function(a, b)
            return a.z_position < b.z_position
        end)
        
        -- Reset animation
        current_frame = 1
        animation_timer = 0
    end
end

function love.update(dt)
    -- Update animation frame
    if selected_animation and selected_animation.frame_count > 1 then
        animation_timer = animation_timer + dt
        if animation_timer >= animation_speed then
            animation_timer = animation_timer - animation_speed
            current_frame = current_frame + 1
            if current_frame > selected_animation.frame_count then
                current_frame = 1
            end
        end
    end
end

function love.draw()
    -- Draw background
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    -- Draw sidebar
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("fill", 0, 0, ui.sidebar_width, love.graphics.getHeight())
    
    -- Draw UI elements
    draw_sidebar()
    
    -- Draw character preview
    draw_character_preview()
end

function draw_sidebar()
    local x = 10
    local y = 10 - ui.scroll_y
    
    -- Draw categories
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Categories:", x, y)
    y = y + 25
    
    for _, category in ipairs(categories) do
        if category == selected_category then
            love.graphics.setColor(0.4, 0.7, 1)
        else
            love.graphics.setColor(0.8, 0.8, 0.8)
        end
        love.graphics.print(category.display_name, x + 10, y)
        y = y + ui.item_height
    end
    
    y = y + 10
    
    -- Draw component types
    if #component_types > 0 then
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Component Types:", x, y)
        y = y + 25
        
        for _, comp_type in ipairs(component_types) do
            if comp_type == selected_component_type then
                love.graphics.setColor(0.4, 0.7, 1)
            else
                love.graphics.setColor(0.8, 0.8, 0.8)
            end
            love.graphics.print(comp_type.display_name, x + 10, y)
            y = y + ui.item_height
        end
        
        y = y + 10
    end
    
    -- Draw components
    if #components > 0 then
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Components:", x, y)
        y = y + 25
        
        for _, component in ipairs(components) do
            if component == selected_component then
                love.graphics.setColor(0.4, 0.7, 1)
            else
                love.graphics.setColor(0.8, 0.8, 0.8)
            end
            love.graphics.print(component.display_name, x + 10, y)
            y = y + ui.item_height
        end
        
        y = y + 10
    end
    
    -- Draw variants
    if #variants > 0 then
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Variants:", x, y)
        y = y + 25
        
        for _, variant in ipairs(variants) do
            if variant == selected_variant then
                love.graphics.setColor(0.4, 0.7, 1)
            else
                love.graphics.setColor(0.8, 0.8, 0.8)
            end
            love.graphics.print(variant.display_name, x + 10, y)
            y = y + ui.item_height
        end
        
        y = y + 10
    end
    
    -- Draw animations
    if #animations > 0 then
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Animations:", x, y)
        y = y + 25
        
        for _, animation in ipairs(animations) do
            if animation == selected_animation then
                love.graphics.setColor(0.4, 0.7, 1)
            else
                love.graphics.setColor(0.8, 0.8, 0.8)
            end
            love.graphics.print(animation.display_name, x + 10, y)
            y = y + ui.item_height
        end
        
        y = y + 10
    end
    
    -- Draw body types
    if #body_types > 0 then
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Body Types:", x, y)
        y = y + 25
        
        for _, body_type in ipairs(body_types) do
            if body_type == selected_body_type then
                love.graphics.setColor(0.4, 0.7, 1)
            else
                love.graphics.setColor(0.8, 0.8, 0.8)
            end
            love.graphics.print(body_type.display_name, x + 10, y)
            y = y + ui.item_height
        end
    end
    
    -- Update max scroll
    ui.max_scroll = math.max(0, y + ui.scroll_y - love.graphics.getHeight() + 20)
end

function draw_character_preview()
    -- Draw character in the center of the screen (right side of sidebar)
    local center_x = ui.sidebar_width + (love.graphics.getWidth() - ui.sidebar_width) / 2
    local center_y = love.graphics.getHeight() / 2
    
    if #sprites == 0 then
        -- No sprites to display
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("No sprites available for this selection", center_x - 100, center_y)
        return
    end
    
    -- Draw each sprite layer
    love.graphics.setColor(1, 1, 1)
    for _, sprite in ipairs(sprites) do
        local image = sprite.image
        if image then
            -- Calculate sprite position based on frame
            local frame_width = image:getWidth() / selected_animation.frame_count
            local quad = love.graphics.newQuad(
                (current_frame - 1) * frame_width, 0,
                frame_width, image:getHeight(),
                image:getWidth(), image:getHeight()
            )
            
            -- Draw the sprite
            love.graphics.draw(
                image,
                quad,
                center_x - frame_width/2,
                center_y - image:getHeight()/2
            )
        end
    end
    
    -- Draw frame info
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(
        "Frame: " .. current_frame .. "/" .. (selected_animation and selected_animation.frame_count or 1),
        center_x - 50,
        center_y + 150
    )
end

function love.mousepressed(x, y, button)
    if button == 1 and x < ui.sidebar_width then
        local item_y = 10 - ui.scroll_y
        
        -- Categories
        item_y = item_y + 25
        for i, category in ipairs(categories) do
            if y >= item_y and y < item_y + ui.item_height then
                selected_category = category
                load_component_types()
                return
            end
            item_y = item_y + ui.item_height
        end
        
        item_y = item_y + 10
        
        -- Component types
        if #component_types > 0 then
            item_y = item_y + 25
            for i, comp_type in ipairs(component_types) do
                if y >= item_y and y < item_y + ui.item_height then
                    selected_component_type = comp_type
                    load_components()
                    return
                end
                item_y = item_y + ui.item_height
            end
            
            item_y = item_y + 10
        end
        
        -- Components
        if #components > 0 then
            item_y = item_y + 25
            for i, component in ipairs(components) do
                if y >= item_y and y < item_y + ui.item_height then
                    selected_component = component
                    load_variants()
                    return
                end
                item_y = item_y + ui.item_height
            end
            
            item_y = item_y + 10
        end
        
        -- Variants
        if #variants > 0 then
            item_y = item_y + 25
            for i, variant in ipairs(variants) do
                if y >= item_y and y < item_y + ui.item_height then
                    selected_variant = variant
                    load_assets()
                    return
                end
                item_y = item_y + ui.item_height
            end
            
            item_y = item_y + 10
        end
        
        -- Animations
        if #animations > 0 then
            item_y = item_y + 25
            for i, animation in ipairs(animations) do
                if y >= item_y and y < item_y + ui.item_height then
                    selected_animation = animation
                    load_assets()
                    return
                end
                item_y = item_y + ui.item_height
            end
            
            item_y = item_y + 10
        end
        
        -- Body types
        if #body_types > 0 then
            item_y = item_y + 25
            for i, body_type in ipairs(body_types) do
                if y >= item_y and y < item_y + ui.item_height then
                    selected_body_type = body_type
                    load_assets()
                    return
                end
                item_y = item_y + ui.item_height
            end
        end
    end
end

function love.wheelmoved(x, y)
    if x < ui.sidebar_width then
        ui.scroll_y = math.max(0, math.min(ui.max_scroll, ui.scroll_y - y * 30))
    end
end

function love.quit()
    if db then
        db:close()
    end
end 