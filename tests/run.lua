local drawer = {}
assert(loadfile("Layout.lua"))("MiniMapButtonDrawer", drawer)
assert(loadfile("Handle.lua"))("MiniMapButtonDrawer", drawer)

for _, edge in ipairs({"LEFT", "RIGHT", "TOP", "BOTTOM"}) do
    for _, thickness in ipairs({4, 8, 24}) do
      for _, flipped in ipairs({false, true}) do
        for _, screen in ipairs({{800, 600}, {1920, 1080}, {3440, 1440}}) do
            for _, count in ipairs({0, 1, 10, 50, 500}) do
                local layout = drawer.Layout.Calculate(edge, 0.5, count, 32, screen[1], screen[2], 1, thickness, flipped)
                for page = 1, layout.pages do
                    layout = drawer.Layout.Calculate(edge, 0.5, count, 32, screen[1], screen[2], page, thickness, flipped)
                    local x, y = drawer.Layout.PanelPosition(layout, 1, screen[1], screen[2])
                    assert(x >= 0 and y >= 0)
                    assert(x + layout.width <= screen[1] and y + layout.height <= screen[2])
                    assert(layout.thickness == thickness)
                    for _, cell in ipairs(layout.cells) do
                        assert(cell.x >= 0 and cell.y >= 0)
                        assert(cell.x + 32 <= layout.width and cell.y + 32 <= layout.height)
                    end
                end
            end
        end
      end
    end
end

for _, edge in ipairs({"LEFT", "RIGHT", "TOP", "BOTTOM"}) do
    for _, flipped in ipairs({false, true}) do
        local dimensions = {{width=32,height=32},{width=200,height=130},{width=4000,height=2000},{width=32,height=32}}
        local layout = drawer.Layout.Calculate(edge, 0.99, #dimensions, 32, 800, 600, 1, 24, flipped, dimensions)
        for page=1,layout.pages do
            layout = drawer.Layout.Calculate(edge, 0.99, #dimensions, 32, 800, 600, page, 24, flipped, dimensions)
            local x,y=drawer.Layout.PanelPosition(layout,1,800,600)
            assert(x>=0 and y>=0 and x+layout.width<=800 and y+layout.height<=600)
            for i,a in ipairs(layout.cells) do
                assert(a.x>=0 and a.y>=0 and a.x+a.width<=layout.width and a.y+a.height<=layout.height)
                for j,b in ipairs(layout.cells) do
                    if i~=j then
                        assert(a.x+a.width<=b.x or b.x+b.width<=a.x or a.y+a.height<=b.y or b.y+b.height<=a.y)
                    end
                end
            end
        end
    end
end

local profile = drawer.Layout.MigrateProfile({opacity = 0.6, addonScale = 1.5}, 1920, 1080)
assert(profile.transparency == 40 and profile.buttonTransparency == 40 and profile.size == 48)
profile.roundedTab, profile.tabThickness = true, 24
profile.tabRed, profile.tabGreen, profile.tabBlue = 0, 128, 255
local restored = drawer.Layout.MigrateProfile(profile, 800, 600)
assert(restored.roundedTab and restored.tabThickness == 24)
assert(restored.tabRed == 0 and restored.tabGreen == 128 and restored.tabBlue == 255)

local function Texture()
    return {
        ClearAllPoints = function(self) self.point = nil end,
        SetPoint = function(self, ...) self.point = {...} end,
        SetWidth = function(self, w) self.width = w end,
        SetHeight = function(self, h) self.height = h end,
        SetTexture = function(self, path) self.texture = path end,
        SetTexCoord = function(self, ...) self.uv = {...} end,
        SetVertexColor = function(self, ...) self.color = {...} end,
        Show = function(self) self.shown = true end,
        Hide = function(self) self.shown = false end,
    }
end
drawer.handle = {GetWidth = function() return 8 end, GetHeight = function() return 50 end, CreateTexture = Texture}
drawer.settings = restored
drawer:CreateHandleAppearance()
for _, rounded in ipairs({false, true}) do
    drawer.settings.roundedTab = rounded
    drawer:ApplyHandleAppearance()
    local area = 0
    for _, layers in ipairs(drawer.handleArt) do
        local normal, hover = layers[1], layers[2]
        assert(normal.shown == hover.shown)
        if normal.shown then
            assert(normal.color[1] == 0 and normal.color[2] == 128/255 and normal.color[3] == 1)
            area = area + normal.width * normal.height
        end
    end
    assert(area == 400)
    assert(drawer.handleArt[1][1].shown == rounded)
end

local file = assert(io.open("Media/TabCircle.tga", "rb"))
local image = file:read("*a")
file:close()
assert(#image == 4114 and image:byte(3) == 2 and image:byte(17) == 32)
assert(image:byte(22) == 0 and image:byte(18 + 4 * (16 * 32 + 16) + 4) == 255)
print("PASS: edge geometry, paging, settings migration, RGB, rounded corners, texture")
