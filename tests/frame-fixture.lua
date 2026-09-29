local drawer={}
MBFDB, MiniMapButtonDrawerDB, MBF, MiniMapButtonDrawer = nil, nil, nil, nil
MinimapButtonFrame, DragonUI_MinimapIconCollector, MBB_MinimapButtonFrame = nil, nil, nil
DragonUI, MBB_Buttons = nil, nil
local loadedAddons, disabled, reloads = {}, {}, 0
IsAddOnLoaded=function(name) return loadedAddons[name] or false end
GetAddOnMetadata=function(name) return name end
DisableAddOn=function(name) disabled[name]=true end
ReloadUI=function() reloads=reloads+1 end
UISpecialFrames={}
SLASH_MINIMAPBUTTONDRAWER1, SLASH_MINIMAPBUTTONDRAWER2 = nil, nil
local frames={}
local Frame={}; Frame.__index=Frame
local function region()
 local r={}
 function r:SetText(t) self.text=t end
 function r:SetPoint(...) self.point={...} end
 function r:SetAllPoints(f) self.parent=f end
 function r:SetTexture(...) self.texture=(...) end
 function r:GetTexture() return self.texture end
 function r:ClearAllPoints() self.point=nil end
 function r:SetWidth(w) self.width=w end
 function r:SetHeight(h) self.height=h end
 function r:SetTexCoord(...) self.uv={...} end
 function r:SetVertexColor(...) self.color={...} end
 function r:Show() self.hidden=false end
 function r:Hide() self.hidden=true end
 function r:SetJustifyH(value) self.justify=value end
 return r
end
local function Fire(f,event,...)
 if f.scripts[event] then return f.scripts[event](f,...) end
end
function Frame:GetName() return self.name end
function Frame:GetObjectType() return self.kind end
function Frame:GetParent() return self.parent end
function Frame:SetParent(p) assert(p~=self); self.parent=p end
function Frame:GetWidth() return self.width end
function Frame:GetHeight() return self.height end
function Frame:SetWidth(w) self:SetSize(w,self.height) end
function Frame:SetSize(w,h)
 local changed=self.width~=w or self.height~=h
 self.width,self.height=w,h
 if changed then Fire(self,'OnSizeChanged',w,h) end
end
function Frame:GetScale() return self.scale end
function Frame:SetScale(s) self.scale=s end
function Frame:GetEffectiveScale() return self.scale*(self.parent and self.parent:GetEffectiveScale() or 1) end
function Frame:GetFrameLevel() return self.level end
function Frame:SetFrameLevel(n) self.level=n end
function Frame:GetFrameStrata() return self.strata end
function Frame:SetFrameStrata(s) self.strata=s end
function Frame:SetAlpha(a) self.alpha=a end
function Frame:EnableMouse(b) self.mouse=b end
function Frame:EnableMouseWheel(b) self.wheel=b end
function Frame:RegisterForDrag(...) self.drags={...} end
function Frame:RegisterForClicks(...) self.clicks={...} end
function Frame:SetBackdrop(t) self.backdrop=t end
function Frame:SetBackdropColor(...) self.bg={...} end
function Frame:SetBackdropBorderColor(...) self.border={...} end
function Frame:SetHighlightTexture(t) self.highlight=t end
function Frame:CreateTexture() local r=region(); self.regions[#self.regions+1]=r; return r end
function Frame:CreateFontString() return region() end
function Frame:GetRegions() return unpack(self.regions) end
function Frame:GetChildren()
 local result={}; for _,f in ipairs(frames) do if f.parent==self then result[#result+1]=f end end
 return unpack(result)
end
function Frame:IsProtected() return self.protected or false end
function Frame:SetScript(event,fn) self.scripts[event]=fn end
function Frame:GetScript(event) return self.scripts[event] end
function Frame:HookScript(event,fn)
 local old=self.scripts[event]
 self.scripts[event]=function(...) if old then old(...) end; fn(...) end
end
function Frame:RegisterEvent(event) self.events[event]=true end
function Frame:GetNumPoints() return #self.points end
function Frame:GetPoint(i) return unpack(self.points[i or 1] or {}) end
function Frame:ClearAllPoints() self.points={} end
function Frame:SetPoint(...) self.points[1]={...} end
function Frame:GetLeft() return self.points[1] and self.points[1][4] or 0 end
function Frame:GetBottom() return self.points[1] and self.points[1][5] or 0 end
function Frame:IsShown() return not self.hidden end
local function Visibility(f,event)
 Fire(f,event)
 for _,c in ipairs({f:GetChildren()}) do if c:IsShown() then Visibility(c,event) end end
end
function Frame:Hide() if not self.hidden then self.hidden=true; Visibility(self,'OnHide') end end
function Frame:Show() if self.hidden then self.hidden=false; Visibility(self,'OnShow') end end
function Frame:SetMinMaxValues(low,high) self.low,self.high=low,high end
function Frame:SetValueStep(step) self.step=step end
function Frame:SetValue(n) self.value=n; Fire(self,'OnValueChanged',n) end
function Frame:SetChecked(value) self.checked=value end
function Frame:GetChecked() return self.checked end
function Frame:SetText(value) self.text=value end
function Frame:Enable() self.enabled=true end
function Frame:Disable() self.enabled=false end
CreateFrame=function(kind,name,parent,template)
 local f=setmetatable({kind=kind,name=name,parent=parent,scale=1,width=32,height=32,level=1,
 strata='LOW',alpha=1,scripts={},events={},points={},regions={}},Frame)
 frames[#frames+1]=f; f.index=#frames
 if name then _G[name]=f end
 if template=='OptionsSliderTemplate' then
  for _,s in ipairs({'Text','Low','High'}) do _G[name..s]=region() end
 end
 if template=='UICheckButtonTemplate' then _G[name..'Text']=region() end
 return f
end
local enumerated=0
EnumerateFrames=function(previous) enumerated=enumerated+1; return frames[previous and previous.index+1 or 1] end
hooksecurefunc=function(object,method,after)
 local before=object[method]
 object[method]=function(...) before(...); after(...) end
end
UIParent=CreateFrame('Frame','UIParent'); UIParent:SetSize(1920,1080)
Minimap=CreateFrame('Frame','Minimap',UIParent)
MinimapBackdrop=CreateFrame('Frame','MinimapBackdrop',UIParent)
MinimapCluster=CreateFrame('Frame','MinimapCluster',UIParent)
SlashCmdList={}
local combat,leftDown=false,false
InCombatLockdown=function() return combat end
IsMouseButtonDown=function() return leftDown end
local cursorX,cursorY=600,100
GetCursorPosition=function() return cursorX,cursorY end
UnitName=function() return 'Example' end
GetRealmName=function() return 'Realm' end
local categories={}
InterfaceOptions_AddCategory=function(panel) categories[#categories+1]=panel end
local opened
InterfaceOptionsFrame_OpenToCategory=function(panel) opened=panel end
local function Event(event,...)
 for _,frame in ipairs(frames) do if frame.events[event] then Fire(frame,'OnEvent',event,...) end end
end
local function Button(name,parent)
 local b=CreateFrame('Button',name,parent or Minimap)
 b:SetPoint('CENTER',b.parent,'CENTER',22,33)
 b:SetScript('OnClick',function(self) self.clickCount=(self.clickCount or 0)+1 end)
 b:SetScript('OnEvent',function(self) self.eventCount=(self.eventCount or 0)+1 end)
 b:SetScript('OnEnter',function(self) self.tooltip=true end)
 return b
end
