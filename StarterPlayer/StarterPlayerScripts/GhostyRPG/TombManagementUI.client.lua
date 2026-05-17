--!strict
--------------------------------------------------------------------------------
-- GhostyRPG | TombManagementUI.client.lua
-- StarterPlayerScripts/TombManagementUI.client.lua
--
-- Full tomb management interface. Four tabs:
--   [Guardians]  Guardian slot grid; click a slot to hire / fire / inspect.
--   [Hire]       Browse available guardians for the current TombTier.
--   [Upgrade]    Requirements for next tier with checkmarks.
--   [Rooms]      Unlocked/locked room list.
--
-- OPEN / CLOSE: Press [T] or call TombManagementUI.Open() / .Close().
--------------------------------------------------------------------------------

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SharedRemotes  = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes")
local GuardianRemotes = require(SharedRemotes:WaitForChild("GuardianRemotes"))

local SharedConfig   = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local GuardianConfig = require(SharedConfig:WaitForChild("GuardianConfig"))

local C = {
    bg=Color3.fromRGB(12,10,18),panel=Color3.fromRGB(22,18,32),
    header=Color3.fromRGB(30,24,46),accent=Color3.fromRGB(160,90,220),
    accentDark=Color3.fromRGB(90,40,140),gold=Color3.fromRGB(255,210,60),
    text=Color3.fromRGB(230,220,255),textDim=Color3.fromRGB(130,110,170),
    green=Color3.fromRGB(80,200,80),red=Color3.fromRGB(220,70,70),
    orange=Color3.fromRGB(220,150,40),slotEmpty=Color3.fromRGB(28,22,44),
    slotFilled=Color3.fromRGB(40,28,65),
    tierBadge={Color3.fromRGB(90,200,90),Color3.fromRGB(60,160,255),
               Color3.fromRGB(200,100,255),Color3.fromRGB(255,180,40),
               Color3.fromRGB(255,60,60)},
}

type UpgradeReq = { gold:number, level:number, magicTier:number, materials:{{name:string,qty:number}} }
local UPGRADE_REQS: {[number]:UpgradeReq} = {
    [2]={gold=5000,  level=10,magicTier=1,materials={{name="RuneStone",qty=5},{name="DarkWood",qty=20}}},
    [3]={gold=25000, level=25,magicTier=3,materials={{name="RuneStone",qty=20},{name="SoulCrystal",qty=10}}},
    [4]={gold=100000,level=40,magicTier=5,materials={{name="VoidEssence",qty=15},{name="SoulCrystal",qty=30}}},
    [5]={gold=500000,level=55,magicTier=8,materials={{name="VoidEssence",qty=50},{name="OverlordCrest",qty=1}}},
}

type RoomInfo = {displayName:string,minTier:number,icon:string}
local ROOM_INFO: {[string]:RoomInfo} = {
    Entrance={displayName="Entrance Hall",minTier=1,icon="🚪"},
    BasicChamber={displayName="Basic Chamber",minTier=1,icon="🏛️"},
    GuardianBarracks={displayName="Guardian Barracks",minTier=2,icon="⚔️"},
    ArcaneStudy={displayName="Arcane Study",minTier=2,icon="📚"},
    LichStudy={displayName="Lich Study",minTier=3,icon="💀"},
    CraftingForge={displayName="Crafting Forge",minTier=3,icon="🔨"},
    TreasureVault_T1={displayName="Treasure Vault I",minTier=3,icon="💰"},
    ThroneRoom={displayName="Throne Room",minTier=4,icon="♛"},
    PvPArena={displayName="PvP Arena",minTier=4,icon="🏟️"},
    TreasureVault_T2={displayName="Treasure Vault II",minTier=4,icon="💎"},
    ArcaneLibrary={displayName="Arcane Library",minTier=4,icon="🔮"},
    GuardianSanctum={displayName="Guardian Sanctum",minTier=4,icon="🌀"},
    NazarickThrone={displayName="Nazarick Throne",minTier=5,icon="👑"},
    FloorGuardianHall={displayName="Floor Guardian Hall",minTier=5,icon="🛡️"},
    TreasureVault_T3={displayName="Treasure Vault III",minTier=5,icon="🏆"},
    ArcaneLibrary_Grand={displayName="Grand Arcane Library",minTier=5,icon="⭐"},
    GuildPortal={displayName="Guild Portal",minTier=5,icon="🌐"},
    OverlordSanctum={displayName="Overlord Sanctum",minTier=5,icon="☠️"},
}
local ROOM_ORDER={"Entrance","BasicChamber","GuardianBarracks","ArcaneStudy","LichStudy","CraftingForge","TreasureVault_T1","ThroneRoom","PvPArena","TreasureVault_T2","ArcaneLibrary","GuardianSanctum","NazarickThrone","FloorGuardianHall","TreasureVault_T3","ArcaneLibrary_Grand","GuildPortal","OverlordSanctum"}
local TIER_NAMES={"Haunted Crypt","Bone Keep","Shadow Fortress","Void Citadel","Nazarick Stronghold"}
local TIER_DESCS={"Basic undead tomb. 2 rooms, 2 guardian slots.","Expanded crypt. Guardian Barracks unlocked. Up to 4 guardians.","Shadow magic seeps the walls. LichStudy and CraftingForge available.","Void energies tear through reality. Throne Room and PvP Arena unlocked.","The supreme undead stronghold. All rooms unlocked. Nazarick Floor Guardian available."}
local ROMAN={"I","II","III","IV","V"}
local MAX_GUARDIAN_SLOTS = 8

type SlotState = {guardianId:string?,occupied:boolean}
local uiState = {open=false,activeTab="guardians",tombTier=1,playerLevel=1,playerMagicTier=1,playerGold=0,slots={} :: {[number]:SlotState},selectedSlot=0,hireSelectedId="",materials={} :: {[string]:number}}
for i=1,MAX_GUARDIAN_SLOTS do uiState.slots[i]={guardianId=nil,occupied=false} end

local function tierColor(t) return C.tierBadge[math.clamp(t,1,#C.tierBadge)] end
local function corner(r,p) local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,r);c.Parent=p end
local function makeLabel(parent,text,size,pos,ts,col,bold)
    local l=Instance.new("TextLabel");l.Size=size;l.Position=pos;l.BackgroundTransparency=1
    l.Text=text;l.TextColor3=col or C.text;l.Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham
    l.TextSize=ts;l.TextXAlignment=Enum.TextXAlignment.Left;l.TextWrapped=true;l.Parent=parent;return l
end
local function makeButton(parent,text,size,pos,bg,ts)
    local b=Instance.new("TextButton");b.Size=size;b.Position=pos;b.BackgroundColor3=bg
    b.BorderSizePixel=0;b.Text=text;b.TextColor3=Color3.fromRGB(255,255,255)
    b.Font=Enum.Font.GothamBold;b.TextSize=ts or 14;b.AutoButtonColor=false;b.Parent=parent;corner(6,b)
    b.MouseEnter:Connect(function() TweenService:Create(b,TweenInfo.new(0.12),{BackgroundColor3=bg:Lerp(Color3.fromRGB(255,255,255),0.12)}):Play() end)
    b.MouseLeave:Connect(function() TweenService:Create(b,TweenInfo.new(0.12),{BackgroundColor3=bg}):Play() end)
    return b
end
local function makeScroll(parent,size,pos)
    local sf=Instance.new("ScrollingFrame");sf.Size=size;sf.Position=pos;sf.BackgroundTransparency=1
    sf.BorderSizePixel=0;sf.ScrollBarThickness=4;sf.ScrollBarImageColor3=C.accent
    sf.CanvasSize=UDim2.new(0,0,0,0);sf.AutomaticCanvasSize=Enum.AutomaticSize.Y;sf.Parent=parent
    local l=Instance.new("UIListLayout");l.Padding=UDim.new(0,6);l.SortOrder=Enum.SortOrder.LayoutOrder;l.Parent=sf
    return sf
end

-- Screen GUI
local screenGui=Instance.new("ScreenGui");screenGui.Name="TombManagementUI";screenGui.ResetOnSpawn=false;screenGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;screenGui.Enabled=false;screenGui.Parent=playerGui

local panel=Instance.new("Frame");panel.Name="Panel";panel.Size=UDim2.new(0,680,0,540);panel.Position=UDim2.new(0.5,-340,0.5,-270);panel.BackgroundColor3=C.bg;panel.BorderSizePixel=0;panel.Parent=screenGui;corner(12,panel)
do local s=Instance.new("UIStroke");s.Color=C.accent;s.Thickness=1.5;s.Transparency=0.4;s.Parent=panel end
do local g=Instance.new("UIGradient");g.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(28,18,48)),ColorSequenceKeypoint.new(1,Color3.fromRGB(12,10,20))});g.Rotation=135;g.Parent=panel end

local header=Instance.new("Frame");header.Size=UDim2.new(1,0,0,50);header.BackgroundColor3=C.header;header.BorderSizePixel=0;header.Parent=panel;corner(12,header)
local hCover=Instance.new("Frame");hCover.Size=UDim2.new(1,0,0,12);hCover.Position=UDim2.new(0,0,1,-12);hCover.BackgroundColor3=C.header;hCover.BorderSizePixel=0;hCover.Parent=header
makeLabel(header,"♛  Tomb Management",UDim2.new(1,-60,1,0),UDim2.new(0,16,0,0),18,C.gold,true)

local tierBadge=Instance.new("Frame");tierBadge.Size=UDim2.new(0,80,0,26);tierBadge.Position=UDim2.new(1,-170,0.5,-13);tierBadge.BackgroundColor3=tierColor(1);tierBadge.BorderSizePixel=0;tierBadge.Parent=header;corner(6,tierBadge)
local tierBadgeLabel=Instance.new("TextLabel");tierBadgeLabel.Size=UDim2.new(1,0,1,0);tierBadgeLabel.BackgroundTransparency=1;tierBadgeLabel.Text="Tier I";tierBadgeLabel.TextColor3=Color3.fromRGB(20,10,10);tierBadgeLabel.Font=Enum.Font.GothamBold;tierBadgeLabel.TextSize=13;tierBadgeLabel.Parent=tierBadge

local closeBtn=makeButton(header,"✕",UDim2.new(0,32,0,32),UDim2.new(1,-44,0.5,-16),Color3.fromRGB(120,40,40),16)

local tabBar=Instance.new("Frame");tabBar.Size=UDim2.new(1,-24,0,36);tabBar.Position=UDim2.new(0,12,0,56);tabBar.BackgroundColor3=C.panel;tabBar.BorderSizePixel=0;tabBar.Parent=panel;corner(8,tabBar)
local tabList=Instance.new("UIListLayout");tabList.FillDirection=Enum.FillDirection.Horizontal;tabList.Padding=UDim.new(0,4);tabList.VerticalAlignment=Enum.VerticalAlignment.Center;tabList.Parent=tabBar
local tabPad=Instance.new("UIPadding");tabPad.PaddingLeft=UDim.new(0,4);tabPad.Parent=tabBar

local contentArea=Instance.new("Frame");contentArea.Name="Content";contentArea.Size=UDim2.new(1,-24,1,-110);contentArea.Position=UDim2.new(0,12,0,100);contentArea.BackgroundColor3=C.panel;contentArea.BorderSizePixel=0;contentArea.ClipsDescendants=true;contentArea.Parent=panel;corner(8,contentArea)

local TAB_DEFS={{id="guardians",label="⚔️ Guardians"},{id="hire",label="➕ Hire"},{id="upgrade",label="⬆ Upgrade"},{id="rooms",label="🏛 Rooms"}}
local tabButtons: {[string]:TextButton} = {}
local function updateTabHighlights(activeId)
    for id,btn in pairs(tabButtons) do
        if id==activeId then btn.BackgroundColor3=C.accent;btn.TextColor3=Color3.fromRGB(255,255,255)
        else btn.BackgroundColor3=C.panel;btn.TextColor3=C.textDim end
    end
end
for _,def in ipairs(TAB_DEFS) do
    local btn=Instance.new("TextButton");btn.Name="Tab_"..def.id;btn.Size=UDim2.new(0,140,0,28)
    btn.BackgroundColor3=C.panel;btn.BorderSizePixel=0;btn.Text=def.label;btn.TextColor3=C.textDim
    btn.Font=Enum.Font.GothamBold;btn.TextSize=13;btn.AutoButtonColor=false;btn.Parent=tabBar;corner(6,btn)
    tabButtons[def.id]=btn
end

local pages: {[string]:Frame} = {}
local function makePage(id)
    local f=Instance.new("Frame");f.Name="Page_"..id;f.Size=UDim2.new(1,0,1,0);f.BackgroundTransparency=1;f.Visible=false;f.Parent=contentArea;pages[id]=f;return f
end

-- GUARDIANS PAGE
local guardianPage=makePage("guardians")
local slotGrid=Instance.new("Frame");slotGrid.Size=UDim2.new(1,-16,0,260);slotGrid.Position=UDim2.new(0,8,0,8);slotGrid.BackgroundTransparency=1;slotGrid.Parent=guardianPage
local sgl=Instance.new("UIGridLayout");sgl.CellSize=UDim2.new(0,140,0,110);sgl.CellPadding=UDim2.new(0,8,0,8);sgl.SortOrder=Enum.SortOrder.LayoutOrder;sgl.Parent=slotGrid
local detailPane=Instance.new("Frame");detailPane.Size=UDim2.new(1,-16,0,120);detailPane.Position=UDim2.new(0,8,0,276);detailPane.BackgroundColor3=C.bg;detailPane.BorderSizePixel=0;detailPane.Parent=guardianPage;corner(8,detailPane)
local detailIcon=makeLabel(detailPane,"❓",UDim2.new(0,60,1,-16),UDim2.new(0,8,0,8),40,C.text,false);detailIcon.TextXAlignment=Enum.TextXAlignment.Center
local detailName=makeLabel(detailPane,"Select a slot",UDim2.new(1,-90,0,24),UDim2.new(0,76,0,10),16,C.text,true)
local detailDesc=makeLabel(detailPane,"",UDim2.new(1,-90,0,40),UDim2.new(0,76,0,34),12,C.textDim,false)
local detailStats=makeLabel(detailPane,"",UDim2.new(1,-90,0,30),UDim2.new(0,76,0,76),11,C.gold,false)
local hireSlotBtn=makeButton(detailPane,"➕ Hire",UDim2.new(0,100,0,28),UDim2.new(1,-214,1,-36),C.accentDark,13)
local fireBtn=makeButton(detailPane,"🔥 Fire",UDim2.new(0,100,0,28),UDim2.new(1,-108,1,-36),Color3.fromRGB(140,40,40),13)

local slotFrames: {Frame} = {}

local function refreshSlotVisual(i)
    local frame=slotFrames[i];if not frame then return end
    local st=uiState.slots[i];local def=st.guardianId and GuardianConfig.Get(st.guardianId)
    local iconL=frame:FindFirstChild("Icon") :: TextLabel?
    local nameL=frame:FindFirstChild("GName") :: TextLabel?
    local tierL=frame:FindFirstChild("Tier") :: TextLabel?
    if def and iconL and nameL and tierL then
        frame.BackgroundColor3=C.slotFilled;iconL.Text=def.icon;nameL.Text=def.displayName
        tierL.Text="Tier "..def.minTombTier;tierL.TextColor3=tierColor(def.minTombTier)
    else
        frame.BackgroundColor3=C.slotEmpty
        if iconL then iconL.Text="+" end
        if nameL then nameL.Text="Empty Slot" end
        if tierL then tierL.Text="" end
    end
    local stroke=frame:FindFirstChildOfClass("UIStroke")
    if stroke then
        if i==uiState.selectedSlot then stroke.Color=C.gold;stroke.Transparency=0;stroke.Thickness=2
        else stroke.Color=C.accent;stroke.Transparency=0.7;stroke.Thickness=1 end
    end
end

local function updateDetailPane()
    local idx=uiState.selectedSlot
    if idx==0 then detailIcon.Text="❓";detailName.Text="Select a slot";detailDesc.Text="";detailStats.Text="";hireSlotBtn.Visible=false;fireBtn.Visible=false;return end
    local st=uiState.slots[idx];local def=st.guardianId and GuardianConfig.Get(st.guardianId)
    if def then
        detailIcon.Text=def.icon;detailName.Text=def.displayName;detailDesc.Text=def.description
        detailStats.Text=string.format("HP: %d  |  DMG: %d  |  Upkeep: %d g/week",
            GuardianConfig.GetScaledHealth(def.guardianId,uiState.tombTier),
            GuardianConfig.GetScaledDamage(def.guardianId,uiState.tombTier),def.weeklyUpkeep)
        hireSlotBtn.Visible=false;fireBtn.Visible=true
    else
        detailIcon.Text="+";detailName.Text=string.format("Slot %d — Empty",idx)
        detailDesc.Text="Hire a guardian to protect this slot.";detailStats.Text=""
        hireSlotBtn.Visible=true;fireBtn.Visible=false
    end
end

for i=1,MAX_GUARDIAN_SLOTS do
    local frame=Instance.new("Frame");frame.Name="Slot_"..i;frame.LayoutOrder=i
    frame.BackgroundColor3=C.slotEmpty;frame.BorderSizePixel=0;frame.Parent=slotGrid;corner(8,frame)
    local stroke=Instance.new("UIStroke");stroke.Color=C.accent;stroke.Transparency=0.7;stroke.Thickness=1;stroke.Parent=frame
    local nb=Instance.new("TextLabel");nb.Size=UDim2.new(0,22,0,18);nb.Position=UDim2.new(0,4,0,4);nb.BackgroundColor3=C.accentDark;nb.BorderSizePixel=0;nb.Text=tostring(i);nb.TextColor3=Color3.fromRGB(200,170,255);nb.Font=Enum.Font.GothamBold;nb.TextSize=11;nb.BackgroundTransparency=0.3;nb.Parent=frame;corner(4,nb)
    local icon=Instance.new("TextLabel");icon.Name="Icon";icon.Size=UDim2.new(1,0,0,50);icon.Position=UDim2.new(0,0,0,22);icon.BackgroundTransparency=1;icon.Text="+";icon.TextColor3=C.textDim;icon.Font=Enum.Font.GothamBold;icon.TextSize=30;icon.Parent=frame
    local gname=Instance.new("TextLabel");gname.Name="GName";gname.Size=UDim2.new(1,-4,0,18);gname.Position=UDim2.new(0,2,0,73);gname.BackgroundTransparency=1;gname.Text="Empty Slot";gname.TextColor3=C.textDim;gname.Font=Enum.Font.Gotham;gname.TextSize=10;gname.TextTruncate=Enum.TextTruncate.AtEnd;gname.Parent=frame
    local tierL=Instance.new("TextLabel");tierL.Name="Tier";tierL.Size=UDim2.new(1,-4,0,14);tierL.Position=UDim2.new(0,2,0,92);tierL.BackgroundTransparency=1;tierL.Text="";tierL.Font=Enum.Font.GothamBold;tierL.TextSize=10;tierL.Parent=frame
    slotFrames[i]=frame
    local ci=i
    local btn=Instance.new("TextButton");btn.Size=UDim2.new(1,0,1,0);btn.BackgroundTransparency=1;btn.Text="";btn.ZIndex=3;btn.Parent=frame
    btn.MouseButton1Click:Connect(function() uiState.selectedSlot=ci;for j=1,MAX_GUARDIAN_SLOTS do refreshSlotVisual(j) end;updateDetailPane() end)
end

hireSlotBtn.MouseButton1Click:Connect(function()
    uiState.activeTab="hire"
    for _,d in ipairs(TAB_DEFS) do if pages[d.id] then pages[d.id].Visible=(d.id=="hire") end end
    updateTabHighlights("hire")
end)
fireBtn.MouseButton1Click:Connect(function()
    local idx=uiState.selectedSlot;if idx==0 or not uiState.slots[idx].occupied then return end
    GuardianRemotes.GetEvent("FireGuardian"):FireServer({slotIndex=idx})
    uiState.slots[idx]={guardianId=nil,occupied=false}
    for j=1,MAX_GUARDIAN_SLOTS do refreshSlotVisual(j) end;updateDetailPane()
end)

-- HIRE PAGE
local hirePage=makePage("hire")
local hireTitle=makeLabel(hirePage,"Available Guardians — Tomb Tier "..uiState.tombTier,UDim2.new(1,-16,0,22),UDim2.new(0,8,0,6),14,C.gold,true)
local hireScroll=makeScroll(hirePage,UDim2.new(1,-16,1,-40),UDim2.new(0,8,0,32))

local function refreshHirePage()
    for _,c in ipairs(hireScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    hireTitle.Text="Available Guardians — Tomb Tier "..uiState.tombTier
    for _,def in ipairs(GuardianConfig.GetAvailableForTier(uiState.tombTier)) do
        local row=Instance.new("Frame");row.Size=UDim2.new(1,-8,0,80);row.BackgroundColor3=C.bg;row.BorderSizePixel=0;row.LayoutOrder=def.minTombTier*100;row.Parent=hireScroll;corner(8,row)
        local iconL=Instance.new("TextLabel");iconL.Size=UDim2.new(0,56,1,-12);iconL.Position=UDim2.new(0,8,0,6);iconL.BackgroundTransparency=1;iconL.Text=def.icon;iconL.TextSize=32;iconL.Font=Enum.Font.GothamBold;iconL.Parent=row
        makeLabel(row,def.displayName,UDim2.new(1,-190,0,20),UDim2.new(0,68,0,6),14,C.text,true)
        makeLabel(row,def.description,UDim2.new(1,-190,0,26),UDim2.new(0,68,0,48),11,C.textDim,false)
        makeLabel(row,string.format("💰 %d g",def.hireCost),UDim2.new(0,110,0,20),UDim2.new(1,-118,0,8),13,C.gold,true)
        local canAfford=uiState.playerGold>=def.hireCost
        local hBtn=makeButton(row,"➕ Hire",UDim2.new(0,100,0,28),UDim2.new(1,-108,0.5,-14),canAfford and C.accent or Color3.fromRGB(60,50,80),13)
        if not canAfford then hBtn.TextColor3=C.textDim end
        local capturedDef=def
        hBtn.MouseButton1Click:Connect(function()
            if uiState.playerGold<capturedDef.hireCost then return end
            local targetSlot=0
            if uiState.selectedSlot>0 and not uiState.slots[uiState.selectedSlot].occupied then targetSlot=uiState.selectedSlot
            else for i=1,MAX_GUARDIAN_SLOTS do if not uiState.slots[i].occupied then targetSlot=i;break end end end
            if targetSlot==0 then TweenService:Create(hBtn,TweenInfo.new(0.1),{BackgroundColor3=C.red}):Play();task.delay(0.3,function() TweenService:Create(hBtn,TweenInfo.new(0.1),{BackgroundColor3=C.accentDark}):Play() end);return end
            GuardianRemotes.GetEvent("HireGuardian"):FireServer({guardianId=capturedDef.guardianId,slotIndex=targetSlot})
            uiState.slots[targetSlot]={guardianId=capturedDef.guardianId,occupied=true}
            for j=1,MAX_GUARDIAN_SLOTS do refreshSlotVisual(j) end;updateDetailPane()
        end)
    end
end

-- UPGRADE PAGE
local upgradePage=makePage("upgrade")
makeLabel(upgradePage,"Current Tomb Tier",UDim2.new(1,-16,0,20),UDim2.new(0,8,0,8),13,C.textDim,false)
local tierDisplay=Instance.new("Frame");tierDisplay.Size=UDim2.new(1,-16,0,60);tierDisplay.Position=UDim2.new(0,8,0,28);tierDisplay.BackgroundColor3=C.bg;tierDisplay.BorderSizePixel=0;tierDisplay.Parent=upgradePage;corner(8,tierDisplay)
local tierNumLabel=makeLabel(tierDisplay,"I",UDim2.new(0,70,1,0),UDim2.new(0,0,0,0),40,C.gold,true);tierNumLabel.Name="TierNum";tierNumLabel.TextXAlignment=Enum.TextXAlignment.Center
local tierNameLabel=makeLabel(tierDisplay,"Haunted Crypt",UDim2.new(1,-80,0,28),UDim2.new(0,76,0,6),18,C.text,true);tierNameLabel.Name="TierName"
local tierDescLabel=makeLabel(tierDisplay,"Basic undead tomb.",UDim2.new(1,-80,0,22),UDim2.new(0,76,0,34),11,C.textDim,false);tierDescLabel.Name="TierDesc"
local sep=Instance.new("Frame");sep.Size=UDim2.new(0.9,0,0,1);sep.Position=UDim2.new(0.05,0,0,96);sep.BackgroundColor3=Color3.fromRGB(60,48,80);sep.BorderSizePixel=0;sep.Parent=upgradePage
local reqTitle=makeLabel(upgradePage,"Requirements for Tier II",UDim2.new(1,-16,0,20),UDim2.new(0,8,0,104),13,C.accent,true);reqTitle.Name="ReqTitle"
local reqScroll=makeScroll(upgradePage,UDim2.new(1,-16,0,230),UDim2.new(0,8,0,126))
local upgradeBtn=makeButton(upgradePage,"⬆  Upgrade Tomb",UDim2.new(0,200,0,36),UDim2.new(0.5,-100,1,-46),C.accentDark,15)

local function makeReqRow(label,met,haveStr,needStr)
    local row=Instance.new("Frame");row.Size=UDim2.new(1,-8,0,36);row.BackgroundColor3=met and Color3.fromRGB(20,40,20) or Color3.fromRGB(40,20,20);row.BorderSizePixel=0;corner(6,row)
    local chk=makeLabel(row,met and "✓" or "✗",UDim2.new(0,26,1,0),UDim2.new(0,6,0,0),18,met and C.green or C.red,true);chk.TextXAlignment=Enum.TextXAlignment.Center
    makeLabel(row,label,UDim2.new(1,-200,1,0),UDim2.new(0,36,0,0),13,C.text,false)
    local prog=makeLabel(row,haveStr.." / "..needStr,UDim2.new(0,120,1,0),UDim2.new(1,-126,0,0),12,met and C.green or C.orange,true);prog.TextXAlignment=Enum.TextXAlignment.Right
    return row
end

local function refreshUpgradePage()
    local tier=uiState.tombTier
    tierNumLabel.Text=ROMAN[tier] or tostring(tier);tierNameLabel.Text=TIER_NAMES[tier] or ("Tier "..tier);tierDescLabel.Text=TIER_DESCS[tier] or ""
    tierBadgeLabel.Text="Tier "..(ROMAN[tier] or tostring(tier));tierBadge.BackgroundColor3=tierColor(tier)
    for _,c in ipairs(reqScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    local nextTier=tier+1;local req=UPGRADE_REQS[nextTier]
    if not req then reqTitle.Text="Maximum Tier Reached  👑";upgradeBtn.Visible=false;return end
    reqTitle.Text="Requirements for Tier "..(ROMAN[nextTier] or tostring(nextTier));upgradeBtn.Visible=true
    local allMet=true
    local function addRow(l,met,h,n) if not met then allMet=false end makeReqRow(l,met,h,n).Parent=reqScroll end
    addRow("Gold",uiState.playerGold>=req.gold,tostring(uiState.playerGold),tostring(req.gold))
    addRow("Player Level",uiState.playerLevel>=req.level,tostring(uiState.playerLevel),tostring(req.level))
    addRow("Magic Tier",uiState.playerMagicTier>=req.magicTier,tostring(uiState.playerMagicTier),tostring(req.magicTier))
    for _,mat in ipairs(req.materials) do
        local have=uiState.materials[mat.name] or 0
        addRow(mat.name,have>=mat.qty,tostring(have),tostring(mat.qty))
    end
    upgradeBtn.BackgroundColor3=allMet and C.accent or C.accentDark
    upgradeBtn.TextColor3=allMet and Color3.fromRGB(255,255,255) or C.textDim
end

upgradeBtn.MouseButton1Click:Connect(function()
    pcall(function() GuardianRemotes.GetEvent("TombUpgrade"):FireServer() end)
end)

-- ROOMS PAGE
local roomsPage=makePage("rooms")
makeLabel(roomsPage,"Tomb Rooms",UDim2.new(1,-16,0,22),UDim2.new(0,8,0,4),15,C.gold,true)
local roomScroll=makeScroll(roomsPage,UDim2.new(1,-16,1,-36),UDim2.new(0,8,0,30))

local function refreshRoomsPage()
    for _,c in ipairs(roomScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    for idx,roomId in ipairs(ROOM_ORDER) do
        local info=ROOM_INFO[roomId];if not info then continue end
        local unlocked=info.minTier<=uiState.tombTier
        local row=Instance.new("Frame");row.Name="Room_"..roomId;row.LayoutOrder=idx;row.Size=UDim2.new(1,-8,0,52)
        row.BackgroundColor3=unlocked and C.slotFilled or C.slotEmpty;row.BorderSizePixel=0;row.Parent=roomScroll;corner(8,row)
        if unlocked then local s=Instance.new("UIStroke");s.Color=C.accent;s.Transparency=0.6;s.Thickness=1;s.Parent=row end
        local iconL=makeLabel(row,info.icon,UDim2.new(0,46,1,0),UDim2.new(0,4,0,0),26,unlocked and C.text or C.textDim,false);iconL.TextXAlignment=Enum.TextXAlignment.Center
        makeLabel(row,info.displayName,UDim2.new(1,-140,0,22),UDim2.new(0,52,0,6),13,unlocked and C.text or C.textDim,true)
        if unlocked then makeLabel(row,"✓ Unlocked",UDim2.new(0,100,0,18),UDim2.new(1,-108,0,16),12,C.green,true)
        else makeLabel(row,"🔒 Requires Tier "..info.minTier,UDim2.new(0,130,0,18),UDim2.new(1,-138,0,16),12,C.orange,false) end
    end
end

-- TAB SWITCHING
local function switchTab(id)
    uiState.activeTab=id
    for _,d in ipairs(TAB_DEFS) do pages[d.id].Visible=(d.id==id) end
    updateTabHighlights(id)
    if id=="hire" then refreshHirePage() end
    if id=="upgrade" then refreshUpgradePage() end
    if id=="rooms" then refreshRoomsPage() end
    if id=="guardians" then for j=1,MAX_GUARDIAN_SLOTS do refreshSlotVisual(j) end;updateDetailPane() end
end
for _,d in ipairs(TAB_DEFS) do tabButtons[d.id].MouseButton1Click:Connect(function() switchTab(d.id) end) end
closeBtn.MouseButton1Click:Connect(function() TombManagementUI.Close() end)

-- PORTAL HUD
local portalHUD=Instance.new("Frame");portalHUD.Size=UDim2.new(0,260,0,44);portalHUD.Position=UDim2.new(0,12,1,-56);portalHUD.BackgroundTransparency=1;portalHUD.Parent=screenGui
local enterBtn=makeButton(portalHUD,"🌀 Enter Tomb",UDim2.new(0,130,0,36),UDim2.new(0,0,0,4),C.accentDark,13)
local exitBtn=makeButton(portalHUD,"← Exit Tomb",UDim2.new(0,110,0,36),UDim2.new(0,138,0,4),Color3.fromRGB(60,50,80),13)
enterBtn.MouseButton1Click:Connect(function() GuardianRemotes.GetEvent("EnterTomb"):FireServer({}) end)
exitBtn.MouseButton1Click:Connect(function() GuardianRemotes.GetEvent("ExitTomb"):FireServer({}) end)

-- MODULE API
local TombManagementUI = {}

function TombManagementUI.Open()
    if uiState.open then return end;uiState.open=true;screenGui.Enabled=true;switchTab("guardians")
    panel.Position=UDim2.new(0.5,-340,0.6,-270);panel.BackgroundTransparency=1
    TweenService:Create(panel,TweenInfo.new(0.25,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Position=UDim2.new(0.5,-340,0.5,-270),BackgroundTransparency=0}):Play()
end
function TombManagementUI.Close()
    if not uiState.open then return end;uiState.open=false
    TweenService:Create(panel,TweenInfo.new(0.2,Enum.EasingStyle.Quart,Enum.EasingDirection.In),{Position=UDim2.new(0.5,-340,0.6,-270),BackgroundTransparency=1}):Play()
    task.delay(0.22,function() screenGui.Enabled=false end)
end
function TombManagementUI.SetTombTier(tier) uiState.tombTier=tier;refreshUpgradePage();refreshRoomsPage();refreshHirePage();for j=1,MAX_GUARDIAN_SLOTS do refreshSlotVisual(j) end end
function TombManagementUI.SetPlayerStats(stats)
    if stats.level      then uiState.playerLevel=stats.level end
    if stats.magicTier  then uiState.playerMagicTier=stats.magicTier end
    if stats.gold       then uiState.playerGold=stats.gold end
    if stats.materials  then uiState.materials=stats.materials end
    if uiState.activeTab=="upgrade" then refreshUpgradePage() end
end
function TombManagementUI.OnGuardianHired(slotIndex,guardianId)
    uiState.slots[slotIndex]={guardianId=guardianId,occupied=true}
    if uiState.activeTab=="guardians" then refreshSlotVisual(slotIndex);updateDetailPane() end
end
function TombManagementUI.OnGuardianFired(slotIndex)
    uiState.slots[slotIndex]={guardianId=nil,occupied=false}
    if uiState.activeTab=="guardians" then refreshSlotVisual(slotIndex);updateDetailPane() end
end
function TombManagementUI.AlertSlot(slotIndex)
    local frame=slotFrames[slotIndex];if not frame then return end
    local stroke=frame:FindFirstChildOfClass("UIStroke")
    if stroke then TweenService:Create(stroke,TweenInfo.new(0.15),{Color=C.red}):Play();task.delay(1.5,function() TweenService:Create(stroke,TweenInfo.new(0.3),{Color=C.accent}):Play() end) end
end

task.spawn(function()
    GuardianRemotes.GetEvent("GuardianStatusUpdate").OnClientEvent:Connect(function(p)
        if not p then return end
        if p.action=="hired" and p.guardianId then TombManagementUI.OnGuardianHired(p.slotIndex,p.guardianId)
        elseif p.action=="fired" then TombManagementUI.OnGuardianFired(p.slotIndex)
        elseif p.action=="defeated" or p.action=="alert" then TombManagementUI.AlertSlot(p.slotIndex) end
    end)
    GuardianRemotes.GetEvent("TombEntered").OnClientEvent:Connect(function(p) if p then TombManagementUI.SetTombTier(p.tombTier or 1) end end)
    -- Phase 7 FIX: restore guardian slots from server snapshot on join.
    -- Boot fires GuardianSlotSync immediately after a player loads if they
    -- have any guardians in their TombData. Without this listener the slots
    -- would always appear empty after a rejoin.
    GuardianRemotes.GetEvent("GuardianSlotSync").OnClientEvent:Connect(function(p)
        if type(p) ~= "table" or type(p.slots) ~= "table" then return end
        for slotIndex, slotData in pairs(p.slots) do
            local idx = tonumber(slotIndex)
            if idx and type(slotData) == "table" and slotData.occupied then
                TombManagementUI.OnGuardianHired(idx, slotData.guardianId or "")
            end
        end
    end)
    GuardianRemotes.GetEvent("TombRoomUnlocked").OnClientEvent:Connect(function(p)
        if not p then return end
        local notif=Instance.new("ScreenGui");notif.Name="RoomUnlockNotif";notif.ResetOnSpawn=false;notif.Parent=playerGui
        local box=Instance.new("Frame");box.Size=UDim2.new(0,340,0,52);box.Position=UDim2.new(0.5,-170,0,80);box.BackgroundColor3=C.header;box.BorderSizePixel=0;box.Parent=notif;corner(8,box)
        local s=Instance.new("UIStroke");s.Color=C.gold;s.Thickness=1.5;s.Parent=box
        makeLabel(box,"🏛️  New Room Unlocked: "..(p.displayName or p.roomId),UDim2.new(1,-16,1,0),UDim2.new(0,8,0,0),14,C.gold,true)
        task.delay(3,function() TweenService:Create(box,TweenInfo.new(0.5),{BackgroundTransparency=1}):Play();task.wait(0.5);notif:Destroy() end)
        if uiState.activeTab=="rooms" then refreshRoomsPage() end
    end)
end)

UserInputService.InputBegan:Connect(function(input,gpe) if gpe then return end if input.KeyCode==Enum.KeyCode.T then if uiState.open then TombManagementUI.Close() else TombManagementUI.Open() end end end)

for j=1,MAX_GUARDIAN_SLOTS do refreshSlotVisual(j) end;updateDetailPane();pages["guardians"].Visible=true;updateTabHighlights("guardians")

return TombManagementUI
