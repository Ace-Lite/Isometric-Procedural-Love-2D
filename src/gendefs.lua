local render = require 'src/cache'

local definitions = {}

local function load_basics(image)
    return love.graphics.newImage("assets/basics/"..image)
end

definitions.basic_block = load_basics("block.png")
definitions.basic_tile = load_basics("tile.png")

local grass_texture         = render:generate("textures/grass.png")
local graygrass_texture     = render:generate("textures/graygrass.png")
local rock_texture          = render:generate("textures/rock.png")
local sand_texture          = render:generate("textures/sand.png")
local sandstone_texture     = render:generate("textures/sandstone.png")
local snow_texture          = render:generate("textures/snow.png")
local purl_texture          = render:generate("textures/purplemess.png")

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
        
        height_multiplier = 1.5,
        heat = 1,
    },
}

render:destroyMeshes()

return definitions