local addonName, Drawer = ...
local Conflicts = {}
Drawer.Conflicts = Conflicts

local adapters = {
    {id = "MinimapButtonFrame", frame = "MinimapButtonFrame", refresh = function()
        if MBF and MBF.Scan then MBF:Scan() end
    end},
    {id = "DragonUI", frame = "DragonUI_MinimapIconCollector", active = function()
        local cfg = DragonUI and DragonUI.db and DragonUI.db.profile and DragonUI.db.profile.minimap
        return cfg and cfg.collector_enabled ~= false
    end, disable = function()
        DragonUI.db.profile.minimap.collector_enabled = false
    end, open = function(frame)
        local collector = DragonUI and DragonUI.MinimapCollector
        if collector and not frame.isOpen then collector:Toggle() end
    end, close = function() DragonUI.MinimapCollector:Hide() end},
    {id = "MBB", frame = "MBB_MinimapButtonFrame", members = function() return MBB_Buttons end},
}

local function Descendant(frame, root)
    while frame do
        if frame == root then return true end
        frame = frame:GetParent()
    end
    return false
end

function Conflicts:CanHost(item)
    if Drawer.Collector.HasProtectedControl(item.frame) then return false, "This container includes protected controls." end
    if item.adapter.members then
        for _, name in ipairs(item.adapter.members() or {}) do
            if _G[name] and not Descendant(_G[name], item.frame) then
                return false, "This version anchors buttons separately; it has no complete container to move."
            end
        end
    end
    return true
end

function Conflicts:HasCollector()
    return next(self.active) ~= nil
end

function Conflicts:Host(item)
    if InCombatLockdown() or not self:CanHost(item) then return false end
    if not Drawer.Collector.entries[item.frame] then
        local release = {}
        for button, entry in pairs(Drawer.Collector.entries) do
            if not entry.container then release[#release + 1] = button end
        end
        for _, button in ipairs(release) do Drawer.Collector:Release(button) end
        if item.adapter.refresh then item.adapter.refresh() end
        item.wasOpen = item.frame.isOpen
        Drawer.Collector:Add(item.frame, true)
        if item.adapter.open then item.adapter.open(item.frame) end
        item.frame:Show()
    end
    return true
end

function Conflicts:Release(item)
    if not Drawer.Collector.entries[item.frame] then return end
    Drawer.Collector:Release(item.frame)
    if item.wasOpen == false and item.adapter.close then item.adapter.close() end
end

function Conflicts:OpenContainers()
    if InCombatLockdown() then return end
    for _, item in pairs(self.active) do
        if Drawer.Collector.entries[item.frame] then
            if item.adapter.open then item.adapter.open(item.frame) end
            item.frame:Show()
        end
    end
end

function Conflicts:Scan()
    if InCombatLockdown() then return end
    for _, adapter in ipairs(adapters) do
        local frame = _G[adapter.frame]
        local active = IsAddOnLoaded(adapter.id) and frame and (not adapter.active or adapter.active())
        if not active and self.active[adapter.id] then
            self:Release(self.active[adapter.id])
            if self.dialog and self.dialog.item == self.active[adapter.id] then self.dialog:Hide() end
            self.active[adapter.id] = nil
        elseif active and not self.active[adapter.id] then
            local title = GetAddOnMetadata(adapter.id, "Title") or adapter.id
            self.active[adapter.id] = {id = adapter.id, title = title:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""), frame = frame, adapter = adapter}
        end
    end
    for _, adapter in ipairs(adapters) do
        local item = self.active[adapter.id]
        if item then
            local choice = Drawer.settings.conflicts[item.id] or {}
            if self.reviewing and not self.seen[item.id] then
                self:Prompt(item)
            elseif choice.host then
                if not self:Host(item) then
                    self:Release(item)
                    if not self.seen[item.id] then self:Prompt(item) end
                end
            elseif not choice.silent and not self.seen[item.id] then self:Prompt(item) end
        end
    end
end

function Conflicts:Choose(action)
    if InCombatLockdown() then return end
    local item = self.dialog.item
    if not item then return end
    local choice = {silent = self.dialog.never:GetChecked() and true or false, host = action == "host"}
    if choice.host and not self:Host(item) then self:Prompt(item, true); return end
    if not choice.host then self:Release(item) end
    Drawer.settings.conflicts[item.id] = choice
    self.dialog.item = nil
    self.dialog:Hide()
    if action == "disableDrawer" or action == "disableOther" then
        if action == "disableOther" and item.adapter.disable then item.adapter.disable()
        else DisableAddOn(action == "disableDrawer" and addonName or item.id) end
        ReloadUI()
    end
end

function Conflicts:CreateDialog()
    local dialog = CreateFrame("Frame", "MiniMapButtonDrawerConflict", UIParent)
    dialog:SetSize(440, 290)
    dialog:SetPoint("CENTER")
    dialog:SetFrameStrata("DIALOG")
    dialog:EnableMouse(true)
    dialog:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32,
        insets = {left = 8, right = 8, top = 8, bottom = 8}})
    dialog.text = dialog:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    dialog.text:SetPoint("TOPLEFT", 24, -22)
    dialog.text:SetWidth(392)
    dialog.text:SetJustifyH("LEFT")
    local function Button(text, y, action)
        local button = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
        button:SetSize(392, 24)
        button:SetPoint("TOPLEFT", 24, y)
        button:SetText(text)
        button:SetScript("OnClick", function() Conflicts:Choose(action) end)
        return button
    end
    dialog.host = Button("Put its container in the drawer", -104, "host")
    dialog.disableDrawer = Button("Disable MiniMapButtonDrawer and reload", -134, "disableDrawer")
    dialog.disableOther = Button("", -164, "disableOther")
    dialog.leave = Button("Leave things as they are", -194, "ignore")
    dialog.never = CreateFrame("CheckButton", "MiniMapButtonDrawerConflictNever", dialog, "UICheckButtonTemplate")
    dialog.never:SetPoint("TOPLEFT", 20, -228)
    _G.MiniMapButtonDrawerConflictNeverText:SetText("Don't ask again for this addon")
    dialog:SetScript("OnHide", function()
        local item = dialog.item
        if item then
            local choice = Drawer.settings.conflicts[item.id] or {}
            choice.silent = dialog.never:GetChecked() and true or false
            Drawer.settings.conflicts[item.id] = choice
        end
        if self.reviewing then
            local pending = false
            for id in pairs(self.active) do if not self.seen[id] then pending = true end end
            self.reviewing = pending
        end
    end)
    UISpecialFrames[#UISpecialFrames + 1] = "MiniMapButtonDrawerConflict"
    dialog:Hide()
    self.dialog = dialog
end

function Conflicts:Prompt(item, refresh)
    if InCombatLockdown() then return end
    if not self.dialog then self:CreateDialog() end
    if self.dialog:IsShown() and not refresh then return end
    local dialog = self.dialog
    local canHost, reason = self:CanHost(item)
    dialog.item = item
    self.seen[item.id] = true
    dialog.text:SetText(item.title .. " also collects minimap buttons.\n\n" ..
        (reason or "Keep its layout inside the drawer, or choose which addon to use."))
    dialog.disableOther:SetText("Disable " .. item.id .. (item.adapter.disable and " collector" or "") .. " and reload")
    dialog.never:SetChecked((Drawer.settings.conflicts[item.id] or {}).silent)
    if canHost then dialog.host:Enable() else dialog.host:Disable() end
    dialog:Show()
end

function Conflicts:Review()
    self.seen, self.reviewing = {}, true
    self:Scan()
end

function Conflicts:Initialize()
    self.active, self.seen = {}, {}
end
