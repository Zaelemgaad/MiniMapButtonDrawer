local addonName, Drawer = ...
local WHITE = "Interface\\Buttons\\WHITE8X8"
local CIRCLE = "Interface\\AddOns\\" .. addonName .. "\\Media\\TabCircle.tga"

function Drawer:CreateHandleAppearance()
    self.handleArt = {}
    for index = 1, 9 do
        self.handleArt[index] = {
            self.handle:CreateTexture(nil, "ARTWORK"),
            self.handle:CreateTexture(nil, "HIGHLIGHT"),
        }
    end
end

function Drawer:ApplyHandleAppearance()
    local width, height = self.handle:GetWidth(), self.handle:GetHeight()
    local radius = self.settings.roundedTab and math.min(6, width / 2, height / 2) or 0
    local xs, ys = {0, radius, width - radius, width}, {0, radius, height - radius, height}
    local r, g, b = self.settings.tabRed / 255, self.settings.tabGreen / 255, self.settings.tabBlue / 255
    -- Nine regions keep corner radii constant as the tab changes size or edge.
    for row = 1, 3 do
        for column = 1, 3 do
            local textures = self.handleArt[(row - 1) * 3 + column]
            local w, h = xs[column + 1] - xs[column], ys[row + 1] - ys[row]
            for layer, texture in ipairs(textures) do
                texture:ClearAllPoints()
                if w > 0 and h > 0 then
                    texture:SetPoint("TOPLEFT", self.handle, "TOPLEFT", xs[column], -ys[row])
                    texture:SetWidth(w)
                    texture:SetHeight(h)
                    local edge = self.settings.edge
                    local inward = (edge == "LEFT" and column == 3) or (edge == "RIGHT" and column == 1)
                        or (edge == "TOP" and row == 3) or (edge == "BOTTOM" and row == 1)
                    if column ~= 2 and row ~= 2 and inward then
                        texture:SetTexture(CIRCLE)
                        local u, v = column == 1 and 0 or 0.5, row == 1 and 0 or 0.5
                        texture:SetTexCoord(u, u + 0.5, v, v + 0.5)
                    else
                        texture:SetTexture(WHITE)
                        texture:SetTexCoord(0, 1, 0, 1)
                    end
                    if layer == 1 then texture:SetVertexColor(r, g, b, 1)
                    else texture:SetVertexColor(1, 1, 1, 0.18) end
                    texture:Show()
                else
                    texture:Hide()
                end
            end
        end
    end
end
