--[[

    Custom Library for this project.
    Generates simple tile set

--]]

---@class slope_data
---@field texture any
---@field renders table<any>

---@class prerendering_library
---@field create function
---@field storage table<slope_data>

local module_data = {
    storage = {},
}

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

local LUT = {
    [0]     = 0, -- Normal block
    [1]     = SLOPE_FRONT,
    [2]     = SLOPE_BACK,
    [3]     = SLOPE_LEFT,
    [4]     = SLOPE_RIGHT,
    [5]     = SLOPE_FRONTLEFT,
    [6]     = SLOPE_FRONTRIGHT,
    [7]     = SLOPE_BACKLEFT,
    [8]     = SLOPE_BACKRIGHT,
    [9]     = SLOPE_CORNERLEFT,
    [10]    = SLOPE_CORNERRIGHT,
}

local genetic_dim = 64
local newCanvas = love.graphics.newCanvas ---@type function
local newMesh = love.graphics.newMesh ---@type function

--
-- Model stuff
--

local vertex_format = {
    {"VertexPosition", "float", 2},
    {"VertexTexCoord", "float", 2},
    {"VertexPlane",    "float", 1},
}

-- shader built on default Love2D shader
local shader = love.graphics.newShader([[
    varying float planeVertex;

#ifdef VERTEX
        attribute float VertexPlane;

        vec4 position(mat4 transform_projection, vec4 vertex_position)
        {
            // The order of operations matters when doing matrix multiplication.
            planeVertex = VertexPlane;
            return transform_projection * vertex_position;
        }
#endif

#ifdef PIXEL
        vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
        {
            vec4 texturecolor = Texel(tex, texture_coords);
            vec4 truecolor = texturecolor * color;
            float brightness = (planeVertex - 1.0) * 0.10f;
            return vec4(truecolor.xyz - brightness, 1.0f);
        }
#endif
]])




local meshes = {}

local function createModel(polygons)
    local verts = {}

    for x = 1, #polygons do
        local plane = polygons[x]

        if #plane > 3 then
            plane[1][5] = x
            plane[2][5] = x
            plane[3][5] = x
            plane[4][5] = x            

            table.insert(verts, plane[1])
            table.insert(verts, plane[2])
            table.insert(verts, plane[3])

            table.insert(verts, plane[4])
            table.insert(verts, plane[3])
            table.insert(verts, plane[1])
        else
            plane[1][5] = x
            plane[2][5] = x
            plane[3][5] = x

            table.insert(verts, plane[1])
            table.insert(verts, plane[2])
            table.insert(verts, plane[3])
        end
    end

    return newMesh(vertex_format, verts, "triangles", "static")
end

meshes[0] = createModel{
    {
        {32,    0,    0, 0},
        {0,    16,    1, 0},
        {32,   32,    1, 1},
        {64,   16,    0, 1}
    },

    {
        {0,    16,    0, 0},
        {32,   32,    1, 0},
        {32,   64,    1, 1},
        {0,    48,    0, 1}
    },

    {
        {64,   16,    0, 0},
        {32,   32,    1, 0},
        {32,   64,    1, 1},
        {64,   48,    0, 1}
    },
}

--
-- Straight slopes
--

meshes[1] = createModel{
    {
        {32,    0,    0, 0},
        {64,   16,    1, 0},
        {32,   64,    1, 1},
        {0,    48,    0, 1}
    },

    {
        {64,   16,    1, 0},
        {32,   64,    1, 1},
        {64,   48,    0, 1},
    },
}

meshes[2] = createModel{
    {
        {0,    16,    0, 0},
        {32,   32,    1, 0},
        {32,   64,    1, 1},
        {0,    48,    0, 1}
    },

    {
        {32,   32,    1, 0},
        {64,   48,    1, 1},
        {32,   64,    0, 1},
    },
}

meshes[3] = createModel{
    {
        {64,   16,    0, 0},
        {32,   32,    1, 0},
        {32,   64,    1, 1},
        {64,   48,    0, 1}
    },

    {
        {32,   32,    1, 0},
        {0,    48,    1, 1},
        {32,   64,    0, 1},
    },
}

meshes[4] = createModel{
    {
        {32,    0,    0, 0},
        {0,    16,    1, 0},
        {32,   64,    1, 1},
        {64,   48,    0, 1}
    },

    {
        {0,    16,    1, 0},
        {32,   64,    1, 1},
        {0,    48,    0, 1},
    },
}

--
-- Turning slopes
--

meshes[5] = meshes[1]

meshes[6] = createModel{
    {
        {32,    0,    0, 0},
        {32,   64,    1, 0},
        {0,    48,    1, 1},
    },

    {
        {32,    0,    0, 0},
        {32,   64,    1, 0},
        {64,   48,    1, 1},
    },
}

meshes[7] = meshes[4]

meshes[8] = createModel{
    {
        {32,    0,    0, 0},
        {32,   64,    1, 0},
        {0,    48,    1, 1},
        {0,    48,    0, 1},        
    },
}

--
-- Corner slopes
--

meshes[9] = meshes[8]

meshes[10] = createModel{
    {
        {32,    0,    0, 0},
        {0,    16,    1, 0},
        {32,   64,    1, 1},
        {64,   16,    0, 1}
    },

    {
        {0,    16,    1, 0},
        {32,   64,    1, 1},
        {32,   48,    1, 1}
    },

    {
        {64,   16,    1, 0},
        {32,   64,    1, 1},
        {64,   48,    1, 1}
    },
}

-- Use when all data were pre-cached
function module_data:destroyMeshes()
    for i = 0, 10 do
        meshes[i]:release()
        meshes[i] = nil -- might seem silly, but garbage collector.. uhh, not letting this one to it, I think...
    end
    
    shader:release()

    shader = nil
    meshes = nil
end

---Creates based on texture bunch of tiles
---@param texture string
---@return table<any>
function module_data:generate(texture)
    if self.storage and self.storage[texture] then
        return self.storage[texture].renders
    end

    -- Prepare the cache
    self.storage[texture] = {
        texture = love.graphics.newImage("assets/"..texture),
        renders = {}
    }

    -- storing obvious references for use
    local ref = self.storage[texture]
    local img = ref.texture

    love.graphics.setShader(shader)

    -- rendering
    for i = 0, 10 do
        meshes[i]:setTexture(img)

        local bit = LUT[i]
        self.storage[texture].renders[bit] = {img = newCanvas(genetic_dim, genetic_dim), offset = 0}
        love.graphics.setCanvas{self.storage[texture].renders[bit].img} 
        love.graphics.draw(meshes[i])
        love.graphics.setCanvas()
    end

    love.graphics.setShader()

    return ref.renders
end

return module_data