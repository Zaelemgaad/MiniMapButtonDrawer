local _, MBF = ...
local Collector = {}
MBF.Collector = Collector

local excludedNames = {}
for _, name in ipairs({"Minimap", "MinimapBackdrop", "MinimapCluster", "MinimapZoomIn",
    "MinimapZoomOut", "MinimapZoneTextButton", "MiniMapTracking", "MiniMapTrackingButton",
    "MiniMapMailFrame", "MiniMapBattlefieldFrame", "MiniMapLFGFrame", "MiniMapWorldMapButton",
    "MiniMapInstanceDifficulty", "MiniMapVoiceChatFrame", "GameTimeFrame", "TimeManagerClockButton",
    "HelpOpenTicketButton", "FeedbackUIButton", "DragonUI_MinimapSettingsButton",
    "MBB_MinimapButtonFrame", "LibDBIcon10_MBF"}) do excludedNames[name] = true end
local pinNames = {"gathermatepin", "gathernote", "handynotespin", "questieframe", "questie_minimapnote",
    "pfquest", "pfmap", "pfminimap", "questhelper", "tomtom", "totemradius", "nauticusminiicon",
    "zgvmarker", "spy_mapnotelist", "worldmappoi", "poiworldmap", "questmappoi", "minimapbuttonframe"}
local pinTextures = {"\\pfquest\\", "\\questie\\", "\\questhelper\\", "\\tomtom\\", "\\totemradius\\"}
local knownButtons = {WIM_IconFrame = true, CTMod2_MinimapButton = true, PoisonerMinimapButton = true,
    AtlasButton = true, pfQuestIcon = true, MetamapButton = true}

local function IsPin(frame, name)
    if frame.miniMapIcon or frame.miniMapIconData or frame.pfQuest or frame.pfquest then return true end
    local lower = name:lower()
    for _, prefix in ipairs(pinNames) do
        if lower:find(prefix, 1, true) then return true end
    end
    for _, region in ipairs({frame:GetRegions()}) do
        if region.GetTexture then
            local texture = region:GetTexture()
            if type(texture) == "string" then
                texture = texture:lower():gsub("/", "\\")
                for _, path in ipairs(pinTextures) do
                    if texture:find(path, 1, true) then return true end
                end
            end
        end
    end
    return false
end

function Collector.HasProtectedControl(frame)
    if frame:IsProtected() then return true end
    for _, child in ipairs({frame:GetChildren()}) do
        if Collector.HasProtectedControl(child) then return true end
    end
    return false
end

function Collector:IsCandidate(frame)
    if self.entries[frame] or frame.MBFDrawerOwned or not frame:IsShown() then return false end
    local kind, name = frame:GetObjectType(), frame:GetName() or ""
    if kind ~= "Button" and kind ~= "Frame" then return false end
    if excludedNames[name] or self.owner.settings.excluded[name] then return false end
    local known = knownButtons[name] or name:find("LibDBIcon10_", 1, true) == 1
    local explicit = self.owner.settings.included[name]
    if kind == "Frame" and not known and not explicit then return false end
    local width, height = frame:GetWidth(), frame:GetHeight()
    if width <= 0 or height <= 0 or width > 80 or height > 80 then return false end
    if not known and not explicit then
        local parent, onMinimap = frame:GetParent(), false
        for _ = 1, 2 do
            if not parent then break end
            if parent == Minimap or parent == MinimapBackdrop or parent == MinimapCluster then
                onMinimap = true
                break
            end
            local parentName = parent:GetName() or ""
            if parent.MBFDrawerOwned or excludedNames[parentName] or IsPin(parent, parentName) then return false end
            parent = parent:GetParent()
        end
        if not onMinimap or IsPin(frame, name) then return false end
    end
    -- Secure action controls stay in their original hierarchy, never in an insecure hover drawer.
    return not Collector.HasProtectedControl(frame)
end

function Collector:Place(entry)
    if self.placing or InCombatLockdown() then return end
    self.placing = true
    local button, slot = entry.button, entry.slot
    slot:SetAlpha(1 - self.owner.settings.buttonTransparency / 100)
    button:SetParent(slot)
    button:SetFrameStrata(self.owner.panel:GetFrameStrata())
    button:SetFrameLevel(slot:GetFrameLevel() + 1)
    button:SetScale(self.owner.settings.size / math.max(button:GetWidth(), button:GetHeight(), 1))
    button:ClearAllPoints()
    button:SetPoint("CENTER", slot, "CENTER", 0, 0)
    self.placing = false
end

function Collector:Add(button)
    if InCombatLockdown() or self.entries[button] then return end
    local slot = CreateFrame("Frame", nil, self.owner.panel)
    slot:SetFrameLevel(self.owner.panel:GetFrameLevel() + 1)
    local entry = {button = button, slot = slot, original = {
        parent = button:GetParent(), scale = button:GetScale(), level = button:GetFrameLevel(),
        strata = button:GetFrameStrata(), dragStart = button:GetScript("OnDragStart"),
        dragStop = button:GetScript("OnDragStop"), points = {},
    }}
    for i = 1, button:GetNumPoints() do entry.original.points[i] = {button:GetPoint(i)} end
    self.entries[button] = entry
    button.MBFDrawerOwned = true
    button:SetScript("OnDragStart", nil)
    button:SetScript("OnDragStop", nil)
    -- Position hooks enforce layout without deleting native event/click/tooltip handlers.
    if not self.hooked[button] then
        self.hooked[button] = true
        for _, method in ipairs({"SetPoint", "ClearAllPoints", "SetParent", "SetScale"}) do
            hooksecurefunc(button, method, function()
                local current = self.entries[button]
                if current and not self.placing then self:Place(current) end
            end)
        end
        local function changed()
            if self.entries[button] and not self.placing then self.owner.layoutDirty = true end
        end
        button:HookScript("OnShow", changed)
        button:HookScript("OnHide", changed)
        button:HookScript("OnSizeChanged", changed)
    end
    self:Place(entry)
    self.owner.layoutDirty = true
end

function Collector:VisibleEntries()
    local result = {}
    for button, entry in pairs(self.entries) do
        if button:IsShown() then result[#result + 1] = entry end
    end
    table.sort(result, function(a, b)
        local left, right = a.button:GetName() or "", b.button:GetName() or ""
        if left == right then return tostring(a.button) < tostring(b.button) end
        return left:lower() < right:lower()
    end)
    return result
end

function Collector:Release(button)
    if InCombatLockdown() then return end
    local entry = self.entries[button]
    if not entry then return end
    local original = entry.original
    self.entries[button] = nil
    button.MBFDrawerOwned = nil
    button:SetParent(original.parent)
    button:SetScale(original.scale)
    button:SetFrameStrata(original.strata)
    button:SetFrameLevel(original.level)
    button:ClearAllPoints()
    for _, point in ipairs(original.points) do button:SetPoint(unpack(point)) end
    button:SetScript("OnDragStart", original.dragStart)
    button:SetScript("OnDragStop", original.dragStop)
    entry.slot:Hide()
    self.owner.layoutDirty = true
end

function Collector:RequestScan()
    self.rescan = true
end

function Collector:Update(elapsed)
    if InCombatLockdown() then return end
    self.delay = self.delay - elapsed
    if not self.scanning then
        if self.delay > 0 and not self.rescan then return end
        self.rescan, self.scanning, self.cursor = false, true, nil
    end
    -- A bounded walk avoids GetChildren's huge multi-return on quest-pin-heavy minimaps.
    for _ = 1, 100 do
        local frame = EnumerateFrames(self.cursor)
        self.cursor = frame
        if not frame then
            self.scanning, self.delay = false, 5
            break
        end
        if self:IsCandidate(frame) then self:Add(frame) end
    end
end

function Collector:Initialize(owner)
    self.owner, self.entries, self.hooked, self.delay = owner, {}, {}, 0
end
