local function Read(path)
    local file = assert(io.open(path, "rb"))
    local value = file:read("*a")
    file:close()
    return value
end
local fixture, modules = Read("tests/frame-fixture.lua"), ""
for _, name in ipairs({"Layout.lua", "Collector.lua", "Conflicts.lua", "Handle.lua", "Drawer.lua", "Options.lua", "MiniMapButtonDrawer.lua"}) do
    modules = modules .. "\nassert(loadstring(" .. string.format("%q", Read(name)) .. "))('MiniMapButtonDrawer',drawer)\n"
end
local initialize = [[
Event('ADDON_LOADED','MiniMapButtonDrawer')
Event('PLAYER_LOGIN')
local function Scan()
 drawer.Collector:RequestScan()
 repeat drawer.Collector:Update(0.01) until not drawer.Collector.scanning
 if drawer.layoutDirty then drawer:RefreshLayout() end
end
]]
local function Test(name, code, beforeInitialize, beforeLoad)
    assert(loadstring(fixture .. (beforeLoad or "") .. modules .. (beforeInitialize and "" or initialize) .. code, name))()
    print("PASS: " .. name)
end

Test('Flip changes drawer layout but never changes tab geometry', [[
for i=1,3 do Button('Test'..i) end
Scan()
for _,edge in ipairs({'LEFT','RIGHT','TOP','BOTTOM'}) do
 drawer.settings.edge=edge; drawer.settings.flipOrientation=false; drawer:RefreshLayout()
 local width,height=drawer.panel:GetWidth(),drawer.panel:GetHeight()
 local hw,hh,hx,hy=drawer.handle:GetWidth(),drawer.handle:GetHeight(),drawer.handle:GetLeft(),drawer.handle:GetBottom()
 drawer.orientationToggle:SetChecked(true); Fire(drawer.orientationToggle,'OnClick'); drawer:RefreshLayout()
 assert(drawer.panel:GetWidth()==height and drawer.panel:GetHeight()==width)
 assert(drawer.handle:GetWidth()==hw and drawer.handle:GetHeight()==hh and drawer.handle:GetLeft()==hx and drawer.handle:GetBottom()==hy)
end
]])

Test('Named collector detection reserves its buttons and hosts the whole container', [[
loadedAddons.MinimapButtonFrame=true
local container=CreateFrame('Frame','MinimapButtonFrame',UIParent)
container:SetSize(160,80); container:SetPoint('BOTTOMLEFT',UIParent,'BOTTOMLEFT',0,0)
local child=Button('ForeignButton',container)
child:SetPoint('BOTTOMLEFT',container,'BOTTOMLEFT',12,12)
local originalParent=container:GetParent()
Scan()
local conflicts=drawer.Conflicts
assert(conflicts.dialog:IsShown() and conflicts.dialog.text.text:find('MinimapButtonFrame',1,true))
assert(not child.MBFDrawerOwned)
conflicts.dialog.never:SetChecked(true)
Fire(conflicts.dialog.host,'OnClick'); drawer:RefreshLayout()
assert(container.MBFDrawerOwned and child:GetParent()==container)
assert(drawer.visible[1].slot:GetWidth()>=160 and drawer.visible[1].slot:GetHeight()>=80)
assert(drawer.settings.conflicts.MinimapButtonFrame.host)
conflicts:Review(); Fire(conflicts.dialog.leave,'OnClick')
assert(not container.MBFDrawerOwned and container:GetParent()==originalParent)
assert(drawer.settings.conflicts.MinimapButtonFrame.silent)
conflicts.seen={}; Scan(); assert(not conflicts.dialog:IsShown())
conflicts:Review(); assert(conflicts.dialog:IsShown())
]])

Test('Protected and separately anchored collectors cannot be stolen', [[
loadedAddons.MBB=true
local container=CreateFrame('Frame','MBB_MinimapButtonFrame',Minimap)
local separate=Button('MBBForeignButton'); MBB_Buttons={'MBBForeignButton'}
Scan()
local conflicts=drawer.Conflicts
assert(conflicts.dialog.host.enabled==false)
assert(not separate.MBFDrawerOwned)
assert(not conflicts:Host(conflicts.active.MBB))
conflicts:Choose('host'); assert(not container.MBFDrawerOwned)
Fire(conflicts.dialog.leave,'OnClick')
separate:SetParent(container); separate.protected=true
conflicts:Review(); assert(conflicts.dialog.host.enabled==false)
]])

Test('Disable choices target only the named addon and require explicit clicks', [[
loadedAddons.MinimapButtonFrame=true
CreateFrame('Frame','MinimapButtonFrame',UIParent)
Scan()
assert(reloads==0 and not next(disabled))
combat=true
Fire(drawer.Conflicts.dialog.disableOther,'OnClick')
assert(reloads==0)
combat=false
Fire(drawer.Conflicts.dialog.disableOther,'OnClick')
assert(disabled.MinimapButtonFrame and not disabled.MiniMapButtonDrawer and reloads==1)
drawer.Conflicts:Review()
Fire(drawer.Conflicts.dialog.disableDrawer,'OnClick')
assert(disabled.MiniMapButtonDrawer and reloads==2)
]])

Test('Drawer settings migrate into their own namespace', [[
MBFDB={version=5,profiles={Default={size=45,transparency=35}},profileKeys={}}
Event('ADDON_LOADED','MiniMapButtonDrawer')
assert(MiniMapButtonDrawerDB.profiles.Default.size==45 and MBFDB==nil)
assert(MBF==nil and MiniMapButtonDrawer==drawer)
assert(SLASH_MINIMAPBUTTONDRAWER1=='/mbd' and SLASH_MINIMAPBUTTONDRAWER2=='/mbf')
]], true)

Test('Independent transparency and live RGB survive settings migration', [[
Button('OpacityTest'); Scan()
Fire(drawer.transparencySlider,'OnValueChanged',100)
Fire(drawer.buttonTransparencySlider,'OnValueChanged',0)
assert(drawer.panel.alpha==1 and drawer.handle.alpha==0)
for _,entry in pairs(drawer.Collector.entries) do assert(entry.slot.alpha==1) end
Fire(drawer.redSlider,'OnValueChanged',30)
drawer.roundedToggle:SetChecked(true); Fire(drawer.roundedToggle,'OnClick')
local migrated=drawer.Layout.MigrateProfile(drawer.settings,800,600)
assert(migrated.tabRed==30 and migrated.roundedTab and migrated.buttonTransparency==0)
]])

Test('The original MBF namespace, settings and slash command are not overwritten', [[
MBFDB={version=5,profiles={Default={size=40}},profileKeys={}}
Event('ADDON_LOADED','MiniMapButtonDrawer')
assert(MBF==originalAddon and MBFDB==originalDB)
assert(MiniMapButtonDrawerDB.profiles.Default.size==40)
assert(SLASH_MINIMAPBUTTONDRAWER2==nil)
]], true, [[
loadedAddons.MinimapButtonFrame=true
local originalAddon,originalDB={original=true},{original=true}
MBF,MBFDB=originalAddon,originalDB
]])

Test('A late collector does not rearrange existing buttons before a user chooses hosting', [[
local button=Button('AlreadyCollected'); Scan()
local slot=button:GetParent()
loadedAddons.MinimapButtonFrame=true
CreateFrame('Frame','MinimapButtonFrame',UIParent)
Scan(); assert(button:GetParent()==slot)
Fire(drawer.Conflicts.dialog.leave,'OnClick')
assert(button:GetParent()==slot)
button:SetParent(MinimapButtonFrame)
assert(not button.MBFDrawerOwned and not drawer.Collector.entries[button])
]])

Test('Hosted container resizing, paging and release retain child handlers and original anchors', [[
loadedAddons.MinimapButtonFrame=true
local container=CreateFrame('Frame','MinimapButtonFrame',UIParent)
container:SetSize(180,60); container:SetPoint('BOTTOMLEFT',UIParent,'BOTTOMLEFT',0,0)
local child=Button('ContainerChild',container)
child:SetPoint('BOTTOMLEFT',container,'BOTTOMLEFT',5,5)
local click=child:GetScript('OnClick')
local original={container:GetPoint()}
Scan(); Fire(drawer.Conflicts.dialog.host,'OnClick'); drawer:RefreshLayout()
container:SetSize(300,80); drawer:RefreshLayout()
assert(drawer.visible[1].slot:GetWidth()>=300)
assert(child:GetParent()==container and child:GetScript('OnClick')==click)
combat=true; container:SetSize(320,90); drawer:RefreshLayout()
assert(drawer.visible[1].slot:GetWidth()==300)
combat=false; drawer:RefreshLayout()
assert(drawer.visible[1].slot:GetWidth()>=320)
drawer.Conflicts:Review(); Fire(drawer.Conflicts.dialog.leave,'OnClick')
local restored={container:GetPoint()}
for i,v in ipairs(original) do assert(restored[i]==v) end
assert(child:GetParent()==container and child:GetScript('OnClick')==click)
]])

Test('DragonUI hosting preserves its closed state and disabling only affects its collector', [[
loadedAddons.DragonUI=true
local container=CreateFrame('Frame','DragonUI_MinimapIconCollector',UIParent)
container.isOpen=false; container:Hide()
DragonUI={db={profile={minimap={collector_enabled=true}}},MinimapCollector={}}
function DragonUI.MinimapCollector:Toggle() container.isOpen=true; container:Show() end
function DragonUI.MinimapCollector:Hide() container.isOpen=false; container:Hide() end
Scan(); Fire(drawer.Conflicts.dialog.host,'OnClick'); drawer:RefreshLayout()
assert(container.isOpen and container.MBFDrawerOwned)
drawer.Conflicts:Review(); Fire(drawer.Conflicts.dialog.leave,'OnClick')
assert(not container.isOpen and not container:IsShown() and container:GetParent()==UIParent)
drawer.Conflicts:Review(); Fire(drawer.Conflicts.dialog.disableOther,'OnClick')
assert(DragonUI.db.profile.minimap.collector_enabled==false and not disabled.DragonUI and reloads==1)
Scan(); assert(not drawer.Conflicts:HasCollector())
]])

Test('Settings review can reopen every dismissed collector, not only the first', [[
loadedAddons.MinimapButtonFrame,loadedAddons.MBB=true,true
CreateFrame('Frame','MinimapButtonFrame',UIParent)
CreateFrame('Frame','MBB_MinimapButtonFrame',Minimap)
drawer.settings.conflicts={MinimapButtonFrame={silent=true},MBB={silent=true}}
Scan(); assert(not drawer.Conflicts.dialog)
drawer.Conflicts:Review()
assert(drawer.Conflicts.dialog.item.id=='MinimapButtonFrame')
Fire(drawer.Conflicts.dialog.leave,'OnClick'); Scan()
assert(drawer.Conflicts.dialog.item.id=='MBB')
Fire(drawer.Conflicts.dialog.leave,'OnClick'); Scan()
assert(not drawer.Conflicts.dialog:IsShown())
]])
