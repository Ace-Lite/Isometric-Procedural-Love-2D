local render = require 'src/cache'


local definitions = {}

local function load_basics(image)
    return love.graphics.newImage("assets/basics/"..image)
end

---@param image    string path string from assets/entities
---@param offset_x number
---@param offset_y number
---@return entity_sprite
local function load_sprite(image, offset_x, offset_y)
    local sprite = love.graphics.newImage("assets/entities/"..image)
    local width, height = sprite:getPixelDimensions()

    return {
        sprite = sprite,
        offset_x = width / 2 + (offset_x or 0),
        offset_y = -height + (offset_y or 0),
    }
end

-- Blocks

definitions.basic_block = load_basics("block.png")
definitions.basic_tile = load_basics("tile.png")

local grass_texture         = render:generate("textures/grass.png")
local graygrass_texture     = render:generate("textures/graygrass.png")
local rock_texture          = render:generate("textures/rock.png")
local sand_texture          = render:generate("textures/sand.png")
local sandstone_texture     = render:generate("textures/sandstone.png")
local snow_texture          = render:generate("textures/snow.png")
local purl_texture          = render:generate("textures/purplemess.png")

-- Entities

local oak_tree = load_sprite("oaktree.png", 0, 0)
local bush = load_sprite("bush.png", 0, 0)

local cactus = load_sprite("cactus.png", 0, 0)

local bigpine_tree = load_sprite("bigpine.png", 0, 0)

definitions.biomes = { ---@type table<biome>
    [1] = { -- Desert
        levels = {        
            sand_texture,
            sandstone_texture,
        },

        mountains = {
            snow_texture,
            rock_texture,
        },

        vegetation = {
            {
                z_min = 0,
                z_max = 20,
                distribution = 64,                
                chance = 0.012,
                sprite = cactus,
            },            
        },

        pillars = false,        
        height_multiplier = 1.0,
        heat = 4,
    },

    [2] = { -- Grass lands
        levels = {
            grass_texture,
            graygrass_texture,
            rock_texture,
        },

        mountains = {
            snow_texture,
            rock_texture,
        },

        vegetation = {
            {
                z_min = 0,
                z_max = 20,
                chance = 0.032,
                distribution = 8,
                sprite = oak_tree,
            },
            {
                z_min = 0,
                z_max = 20,
                chance = 0.02,
                distribution = 16,                
                sprite = bush,
            },            
        },

        pillars = false,
        height_multiplier = 1.3,
        heat = 3,
    },

    [3] = { -- High lands
        levels = {
            grass_texture,
            graygrass_texture,
            rock_texture,
        },

        mountains = {
            snow_texture,
            rock_texture,
        },

        vegetation = {
            {
                z_min = 0,
                z_max = 20,
                chance = 0.09,
                distribution = 20,                
                sprite = bigpine_tree,
            },        
        },

        pillars = true,        
        height_multiplier = 1.38,
        heat = 2,
    },

    [4] = { -- Freezing
        levels = {        
            snow_texture,
            rock_texture,
        },

        mountains = {
            snow_texture,
            rock_texture,
        },

        pillars = false,        
        height_multiplier = 1.5,
        heat = 1,
    },
}

render:destroyMeshes()

return definitions