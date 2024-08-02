--local Steam = require 'luasteam'

Debug_Mode = true
Game_Scene = 0
redraw = false

scope = 1.00

cor_x = 0.00
cor_y = 0.00

map = {}

width, height = love.graphics.getDimensions()
half_width, half_height = width/2, height/2
map_width, map_height = 512, 512
map_width_dim_x, map_height_dim_y = 0, 0 

tile = love.graphics.newImage("tile.png")
tile_width, tile_height = tile:getPixelDimensions()
tile_width_half, tile_height_half = tile_width/2, tile_height/2

block = love.graphics.newImage("block.png")
block_width, block_height = tile:getPixelDimensions()

speed_x = 2/tile_width_half
speed_y = 2/tile_height_half

map_img = love.graphics.newCanvas(tile_width*map_width, tile_height*map_height)

local levels = {
    [1] = love.graphics.newImage("rock.png"),
    [2] = love.graphics.newImage("soil.png"),
    [4] = love.graphics.newImage("grass.png"),
    [5] = love.graphics.newImage("snow.png"),    
}

tree = love.graphics.newImage("tree.png") 
tree_width, tree_height = tree:getPixelDimensions()
tree_height = tree_height-tile_height*4

levels[3] = levels[2]

--local Steam_username

local SLOPE_FRONT = 1
local SLOPE_BACK = 2
local SLOPE_LEFT = 4
local SLOPE_RIGHT = 8
local SLOPE_FRONTLEFT = 16
local SLOPE_FRONTRIGHT = 32
local SLOPE_BACKLEFT = 64
local SLOPE_BACKRIGHT = 128
local SLOPE_CORNERLEFT = 256
local SLOPE_CORNERRIGHT = 512

local Slope_Graphics_Registry = {
    [1] = love.graphics.newImage("soil_slopes2.png"),
    [2] = love.graphics.newImage("soil_slopes8.png"),
    [4] = love.graphics.newImage("soil_slopes7.png"),   
    [8] = love.graphics.newImage("soil_slopes1.png"),
}

local Snow_Slope_Graphics_Registry = {
    [1] = love.graphics.newImage("snow_slopes2.png"),
    [2] = love.graphics.newImage("snow_slopes8.png"),
    [4] = love.graphics.newImage("snow_slopes7.png"),   
    [8] = love.graphics.newImage("snow_slopes1.png"),
}

local function check_surronding_tiles(tile_x, tile_y, tile_z, snow_seed)
    local sl_flags = 0
    local tiley_curr = map[tile_y]
    local tiley_offp = map[tile_y+1]
    local tiley_offm = map[tile_y-1]    

    if tiley_curr[tile_x+1] ~= nil and tiley_curr[tile_x+1].height < tile_z then
        sl_flags = SLOPE_RIGHT
    elseif tiley_curr[tile_x-1] ~= nil and tiley_curr[tile_x-1].height < tile_z then
        sl_flags = SLOPE_LEFT
    elseif tiley_offp ~= nil then
        if tiley_offp[tile_x] ~= nil and tiley_offp[tile_x].height < tile_z then
            sl_flags = SLOPE_FRONT
        
            if tiley_offp[tile_x-1] ~= nil and tiley_offp[tile_x-1].height < tile_z then
                sl_flags = SLOPE_FTONRLEFT
                if tiley_offp[tile_x+1] ~= nil and tiley_offp[tile_x+1].height < tile_z then
                    sl_flags = SLOPE_CORNERRIGHT
                end
            elseif tiley_offp[tile_x+1] ~= nil and tiley_offp[tile_x+1].height < tile_z then
                sl_flags = SLOPE_FRONTRIGHT
            end      
        end         
    elseif tiley_offm ~= nil then
        if tiley_offm[tile_x] ~= nil and tiley_offm[tile_x].height < tile_z then
            sl_flags = SLOPE_BACK

            if tiley_offm[tile_x-1] ~= nil and tiley_offm[tile_x-1].height < tile_z then
                sl_flags = SLOPE_BACKLEFT
                if tiley_offm[tile_x+1] ~= nil and tiley_offm[tile_x+1].height < tile_z then
                    sl_flags = SLOPE_CORNERLEFT
                end
            elseif tiley_offm[tile_x+1] ~= nil and tiley_offm[tile_x+1].height < tile_z then
                sl_flags = SLOPE_BACKRIGHT
            end
        end
    end

    if Slope_Graphics_Registry[sl_flags] ~= nil then
        if tile_z > (32+snow_seed) then
            return Snow_Slope_Graphics_Registry[sl_flags]
        else
            return Slope_Graphics_Registry[sl_flags]
        end
    else
        return nil
    end
end

local function calculate_Depth(tile_x, tile_y, tile_z)
    return tile_x + tile_y + 0.001 * tile_z 
end

local function sort_IsoDepth(depth_a, depth_b)
    if depth_a > depth_b then
        return 1
    elseif depth_a < depth_b then
        return -1
    end

    return 0
end

function love.load()
    love.graphics.setCanvas(map_img)
    local low_seed, high_seed = love.math.getRandomSeed()

    for y = -map_width, map_width do 
        map[y] = {depth = calculate_Depth(0, y, 0)}
        for x = -map_height, map_height do
            map[y][x] = {type = math.max(math.random(-16,4), 0), 
            height = love.math.noise(high_seed+(x/32), high_seed+(y/32))*4,
            x = x}
            local mountain_seed = math.random(0, 24)/16
            map[y][x].height = map[y][x].height+math.max((love.math.noise(high_seed+(x/100), high_seed+(y/100), high_seed+(map[y][x].height/100), high_seed+(map[y][x].height/100))*(225+mountain_seed))-120, 0)
            map[y][x].pillar = map[y][x].height > 8 and 0 or math.max(math.random(-512,4), 0)
            map[y][x].depth = calculate_Depth(x, y, map[y][x].height)
        end
    end

    for y = -map_width, map_width do
        table.sort(map, function(a, b)
            return a.depth < b.depth
        end) 
        local map_y = map[y]
        table.sort(map_y, function(a, b)
            return a.depth < b.depth
        end) 
        for x = -map_height, map_height do
            local z_offset = 0
            local snow_seed = math.random(0, 4)
            local tree_seed = math.random(0, 256)            
            local sel_tile = map_y[x]
            local current_z = math.floor(sel_tile.height)+1
            local pillar_level = sel_tile.pillar
            local c_tile = pillar_level > 0 and block or (current_z > (32+snow_seed) and levels[5] or levels[math.min(current_z, 4)])
            local literal_z = current_z+pillar_level
            local l_tile = c_tile

            if (current_z > 6 and 16 > current_z and tree_seed > 32) or (tree_seed > 254) then
                l_tile = tree
                z_offset = tree_height
            end

            if sel_tile.height > 0 then
                for i = 0, literal_z do
                    if c_tile ~= block and i == literal_z then
                        local slope = check_surronding_tiles(x, y, literal_z-1, snow_seed)
                        love.graphics.draw(slope == nil and l_tile or slope, 
                        (x - y) * tile_width_half,
                        (x + y) * tile_height_half - i*block_height-z_offset,
                        0,
                        1,
                        1)
                    else
                        love.graphics.draw(c_tile, 
                        (x - y) * tile_width_half,
                        (x + y) * tile_height_half - i*block_height,
                        0,
                        1,
                        1)
                    end
                end
            else
                love.graphics.draw(tile, 
                (x - y) * tile_width_half,
                (x + y) * tile_height_half,
                0,
                1,
                1)
            end
        end
    end

    map_width_dim_x = 128*2*tile_width
    map_height_dim_y = 128*2*tile_height
    love.graphics.setCanvas()
    --Steam.init()
    --Steam_username = Steam.user.getSteamID()
end



function love.draw()
    local canvas_dim_x, canvas_dim_y = map_img:getDimensions()
    love.graphics.draw(map_img, 
    math.floor(-cor_x*tile_width_half -map_width)*scope + half_width,                            
    math.floor(cor_y*tile_height_half -map_height)*scope + half_height,
    0, 
    scope,
    scope) 

    if Debug_Mode then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("fps:"..love.timer.getFPS( ), 0, 10)        
        love.graphics.print("x: "..cor_x, 0, 20)         
        love.graphics.print("y: "..cor_y, 0, 30)
        love.graphics.setColor(223, 113, 38, 80)
        love.graphics.rectangle("fill", bit.rshift(width, 1)-scope/2, bit.rshift(height, 1)-scope/2, scope, scope)
    end
end

local function round(num, precision)
    local str_num = num.."0000000"
    local dot_pos = str_num:find(".")
    
    return tonumber(str_num:sub(0, dot_pos+precision))
end

function love.update()
    if love.keyboard.isDown("up") then
        cor_y = math.min(cor_y+speed_y, map_height)
        redraw = true
    end

    if love.keyboard.isDown("down") then
        cor_y = math.max(cor_y-speed_y, -map_height)
        redraw = true        
    end

    if love.keyboard.isDown("right") then
        cor_x = math.min(cor_x+speed_x, map_width)
        redraw = true        
    end

    if love.keyboard.isDown("left") then
        cor_x = math.max(cor_x-speed_x, -map_width)
        redraw = true
    end

    if love.keyboard.isDown("[") then
        scope = math.min(scope+0.005, 64.0)
    end

    if love.keyboard.isDown("]") then
        scope = math.max(scope-0.005, 0.0)
    end

end

--function love.quit()
    --Steam.shutdown()
    --return true
--end