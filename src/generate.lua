--[[

    Custom Library for this project.
    Generates map based on noises

--]]

---@class flatmap
---@field width number
---@field height number
---@field seed number
---@field numbiomes number number of biomes
---@field heightmap table<table<tile>>
---@field biomemap  table<table<number>>
---@field levelsmap table<table<number>>
---@field entities  table<table<table<entity>>>

---@class generator
---@field new function
---@field render function
---@field spliceRender function

---@class chunk
---@field map                   table<table<table>>
---@field depthmap              table
---@field update                function
---@field image                 any

---@class entity_sprite
---@field sprite    any
---@field offset_x  number
---@field offset_y  number

---@class entity
---@field offset_x  number
---@field offset_y  number
---@field sprite    entity_sprite
---@field z         number

---@class tile
---@field type                  number
---@field height                number
---@field pillar                number
---@field depth                 number
---@field slope                 number

---@class vegetation
---@field z_min         number
---@field z_max         number
---@field chance        number
---@field distribution  number
---@field sprite        any

---@class biome
---@field levels                table<any>
---@field mountains             table<any>
---@field vegetation            table<vegetation>
---@field height_multiplier     number
---@field pillars               boolean

local generator = {} ---@type generator

-- Constants

local MAP_BLOCK         = 64
local MAP_BLOCK_HALF    = MAP_BLOCK / 2
local MAP_TILE_HALF     = MAP_BLOCK_HALF / 2

local SLOPE_FRONT = 1
local SLOPE_BACK = 2
local SLOPE_LEFT = 4
local SLOPE_RIGHT = 8
local SLOPE_FRONTLEFT = bit.bor(SLOPE_FRONT, SLOPE_LEFT)
local SLOPE_FRONTRIGHT = bit.bor(SLOPE_FRONT, SLOPE_RIGHT)
local SLOPE_BACKLEFT = bit.bor(SLOPE_BACK, SLOPE_LEFT)
local SLOPE_BACKRIGHT = bit.bor(SLOPE_BACK, SLOPE_RIGHT)
local SLOPE_CORNERLEFT = 256
local SLOPE_CORNERRIGHT = 512

local graphics = love.graphics

local draw = graphics.draw

---calculates depth of the tile
---@param tile_x number
---@param tile_y number
---@param tile_z number
---@return number
local function calculateDepth(tile_x, tile_y, tile_z)
    return tile_x + tile_y + 0.001 * tile_z
end

---checks if certain terrain tiles could be not flat
---@param heightmap table<any>
---@param tile_x number
---@param tile_y number
---@param tile_z number
---@return number
local function checkStraightSlopes(heightmap, tile_x, tile_y, tile_z)
    local flags = 0

    -- Get surronding 

    local current_row = heightmap[tile_y]
    local front_row =   heightmap[tile_y + 1]
    local back_row =    heightmap[tile_y - 1]

    local left_tile =   current_row[tile_x - 1]
    local right_tile =  current_row[tile_x + 1]

    -- Attaching to the top tile slope sprite

    if  right_tile ~= nil 
    and right_tile.height < tile_z
    and right_tile.pillar == 0 then
        flags = SLOPE_RIGHT
    end

    if  left_tile ~= nil 
    and left_tile.height < tile_z
    and left_tile.pillar == 0 then
        flags = SLOPE_LEFT
    end
    
    if front_row ~= nil then
        local front_tile = front_row[tile_x]

        if  front_tile ~= nil 
        and front_tile.height < tile_z
        and front_tile.pillar == 0 then
            flags = SLOPE_FRONT
        end
    end

    if back_row ~= nil then
        local back_tile = back_row[tile_x]

        if  back_tile ~= nil 
        and back_tile.height < tile_z
        and back_tile.pillar == 0 then
            flags = SLOPE_BACK
        end
    end

    return flags
end

---generates map scenario
---@param seed              number
---@param width             number
---@param height            number
---@param biomedef          table<biome>    biome data
---@return flatmap
function generator:new(seed, width, height, biomedef)
    
    -- defaulting up-values

    seed = seed or 0
    width = width or 1
    height = height or 1
    local biomes = #biomedef or 1
    
    -- setup

    local map = { ---@type flatmap
        seed = seed,

        width = width,
        height = height,

        numbiomes = biomes,

        -- maps
        heightmap = {},
        biomemap = {},
        levelsmap = {},
        entities = {}
    }
    
    local heightmap = map.heightmap
    local levelsmap = map.levelsmap
    local biomemap = map.biomemap
    local entitymap = map.entities

    -- generating various maps

    for y = -width, width do
        heightmap[y] = {
            depth = calculateDepth(0, y, 0)
        }

        levelsmap[y] = {}

        biomemap[y] = {}

        entitymap[y] = {}     

        for x = -height, height do

            -- biome map sampling

            local heat_sample = love.math.noise(
                seed + (x / 256),
                seed + (y / 256)
            )

            local heat = math.floor(heat_sample * 6)

            local biome = math.min(math.max(heat, 1), biomes)
            biomemap[y][x] = biome

            -- height map sampling

            heightmap[y][x] = {
                type = math.max(math.random(-16, 4), 0), 
                height = 4 * love.math.noise(
                    seed + (x / 32),
                    seed + (y / 32)
                ), -- basic terrain
                slope = 0,
                pillar = 0,
            }
            
            local tile = heightmap[y][x]
            local mountain_randomness = biomedef[biome].height_multiplier * math.random(0, 24)/16
            local hill_randomness = biomedef[biome].height_multiplier * math.random(0, 4)/6

            local hills = love.math.noise(
                seed + (x / 100),
                seed + (y / 100),
                seed + (tile.height/100)*mountain_randomness/40,
                seed + (tile.height/100)*mountain_randomness/40
            )

            tile.height = tile.height + math.max(hills * (225 + hill_randomness + mountain_randomness) - 120, 0)
            
            tile.pillar = biomedef[biome].pillars == true and (tile.height > 8 and 0 or math.max(math.random(-512, 4), 0)) or 0 -- random pillars
            tile.depth = calculateDepth(x, y, tile.height)
            
            -- levels map sampling

            local levels_sample = love.math.noise(
                seed - (x / 64),
                seed - (y / 64)
            )

            levelsmap[y][x] = math.abs(math.floor(levels_sample * -8))

            if tile.pillar == 0 and biomedef[biome].vegetation then
                local vegs = biomedef[biome].vegetation

                for vg = 1, #vegs do
                    local veg = biomedef[biome].vegetation[vg]

                    if tile.height > veg.z_min and tile.height < veg.z_max then

                        local entity_spawns = math.ceil(love.math.noise(
                            seed + x / veg.distribution,
                            seed + y / veg.distribution
                        ) * 500)/500

                        if entity_spawns < veg.chance then
                            if entitymap[y][x] == nil then
                                entitymap[y][x] = {}
                            end

                            table.insert(entitymap[y][x], 
                            {
                                sprite = veg.sprite,
                                offset_x = math.random(-16, 16),
                                offset_y = math.random(-16, 16)
                            })
                        end
                    end
                end
            end
        end
    end

    -- few more run downs of height map to check for slopes

    for y = -width, width do
        for x = -height, height do
            local tile = heightmap[y][x]  ---@type tile
            local z = math.floor(tile.height) + 1

            if tile.pillar == 0 then
                heightmap[y][x].slope = checkStraightSlopes(heightmap, x, y, z)
            end
        end
    end

    return map
end

---renders splices of the level for better composition
---@param map               flatmap
---@param biomedef          table<biome>    biome data
---@param default_block     any             graphic for default block
---@param default_tile      any             graphic for default tile
---@param camera_x          number
---@param camera_y          number
---@param screen_scale      number
---@param screen_width      number
---@param screen_height     number
---@return table<any>
function generator:draw(map, biomedef, default_block, default_tile, camera_x, camera_y, screen_scale, screen_width, screen_height)
    local screen = love.graphics.newCanvas(
        map.width * MAP_BLOCK,
        map.height * MAP_BLOCK_HALF
    )

    graphics.setCanvas(screen)


    local height_map = map.heightmap
    local levels_map = map.levelsmap
    local biome_map  = map.biomemap
    local entit_map  = map.entities

    local height = map.height
    local width = map.width

    for y = -height, height do

        local height_row = height_map[y]
        local level_row  = levels_map[y]
        local biome_row  = biome_map[y]
        local entit_row  = entit_map[y]

        if height_row then
            for x = -width, width do
                local height_tile   = height_row[x] ---@type tile
                local level_tile    = level_row[x]  ---@type number
                local biome_tile    = biomedef[math.max(math.min(biome_row[x], #biomedef), 1)]
                local levels        = biome_tile.levels
                local size          = height_tile.height + height_tile.pillar

                local mountain_threshold = math.random(7, 10)

                if mountain_threshold < size then
                    for z = 0, size do
                        local level = math.random(28, 32) < size 
                        and biome_tile.mountains[1]
                        or biome_tile.mountains[#biome_tile.mountains > 1 and math.random(2, #biome_tile.mountains) or 1] 
                        local offset = 0
                        local img = level
                        
                        if type(level) == "table" then
                            if level[0] ~= nil then
                                if z > size - 1 and level[height_tile.slope] ~= nil then
                                    level = level[height_tile.slope]
                                else
                                    level = level[0]
                                end
                            end

                            img = level.img
                            offset = level.offset or 0
                        end

                        draw(
                            img or default_block, 
                            (x - y) * MAP_BLOCK_HALF,
                            (x + y) * MAP_TILE_HALF - z * MAP_BLOCK_HALF + offset
                        )
                    end
                elseif size > 0 then
                    if height_tile.pillar > 0 then
                        for z = 0, size do
                            draw(
                                default_block,
                                (x - y) * MAP_BLOCK_HALF,
                                (x + y) * MAP_TILE_HALF - z * MAP_BLOCK_HALF
                            )
                        end
                    else
                        for z = 0, size do
                            local level = levels[math.max(math.min(math.floor(((size - z) * #levels / level_tile) or 1), #levels), 1)]
                            local offset = 0
                            local img = level
                            
                            if type(level) == "table" then
                                if level[0] ~= nil then
                                    if z > size - 1 and level[height_tile.slope] ~= nil then
                                        level = level[height_tile.slope]
                                    else
                                        level = level[0]
                                    end
                                end

                                img = level.img
                                offset = level.offset or 0
                            end

                            draw(
                                img or default_block, 
                                (x - y) * MAP_BLOCK_HALF,
                                (x + y) * MAP_TILE_HALF - z * MAP_BLOCK_HALF + offset
                            )
                        end
                    end
                else
                    draw(
                        default_tile, 
                        (x - y) * MAP_BLOCK_HALF,
                        (x + y) * MAP_TILE_HALF
                    )
                end

                if entit_row ~= nil then
                    local entities      = entit_row[x]

                    if entities then
                        for i = 1, #entities do
                            local entity = entities[i] ---@cast entity entity
                            
                            draw(
                                entity.sprite.sprite, 
                                (x - y) * MAP_BLOCK_HALF + entity.sprite.offset_x + entity.offset_x,
                                (x + y) * MAP_TILE_HALF + entity.sprite.offset_y + entity.offset_y
                            )
                        end
                    end
                end
            end
        end
    end

    love.graphics.setCanvas()    
    return screen
end

---compresses renders into one image
---@param map               flatmap
---@param biomedef          table<biome>    biome data
---@param default_block     any             graphic for default block
---@param default_tile      any             graphic for default tile
---@return table<any>
function generator:render(map, biomedef, default_block, default_tile)
    if not map then
        error("Map doesn't exist")
    end
    
    local render = self:draw(map, biomedef, default_block, default_tile)

    return render
end


return generator