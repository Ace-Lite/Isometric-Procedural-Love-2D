--[[

    Custom Library for this project.
    Generates map based on noises

--]]

---@class map
---@field width number
---@field height number
---@field seed number
---@field numbiomes number number of biomes
---@field heightmap table<table<tile>>
---@field biomemap  table<table<number>>
---@field levelsmap table<table<number>>

---@class generator
---@field new function
---@field render function
---@field spliceRender function

---@class tile
---@field type number
---@field height number
---@field pillar number
---@field depth number
---@field slope number

---@class biome
---@field levels table<any>
---@field mountains table<any>
---@field height_multiplier number

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
---@return map
function generator:new(seed, width, height, biomedef)
    
    -- defaulting up-values

    seed = seed or 0
    width = width or 1
    height = height or 1
    local biomes = #biomedef or 1
    
    -- setup

    local map = { ---@type map
        seed = seed,

        width = width,
        height = height,

        numbiomes = biomes,

        -- maps
        heightmap = {},
        biomemap = {},
        levelsmap = {}
    }
    
    local heightmap = map.heightmap
    local levelsmap = map.levelsmap
    local biomemap = map.biomemap

    -- generating various maps

    for y = -width, width do
        heightmap[y] = {
            depth = calculateDepth(0, y, 0)
        }

        levelsmap[y] = {}

        biomemap[y] = {}

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
            
            tile.pillar = tile.height > 8 and 0 or math.max(math.random(-512, 4), 0) -- random pillars
            tile.depth = calculateDepth(x, y, tile.height)
            
            -- levels map sampling

            local levels_sample = love.math.noise(
                seed - (x / 64),
                seed - (y / 64)
            )

            levelsmap[y][x] = math.abs(math.floor(levels_sample * -8))
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
---@param map               map
---@param biomedef          table<biome>    biome data
---@param default_block     any             graphic for default block
---@param default_tile      any             graphic for default tile
---@return table<any>
function generator:draw(map, biomedef, default_block, default_tile)
    local map_img = love.graphics.newCanvas(
            MAP_BLOCK * map.width,
            MAP_BLOCK_HALF * map.height
    )

    love.graphics.setCanvas(map_img)


    local height_map = map.heightmap
    local levels_map = map.levelsmap
    local biome_map  = map.biomemap

    local height = map.height
    local width = map.width

    for y = -height, height do

        local height_row = height_map[y]
        local level_row  = levels_map[y]
        local biome_row  = biome_map[y]

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

                    love.graphics.draw(
                        img or default_block, 
                        (x - y) * MAP_BLOCK_HALF,
                        (x + y) * MAP_TILE_HALF - z * MAP_BLOCK_HALF + offset
                    )
                end
            elseif size > 0 then
                if height_tile.pillar > 0 then
                    for z = 0, size do
                        love.graphics.draw(
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

                        love.graphics.draw(
                            img or default_block, 
                            (x - y) * MAP_BLOCK_HALF,
                            (x + y) * MAP_TILE_HALF - z * MAP_BLOCK_HALF + offset
                        )
                    end
                end
            else
                love.graphics.draw(
                    default_tile, 
                    (x - y) * MAP_BLOCK_HALF,
                    (x + y) * MAP_TILE_HALF
                )
            end
        end
    end

    love.graphics.setCanvas()    
    return map_img
end

---compresses renders into one image
---@param map               map
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