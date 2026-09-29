local _, MBF = ...
local Layout = MBF.Layout
local WHITE = "Interface\\Buttons\\WHITE8X8"

local function Inside(frame, x, y)
    if not frame:IsShown() then return false end
    local left, bottom = frame:GetLeft(), frame:GetBottom()
    return left and bottom and x >= left and x <= left + frame:GetWidth()
        and y >= bottom and y <= bottom + frame:GetHeight()
end

function MBF:CursorPosition()
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    return x / scale, y / scale
end

function MBF:ApplyTransparency()
    local alpha = 1 - self.settings.transparency / 100
    self.handle:SetAlpha(alpha)
    self.panel:SetAlpha(1)
    self.panel:SetBackdropColor(0.045, 0.05, 0.055, 0.95 * alpha)
    self.panel:SetBackdropBorderColor(0.64, 0.49, 0.19, alpha)
    for _, entry in pairs(self.Collector.entries) do
        entry.slot:SetAlpha(1 - self.settings.buttonTransparency / 100)
    end
end

function MBF:PositionPanel()
    local x, y = Layout.PanelPosition(self.layout, self.progress, self.width, self.height)
    self.panel:ClearAllPoints()
    self.panel:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
end

function MBF:RefreshLayout()
    if InCombatLockdown() then return end
    self.layoutDirty = false
    self.width, self.height = UIParent:GetWidth(), UIParent:GetHeight()
    self.visible = self.Collector:VisibleEntries()
    local settings = self.settings
    local dimensions = {}
    for index, entry in ipairs(self.visible) do
        dimensions[index] = self.Collector:Measure(entry)
    end
    local layout = Layout.Calculate(settings.edge, settings.offset, #self.visible,
        settings.size, self.width, self.height, self.page, settings.tabThickness, settings.flipOrientation, dimensions)
    self.layout, self.page = layout, layout.page
    self.panel:SetSize(math.max(1, layout.width), math.max(1, layout.height))
    self.handle:ClearAllPoints()
    if layout.vertical then
        self.handle:SetSize(layout.thickness, layout.handleLength)
        local x = settings.edge == "LEFT" and 0 or self.width - layout.thickness
        self.handle:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, layout.center - layout.handleLength / 2)
    else
        self.handle:SetSize(layout.handleLength, layout.thickness)
        local y = settings.edge == "BOTTOM" and 0 or self.height - layout.thickness
        self.handle:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", layout.center - layout.handleLength / 2, y)
    end
    self:ApplyHandleAppearance()
    for _, entry in pairs(self.Collector.entries) do entry.onPage = false end
    for index = layout.first, layout.last do
        local entry, cell = self.visible[index], layout.cells[index - layout.first + 1]
        entry.onPage = true
        entry.fitScale = cell.scale
        entry.slot:SetSize(cell.width, cell.height)
        entry.slot:ClearAllPoints()
        entry.slot:SetPoint("BOTTOMLEFT", self.panel, "BOTTOMLEFT", cell.x, cell.y)
        self.Collector:Place(entry)
    end
    for _, entry in pairs(self.Collector.entries) do
        if entry.onPage then
            if not entry.slot:IsShown() then entry.slot:Show() end
        elseif entry.slot:IsShown() then entry.slot:Hide() end
    end
    if #self.visible == 0 then self.progress, self.target = 0, 0 end
    self:PositionPanel()
    if self.progress == 0 then self.panel:Hide() end
    self:ApplyTransparency()
end

function MBF:SetOpen(open)
    if not self.layout or self.protectedInCombat then return end
    local target = open and #self.visible > 0 and 1 or 0
    if target == 1 and self.target ~= 1 then self.Conflicts:OpenContainers() end
    self.target = target
    if self.target == 1 and not self.panel:IsShown() then self.panel:Show() end
end

function MBF:StartDrag()
    if InCombatLockdown() then return end
    self.dragging = true
    local x, y = self:CursorPosition()
    self.dragOffset = self.layout.center - (self.layout.vertical and y or x)
    self.dragEdge = self.settings.edge
    self:SetOpen(false)
end

function MBF:DragTo(x, y)
    local edge, offset = Layout.NearestEdge(x, y, self.width, self.height, self.settings.edge)
    if edge == self.dragEdge then
        offset = offset + self.dragOffset / ((edge == "LEFT" or edge == "RIGHT") and self.height or self.width)
    else
        self.dragEdge, self.dragOffset = edge, 0
    end
    self.settings.edge, self.settings.offset = edge, Layout.Clamp(offset, 0, 1)
    self:RefreshLayout()
end

function MBF:StopDrag()
    self.dragging = false
    self.leaveTime = 0
end

function MBF:ChangePage(delta)
    if not self.layout or InCombatLockdown() then return end
    self.page = Layout.Clamp(self.page - delta, 1, self.layout.pages)
    self.layoutDirty = true
end

function MBF:UpdateDrawer(elapsed)
    self.Collector:Update(elapsed)
    if self.layoutDirty and not InCombatLockdown() then self:RefreshLayout() end
    if not self.layout or self.protectedInCombat then return end
    local x, y = self:CursorPosition()
    if self.dragging then
        if not IsMouseButtonDown("LeftButton") or InCombatLockdown() then self:StopDrag()
        else self:DragTo(x, y) end
    end
    if not self.dragging then
        local over = Inside(self.handle, x, y) or Inside(self.panel, x, y)
        -- Keep a menu launched by a collected button usable outside the drawer rectangle.
        if not over and UIDROPDOWNMENU_OPEN_MENU and DropDownList1 and DropDownList1:IsShown() then
            local menu = UIDROPDOWNMENU_OPEN_MENU
            if type(menu) == "table" and menu.GetParent then
                local parent = menu
                for _ = 1, 10 do
                    if parent == self.panel or (parent and parent.MBFDrawerOwned) then over = true; break end
                    parent = parent and parent:GetParent()
                    if not parent then break end
                end
            end
        end
        if over then self.leaveTime = 0; self:SetOpen(true)
        else
            self.leaveTime = self.leaveTime + elapsed
            if self.leaveTime >= 0.25 then self:SetOpen(false) end
        end
    end
    if self.progress ~= self.target then
        local step = elapsed / 0.16
        if self.target > self.progress then self.progress = math.min(self.target, self.progress + step)
        else self.progress = math.max(self.target, self.progress - step) end
        self:PositionPanel()
        if self.progress == 0 then self.panel:Hide() end
    end
end

function MBF:CreateDrawer()
    self.progress, self.target, self.leaveTime, self.page = 0, 0, 0, 1
    self.panel = CreateFrame("Frame", "MiniMapButtonDrawerFrame", UIParent)
    self.panel:SetFrameStrata("HIGH")
    self.panel:SetFrameLevel(40)
    self.panel:EnableMouse(true)
    self.panel:EnableMouseWheel(true)
    self.panel:SetBackdrop({bgFile = WHITE, edgeFile = WHITE, edgeSize = 1})
    self.panel:SetBackdropColor(0.045, 0.05, 0.055, 0.95)
    self.panel:SetBackdropBorderColor(0.64, 0.49, 0.19, 1)
    self.panel:SetScript("OnMouseWheel", function(_, delta) self:ChangePage(delta) end)
    self.panel:Hide()

    self.handle = CreateFrame("Button", "MiniMapButtonDrawerHandle", UIParent)
    self.handle:SetFrameStrata("HIGH")
    self.handle:SetFrameLevel(45)
    self.handle:EnableMouse(true)
    self.handle:RegisterForDrag("LeftButton")
    self.handle:RegisterForClicks("RightButtonUp")
    self.handle:EnableMouseWheel(true)
    self:CreateHandleAppearance()
    self.handle:SetScript("OnEnter", function() self.leaveTime = 0; self:SetOpen(true) end)
    self.handle:SetScript("OnDragStart", function() self:StartDrag() end)
    self.handle:SetScript("OnDragStop", function() self:StopDrag() end)
    self.handle:SetScript("OnMouseUp", function(_, button) if button == "LeftButton" then self:StopDrag() end end)
    self.handle:SetScript("OnClick", function(_, button) if button == "RightButton" then self:OpenOptions() end end)
    self.handle:SetScript("OnMouseWheel", function(_, delta) self:ChangePage(delta) end)
end
