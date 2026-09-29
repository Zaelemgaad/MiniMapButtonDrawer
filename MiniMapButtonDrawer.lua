local addonName, MBF = ...
_G.MBF = MBF
_G.MiniMapButtonDrawer = MBF

function MBF:IsEnabled()
    return self.settings ~= nil
end

function MBF:Initialize()
    local old = type(MBFDB) == "table" and MBFDB or {}
    local db = {version = 5, profiles = {}, profileKeys = {}}
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    for name, profile in pairs(old.profiles or {}) do
        db.profiles[name] = self.Layout.MigrateProfile(profile, width, height)
    end
    for character, profile in pairs(old.profileKeys or {}) do db.profileKeys[character] = profile end
    local character = UnitName("player") .. " - " .. GetRealmName()
    local profileName = db.profileKeys[character] or "Default"
    db.profileKeys[character] = profileName
    db.profiles[profileName] = db.profiles[profileName] or self.Layout.MigrateProfile({}, width, height)
    MBFDB, self.settings = db, db.profiles[profileName]
    self:CreateDrawer()
    self.Collector:Initialize(self)
    self:CreateOptions()
    self:RefreshLayout()
    SLASH_MBF1 = "/mbf"
    SLASH_MBF2 = "/mbd"
    SlashCmdList.MBF = function() self:OpenOptions() end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("DISPLAY_SIZE_CHANGED")
events:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == addonName then
        MBF:Initialize()
    elseif MBF:IsEnabled() then
        if event == "PLAYER_LOGIN" then
            events:SetScript("OnUpdate", function(_, elapsed) MBF:UpdateDrawer(elapsed) end)
        elseif event == "PLAYER_REGEN_DISABLED" then
            MBF:StopDrag()
            MBF.protectedInCombat = MBF.Collector.HasProtectedControl(MBF.panel)
        elseif event == "PLAYER_REGEN_ENABLED" then
            MBF.protectedInCombat = false
            for button in pairs(MBF.Collector.entries) do
                if MBF.Collector.HasProtectedControl(button) then MBF.Collector:Release(button) end
            end
            MBF.layoutDirty = true
        elseif event == "DISPLAY_SIZE_CHANGED" then MBF.layoutDirty = true end
        MBF.Collector:RequestScan()
    end
end)
UIParent:HookScript("OnSizeChanged", function() MBF.layoutDirty = true end)
