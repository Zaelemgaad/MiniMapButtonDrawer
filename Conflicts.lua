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
        if DragonUI and DragonUI.db then DragonUI.db.profile.minimap.collector_enabled = false end
    end, enable = function()
        if DragonUI and DragonUI.db then DragonUI.db.profile.minimap.collector_enabled = true end
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
    if item.inactive then return true end
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

function Conflicts:Installed()
    local result = {}
    for _, adapter in ipairs(adapters) do
        if IsAddOnLoaded(adapter.id) or (GetAddOnInfo and GetAddOnInfo(adapter.id)) then
            result[#result + 1] = self.active[adapter.id] or {
                id = adapter.id, title = adapter.id, adapter = adapter, frame = _G[adapter.frame], inactive = true,
            }
        end
    end
    return result
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
    if not item.frame then return end
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
    if self.reviewing then
        for _, item in ipairs(self.reviewItems or {}) do
            if not self.seen[item.id] then self:Prompt(item) end
        end
    end
end

function Conflicts:Choose(action)
    if InCombatLockdown() then return end
    local item = self.dialog.item
    if not item then return end
    local choice = {silent = self.dialog.never:GetChecked() and true or false, host = action == "host"}
    if item.inactive and (choice.host or action == "disableDrawer") then
        Drawer.settings.conflicts[item.id] = choice
        EnableAddOn(item.id)
        if item.adapter.enable then item.adapter.enable() end
        if action == "disableDrawer" then DisableAddOn(addonName) end
        self.dialog.item = nil
        self.dialog:Hide()
        ReloadUI()
        return
    end
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
    dialog:SetSize(300, 166)
    dialog:SetPoint("TOP", UIParent, "TOP", 0, -100)
    dialog:SetFrameStrata("DIALOG")
    dialog:EnableMouse(true)
    dialog:SetBackdrop({bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32,
        insets = {left = 8, right = 8, top = 8, bottom = 8}})
    dialog.text = dialog:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    dialog.text:SetPoint("TOPLEFT", 18, -18)
    dialog.text:SetWidth(264)
    dialog.text:SetJustifyH("LEFT")
    local function Button(text, x, y, action)
        local button = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
        button:SetSize(130, 24)
        button:SetPoint("TOPLEFT", x, y)
        button:SetText(text)
        button:SetScript("OnClick", function() Conflicts:Choose(action) end)
        return button
    end
    dialog.host = Button("Nest its container", 18, -68, "host")
    dialog.leave = Button("Keep both as-is", 152, -68, "ignore")
    dialog.disableOther = Button("Use drawer only", 18, -98, "disableOther")
    dialog.disableDrawer = Button("Use other only", 152, -98, "disableDrawer")
    dialog.never = CreateFrame("CheckButton", "MiniMapButtonDrawerConflictNever", dialog, "UICheckButtonTemplate")
    dialog.never:SetPoint("TOPLEFT", 14, -128)
    _G.MiniMapButtonDrawerConflictNeverText:SetText("Don't ask again")
    dialog:SetScript("OnHide", function()
        local item = dialog.item
        if item then
            local choice = Drawer.settings.conflicts[item.id] or {}
            choice.silent = dialog.never:GetChecked() and true or false
            Drawer.settings.conflicts[item.id] = choice
        end
        if self.reviewing then
            local pending = false
            for _, item in ipairs(self.reviewItems or {}) do if not self.seen[item.id] then pending = true end end
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
    dialog.text:SetText(item.title .. (item.inactive and " collector is disabled.\n" or " also collects buttons.\n") ..
        (reason and "Its container cannot be nested." or "Changing the active addon reloads the UI."))
    dialog.host:SetText(item.inactive and "Enable and nest" or "Nest its container")
    dialog:SetScript("OnEnter", function(frame)
        if reason then
            GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
            GameTooltip:SetText(reason, 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    dialog:SetScript("OnLeave", function() GameTooltip:Hide() end)
    dialog.never:SetChecked((Drawer.settings.conflicts[item.id] or {}).silent)
    if canHost then dialog.host:Enable() else dialog.host:Disable() end
    dialog:Show()
end

function Conflicts:Review()
    self.seen, self.reviewing = {}, true
    self.reviewItems = self:Installed()
    self:Scan()
end

function Conflicts:Initialize()
    self.active, self.seen = {}, {}
end
