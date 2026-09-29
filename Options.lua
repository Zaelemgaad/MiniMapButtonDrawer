local _, MBF = ...

function MBF:CreateOptions()
    local panel = CreateFrame("Frame", "MiniMapButtonDrawerOptions", UIParent)
    panel.name = "MiniMapButtonDrawer"
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(panel.name)
    local function Slider(name, label, y, low, high, step, key, suffix, x, width)
        local slider = CreateFrame("Slider", name, panel, "OptionsSliderTemplate")
        slider:SetPoint("TOPLEFT", x or 24, y)
        slider:SetWidth(width or 260)
        slider:SetMinMaxValues(low, high)
        slider:SetValueStep(step)
        _G[name .. "Low"]:SetText(low .. suffix)
        _G[name .. "High"]:SetText(high .. suffix)
        local function Sync(value)
            _G[name .. "Text"]:SetText(label .. ": " .. value .. suffix)
        end
        slider:SetScript("OnValueChanged", function(_, value)
            value = math.floor(value / step + 0.5) * step
            Sync(value)
            if self.settings[key] == value then return end
            self.settings[key] = value
            if key == "transparency" or key == "buttonTransparency" then
                self:ApplyTransparency()
            elseif key == "tabRed" or key == "tabGreen" or key == "tabBlue" then
                self:ApplyHandleAppearance()
                self.colorSwatch:SetVertexColor(self.settings.tabRed / 255, self.settings.tabGreen / 255, self.settings.tabBlue / 255)
            else self.layoutDirty = true end
        end)
        slider:SetScript("OnShow", function() slider:SetValue(self.settings[key]); Sync(self.settings[key]) end)
        return slider
    end
    self.sizeSlider = Slider("MiniMapButtonDrawerSize", "Button size", -68, 20, 56, 1, "size", " px")
    self.transparencySlider = Slider("MiniMapButtonDrawerTransparency", "Drawer transparency", -124, 0, 100, 1, "transparency", "%")
    self.buttonTransparencySlider = Slider("MiniMapButtonDrawerButtonTransparency", "Button transparency", -180, 0, 100, 1, "buttonTransparency", "%")
    self.thicknessSlider = Slider("MiniMapButtonDrawerThickness", "Tab thickness", -236, 4, 24, 1, "tabThickness", " px")
    self.redSlider = Slider("MiniMapButtonDrawerRed", "Red", -310, 0, 255, 1, "tabRed", "", 24, 76)
    self.greenSlider = Slider("MiniMapButtonDrawerGreen", "Green", -310, 0, 255, 1, "tabGreen", "", 124, 76)
    self.blueSlider = Slider("MiniMapButtonDrawerBlue", "Blue", -310, 0, 255, 1, "tabBlue", "", 224, 76)
    local colorLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    colorLabel:SetPoint("TOPLEFT", 24, -270)
    colorLabel:SetText("Tab color (RGB)")
    self.colorSwatch = panel:CreateTexture(nil, "ARTWORK")
    self.colorSwatch:SetTexture("Interface\\Buttons\\WHITE8X8")
    self.colorSwatch:SetPoint("TOPLEFT", 160, -268)
    self.colorSwatch:SetWidth(24)
    self.colorSwatch:SetHeight(16)
    self.roundedToggle = CreateFrame("CheckButton", "MiniMapButtonDrawerRounded", panel, "UICheckButtonTemplate")
    self.roundedToggle:SetPoint("TOPLEFT", 18, -354)
    _G.MiniMapButtonDrawerRoundedText:SetText("Rounded tab corners")
    self.roundedToggle:SetScript("OnClick", function(button)
        self.settings.roundedTab = button:GetChecked() and true or false
        self:ApplyHandleAppearance()
    end)
    local function SyncColor()
        self.roundedToggle:SetChecked(self.settings.roundedTab)
        self.colorSwatch:SetVertexColor(self.settings.tabRed / 255, self.settings.tabGreen / 255, self.settings.tabBlue / 255)
    end
    panel:SetScript("OnShow", SyncColor)
    SyncColor()
    panel.default = function()
        self.settings.size, self.settings.transparency = 32, 20
        self.settings.buttonTransparency = 20
        self.settings.tabThickness, self.settings.roundedTab = 8, false
        self.settings.tabRed, self.settings.tabGreen, self.settings.tabBlue = 209, 166, 64
        self.sizeSlider:SetValue(32)
        self.transparencySlider:SetValue(20)
        self.buttonTransparencySlider:SetValue(20)
        self.thicknessSlider:SetValue(8)
        self.redSlider:SetValue(209)
        self.greenSlider:SetValue(166)
        self.blueSlider:SetValue(64)
        SyncColor()
        self.layoutDirty = true
        self:ApplyTransparency()
    end
    self.optionsPanel = panel
    panel:Hide()
    InterfaceOptions_AddCategory(panel)
end

function MBF:OpenOptions()
    InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
end
