local gen = require 'src/generate'
local def = require 'src/gendefs'

-- "GAME" SETTINGS

Debug_Mode = true
Game_Scene = 0

-- USER VARIABLES

scope = 1.00

x = 0.00
y = 0.00

world = {} ---@type map

render = nil

-- CONSTANTS

local MAP_BLOCK         = 64
local MAP_BLOCK_HALF    = MAP_BLOCK / 2
local MAP_TILE_HALF     = MAP_BLOCK_HALF / 2

local X_SPEED = 16 / MAP_BLOCK
local Y_SPEED = 16 / MAP_BLOCK

function love.load()
    ---------------------
    --
    --  Generate world
    --
    ---------------------

    local randomness = love.math.newRandomGenerator()

    local biomes = def.biomes

    world = gen:new(randomness:random(), 512, 512, biomes)

    render = gen:render(world, biomes, def.basic_block, def.basic_tile)

    randomness:release()
end

function love.draw()
    --local canvas_dim_x, canvas_dim_y = render:getDimensions()
    
    local x_off = math.floor(-x * MAP_BLOCK_HALF - world.width) * scope + world.width/2
    local y_off = math.floor(y * MAP_TILE_HALF - world.height) * scope + world.height/2

    love.graphics.draw(
        render, 
        x_off,
        y_off,
        0, 
        scope,
        scope
    )

    if Debug_Mode then
        love.graphics.setColor(1, 1, 1, 1)

        love.graphics.print("fps:"..love.timer.getFPS( ), 0, 10)
        
        love.graphics.print("x: "..x, 0, 20)
        love.graphics.print("y: "..y, 0, 30)
        
        love.graphics.setColor(223, 113, 38, 80)
        
        love.graphics.rectangle("fill", 
                bit.rshift(world.width, 1) - scope/2,
                bit.rshift(world.height, 1) - scope/2,
                scope,
                scope
        )
    end
end

function love.update()
    if love.keyboard.isDown("up") or love.keyboard.isDown("w") then
        y = math.min(
            y + Y_SPEED,
            world.height
        )
    end

    if love.keyboard.isDown("down") or love.keyboard.isDown("s") then
        y = math.max(
            y - Y_SPEED,
            - world.height
        )    
    end

    if love.keyboard.isDown("right") or love.keyboard.isDown("d") then
        x = math.min(
            x + X_SPEED,
            world.width
        )     
    end

    if love.keyboard.isDown("left") or love.keyboard.isDown("a") then
        x = math.max(
            x - X_SPEED,
            - world.width
        )
    end

    if love.keyboard.isDown("[") or love.keyboard.isDown("pageup") then
        scope = math.min(
            scope + 0.0005,
            64.0
        )
    end

    if love.keyboard.isDown("]") or love.keyboard.isDown("pagedown") then
        scope = math.max(
            scope - 0.0005,
            0.0
        )
    end

end

--function love.quit()
--end