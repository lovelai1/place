-- ================================================================
--  HIGHGARD MAP — All-in-One Plugin
--  Place this Script inside: ServerStorage → right-click → Plugin
--  OR save as a .lua file and load via Plugin Builder.
--
--  Click the "🗺 Build Map" button in the Plugins toolbar.
--  Zones are built sequentially; Studio stays responsive.
-- ================================================================

if not plugin then
    warn("[HighgardPlugin] Must run as a Studio Plugin, not a regular Script.")
    return
end

-- ── Toolbar ──────────────────────────────────────────────────────
local toolbar   = plugin:CreateToolbar("Highgard Map")

local btnBuild  = toolbar:CreateButton(
    "🗺 Build Map",
    "Generate all 7 zones (Zones 1-6 + Environment)",
    "rbxassetid://0"   -- replace with your icon asset id if desired
)
btnBuild.ClickableWhenViewportHidden = true

local btnRebuild = toolbar:CreateButton(
    "✨ Rebuild Map",
    "Clear existing zones and build a fresh full map",
    "rbxassetid://0"
)
btnRebuild.ClickableWhenViewportHidden = true

local btnClear  = toolbar:CreateButton(
    "🗑 Clear Map",
    "Remove all generated zone folders from workspace",
    "rbxassetid://0"
)
btnClear.ClickableWhenViewportHidden = true

-- ── State ────────────────────────────────────────────────────────
local isRunning = false
local forceRebuild = false

local ZONE_FOLDERS = {
    "Highgard_Zone1",
    "EmeraldHaven_Zone2",
    "SunScorch_Zone3",
    "SnowDust_Zone4",
    "GloomWood_Zone5",
    "FensOfDespair_Zone6",
}

local function clearGeneratedMap()
    local removed = 0
    for _, name in ipairs(ZONE_FOLDERS) do
        local f = workspace:FindFirstChild(name)
        if f then f:Destroy(); removed += 1 end
    end

    local lighting = game:GetService("Lighting")
    local toRemove = {"Atmosphere","Sky","ColorCorrectionEffect","BloomEffect","SunRaysEffect","DepthOfFieldEffect"}
    for _, className in ipairs(toRemove) do
        for _, obj in ipairs(lighting:GetChildren()) do
            if obj.ClassName == className then
                obj:Destroy()
            end
        end
    end

    print(string.format("[HighgardPlugin] 🗑 Cleared %d zone folders.", removed))
    return removed
end

-- ── Clear helper ─────────────────────────────────────────────────
btnClear.Click:Connect(function()
    if isRunning then return end
    clearGeneratedMap()
    btnClear:SetActive(false)
end)

-- ════════════════════════════════════════════════════════════════
-- ZONE BUILD FUNCTIONS
-- Each zone is isolated inside its own do...end block so local
-- variables (ORIGIN, C, MAT, folder, helpers) don't conflict.
-- ════════════════════════════════════════════════════════════════

local zoneFunctions = {}


-- ────────────────────────────────────────────────────────────────
zoneFunctions["Zone1_Highgard"] = function()
    print("[HighgardPlugin] 🔨 Building Zone1_Highgard...")
    do
    -- ── ORIGIN (move the whole castle by changing this one CFrame) ──
    local ORIGIN = CFrame.new(0, 50, 0)   -- Y=50 puts it above flat baseplate
    
    -- ── Palette ─────────────────────────────────────────────────────
    local C = {
    	stone        = Color3.fromRGB(148, 142, 135),
    	stoneDark    = Color3.fromRGB(105,  98,  90),
    	stoneLight   = Color3.fromRGB(185, 180, 172),
    	stoneMoss    = Color3.fromRGB( 95, 108,  82),
    	cobble       = Color3.fromRGB(128, 122, 115),
    	cobbleDark   = Color3.fromRGB(100,  95,  88),
    	cliff        = Color3.fromRGB( 88,  80,  70),
    	dirt         = Color3.fromRGB(110,  88,  62),
    	sand         = Color3.fromRGB(210, 175, 105),
    	orangeRoof   = Color3.fromRGB(205,  90,  22),
    	orangeRoofDk = Color3.fromRGB(165,  68,  14),
    	wood         = Color3.fromRGB(128,  82,  38),
    	woodDark     = Color3.fromRGB( 78,  48,  18),
    	woodLight    = Color3.fromRGB(168, 128,  68),
    	canvasBlue   = Color3.fromRGB( 55, 105, 185),
    	canvasTeal   = Color3.fromRGB( 42, 135, 125),
    	canvasYellow = Color3.fromRGB(215, 178,  45),
    	canvasRed    = Color3.fromRGB(175,  50,  38),
    	flagBlue     = Color3.fromRGB( 28,  75, 175),
    	flagRed      = Color3.fromRGB(175,  30,  30),
    	metalDark    = Color3.fromRGB( 55,  55,  60),
    	metalGrey    = Color3.fromRGB( 90,  90,  95),
    	waterBlue    = Color3.fromRGB( 52,  98, 165),
    	grassGreen   = Color3.fromRGB( 78, 118,  58),
    	lanternAmber = Color3.fromRGB(255, 195,  55),
    	ropeColor    = Color3.fromRGB(155, 125,  75),
    	ironChain    = Color3.fromRGB( 60,  62,  68),
    	chainMail    = Color3.fromRGB( 80,  80,  85),
    	glassColor   = Color3.fromRGB(140, 175, 200),
    	crateWood    = Color3.fromRGB(148, 108,  58),
    	barrelDark   = Color3.fromRGB( 92,  60,  28),
    	haybale      = Color3.fromRGB(215, 178,  75),
    	sackColor    = Color3.fromRGB(165, 140,  88),
    	torchFlame   = Color3.fromRGB(255, 130,  20),
    	torchEmber   = Color3.fromRGB(255,  60,   5),
    	npcSkin      = Color3.fromRGB(225, 185, 140),
    	npcArmor     = Color3.fromRGB(100, 100, 110),
    	npcRobe      = Color3.fromRGB( 68,  95, 148),
    	black        = Color3.fromRGB( 20,  18,  15),
    	shadow       = Color3.fromRGB( 35,  32,  28),
    }
    
    local M = Enum.Material
    local MAT = {
    	stone  = M.SmoothPlastic,
    	cobble = M.Cobblestone,
    	wood   = M.Wood,
    	brick  = M.Brick,
    	metal  = M.Metal,
    	glass  = M.Glass,
    	neon   = M.Neon,
    	grass  = M.Grass,
    	slate  = M.Slate,
    	ice    = M.Ice,
    	fabric = M.Fabric,
    	foil   = M.Foil,
    	sand   = M.Sand,
    	plast  = M.SmoothPlastic,
    }
    
    -- ── Root folder ──────────────────────────────────────────────────
    local folder = Instance.new("Folder")
    folder.Name   = "Highgard_Zone1"
    folder.Parent = workspace
    
    -- ── Helper functions ─────────────────────────────────────────────
    
    local function cf(x, y, z) return ORIGIN * CFrame.new(x, y, z) end
    local function cfr(x, y, z, rx, ry, rz) return cf(x,y,z) * CFrame.Angles(rx,ry,rz) end
    
    local function part(name, size, cframe, color, material, transparency)
    	local p = Instance.new("Part")
    	p.Name            = name
    	p.Size            = size
    	p.CFrame          = cframe
    	p.Color           = color or C.stone
    	p.Material        = material or MAT.stone
    	p.Transparency    = transparency or 0
    	p.Anchored        = true
    	p.CastShadow      = true
    	p.TopSurface      = Enum.SurfaceType.Smooth
    	p.BottomSurface   = Enum.SurfaceType.Smooth
    	p.Parent          = folder
    	return p
    end
    
    local function wedgePart(name, size, cframe, color, material)
    	local p = Instance.new("WedgePart")
    	p.Name          = name
    	p.Size          = size
    	p.CFrame        = cframe
    	p.Color         = color or C.stone
    	p.Material      = material or MAT.stone
    	p.Anchored      = true
    	p.TopSurface    = Enum.SurfaceType.Smooth
    	p.BottomSurface = Enum.SurfaceType.Smooth
    	p.Parent        = folder
    	return p
    end
    
    local function cyl(name, height, diam, cframe, color, material, transparency)
    	local p = Instance.new("Part")
    	p.Name          = name
    	p.Shape         = Enum.PartType.Cylinder
    	p.Size          = Vector3.new(height, diam, diam)
    	p.CFrame        = cframe * CFrame.Angles(0, 0, math.pi/2)
    	p.Color         = color or C.stone
    	p.Material      = material or MAT.stone
    	p.Transparency  = transparency or 0
    	p.Anchored      = true
    	p.TopSurface    = Enum.SurfaceType.Smooth
    	p.BottomSurface = Enum.SurfaceType.Smooth
    	p.Parent        = folder
    	return p
    end
    
    local function sphere(name, diam, cframe, color, material, transparency)
    	local p = Instance.new("Part")
    	p.Name          = name
    	p.Shape         = Enum.PartType.Ball
    	p.Size          = Vector3.new(diam, diam, diam)
    	p.CFrame        = cframe
    	p.Color         = color or C.stone
    	p.Material      = material or MAT.stone
    	p.Transparency  = transparency or 0
    	p.Anchored      = true
    	p.Parent        = folder
    	return p
    end
    
    local function coneMesh(name, height, diam, cframe, color, material)
    	local p = Instance.new("Part")
    	p.Name     = name
    	p.Size     = Vector3.new(diam, height, diam)
    	p.CFrame   = cframe
    	p.Color    = color or C.orangeRoof
    	p.Material = material or MAT.plast
    	p.Anchored = true
    	p.TopSurface    = Enum.SurfaceType.Smooth
    	p.BottomSurface = Enum.SurfaceType.Smooth
    	p.Parent   = folder
    	local mesh = Instance.new("SpecialMesh", p)
    	mesh.MeshType = Enum.MeshType.FileMesh
    	mesh.MeshId   = "rbxassetid://1078075"   -- Roblox cone mesh
    	mesh.Scale    = Vector3.new(diam/5, height/5, diam/5)
    	return p
    end
    
    local function addPointLight(parent, color, brightness, range)
    	local l = Instance.new("PointLight", parent)
    	l.Color      = color
    	l.Brightness = brightness or 3
    	l.Range      = range or 18
    	l.Enabled    = true
    end
    
    local function addBillboard(parent, text, size)
    	local bg = Instance.new("BillboardGui", parent)
    	bg.Size       = UDim2.fromOffset(size or 60, 28)
    	bg.StudsOffset = Vector3.new(0, 3, 0)
    	bg.AlwaysOnTop = false
    	local lbl = Instance.new("TextLabel", bg)
    	lbl.Size = UDim2.fromScale(1, 1)
    	lbl.BackgroundTransparency = 1
    	lbl.Text = text
    	lbl.TextColor3 = Color3.new(1, 1, 1)
    	lbl.TextScaled = true
    end
    
    -- ── SECTION 1: CLIFF / MOUND BASE ───────────────────────────────
    -- Irregular rocky mound that the castle sits on
    
    local function cliffLayer(offsetY, sx, sz, col)
    	part("Cliff", Vector3.new(sx, 8, sz), cf(0, offsetY, 0), col, MAT.slate)
    end
    
    cliffLayer(-14, 260, 230, C.cliff)
    cliffLayer(-8,  240, 210, Color3.fromRGB(96, 88, 78))
    cliffLayer(-2,  222, 195, Color3.fromRGB(108, 100, 90))
    
    -- Cliff edge crags (decorative rough boulders)
    local cragPositions = {
    	{-112, -4, -96}, {110, -4, -94}, {-110, -4, 95}, {112, -4, 94},
    	{-100, -6, 0},   {108,  -5, 10}, {0, -5, -98},   {5, -5, 98},
    	{-60, -3, -100},{65, -3, 98},   {-105, -3, -40}, {106, -3, 40},
    }
    for _, c2 in ipairs(cragPositions) do
    	local s = math.random(6, 14)
    	part("Crag", Vector3.new(s, s*0.7, s),
    		cfr(c2[1], c2[2], c2[3], 0, math.random()*math.pi, 0),
    		C.cliff, MAT.slate)
    end
    
    -- Cliff moss patches
    for i = 1, 12 do
    	local angle = (i/12) * 2 * math.pi
    	local r = 108 + math.random(-8, 8)
    	part("MossPatch",
    		Vector3.new(math.random(5,12), 0.5, math.random(5,12)),
    		cfr(math.cos(angle)*r, -2, math.sin(angle)*r, 0, math.random()*math.pi, 0),
    		C.stoneMoss, MAT.grass, 0)
    end
    
    -- ── SECTION 2: GROUND LEVEL ──────────────────────────────────────
    
    local GY = 0   -- ground Y (top surface of mound)
    
    -- Outer courtyard ring (between walls) — cobblestone
    part("OuterCourt",
    	Vector3.new(210, 1, 200),
    	cf(0, GY + 0.5, 0), C.cobble, MAT.cobble)
    
    -- Inner courtyard floor — lighter cobble
    part("InnerCourt",
    	Vector3.new(136, 1, 120),
    	cf(0, GY + 1.0, 0), C.stoneLight, MAT.cobble)
    
    -- Courtyard gutter channels (thin dark lines for realism)
    for _, z in ipairs({-55, 0, 55}) do
    	part("Gutter", Vector3.new(130, 0.4, 0.6), cf(0, GY + 1.5, z), C.stoneDark, MAT.cobble)
    end
    for _, x in ipairs({-60, 0, 60}) do
    	part("Gutter", Vector3.new(0.6, 0.4, 110), cf(x, GY + 1.5, 0), C.stoneDark, MAT.cobble)
    end
    
    -- ── SECTION 3: OUTER WALL (200×180 × height 18, thickness 4) ────
    
    local OW = { hx=100, hz=90, h=18, t=4 }
    
    -- North wall
    part("OW_North", Vector3.new(OW.hx*2 + OW.t*2, OW.h, OW.t),
    	cf(0, GY + OW.h/2, -OW.hz), C.stone, MAT.stone)
    -- South wall — two halves leaving gate gap
    local gateX = -15  -- gate is slightly to the west-center
    local gateW = 14
    part("OW_South_L",
    	Vector3.new((OW.hx + gateX - gateW/2), OW.h, OW.t),
    	cf((-OW.hx + gateX - gateW/2)/2, GY + OW.h/2, OW.hz),
    	C.stone, MAT.stone)
    part("OW_South_R",
    	Vector3.new((OW.hx - gateX - gateW/2), OW.h, OW.t),
    	cf((OW.hx + gateX + gateW/2)/2, GY + OW.h/2, OW.hz),
    	C.stone, MAT.stone)
    -- Wall cap above gate (lintel)
    part("OW_GateLintel",
    	Vector3.new(gateW, OW.h - 14, OW.t),
    	cf(gateX, GY + 14 + (OW.h-14)/2, OW.hz),
    	C.stone, MAT.stone)
    
    -- West wall
    part("OW_West",  Vector3.new(OW.t, OW.h, OW.hz*2),
    	cf(-OW.hx, GY + OW.h/2, 0), C.stone, MAT.stone)
    -- East wall
    part("OW_East",  Vector3.new(OW.t, OW.h, OW.hz*2),
    	cf( OW.hx, GY + OW.h/2, 0), C.stone, MAT.stone)
    
    -- Wall top walkway surface
    part("Walk_North", Vector3.new(OW.hx*2, 1.5, OW.t+2),
    	cf(0, GY + OW.h + 0.75, -OW.hz), C.cobbleDark, MAT.cobble)
    part("Walk_South", Vector3.new(OW.hx*2, 1.5, OW.t+2),
    	cf(gateX/2, GY + OW.h + 0.75, OW.hz), C.cobbleDark, MAT.cobble)
    part("Walk_West",  Vector3.new(OW.t+2, 1.5, OW.hz*2),
    	cf(-OW.hx, GY + OW.h + 0.75, 0), C.cobbleDark, MAT.cobble)
    part("Walk_East",  Vector3.new(OW.t+2, 1.5, OW.hz*2),
    	cf( OW.hx, GY + OW.h + 0.75, 0), C.cobbleDark, MAT.cobble)
    
    -- ── SECTION 4: MERLONS (outer wall) ─────────────────────────────
    
    local MW, MH, MD = 2, 3, 3.5
    local MSTEP = 5
    local mY = GY + OW.h + MH/2 + 1.5  -- sits on walkway
    
    local function merlonRow(axis, fixedVal, rangeMin, rangeMax, facing)
    	for v = rangeMin, rangeMax, MSTEP do
    		local px = axis == "x" and v or fixedVal
    		local pz = axis == "x" and fixedVal or v
    		local sz = axis == "x"
    			and Vector3.new(MW, MH, MD)
    			or  Vector3.new(MD, MH, MW)
    		part("Merlon", sz, cf(px, mY, pz), C.stone, MAT.stone)
    	end
    end
    
    merlonRow("x", -OW.hz - OW.t/2, -OW.hx+2, OW.hx-2)   -- North outer face
    merlonRow("x",  OW.hz + OW.t/2, -OW.hx+2, OW.hx-2)   -- South outer face
    merlonRow("z", -OW.hx - OW.t/2, -OW.hz+2, OW.hz-2)   -- West outer face
    merlonRow("z",  OW.hx + OW.t/2, -OW.hz+2, OW.hz-2)   -- East outer face
    
    -- Inner parapet (crenels face the courtyard)
    local mY2 = GY + OW.h + MH/2 + 1.5
    merlonRow("x", -OW.hz + OW.t/2 + 1, -OW.hx+2, OW.hx-2)
    merlonRow("x",  OW.hz - OW.t/2 - 1, -OW.hx+2, OW.hx-2)
    merlonRow("z", -OW.hx + OW.t/2 + 1, -OW.hz+2, OW.hz-2)
    merlonRow("z",  OW.hx - OW.t/2 - 1, -OW.hz+2, OW.hz-2)
    
    -- ── SECTION 5: WALL TORCHES ──────────────────────────────────────
    
    local function wallTorch(x, z, side)
    	-- bracket
    	part("TorchBracket", Vector3.new(0.4, 0.4, 1.2),
    		cfr(x, GY + OW.h - 3, z, 0, side, 0), C.metalDark, MAT.metal)
    	-- handle
    	part("TorchHandle", Vector3.new(0.4, 2, 0.4),
    		cfr(x, GY + OW.h - 2, z, 0, side, 0), C.wood, MAT.wood)
    	-- flame part
    	local flamePart = part("TorchFlame", Vector3.new(0.6, 0.8, 0.6),
    		cf(x, GY + OW.h - 0.8, z), C.torchFlame, MAT.neon)
    	addPointLight(flamePart, Color3.fromRGB(255, 165, 40), 4, 22)
    	-- ember glow
    	sphere("TorchEmber", 0.4,
    		cf(x, GY + OW.h - 1, z), C.torchEmber, MAT.neon, 0.2)
    end
    
    -- Torches spaced along each wall face
    for t = -80, 80, 25 do
    	wallTorch(t, -OW.hz - 2, 0)
    	wallTorch(t,  OW.hz + 2, 0)
    end
    for t = -70, 70, 25 do
    	wallTorch(-OW.hx - 2, t, math.pi/2)
    	wallTorch( OW.hx + 2, t, math.pi/2)
    end
    
    -- ── SECTION 6: CORNER TOWERS ────────────────────────────────────
    
    local CTH = 30
    local CTD = 15
    
    local corners = {
    	{ x=-OW.hx, z=-OW.hz },
    	{ x= OW.hx, z=-OW.hz },
    	{ x=-OW.hx, z= OW.hz },
    	{ x= OW.hx, z= OW.hz },
    }
    
    for i, cor in ipairs(corners) do
    	-- Tower body
    	cyl("CTower_"..i, CTD, CTD, cf(cor.x, GY + CTH/2, cor.z), C.stone, MAT.stone)
    	-- Tower top ring (slightly wider, like a parapet base)
    	cyl("CTower_Ring_"..i, CTD+3, CTD+3,
    		cf(cor.x, GY + CTH + 0.5, cor.z), C.stoneDark, MAT.stone)
    	-- Battlements ring (8 merlons around circle)
    	for a = 0, 2*math.pi - 0.01, math.pi/4 do
    		local r2 = CTD/2 + 1.5
    		part("CTMerlon", Vector3.new(2.5, MH, 2.5),
    			cfr(cor.x + math.cos(a)*r2, GY + CTH + 2 + MH/2, cor.z + math.sin(a)*r2,
    				0, a, 0),
    			C.stone, MAT.stone)
    	end
    	-- Cone roof
    	coneMesh("CTowerRoof_"..i, 12, CTD+3, cf(cor.x, GY + CTH + 6 + 1.5, cor.z), C.orangeRoof)
    	-- Roof ridge cap (sphere finial)
    	sphere("CTowerFinial_"..i, 2,
    		cf(cor.x, GY + CTH + 12 + 1.5, cor.z), C.orangeRoofDk, MAT.plast)
    	-- Arrow slits (3 per tower at different heights)
    	local slitAngles = { 0, math.pi*2/3, math.pi*4/3 }
    	for _, ang in ipairs(slitAngles) do
    		local sx = cor.x + math.cos(ang) * (CTD/2 + 0.1)
    		local sz = cor.z + math.sin(ang) * (CTD/2 + 0.1)
    		for _, sy in ipairs({ GY+8, GY+16, GY+24 }) do
    			part("TowerSlit", Vector3.new(0.8, 3, 0.4),
    				cfr(sx, sy, sz, 0, ang, 0), C.black, MAT.stone)
    		end
    	end
    	-- Lantern at tower base (exterior)
    	local lx = cor.x + math.sign(cor.x) * (-CTD/2 - 2)
    	local lz = cor.z + math.sign(cor.z) * (-CTD/2 - 2)
    	local lampPost = part("TowerLamp_Post", Vector3.new(0.5, 5, 0.5),
    		cf(lx, GY + 2.5, lz), C.woodDark, MAT.wood)
    	local lampHead = part("TowerLamp", Vector3.new(1.5, 1.5, 1.5),
    		cf(lx, GY + 5.5, lz), C.lanternAmber, MAT.neon)
    	addPointLight(lampHead, Color3.fromRGB(255, 200, 100), 3.5, 20)
    end
    
    -- ── SECTION 7: MID-WALL FLANKING TOWERS ─────────────────────────
    
    local midTowers = {
    	{ x=  0, z=-OW.hz },  -- North
    	{ x=  0, z= OW.hz },  -- South
    	{ x=-OW.hx, z=  0 },  -- West
    	{ x= OW.hx, z=  0 },  -- East
    }
    
    for i, mt in ipairs(midTowers) do
    	local mth = 24
    	local mtd = 12
    	cyl("MidTower_"..i, mtd, mtd, cf(mt.x, GY + mth/2, mt.z), C.stone, MAT.stone)
    	cyl("MidTower_Top_"..i, mtd+2, mtd+2,
    		cf(mt.x, GY + mth + 0.5, mt.z), C.stoneDark, MAT.stone)
    	coneMesh("MidTowerRoof_"..i, 9, mtd+2,
    		cf(mt.x, GY + mth + 4.5 + 0.5, mt.z), C.orangeRoof)
    	sphere("MidTowerFinial_"..i, 1.5,
    		cf(mt.x, GY + mth + 9 + 0.5, mt.z), C.orangeRoofDk, MAT.plast)
    	-- Arrow slits
    	for a = 0, 2*math.pi - 0.01, math.pi/2 do
    		local sx = mt.x + math.cos(a) * (mtd/2 + 0.1)
    		local sz = mt.z + math.sin(a) * (mtd/2 + 0.1)
    		part("MidSlit", Vector3.new(0.8, 2.5, 0.4),
    			cfr(sx, GY + 12, sz, 0, a, 0), C.black, MAT.stone)
    	end
    end
    
    -- ── SECTION 8: WALL STAIRS (access from courtyard to walkway) ────
    
    local stairCases = {
    	{ x= 80, z=  0, rot=math.pi/2  },  -- East stair
    	{ x=-80, z=  0, rot=-math.pi/2 },  -- West stair
    	{ x=  0, z=-78, rot=0          },  -- North stair
    }
    
    for _, sc in ipairs(stairCases) do
    	for step = 0, OW.h-1 do
    		local depth = step * 1.2
    		part("Stair", Vector3.new(5, 1, 1.2),
    			cfr(sc.x + math.sin(sc.rot)*depth,
    				GY + step + 0.5,
    				sc.z + math.cos(sc.rot)*(-depth),
    				0, sc.rot, 0),
    			C.cobble, MAT.cobble)
    	end
    end
    
    -- ── SECTION 9: INNER WALL (citadel ring, h22, t3) ────────────────
    
    local IW = { hx=65, hz=56, h=22, t=3 }
    
    -- North
    part("IW_North", Vector3.new(IW.hx*2 + IW.t*2, IW.h, IW.t),
    	cf(0, GY + IW.h/2, -IW.hz), C.stoneDark, MAT.stone)
    -- South (two halves, inner gate opening)
    local igW = 10
    part("IW_South_L",
    	Vector3.new((IW.hx - igW/2), IW.h, IW.t),
    	cf((-IW.hx - igW/2)/2, GY + IW.h/2, IW.hz), C.stoneDark, MAT.stone)
    part("IW_South_R",
    	Vector3.new((IW.hx - igW/2), IW.h, IW.t),
    	cf((IW.hx + igW/2)/2, GY + IW.h/2, IW.hz), C.stoneDark, MAT.stone)
    part("IW_South_Top",
    	Vector3.new(igW, IW.h - 12, IW.t),
    	cf(0, GY + 12 + (IW.h-12)/2, IW.hz), C.stoneDark, MAT.stone)
    -- East / West
    part("IW_East",  Vector3.new(IW.t, IW.h, IW.hz*2),
    	cf( IW.hx, GY + IW.h/2, 0), C.stoneDark, MAT.stone)
    part("IW_West",  Vector3.new(IW.t, IW.h, IW.hz*2),
    	cf(-IW.hx, GY + IW.h/2, 0), C.stoneDark, MAT.stone)
    
    -- Inner wall walkways
    part("IWalk_N",  Vector3.new(IW.hx*2, 1.5, IW.t+2),
    	cf(0, GY + IW.h + 0.75, -IW.hz), C.cobbleDark, MAT.cobble)
    part("IWalk_S",  Vector3.new(IW.hx*2, 1.5, IW.t+2),
    	cf(0, GY + IW.h + 0.75,  IW.hz), C.cobbleDark, MAT.cobble)
    part("IWalk_E",  Vector3.new(IW.t+2, 1.5, IW.hz*2),
    	cf( IW.hx, GY + IW.h + 0.75, 0), C.cobbleDark, MAT.cobble)
    part("IWalk_W",  Vector3.new(IW.t+2, 1.5, IW.hz*2),
    	cf(-IW.hx, GY + IW.h + 0.75, 0), C.cobbleDark, MAT.cobble)
    
    -- Inner wall merlons
    local imY = GY + IW.h + MH/2 + 1.5
    merlonRow = function(axis, fixedVal, rangeMin, rangeMax)
    	for v = rangeMin, rangeMax, MSTEP do
    		local px = axis == "x" and v or fixedVal
    		local pz = axis == "x" and fixedVal or v
    		local sz = axis == "x"
    			and Vector3.new(MW, MH, MD) or Vector3.new(MD, MH, MW)
    		part("IWMerlon", sz, cf(px, imY, pz), C.stoneDark, MAT.stone)
    	end
    end
    merlonRow("x", -IW.hz - IW.t/2 - 0.5, -IW.hx+2, IW.hx-2)
    merlonRow("x",  IW.hz + IW.t/2 + 0.5, -IW.hx+2, IW.hx-2)
    merlonRow("z", -IW.hx - IW.t/2 - 0.5, -IW.hz+2, IW.hz-2)
    merlonRow("z",  IW.hx + IW.t/2 + 0.5, -IW.hz+2, IW.hz-2)
    
    -- Inner wall corner mini-towers
    local IWcorners = {
    	{-IW.hx, -IW.hz}, { IW.hx, -IW.hz},
    	{-IW.hx,  IW.hz}, { IW.hx,  IW.hz},
    }
    for i, iwc in ipairs(IWcorners) do
    	local iwtH = IW.h + 6
    	local iwtD = 10
    	cyl("IWT_"..i, iwtD, iwtD, cf(iwc[1], GY + iwtH/2, iwc[2]), C.stoneDark, MAT.stone)
    	coneMesh("IWT_Roof_"..i, 8, iwtD+2,
    		cf(iwc[1], GY + iwtH + 4, iwc[2]), C.orangeRoof)
    end
    
    -- ── SECTION 10: MAIN GATEHOUSE (outer wall, south) ───────────────
    
    local GX = gateX
    local GZ = OW.hz
    
    -- Gate platform/bridge
    part("GatePlatform",
    	Vector3.new(gateW + 8, 1.5, 22),
    	cf(GX, GY + 0.75, GZ + 11), C.cobble, MAT.cobble)
    -- Bridge side walls/rails
    part("BridgeRail_L",
    	Vector3.new(gateW + 2, 2, 1),
    	cf(GX - gateW/2 - 3, GY + 1.5, GZ + 11),
    	C.stone, MAT.stone)
    part("BridgeRail_R",
    	Vector3.new(gateW + 2, 2, 1),
    	cf(GX + gateW/2 + 3, GY + 1.5, GZ + 11),
    	C.stone, MAT.stone)
    
    -- Left gate tower
    part("GateTower_L",
    	Vector3.new(9, 28, 11),
    	cf(GX - gateW/2 - 4.5, GY + 14, GZ + 1.5),
    	C.stone, MAT.stone)
    coneMesh("GTRoof_L", 11, 11,
    	cf(GX - gateW/2 - 4.5, GY + 28 + 5.5, GZ + 1.5), C.orangeRoof)
    sphere("GTFinial_L", 1.8,
    	cf(GX - gateW/2 - 4.5, GY + 28 + 11, GZ + 1.5), C.orangeRoofDk, MAT.plast)
    
    -- Right gate tower
    part("GateTower_R",
    	Vector3.new(9, 28, 11),
    	cf(GX + gateW/2 + 4.5, GY + 14, GZ + 1.5),
    	C.stone, MAT.stone)
    coneMesh("GTRoof_R", 11, 11,
    	cf(GX + gateW/2 + 4.5, GY + 28 + 5.5, GZ + 1.5), C.orangeRoof)
    sphere("GTFinial_R", 1.8,
    	cf(GX + gateW/2 + 4.5, GY + 28 + 11, GZ + 1.5), C.orangeRoofDk, MAT.plast)
    
    -- Gate tower arrow slits
    for _, side in ipairs({{GX - gateW/2 - 4.5}, {GX + gateW/2 + 4.5}}) do
    	for h = 8, 24, 8 do
    		part("GTSlit", Vector3.new(0.8, 2.8, 0.4),
    			cf(side[1], GY + h, GZ + OW.t/2 + 0.2), C.black, MAT.stone)
    	end
    end
    
    -- Gate arch sides
    part("GateArch_L",
    	Vector3.new(4.5, 14, OW.t + 3),
    	cf(GX - gateW/2 + 2, GY + 7, GZ), C.stone, MAT.stone)
    part("GateArch_R",
    	Vector3.new(4.5, 14, OW.t + 3),
    	cf(GX + gateW/2 - 2, GY + 7, GZ), C.stone, MAT.stone)
    part("GateArch_Top",
    	Vector3.new(gateW, 5, OW.t + 3),
    	cf(GX, GY + 12, GZ), C.stone, MAT.stone)
    -- Arch keystone
    part("GateKeystone",
    	Vector3.new(3, 2, OW.t + 3.5),
    	cf(GX, GY + 15, GZ), C.stoneLight, MAT.stone)
    
    -- Portcullis (iron gate, visible in archway)
    for xi = -3, 3, 1.5 do
    	part("Portcullis_V",
    		Vector3.new(0.4, 13, 0.4),
    		cf(GX + xi, GY + 6.5, GZ - 0.5), C.metalDark, MAT.metal)
    end
    for yi = 2, 12, 2.5 do
    	part("Portcullis_H",
    		Vector3.new(gateW - 1, 0.4, 0.4),
    		cf(GX, GY + yi, GZ - 0.5), C.metalDark, MAT.metal)
    end
    -- Portcullis spikes at bottom
    for xi = -3, 3, 1.5 do
    	part("Portcullis_Spike",
    		Vector3.new(0.4, 1.5, 0.4),
    		cf(GX + xi, GY + 0.75, GZ - 0.5), C.metalGrey, MAT.metal)
    end
    
    -- Gate chains
    for _, side in ipairs({-4, 4}) do
    	for link = 0, 12 do
    		cyl("Chain", 0.5, 0.5,
    			cf(GX + side, GY + 1 + link * 1.1, GZ - 0.4)
    				* CFrame.Angles(0, 0, (link%2 == 0 and math.pi/2 or 0)),
    			C.ironChain, MAT.metal)
    	end
    end
    
    -- Wooden gate doors (behind portcullis)
    part("GateDoor_L",
    	Vector3.new(gateW/2 - 0.8, 13, 0.9),
    	cfr(GX - gateW/4, GY + 6.5, GZ + 1, 0, 0, 0),
    	C.woodDark, MAT.wood)
    part("GateDoor_R",
    	Vector3.new(gateW/2 - 0.8, 13, 0.9),
    	cfr(GX + gateW/4, GY + 6.5, GZ + 1, 0, 0, 0),
    	C.woodDark, MAT.wood)
    -- Door planks texture strips
    for plank = -2, 2 do
    	part("DoorPlank_L",
    		Vector3.new(gateW/2 - 1.2, 0.6, 1.0),
    		cf(GX - gateW/4, GY + 6.5 + plank * 2.2, GZ + 1.05),
    		C.wood, MAT.wood)
    	part("DoorPlank_R",
    		Vector3.new(gateW/2 - 1.2, 0.6, 1.0),
    		cf(GX + gateW/4, GY + 6.5 + plank * 2.2, GZ + 1.05),
    		C.wood, MAT.wood)
    end
    -- Door iron rivets
    for rix = -1, 1, 0.8 do
    	for riy = -2, 2, 1.5 do
    		sphere("DoorRivet", 0.25,
    			cf(GX - gateW/4 + rix, GY + 6.5 + riy * 2.2, GZ + 1.6),
    			C.metalDark, MAT.metal)
    		sphere("DoorRivet", 0.25,
    			cf(GX + gateW/4 + rix, GY + 6.5 + riy * 2.2, GZ + 1.6),
    			C.metalDark, MAT.metal)
    	end
    end
    
    -- Guard post niches (recesses in gate arch sides)
    for _, side in ipairs({-1, 1}) do
    	part("GuardNiche",
    		Vector3.new(3.5, 6, 1),
    		cf(GX + side * (gateW/2 + 7), GY + 3, GZ + 0.8),
    		C.stoneDark, MAT.stone)
    end
    
    -- Gate lanterns (hanging)
    for _, side in ipairs({-4, 4}) do
    	-- Hanging arm
    	part("LampArm", Vector3.new(0.4, 0.4, 2),
    		cf(GX + side, GY + 14.5, GZ - 1.5), C.metalDark, MAT.metal)
    	local lantern = part("GateLantern", Vector3.new(1.2, 1.8, 1.2),
    		cf(GX + side, GY + 13.5, GZ - 2), C.lanternAmber, MAT.neon)
    	addPointLight(lantern, Color3.fromRGB(255, 195, 80), 4, 24)
    	-- Chain links
    	for link = 0, 3 do
    		cyl("LanternChain", 0.4, 0.4,
    			cf(GX + side, GY + 14.5 - link*0.5, GZ - 1.8),
    			C.ironChain, MAT.metal)
    	end
    end
    
    -- ── SECTION 11: KEEP / DONJON ─────────────────────────────────────
    
    local KX, KZ = 0, -15   -- keep center
    local KW, KD, KH = 32, 27, 38
    
    -- Keep base foundation
    part("Keep_Foundation",
    	Vector3.new(KW + 4, 2, KD + 4),
    	cf(KX, GY + 1, KZ), C.stoneDark, MAT.stone)
    
    -- Main keep body
    part("Keep_Main",
    	Vector3.new(KW, KH, KD),
    	cf(KX, GY + 2 + KH/2, KZ), C.stoneDark, MAT.stone)
    
    -- Stone banding (decorative horizontal bands)
    for band = 8, KH - 4, 8 do
    	part("KeepBand",
    		Vector3.new(KW + 0.4, 0.8, KD + 0.4),
    		cf(KX, GY + 2 + band, KZ), C.stoneLight, MAT.stone)
    end
    
    -- Keep corner buttresses (4 per corner, adds depth)
    for _, cx2 in ipairs({-KW/2, KW/2}) do
    	for _, cz2 in ipairs({-KD/2, KD/2}) do
    		part("Buttress",
    			Vector3.new(4, KH, 4),
    			cf(KX + cx2, GY + 2 + KH/2, KZ + cz2), C.stone, MAT.stone)
    	end
    end
    
    -- Keep main roof (cone)
    coneMesh("Keep_Roof", 16, KW + 4,
    	cf(KX, GY + 2 + KH + 8, KZ), C.orangeRoof)
    -- Roof ridge ring
    cyl("Keep_RoofRing", KW + 4, KW + 4,
    	cf(KX, GY + 2 + KH + 0.5, KZ), C.orangeRoofDk, MAT.plast)
    -- Finial sphere
    sphere("Keep_Finial", 2.5, cf(KX, GY + 2 + KH + 16, KZ), C.orangeRoofDk, MAT.plast)
    
    -- Flag mast
    part("FlagMast", Vector3.new(0.5, 14, 0.5),
    	cf(KX, GY + 2 + KH + 17, KZ), C.wood, MAT.wood)
    -- Flag cloth
    part("Flag", Vector3.new(8, 4, 0.3),
    	cf(KX + 4, GY + 2 + KH + 22, KZ), C.flagBlue, MAT.fabric)
    -- Flag emblem
    part("FlagEmblem", Vector3.new(2.5, 2.5, 0.35),
    	cf(KX + 4, GY + 2 + KH + 22, KZ), C.stoneLight, MAT.plast)
    -- Flag rope lines
    for seg = 0, 5 do
    	cyl("FlagRope", 0.15, 0.15,
    		cf(KX + seg * 0.5, GY + 2 + KH + 20 - seg * 0.3, KZ),
    		C.ropeColor, MAT.plast)
    end
    
    -- Side wings of the keep
    local wingData = {
    	{ dx=-22, dz=0, w=14, d=22, h=28 },
    	{ dx= 22, dz=0, w=14, d=22, h=28 },
    }
    for i, wd in ipairs(wingData) do
    	-- Wing body
    	part("Keep_Wing_"..i,
    		Vector3.new(wd.w, wd.h, wd.d),
    		cf(KX + wd.dx, GY + 2 + wd.h/2, KZ + wd.dz), C.stoneDark, MAT.stone)
    	-- Wing buttresses
    	for _, czw in ipairs({-wd.d/2, wd.d/2}) do
    		part("WingButtress",
    			Vector3.new(wd.w + 2, wd.h, 3.5),
    			cf(KX + wd.dx, GY + 2 + wd.h/2, KZ + wd.dz + czw),
    			C.stone, MAT.stone)
    	end
    	-- Wing roof (lower cone)
    	coneMesh("Keep_WingRoof_"..i, 10, wd.w + 3,
    		cf(KX + wd.dx, GY + 2 + wd.h + 5, KZ + wd.dz), C.orangeRoof)
    	sphere("WingFinial_"..i, 1.8,
    		cf(KX + wd.dx, GY + 2 + wd.h + 10, KZ + wd.dz), C.orangeRoofDk, MAT.plast)
    	-- Connecting arch between wing and main tower
    	part("WingArch",
    		Vector3.new(math.abs(wd.dx) - KW/2 - wd.w/2, 12, 8),
    		cf(KX + wd.dx/2, GY + 2 + 6, KZ), C.stoneDark, MAT.stone)
    end
    
    -- Keep main entrance door arch
    part("KeepDoor_ArchL", Vector3.new(3, 12, 3), cf(KX - 3, GY + 8, KZ + KD/2), C.stone, MAT.stone)
    part("KeepDoor_ArchR", Vector3.new(3, 12, 3), cf(KX + 3, GY + 8, KZ + KD/2), C.stone, MAT.stone)
    part("KeepDoor_ArchTop", Vector3.new(8, 3, 3), cf(KX, GY + 13, KZ + KD/2), C.stone, MAT.stone)
    -- Keep door
    part("KeepDoor",
    	Vector3.new(6, 10, 0.8),
    	cf(KX, GY + 7, KZ + KD/2 + 0.5), C.woodDark, MAT.wood)
    
    -- Keep windows (arrow slits, front & back faces, multiple floors)
    local function keepSlits(side_z, facing)
    	for _, hgt in ipairs({ GY+10, GY+18, GY+26, GY+34 }) do
    		for _, xOff in ipairs({ -10, -3, 3, 10 }) do
    			part("KeepSlit", Vector3.new(1, 3.5, 0.4),
    				cf(KX + xOff, hgt, side_z), C.black, MAT.stone)
    		end
    	end
    end
    keepSlits(KZ + KD/2 + 0.2,  1)
    keepSlits(KZ - KD/2 - 0.2, -1)
    
    -- Keep side windows
    for _, xSide in ipairs({ KX - KW/2 - 0.2, KX + KW/2 + 0.2 }) do
    	for _, hgt in ipairs({ GY+10, GY+18, GY+26, GY+34 }) do
    		for _, zOff in ipairs({ -8, 0, 8 }) do
    			part("KeepSlit_Side", Vector3.new(0.4, 3.5, 1),
    				cf(xSide, hgt, KZ + zOff), C.black, MAT.stone)
    		end
    	end
    end
    
    -- Bartizan turrets on keep corners (small corbelled corner turrets)
    for _, cx2 in ipairs({ -KW/2 - 2, KW/2 + 2 }) do
    	for _, cz2 in ipairs({ -KD/2 - 2, KD/2 + 2 }) do
    		local btH = KH - 5
    		cyl("Bartizan", 8, 8,
    			cf(KX + cx2, GY + 2 + btH + 4, KZ + cz2), C.stone, MAT.stone)
    		coneMesh("BartizanRoof", 6, 9,
    			cf(KX + cx2, GY + 2 + btH + 8 + 3, KZ + cz2), C.orangeRoof)
    	end
    end
    
    -- ── SECTION 12: MARKET STALLS ────────────────────────────────────
    
    local stallConfigs = {
    	{ x=  22, z= 25, rot=0,           col=C.canvasBlue,   flag="Weaponsmith" },
    	{ x=   0, z= 35, rot=0,           col=C.canvasYellow, flag="Merchant"    },
    	{ x= -22, z= 25, rot=0,           col=C.canvasTeal,   flag="Alchemist"   },
    	{ x=  18, z= 45, rot=math.pi/6,   col=C.canvasRed,    flag="Tailor"      },
    	{ x= -18, z= 45, rot=-math.pi/6,  col=C.canvasYellow, flag="Herbalist"   },
    }
    
    for i, sc in ipairs(stallConfigs) do
    	local sx, sz, col = sc.x, sc.z, sc.col
    	-- Stall frame posts
    	for _, px in ipairs({ -3, 3 }) do
    		for _, pz in ipairs({ -2, 2 }) do
    			part("StallPost",
    				Vector3.new(0.5, 5, 0.5),
    				cf(sx+px, GY+2.5, sz+pz), C.woodDark, MAT.wood)
    		end
    	end
    	-- Table top
    	part("StallTable",
    		Vector3.new(7, 1, 4.5),
    		cf(sx, GY+3, sz), C.wood, MAT.wood)
    	-- Table frame
    	part("TableFrame",
    		Vector3.new(7.2, 0.4, 4.7),
    		cf(sx, GY+2.5, sz), C.woodDark, MAT.wood)
    	-- Back wall
    	part("StallBack",
    		Vector3.new(7, 4, 0.5),
    		cf(sx, GY+4, sz-2.5), col, MAT.fabric)
    	-- Roof awning
    	wedgePart("StallAwning_F",
    		Vector3.new(7.2, 2, 3),
    		cfr(sx, GY+5.5, sz-0.5, math.rad(-30), 0, 0), col, MAT.fabric)
    	wedgePart("StallAwning_B",
    		Vector3.new(7.2, 2, 3),
    		cfr(sx, GY+5.5, sz+0.5, math.rad(-30), math.pi, 0), col, MAT.fabric)
    	-- Sign
    	part("StallSign",
    		Vector3.new(4, 1.5, 0.3),
    		cf(sx, GY+6.5, sz-2.6), C.wood, MAT.wood)
    	local signLabel = part("StallSignLabel", Vector3.new(3.5, 1, 0.35),
    		cf(sx, GY+6.5, sz-2.75), C.woodLight, MAT.wood)
    	addBillboard(signLabel, sc.flag, 80)
    	-- Goods on table
    	for g = 1, 3 do
    		-- Random goods: crate, barrel, sack
    		local gx = sx - 2 + (g-1) * 2
    		if g == 1 then  -- crate
    			part("Crate", Vector3.new(1.5, 1.5, 1.5),
    				cf(gx, GY+4, sz), C.crateWood, MAT.wood)
    			-- crate top planks
    			part("CrateLid", Vector3.new(1.6, 0.3, 1.6),
    				cf(gx, GY+4.75, sz), C.woodDark, MAT.wood)
    		elseif g == 2 then  -- barrel
    			cyl("StallBarrel", 2.2, 1.8,
    				cf(gx, GY+4.1, sz), C.barrelDark, MAT.wood)
    			cyl("BarrelRing", 2.4, 1.4,
    				cf(gx, GY+3.8, sz), C.ironChain, MAT.metal)
    			cyl("BarrelRing", 2.4, 1.4,
    				cf(gx, GY+4.4, sz), C.ironChain, MAT.metal)
    		else  -- sack
    			sphere("Sack", 1.8,
    				cf(gx, GY+4.4, sz), C.sackColor, MAT.fabric)
    		end
    	end
    end
    
    -- ── SECTION 13: COURTYARD WELL ───────────────────────────────────
    
    local WLX, WLZ = -30, 30
    
    -- Well base
    part("Well_Base",
    	Vector3.new(6, 1.5, 6),
    	cf(WLX, GY+0.75, WLZ), C.stone, MAT.stone)
    -- Well wall (outer ring)
    for angle = 0, 2*math.pi - 0.01, math.pi/8 do
    	local r2 = 2.8
    	part("WellBlock", Vector3.new(1.8, 3, 1.8),
    		cf(WLX + math.cos(angle)*r2, GY+2, WLZ + math.sin(angle)*r2),
    		C.stone, MAT.stone)
    end
    -- Well water
    cyl("WellWater", 4.5, 4.5,
    	cf(WLX, GY+0.5, WLZ), C.waterBlue, MAT.glass, 0.3)
    -- Well frame posts
    part("WellPost_L",
    	Vector3.new(0.5, 5, 0.5),
    	cf(WLX-2.5, GY+5, WLZ), C.woodDark, MAT.wood)
    part("WellPost_R",
    	Vector3.new(0.5, 5, 0.5),
    	cf(WLX+2.5, GY+5, WLZ), C.woodDark, MAT.wood)
    -- Crossbeam
    part("WellBeam",
    	Vector3.new(6, 0.5, 0.5),
    	cf(WLX, GY+7.5, WLZ), C.wood, MAT.wood)
    -- Rope drum
    cyl("WellDrum", 2, 1.2,
    	cf(WLX, GY+7.2, WLZ), C.wood, MAT.wood)
    -- Rope
    for seg = 0, 6 do
    	part("WellRope", Vector3.new(0.2, 1.2, 0.2),
    		cf(WLX, GY+7 - seg*1.1, WLZ+0.2), C.ropeColor, MAT.plast)
    end
    -- Bucket
    part("Bucket_Body",
    	Vector3.new(1.2, 1.5, 1.2),
    	cf(WLX, GY+1.5, WLZ+0.2), C.wood, MAT.wood)
    cyl("Bucket_Rim", 1.6, 1.4,
    	cf(WLX, GY+2.3, WLZ+0.2), C.ironChain, MAT.metal)
    -- Well canopy roof
    coneMesh("WellRoof", 3.5, 7,
    	cf(WLX, GY+10, WLZ), C.orangeRoofDk, MAT.plast)
    
    -- ── SECTION 14: NOTICE BOARD / QUEST BOARD ───────────────────────
    
    local QBX, QBZ = 30, 15
    part("NoticeBoardPost_L", Vector3.new(0.5, 5, 0.5),
    	cf(QBX - 2, GY+2.5, QBZ), C.woodDark, MAT.wood)
    part("NoticeBoardPost_R", Vector3.new(0.5, 5, 0.5),
    	cf(QBX + 2, GY+2.5, QBZ), C.woodDark, MAT.wood)
    part("NoticeBoardPanel", Vector3.new(4.5, 3.5, 0.4),
    	cf(QBX, GY+4.5, QBZ), C.crateWood, MAT.wood)
    -- Notice papers
    for _, paperData in ipairs({{-1, 1, 0.6}, {0.5, 0.5, -0.3}, {-0.8, -0.5, 0.4}}) do
    	part("Paper", Vector3.new(1.2, 1.6, 0.1),
    		cfr(QBX + paperData[1], GY+4.5 + paperData[2], QBZ - 0.25, 0, 0, paperData[3]),
    		Color3.fromRGB(225, 215, 185), MAT.plast)
    end
    local questSignal = part("QuestMarker", Vector3.new(0.8, 0.8, 0.8),
    	cf(QBX, GY+6.8, QBZ), Color3.fromRGB(255, 220, 0), MAT.neon)
    addBillboard(questSignal, "❓", 40)
    addPointLight(questSignal, Color3.fromRGB(255, 220, 50), 2, 10)
    
    -- ── SECTION 15: DECORATIVE PROPS ─────────────────────────────────
    
    -- Scatter of barrels and crates near market area
    local propPositions = {
    	{35, 0, 30}, {37, 0, 28}, {-35, 0, 22}, {-37, 0, 25},
    	{40, 0, 45}, {-40, 0, 40}, {25, 0, 50}, {-25, 0, 50},
    }
    for i, pp in ipairs(propPositions) do
    	if i % 3 == 0 then
    		part("PropCrate", Vector3.new(2, 2, 2),
    			cfr(pp[1], GY+1, pp[3], 0, math.random()*math.pi, 0),
    			C.crateWood, MAT.wood)
    	elseif i % 3 == 1 then
    		cyl("PropBarrel", 2.5, 2,
    			cf(pp[1], GY+1.25, pp[3]), C.barrelDark, MAT.wood)
    		cyl("PropBarrelRing", 2.7, 1.5,
    			cf(pp[1], GY+1, pp[3]), C.ironChain, MAT.metal)
    	else
    		sphere("PropSack", 2,
    			cf(pp[1], GY+1, pp[3]), C.sackColor, MAT.fabric)
    	end
    end
    
    -- Stack of cannonballs near corner towers
    for _, stackPos in ipairs({{ -85, GY, -75 }, { 85, GY, 75 }}) do
    	for row = 0, 2 do
    		for col = 0, 2 - row do
    			sphere("Cannonball", 1.2,
    				cf(stackPos[1] + col*1.4, stackPos[2] + row*1.4 + 0.6, stackPos[3]),
    				C.metalDark, MAT.metal)
    		end
    	end
    end
    
    -- Hay bales near stalls
    for _, hbPos in ipairs({{ 45, GY, 35 }, { -45, GY, 38 }}) do
    	cyl("HayBale", 3, 2.5, cf(hbPos[1], hbPos[2]+1.25, hbPos[3]), C.haybale, MAT.fabric)
    	-- Rope band on bale
    	cyl("HayRope", 3.1, 0.6, cf(hbPos[1], hbPos[2]+1.25, hbPos[3]), C.ropeColor, MAT.plast)
    end
    
    -- ── SECTION 16: LANTERN POSTS (courtyard) ────────────────────────
    
    local lampRows = {
    	{ -50,  50 }, { 50,  50 }, { -50, -50 }, { 50, -50 },
    	{   0,  55 }, {  0, -55 }, { -55,   0 }, { 55,   0 },
    	{  30,  15 }, { -30,  15 }, {  30, -15 }, { -30, -15 },
    }
    
    for _, lp in ipairs(lampRows) do
    	local lx, lz = lp[1], lp[2]
    	-- Stone pedestal
    	part("LampBase", Vector3.new(1.2, 0.8, 1.2),
    		cf(lx, GY+0.4, lz), C.stone, MAT.stone)
    	-- Iron pole
    	part("LampPole", Vector3.new(0.4, 7, 0.4),
    		cf(lx, GY+4, lz), C.metalDark, MAT.metal)
    	-- Pole bracket arm
    	part("LampArm", Vector3.new(0.3, 0.3, 2.2),
    		cf(lx, GY+7.5, lz + 1), C.metalDark, MAT.metal)
    	-- Lantern cage
    	part("LampCage", Vector3.new(1.4, 2, 1.4),
    		cf(lx, GY+6.8, lz + 2), C.metalDark, MAT.metal, 0.5)
    	-- Flame glow
    	local flamePt = part("LampFlame", Vector3.new(0.9, 1.4, 0.9),
    		cf(lx, GY+6.8, lz + 2), C.lanternAmber, MAT.neon)
    	addPointLight(flamePt, Color3.fromRGB(255, 195, 80), 3.5, 18)
    	-- Smoke hint (dark sphere, transparent)
    	sphere("LampSmoke", 0.8,
    		cf(lx, GY+8, lz + 2), Color3.fromRGB(60, 58, 55), MAT.plast, 0.7)
    end
    
    -- ── SECTION 17: GUARD NPC PLACEHOLDERS ───────────────────────────
    
    local guardPositions = {
    	-- { x, z, name, color }
    	{ -15, OW.hz + 10, "Gate Guard L", C.npcArmor },
    	{ -15 + gateW + 2, OW.hz + 10, "Gate Guard R", C.npcArmor },
    	{ 0, KZ + KD/2 + 6, "Keep Guard", C.npcArmor },
    	{ 30, 30, "Market Guard", C.npcRobe },
    	{ -30, 40, "Merchant NPC", C.canvasBlue },
    }
    
    for _, gp in ipairs(guardPositions) do
    	-- Torso
    	part("NPC_Torso",
    		Vector3.new(2, 2.5, 1),
    		cf(gp[1], GY+2.75, gp[3]), gp[4], MAT.plast)
    	-- Head
    	sphere("NPC_Head", 1.8,
    		cf(gp[1], GY+5, gp[3]), C.npcSkin, MAT.plast)
    	-- Legs
    	part("NPC_LegL",
    		Vector3.new(0.9, 2, 0.9),
    		cf(gp[1]-0.55, GY+1, gp[3]), gp[4], MAT.plast)
    	part("NPC_LegR",
    		Vector3.new(0.9, 2, 0.9),
    		cf(gp[1]+0.55, GY+1, gp[3]), gp[4], MAT.plast)
    	-- Arms
    	part("NPC_ArmL",
    		Vector3.new(0.8, 2.2, 0.8),
    		cfr(gp[1]-1.4, GY+2.5, gp[3], 0, 0, math.rad(20)), gp[4], MAT.plast)
    	part("NPC_ArmR",
    		Vector3.new(0.8, 2.2, 0.8),
    		cfr(gp[1]+1.4, GY+2.5, gp[3], 0, 0, math.rad(-20)), gp[4], MAT.plast)
    	-- Name billboard
    	local nameAnchor = part("NPC_NameAnchor", Vector3.new(0.1, 0.1, 0.1),
    		cf(gp[1], GY+7, gp[3]), C.black, MAT.plast, 1)
    	addBillboard(nameAnchor, gp[2], 90)
    end
    
    -- ── SECTION 18: COURTYARD TREES / PLANTERS ───────────────────────
    
    local treePlanterPositions = {
    	{  48, -48 }, { -48, -48 }, {  48,  48 }, { -48,  48 }
    }
    
    for _, tp in ipairs(treePlanterPositions) do
    	-- Stone planter box
    	part("Planter",
    		Vector3.new(5, 2, 5),
    		cf(tp[1], GY+1, tp[2]), C.stone, MAT.stone)
    	part("Planter_Soil",
    		Vector3.new(4.2, 0.6, 4.2),
    		cf(tp[1], GY+2.3, tp[2]), C.dirt, MAT.grass)
    	-- Tree trunk
    	cyl("TreeTrunk", 2, 2,
    		cf(tp[1], GY+5, tp[2]), C.woodDark, MAT.wood)
    	-- Tree foliage (layered spheres)
    	sphere("TreeFoliage_1", 7,
    		cf(tp[1], GY+9, tp[2]), C.grassGreen, MAT.grass)
    	sphere("TreeFoliage_2", 5,
    		cf(tp[1] + 1, GY+11.5, tp[2] - 1), C.grassGreen, MAT.grass)
    	sphere("TreeFoliage_3", 4,
    		cf(tp[1] - 0.5, GY+13, tp[2] + 0.5),
    		Color3.fromRGB(68, 130, 48), MAT.grass)
    end
    
    -- Flower bushes near keep entrance
    local bushPositions = {
    	{ KX - 6, KZ + KD/2 + 3 },
    	{ KX + 6, KZ + KD/2 + 3 },
    	{ KX - 12, KZ + KD/2 + 4 },
    	{ KX + 12, KZ + KD/2 + 4 },
    }
    for _, bp in ipairs(bushPositions) do
    	sphere("Bush", 3, cf(bp[1], GY+1.5, bp[2]),
    		Color3.fromRGB(78, 135, 55), MAT.grass)
    	-- Flowers on top
    	for fi = 1, 3 do
    		local fAngle = fi * math.pi * 2/3
    		sphere("Flower", 0.5,
    			cf(bp[1] + math.cos(fAngle)*1.2, GY+3, bp[2] + math.sin(fAngle)*1.2),
    			Color3.fromRGB(220, 80, 80), MAT.plast)
    	end
    end
    
    -- ── SECTION 19: MOAT ─────────────────────────────────────────────
    
    -- Water trench around outer wall
    -- North/South moat channels
    for _, mz in ipairs({ -OW.hz - 12, OW.hz + 12 }) do
    	part("Moat_NS",
    		Vector3.new(OW.hx*2 + 30, 4, 10),
    		cf(0, GY - 2, mz), C.waterBlue, MAT.glass, 0.25)
    end
    -- East/West moat channels
    for _, mx in ipairs({ -OW.hx - 12, OW.hx + 12 }) do
    	part("Moat_EW",
    		Vector3.new(10, 4, OW.hz*2 + 10),
    		cf(mx, GY - 2, 0), C.waterBlue, MAT.glass, 0.25)
    end
    -- Corner moat fills
    for _, cx2 in ipairs({ -OW.hx-12, OW.hx+12 }) do
    	for _, cz2 in ipairs({ -OW.hz-12, OW.hz+12 }) do
    		part("MoatCorner", Vector3.new(10, 4, 10),
    			cf(cx2, GY-2, cz2), C.waterBlue, MAT.glass, 0.25)
    	end
    end
    -- Moat bed (dark stone)
    part("MoatBed",
    	Vector3.new(OW.hx*2 + 34, 2, OW.hz*2 + 34),
    	cf(0, GY-4.5, 0), C.stoneDark, MAT.stone)
    
    -- ── SECTION 20: MAIN ROAD (to village, SW) ───────────────────────
    
    -- Road segments curving south-west
    local roadNodes = {
    	{ x=GX-5, z=OW.hz+26, w=12, l=24 },
    	{ x=GX-18, z=OW.hz+52, w=10, l=30, rot=math.rad(15) },
    	{ x=GX-35, z=OW.hz+82, w=10, l=40, rot=math.rad(25) },
    	{ x=GX-55, z=OW.hz+120,w=10, l=50, rot=math.rad(30) },
    }
    for i, rn in ipairs(roadNodes) do
    	part("Road_Main_"..i,
    		Vector3.new(rn.w, 0.5, rn.l),
    		cfr(rn.x, GY+0.25, rn.z, 0, rn.rot or 0, 0),
    		C.cobble, MAT.cobble)
    	-- Road edge stones
    	for _, side in ipairs({-1, 1}) do
    		part("RoadEdge",
    			Vector3.new(0.8, 0.8, rn.l),
    			cfr(rn.x + side*(rn.w/2 + 0.4), GY+0.4, rn.z, 0, rn.rot or 0, 0),
    			C.stoneDark, MAT.stone)
    	end
    end
    
    -- ── SECTION 21: NORTH / EAST / WEST PATHS ────────────────────────
    
    local pathColor = Color3.fromRGB(132, 112, 82)
    local pathMat   = MAT.stone
    
    -- North path (to mountain)
    part("Path_North_1", Vector3.new(7, 0.3, 100),
    	cf(0, GY+0.15, -OW.hz - 50), pathColor, pathMat)
    part("Path_North_2", Vector3.new(7, 0.3, 80),
    	cfr(0, GY+0.15, -OW.hz - 140, 0, math.rad(5), 0), pathColor, pathMat)
    
    -- East path (to Gloom-Wood)
    part("Path_East_1", Vector3.new(100, 0.3, 6),
    	cf(OW.hx + 50, GY+0.15, 12), pathColor, pathMat)
    part("Path_East_2", Vector3.new(80, 0.3, 6),
    	cfr(OW.hx + 140, GY+0.15, 18, 0, math.rad(8), 0), pathColor, pathMat)
    
    -- West path (to Sun-Scorch)
    part("Path_West_1", Vector3.new(100, 0.3, 6),
    	cf(-OW.hx - 50, GY+0.15, 0), pathColor, pathMat)
    part("Path_West_2", Vector3.new(80, 0.3, 6),
    	cfr(-OW.hx - 140, GY+0.15, -5, 0, math.rad(-8), 0), pathColor, pathMat)
    
    -- Path edge markers (small stones)
    for pDist = 1, 5 do
    	local d = pDist * 20
    	for _, side in ipairs({-1, 1}) do
    		sphere("PathStone", 0.8,
    			cf(side*4, GY+0.4, -OW.hz - d), C.stoneLight, MAT.stone)
    		sphere("PathStone", 0.8,
    			cf(OW.hx + d, GY+0.4, 12 + side*4), C.stoneLight, MAT.stone)
    	end
    end
    
    -- ── SECTION 22: ATMOSPHERIC DETAILS ─────────────────────────────
    
    -- Scattered pebbles / small rocks on courtyard edges
    for i = 1, 20 do
    	local angle = (i/20) * 2*math.pi
    	local r = 90 + math.sin(i * 3.7) * 10
    	sphere("Pebble",
    		math.random(3,7) * 0.1 + 0.3,
    		cf(math.cos(angle)*r, GY+0.3, math.sin(angle)*r),
    		C.stoneLight, MAT.stone)
    end
    
    -- Moss creep on walls (green tinted patches at base)
    for i = 1, 8 do
    	local positions = {
    		{ -OW.hx - OW.t/2, GY+1.5, (i-4.5)*22 },
    		{  OW.hx + OW.t/2, GY+1.5, (i-4.5)*22 },
    	}
    	for _, mp in ipairs(positions) do
    		part("MossWall",
    			Vector3.new(0.5, math.random(3,7), math.random(4,10)),
    			cfr(mp[1], mp[2], mp[3], 0, math.random()*0.5, 0),
    			C.stoneMoss, MAT.grass, 0.3)
    	end
    end
    
    -- ── FINAL REPORT ─────────────────────────────────────────────────
    
    local count = #folder:GetDescendants()
    print(string.format(
    	"[Highgard Zone 1] ✅ Done!  %d objects created in workspace.Highgard_Zone1",
    	count
    ))
    end
    print("[HighgardPlugin] ✅ Zone1_Highgard complete.")
end


-- ────────────────────────────────────────────────────────────────
zoneFunctions["Zone2_EmeraldHaven"] = function()
    print("[HighgardPlugin] 🔨 Building Zone2_EmeraldHaven...")
    do
    local ORIGIN = CFrame.new(-220, 50, 220)
    
    -- ── Palette ─────────────────────────────────────────────────────
    local C = {
    	stone       = Color3.fromRGB(148, 142, 135),
    	stoneDark   = Color3.fromRGB(105,  98,  90),
    	stoneLight  = Color3.fromRGB(185, 180, 172),
    	cobble      = Color3.fromRGB(128, 122, 115),
    	cobbleDark  = Color3.fromRGB(100,  95,  88),
    	wood        = Color3.fromRGB(128,  82,  38),
    	woodDark    = Color3.fromRGB( 78,  48,  18),
    	woodLight   = Color3.fromRGB(168, 128,  68),
    	thatch      = Color3.fromRGB(185, 155,  60),
    	thatchDark  = Color3.fromRGB(148, 118,  42),
    	plasterWall = Color3.fromRGB(220, 210, 188),
    	plasterWarm = Color3.fromRGB(215, 198, 168),
    	grassGreen  = Color3.fromRGB( 78, 118,  58),
    	grassLight  = Color3.fromRGB(102, 148,  72),
    	dirt        = Color3.fromRGB(110,  88,  62),
    	dirtDark    = Color3.fromRGB( 85,  65,  42),
    	waterBlue   = Color3.fromRGB( 72, 138, 195),
    	waterShallow= Color3.fromRGB( 88, 165, 210),
    	foliageDark = Color3.fromRGB( 52,  88,  38),
    	foliageMid  = Color3.fromRGB( 68, 108,  48),
    	foliageLight= Color3.fromRGB( 88, 135,  62),
    	treeSpruceD = Color3.fromRGB( 38,  72,  42),
    	treeSpruce  = Color3.fromRGB( 52,  95,  55),
    	trunkBrown  = Color3.fromRGB( 72,  48,  22),
    	ironMetal   = Color3.fromRGB( 55,  55,  60),
    	ropeColor   = Color3.fromRGB(155, 125,  75),
    	haybale     = Color3.fromRGB(210, 175,  70),
    	crateWood   = Color3.fromRGB(148, 108,  58),
    	barrelDark  = Color3.fromRGB( 92,  60,  28),
    	sackColor   = Color3.fromRGB(165, 140,  88),
    	lanternAmb  = Color3.fromRGB(255, 195,  55),
    	torchFlame  = Color3.fromRGB(255, 130,  20),
    	npcSkin     = Color3.fromRGB(225, 185, 140),
    	npcArmor    = Color3.fromRGB(100, 100, 110),
    	npcRobe     = Color3.fromRGB( 68,  95, 148),
    	npcGreen    = Color3.fromRGB( 60, 105,  60),
    	npcRed      = Color3.fromRGB(155,  48,  38),
    	npcBrown    = Color3.fromRGB(105,  72,  38),
    	signBoard   = Color3.fromRGB(148, 108,  52),
    	questYellow = Color3.fromRGB(255, 218,  45),
    	dangerRed   = Color3.fromRGB(195,  38,  38),
    	flowerRed   = Color3.fromRGB(210,  65,  65),
    	flowerYel   = Color3.fromRGB(230, 185,  45),
    	flowerWhite = Color3.fromRGB(238, 235, 228),
    	chimneyGrey = Color3.fromRGB(115, 108, 100),
    	black       = Color3.fromRGB( 20,  18,  15),
    	mudGrey     = Color3.fromRGB( 95,  88,  78),
    }
    
    local M = Enum.Material
    local MAT = {
    	stone  = M.SmoothPlastic,
    	cobble = M.Cobblestone,
    	wood   = M.Wood,
    	brick  = M.Brick,
    	metal  = M.Metal,
    	glass  = M.Glass,
    	neon   = M.Neon,
    	grass  = M.Grass,
    	slate  = M.Slate,
    	fabric = M.Fabric,
    	plast  = M.SmoothPlastic,
    	sand   = M.Sand,
    }
    
    -- ── Root folder ──────────────────────────────────────────────────
    local folder = Instance.new("Folder")
    folder.Name   = "EmeraldHaven_Zone2"
    folder.Parent = workspace
    
    -- ── Helper functions ─────────────────────────────────────────────
    local function cf(x, y, z)      return ORIGIN * CFrame.new(x, y, z) end
    local function cfr(x,y,z,rx,ry,rz) return cf(x,y,z)*CFrame.Angles(rx,ry,rz) end
    
    local function part(name, size, cframe, color, material, transparency)
    	local p = Instance.new("Part")
    	p.Name          = name
    	p.Size          = size
    	p.CFrame        = cframe
    	p.Color         = color or C.stone
    	p.Material      = material or MAT.stone
    	p.Transparency  = transparency or 0
    	p.Anchored      = true
    	p.CastShadow    = true
    	p.TopSurface    = Enum.SurfaceType.Smooth
    	p.BottomSurface = Enum.SurfaceType.Smooth
    	p.Parent        = folder
    	return p
    end
    
    local function wedge(name, size, cframe, color, material)
    	local p = Instance.new("WedgePart")
    	p.Name          = name
    	p.Size          = size
    	p.CFrame        = cframe
    	p.Color         = color or C.thatch
    	p.Material      = material or MAT.wood
    	p.Anchored      = true
    	p.TopSurface    = Enum.SurfaceType.Smooth
    	p.BottomSurface = Enum.SurfaceType.Smooth
    	p.Parent        = folder
    	return p
    end
    
    local function cyl(name, height, diam, cframe, color, material, transp)
    	local p = Instance.new("Part")
    	p.Name          = name
    	p.Shape         = Enum.PartType.Cylinder
    	p.Size          = Vector3.new(height, diam, diam)
    	p.CFrame        = cframe * CFrame.Angles(0, 0, math.pi/2)
    	p.Color         = color or C.wood
    	p.Material      = material or MAT.wood
    	p.Transparency  = transp or 0
    	p.Anchored      = true
    	p.TopSurface    = Enum.SurfaceType.Smooth
    	p.BottomSurface = Enum.SurfaceType.Smooth
    	p.Parent        = folder
    	return p
    end
    
    local function sphere(name, diam, cframe, color, material, transp)
    	local p = Instance.new("Part")
    	p.Name         = name
    	p.Shape        = Enum.PartType.Ball
    	p.Size         = Vector3.new(diam, diam, diam)
    	p.CFrame       = cframe
    	p.Color        = color or C.foliageMid
    	p.Material     = material or MAT.grass
    	p.Transparency = transp or 0
    	p.Anchored     = true
    	p.Parent       = folder
    	return p
    end
    
    local function addLight(parent, color, brightness, range)
    	local l = Instance.new("PointLight", parent)
    	l.Color      = color
    	l.Brightness = brightness or 3
    	l.Range      = range or 18
    	l.Enabled    = true
    end
    
    local function billboard(parent, text, size)
    	local bg = Instance.new("BillboardGui", parent)
    	bg.Size        = UDim2.fromOffset(size or 60, 28)
    	bg.StudsOffset = Vector3.new(0, 3, 0)
    	bg.AlwaysOnTop = false
    	local lbl = Instance.new("TextLabel", bg)
    	lbl.Size                 = UDim2.fromScale(1, 1)
    	lbl.BackgroundTransparency = 1
    	lbl.Text                 = text
    	lbl.TextColor3           = Color3.new(1, 1, 1)
    	lbl.TextScaled           = true
    end
    
    local GY = 0  -- ground level (relative to ORIGIN)
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 1: GROUND / TERRAIN BASE
    -- ═══════════════════════════════════════════════════════════════
    
    -- Rolling green hill base
    part("VillageHill",    Vector3.new(185, 4,  165), cf(0, -2.5, 0), C.grassGreen, MAT.grass)
    part("VillageHillMid", Vector3.new(165, 2,  145), cf(0, -0.2, 0), C.grassLight, MAT.grass)
    
    -- Dirt paths inside village
    local pathSegs = {
    	{ x= 0,   z= 0,  w=5, l=70  },   -- main N-S path
    	{ x=-20,  z= 10, w=5, l=45, rot=math.rad(30)  },  -- path to house cluster left
    	{ x= 22,  z= 8,  w=5, l=40, rot=math.rad(-20) },  -- path to barn right
    	{ x= 0,   z= 38, w=5, l=22  },   -- path to well
    }
    for _, ps in ipairs(pathSegs) do
    	part("VillagePath",
    		Vector3.new(ps.w, 0.4, ps.l),
    		cfr(ps.x, GY+0.2, ps.z, 0, ps.rot or 0, 0),
    		C.dirtDark, MAT.stone)
    end
    
    -- Road connection NE toward Highgard (cobblestone)
    part("Road_ToHighgard_1",
    	Vector3.new(10, 0.5, 80),
    	cfr(55, GY+0.25, -55, 0, math.rad(-42), 0),
    	C.cobble, MAT.cobble)
    part("Road_ToHighgard_2",
    	Vector3.new(10, 0.5, 60),
    	cfr(95, GY+0.25, -105, 0, math.rad(-36), 0),
    	C.cobble, MAT.cobble)
    -- Road edge stones
    for i = 0, 6 do
    	local d = i * 12
    	for _, side in ipairs({-1, 1}) do
    		sphere("RoadEdgeStone", 0.7,
    			cf(45 + d*0.5, GY+0.4, -40 - d + side*5.5),
    			C.stoneLight, MAT.stone)
    	end
    end
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 2: HOUSE 1 — Large central farmhouse
    -- ═══════════════════════════════════════════════════════════════
    -- Half-timber style: plaster walls, dark timber frame, thatched roof
    
    local H1X, H1Z = -5, -15
    
    -- Foundation
    part("H1_Foundation", Vector3.new(16, 1, 12),
    	cf(H1X, GY+0.5, H1Z), C.stoneDark, MAT.stone)
    -- Walls
    part("H1_Wall_Front", Vector3.new(16, 8, 1),
    	cf(H1X, GY+1+4, H1Z+6), C.plasterWall, MAT.plast)
    part("H1_Wall_Back",  Vector3.new(16, 8, 1),
    	cf(H1X, GY+1+4, H1Z-6), C.plasterWall, MAT.plast)
    part("H1_Wall_L",     Vector3.new(1, 8, 12),
    	cf(H1X-8, GY+1+4, H1Z),  C.plasterWall, MAT.plast)
    part("H1_Wall_R",     Vector3.new(1, 8, 12),
    	cf(H1X+8, GY+1+4, H1Z),  C.plasterWall, MAT.plast)
    
    -- Timber framing (dark wood beams overlaid on plaster)
    for _, beamX in ipairs({H1X-6, H1X, H1X+6}) do
    	part("H1_BeamV", Vector3.new(0.6, 8, 0.6),
    		cf(beamX, GY+5, H1Z+6.3), C.woodDark, MAT.wood)
    	part("H1_BeamV", Vector3.new(0.6, 8, 0.6),
    		cf(beamX, GY+5, H1Z-6.3), C.woodDark, MAT.wood)
    end
    for _, beamY in ipairs({GY+3, GY+6, GY+9}) do
    	part("H1_BeamH_F", Vector3.new(16.2, 0.6, 0.6),
    		cf(H1X, beamY, H1Z+6.3), C.woodDark, MAT.wood)
    	part("H1_BeamH_B", Vector3.new(16.2, 0.6, 0.6),
    		cf(H1X, beamY, H1Z-6.3), C.woodDark, MAT.wood)
    end
    for _, beamZ in ipairs({H1Z-4, H1Z, H1Z+4}) do
    	part("H1_BeamV_Side", Vector3.new(0.6, 8, 0.6),
    		cf(H1X-8.3, GY+5, beamZ), C.woodDark, MAT.wood)
    	part("H1_BeamV_Side", Vector3.new(0.6, 8, 0.6),
    		cf(H1X+8.3, GY+5, beamZ), C.woodDark, MAT.wood)
    end
    
    -- Thatched roof (two wedge halves + ridge)
    wedge("H1_Roof_F",
    	Vector3.new(17, 5, 8),
    	cfr(H1X, GY+10+2.5, H1Z+2, math.rad(-20), 0, 0),
    	C.thatch, MAT.fabric)
    wedge("H1_Roof_B",
    	Vector3.new(17, 5, 8),
    	cfr(H1X, GY+10+2.5, H1Z-2, math.rad(20), math.pi, 0),
    	C.thatch, MAT.fabric)
    -- Roof ridge beam
    part("H1_Ridge", Vector3.new(17.5, 0.8, 0.8),
    	cf(H1X, GY+13.5, H1Z), C.thatchDark, MAT.wood)
    -- Eaves overhang strips
    part("H1_Eave_F", Vector3.new(17.5, 0.5, 1),
    	cf(H1X, GY+9.5, H1Z+6.5), C.thatchDark, MAT.wood)
    part("H1_Eave_B", Vector3.new(17.5, 0.5, 1),
    	cf(H1X, GY+9.5, H1Z-6.5), C.thatchDark, MAT.wood)
    part("H1_Eave_L", Vector3.new(1, 0.5, 14),
    	cf(H1X-8.5, GY+9.5, H1Z), C.thatchDark, MAT.wood)
    part("H1_Eave_R", Vector3.new(1, 0.5, 14),
    	cf(H1X+8.5, GY+9.5, H1Z), C.thatchDark, MAT.wood)
    
    -- Chimney
    part("H1_Chimney", Vector3.new(2.5, 6, 2.5),
    	cf(H1X+5, GY+13, H1Z-3), C.chimneyGrey, MAT.stone)
    part("H1_ChimneyCap", Vector3.new(3.2, 0.6, 3.2),
    	cf(H1X+5, GY+16.2, H1Z-3), C.stoneDark, MAT.stone)
    -- Chimney smoke (neon for effect)
    sphere("H1_Smoke1", 1.8,
    	cf(H1X+5, GY+17.5, H1Z-3), Color3.fromRGB(65, 62, 58), MAT.plast, 0.65)
    sphere("H1_Smoke2", 1.2,
    	cf(H1X+5.5, GY+19, H1Z-2.5), Color3.fromRGB(65, 62, 58), MAT.plast, 0.8)
    
    -- Door
    part("H1_Door_Frame", Vector3.new(4.5, 7.5, 0.8),
    	cf(H1X-2, GY+4.75, H1Z+6.4), C.woodDark, MAT.wood)
    part("H1_Door_L", Vector3.new(1.8, 7, 0.5),
    	cf(H1X-2.8, GY+4.5, H1Z+6.7), C.wood, MAT.wood)
    part("H1_Door_R", Vector3.new(1.8, 7, 0.5),
    	cf(H1X-0.8, GY+4.5, H1Z+6.7), C.wood, MAT.wood)
    -- Door planks
    for pi2 = -2, 2 do
    	part("H1_Plank_L", Vector3.new(1.8, 0.5, 0.6),
    		cf(H1X-2.8, GY+4.5+pi2*1.3, H1Z+6.8), C.woodLight, MAT.wood)
    	part("H1_Plank_R", Vector3.new(1.8, 0.5, 0.6),
    		cf(H1X-0.8, GY+4.5+pi2*1.3, H1Z+6.8), C.woodLight, MAT.wood)
    end
    -- Iron door hinges
    for _, hy in ipairs({GY+3, GY+5.5, GY+7.5}) do
    	sphere("H1_Hinge_L", 0.22, cf(H1X-1.9, hy, H1Z+6.9), C.ironMetal, MAT.metal)
    	sphere("H1_Hinge_R", 0.22, cf(H1X+0.1, hy, H1Z+6.9), C.ironMetal, MAT.metal)
    end
    
    -- Windows (two front, one each side)
    for _, wx in ipairs({H1X+3, H1X+6}) do
    	part("H1_Win_Frame", Vector3.new(3.5, 3.5, 0.8),
    		cf(wx, GY+5.5, H1Z+6.4), C.woodDark, MAT.wood)
    	part("H1_Win_Glass", Vector3.new(2.8, 2.8, 0.4),
    		cf(wx, GY+5.5, H1Z+6.6), C.waterShallow, MAT.glass, 0.55)
    	-- Window cross
    	part("H1_Win_CrossV", Vector3.new(0.4, 2.8, 0.5),
    		cf(wx, GY+5.5, H1Z+6.65), C.woodDark, MAT.wood)
    	part("H1_Win_CrossH", Vector3.new(2.8, 0.4, 0.5),
    		cf(wx, GY+5.5, H1Z+6.65), C.woodDark, MAT.wood)
    end
    -- Side windows
    part("H1_Win_SideL", Vector3.new(0.8, 3, 3),
    	cf(H1X-8.4, GY+5.5, H1Z+2), C.waterShallow, MAT.glass, 0.55)
    part("H1_Win_SideR", Vector3.new(0.8, 3, 3),
    	cf(H1X+8.4, GY+5.5, H1Z-2), C.waterShallow, MAT.glass, 0.55)
    
    -- Flower box under front windows
    part("H1_FlowerBox", Vector3.new(7, 0.8, 1.2),
    	cf(H1X+4.5, GY+3.8, H1Z+6.6), C.woodDark, MAT.wood)
    for fi = 0, 5 do
    	local fcol = (fi%2==0) and C.flowerRed or C.flowerYel
    	sphere("H1_Flower", 0.55,
    		cf(H1X+2+fi*0.9, GY+4.5, H1Z+6.6), fcol, MAT.plast)
    end
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 3: HOUSE 2 — Small cottage (left cluster)
    -- ═══════════════════════════════════════════════════════════════
    
    local H2X, H2Z = -38, -8
    
    part("H2_Foundation", Vector3.new(12, 0.8, 10),
    	cf(H2X, GY+0.4, H2Z), C.stoneDark, MAT.stone)
    part("H2_Wall_F",  Vector3.new(12, 7, 1), cf(H2X, GY+4.5, H2Z+5),  C.plasterWarm, MAT.plast)
    part("H2_Wall_B",  Vector3.new(12, 7, 1), cf(H2X, GY+4.5, H2Z-5),  C.plasterWarm, MAT.plast)
    part("H2_Wall_L",  Vector3.new(1, 7, 10), cf(H2X-6, GY+4.5, H2Z),  C.plasterWarm, MAT.plast)
    part("H2_Wall_R",  Vector3.new(1, 7, 10), cf(H2X+6, GY+4.5, H2Z),  C.plasterWarm, MAT.plast)
    -- Timber beams
    for _, bx in ipairs({H2X-4, H2X, H2X+4}) do
    	part("H2_Beam", Vector3.new(0.5, 7, 0.5), cf(bx, GY+4.5, H2Z+5.3), C.woodDark, MAT.wood)
    end
    part("H2_BeamH", Vector3.new(12.4, 0.5, 0.5), cf(H2X, GY+5.5, H2Z+5.3), C.woodDark, MAT.wood)
    -- Gabled roof
    wedge("H2_Roof_F", Vector3.new(13, 4, 7),
    	cfr(H2X, GY+8+2, H2Z+1.5, math.rad(-18), 0, 0), C.thatch, MAT.fabric)
    wedge("H2_Roof_B", Vector3.new(13, 4, 7),
    	cfr(H2X, GY+8+2, H2Z-1.5, math.rad(18), math.pi, 0), C.thatch, MAT.fabric)
    part("H2_Ridge", Vector3.new(13, 0.7, 0.7),
    	cf(H2X, GY+11.5, H2Z), C.thatchDark, MAT.wood)
    -- Chimney (smaller)
    part("H2_Chimney", Vector3.new(2, 5, 2),
    	cf(H2X-3, GY+11, H2Z-2), C.chimneyGrey, MAT.stone)
    -- Door and window
    part("H2_Door", Vector3.new(3, 6, 0.6),
    	cf(H2X+2, GY+4, H2Z+5.3), C.wood, MAT.wood)
    part("H2_Win",  Vector3.new(0.6, 2.5, 2.5),
    	cf(H2X-6.3, GY+5, H2Z+2), C.waterShallow, MAT.glass, 0.5)
    
    -- Garden / vegetable patch next to house 2
    for row = 0, 2 do
    	for col = 0, 3 do
    		part("Garden_Bed",
    			Vector3.new(2.5, 0.4, 1.8),
    			cf(H2X - 10 + col*3.2, GY+0.2, H2Z+2 + row*2.5),
    			C.dirtDark, MAT.stone)
    		-- Crop plant
    		sphere("Crop", 0.7,
    			cf(H2X - 10 + col*3.2, GY+0.8, H2Z+2 + row*2.5),
    			Color3.fromRGB(62, 138, 42), MAT.grass)
    	end
    end
    -- Garden fence
    for i = 0, 12 do
    	part("GardenFence_Post", Vector3.new(0.4, 1.8, 0.4),
    		cf(H2X-18 + i*1.8, GY+0.9, H2Z-2), C.woodLight, MAT.wood)
    end
    part("GardenFence_Rail_H", Vector3.new(22, 0.4, 0.4),
    	cf(H2X-7, GY+1.2, H2Z-2), C.wood, MAT.wood)
    part("GardenFence_Rail_L", Vector3.new(22, 0.4, 0.4),
    	cf(H2X-7, GY+0.5, H2Z-2), C.wood, MAT.wood)
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 4: HOUSE 3 — Large two-storey (NE cluster)
    -- ═══════════════════════════════════════════════════════════════
    
    local H3X, H3Z = 28, -22
    
    -- Ground floor
    part("H3_Foundation", Vector3.new(18, 1, 14), cf(H3X, GY+0.5, H3Z), C.stone, MAT.stone)
    part("H3_WallF_G",  Vector3.new(18, 8, 1),   cf(H3X, GY+5, H3Z+7),   C.plasterWall, MAT.plast)
    part("H3_WallB_G",  Vector3.new(18, 8, 1),   cf(H3X, GY+5, H3Z-7),   C.plasterWall, MAT.plast)
    part("H3_WallL_G",  Vector3.new(1, 8, 14),   cf(H3X-9, GY+5, H3Z),   C.plasterWall, MAT.plast)
    part("H3_WallR_G",  Vector3.new(1, 8, 14),   cf(H3X+9, GY+5, H3Z),   C.plasterWall, MAT.plast)
    -- Upper floor
    part("H3_FloorPlank", Vector3.new(18, 0.8, 14), cf(H3X, GY+9.4, H3Z), C.wood, MAT.wood)
    part("H3_WallF_U",  Vector3.new(18, 6, 1),   cf(H3X, GY+13, H3Z+7),  C.plasterWarm, MAT.plast)
    part("H3_WallB_U",  Vector3.new(18, 6, 1),   cf(H3X, GY+13, H3Z-7),  C.plasterWarm, MAT.plast)
    part("H3_WallL_U",  Vector3.new(1, 6, 14),   cf(H3X-9, GY+13, H3Z),  C.plasterWarm, MAT.plast)
    part("H3_WallR_U",  Vector3.new(1, 6, 14),   cf(H3X+9, GY+13, H3Z),  C.plasterWarm, MAT.plast)
    -- Upper floor overhang (jettied style)
    part("H3_Jetty_F",  Vector3.new(20, 1, 2),   cf(H3X, GY+9, H3Z+8.5), C.woodDark, MAT.wood)
    part("H3_Jetty_L",  Vector3.new(2, 1, 16),   cf(H3X-10, GY+9, H3Z),  C.woodDark, MAT.wood)
    part("H3_Jetty_R",  Vector3.new(2, 1, 16),   cf(H3X+10, GY+9, H3Z),  C.woodDark, MAT.wood)
    -- Timber framing upper
    for _, bx in ipairs({H3X-7, H3X-2, H3X+3, H3X+8}) do
    	part("H3_BeamU", Vector3.new(0.5, 6, 0.5), cf(bx, GY+13, H3Z+7.3), C.woodDark, MAT.wood)
    end
    part("H3_BeamH_U",  Vector3.new(18.4, 0.5, 0.5), cf(H3X, GY+12, H3Z+7.3), C.woodDark, MAT.wood)
    -- Steep roof
    wedge("H3_Roof_F",
    	Vector3.new(20, 6, 9),
    	cfr(H3X, GY+17+3, H3Z+2.5, math.rad(-22), 0, 0), C.thatch, MAT.fabric)
    wedge("H3_Roof_B",
    	Vector3.new(20, 6, 9),
    	cfr(H3X, GY+17+3, H3Z-2.5, math.rad(22), math.pi, 0), C.thatch, MAT.fabric)
    part("H3_Ridge", Vector3.new(20.5, 0.8, 0.8),
    	cf(H3X, GY+22.5, H3Z), C.thatchDark, MAT.wood)
    -- Chimney (double)
    for _, cxOff in ipairs({H3X-4, H3X+4}) do
    	part("H3_Chimney", Vector3.new(2.2, 7, 2.2), cf(cxOff, GY+20, H3Z-4), C.chimneyGrey, MAT.stone)
    	part("H3_ChimneyCap", Vector3.new(3, 0.5, 3), cf(cxOff, GY+23.5, H3Z-4), C.stoneDark, MAT.stone)
    end
    -- Windows (multiple floors)
    for _, wz in ipairs({H3Z+4, H3Z-4}) do
    	part("H3_Win_G", Vector3.new(0.6, 2.8, 2.8), cf(H3X-9.3, GY+5.5, wz), C.waterShallow, MAT.glass, 0.5)
    	part("H3_Win_U", Vector3.new(0.6, 2.5, 2.5), cf(H3X-9.3, GY+13, wz),  C.waterShallow, MAT.glass, 0.5)
    end
    for _, wx in ipairs({H3X-5, H3X, H3X+5}) do
    	part("H3_Win_Front", Vector3.new(3, 2.8, 0.6), cf(wx, GY+13, H3Z+7.3), C.waterShallow, MAT.glass, 0.5)
    end
    -- Door
    part("H3_Door_Frame", Vector3.new(4, 8.5, 0.8), cf(H3X+6, GY+5.25, H3Z+7.4), C.woodDark, MAT.wood)
    part("H3_Door",       Vector3.new(3.5, 8, 0.5), cf(H3X+6, GY+5, H3Z+7.7), C.wood, MAT.wood)
    -- Steps
    for step = 0, 2 do
    	part("H3_Step", Vector3.new(4.5, 0.5, 0.8),
    		cf(H3X+6, GY+0.25+step*0.5, H3Z+8.5-step*0.8), C.stone, MAT.stone)
    end
    -- Balcony railing upper floor front
    part("H3_Balcony", Vector3.new(10, 0.8, 2.5),
    	cf(H3X+4, GY+9.4, H3Z+8.5), C.wood, MAT.wood)
    part("H3_Rail_H", Vector3.new(10.5, 0.4, 0.4),
    	cf(H3X+4, GY+10.8, H3Z+9.6), C.woodDark, MAT.wood)
    for bi = 0, 8 do
    	part("H3_BalPost", Vector3.new(0.4, 1.5, 0.4),
    		cf(H3X-0.5 + bi*1.2, GY+10.2, H3Z+9.6), C.woodDark, MAT.wood)
    end
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 5: BARN / STORAGE
    -- ═══════════════════════════════════════════════════════════════
    
    local BRX, BRZ = 42, 10
    
    part("Barn_Foundation", Vector3.new(20, 0.8, 14), cf(BRX, GY+0.4, BRZ), C.stoneDark, MAT.stone)
    -- Barn walls (wooden boards)
    part("Barn_WallF", Vector3.new(20, 10, 1), cf(BRX, GY+6, BRZ+7),  C.wood, MAT.wood)
    part("Barn_WallB", Vector3.new(20, 10, 1), cf(BRX, GY+6, BRZ-7),  C.wood, MAT.wood)
    part("Barn_WallL", Vector3.new(1, 10, 14), cf(BRX-10, GY+6, BRZ), C.woodDark, MAT.wood)
    part("Barn_WallR", Vector3.new(1, 10, 14), cf(BRX+10, GY+6, BRZ), C.woodDark, MAT.wood)
    -- Plank texture strips
    for si = -3, 3 do
    	part("Barn_Plank_F", Vector3.new(20.2, 0.4, 0.6),
    		cf(BRX, GY+4+si*1.5, BRZ+7.3), C.woodLight, MAT.wood)
    end
    -- Large barn doors (double-wide, front)
    part("Barn_DoorL", Vector3.new(5, 9, 0.7), cf(BRX-3, GY+5.5, BRZ+7.4), C.woodDark, MAT.wood)
    part("Barn_DoorR", Vector3.new(5, 9, 0.7), cf(BRX+3, GY+5.5, BRZ+7.4), C.woodDark, MAT.wood)
    -- Door X-brace
    part("Barn_BraceL", Vector3.new(7, 0.5, 0.7),
    	cfr(BRX-3, GY+5, BRZ+7.5, 0, 0, math.rad(50)), C.wood, MAT.wood)
    part("Barn_BraceR", Vector3.new(7, 0.5, 0.7),
    	cfr(BRX+3, GY+5, BRZ+7.5, 0, 0, math.rad(-50)), C.wood, MAT.wood)
    -- Barn roof (steep pitched)
    wedge("Barn_Roof_F", Vector3.new(21, 7, 10),
    	cfr(BRX, GY+11+3.5, BRZ+2, math.rad(-25), 0, 0), C.thatchDark, MAT.fabric)
    wedge("Barn_Roof_B", Vector3.new(21, 7, 10),
    	cfr(BRX, GY+11+3.5, BRZ-2, math.rad(25), math.pi, 0), C.thatchDark, MAT.fabric)
    part("Barn_Ridge", Vector3.new(21.5, 0.8, 0.8),
    	cf(BRX, GY+17.5, BRZ), C.woodDark, MAT.wood)
    -- Hay bales inside/outside barn
    for _, hb in ipairs({{BRX+6, BRZ+3}, {BRX+7, BRZ-2}, {BRX-6, BRZ+2}}) do
    	cyl("HayBale", 3.2, 2.6, cf(hb[1], GY+1.3, hb[2]), C.haybale, MAT.fabric)
    	cyl("HayBaleRope", 3.4, 0.6, cf(hb[1], GY+1.3, hb[2]), C.ropeColor, MAT.plast)
    end
    -- Pitchfork leaned against barn
    part("PitchForkHandle", Vector3.new(0.3, 6, 0.3),
    	cfr(BRX-10.5, GY+4, BRZ+5, math.rad(-15), 0, 0), C.woodDark, MAT.wood)
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 6: VILLAGE WELL
    -- ═══════════════════════════════════════════════════════════════
    
    local WX, WZ = 8, 48
    
    -- Well base stones
    part("Well_Base", Vector3.new(7, 1.5, 7), cf(WX, GY+0.75, WZ), C.stone, MAT.stone)
    -- Well ring walls
    for ang = 0, 2*math.pi-0.01, math.pi/6 do
    	local r = 3.2
    	part("WellBlock", Vector3.new(2, 3.5, 2),
    		cfr(WX+math.cos(ang)*r, GY+2.25, WZ+math.sin(ang)*r, 0, ang, 0),
    		C.stone, MAT.stone)
    end
    -- Water
    cyl("WellWater", 5, 5, cf(WX, GY+0.8, WZ), C.waterBlue, MAT.glass, 0.3)
    -- Posts and beam
    part("WellPost_L", Vector3.new(0.6, 6, 0.6), cf(WX-3, GY+6, WZ), C.woodDark, MAT.wood)
    part("WellPost_R", Vector3.new(0.6, 6, 0.6), cf(WX+3, GY+6, WZ), C.woodDark, MAT.wood)
    part("WellBeam",   Vector3.new(7, 0.6, 0.6), cf(WX,   GY+9, WZ), C.wood,     MAT.wood)
    cyl("WellDrum",    2.4, 1.4, cf(WX, GY+8.8, WZ), C.wood, MAT.wood)
    -- Rope and bucket
    for s = 0, 5 do
    	part("WellRope", Vector3.new(0.25, 1.5, 0.25),
    		cf(WX, GY+8-s*1.2, WZ+0.3), C.ropeColor, MAT.plast)
    end
    part("WellBucket", Vector3.new(1.4, 1.8, 1.4), cf(WX, GY+2, WZ+0.3), C.wood, MAT.wood)
    cyl("WellBucketRim", 1.8, 1.6, cf(WX, GY+2.9, WZ+0.3), C.ironMetal, MAT.metal)
    -- Well canopy
    wedge("WellRoof_F", Vector3.new(8, 4, 5),
    	cfr(WX, GY+10+2, WZ+1.5, math.rad(-22), 0, 0), C.thatch, MAT.fabric)
    wedge("WellRoof_B", Vector3.new(8, 4, 5),
    	cfr(WX, GY+10+2, WZ-1.5, math.rad(22), math.pi, 0), C.thatch, MAT.fabric)
    part("WellRidge", Vector3.new(8.5, 0.6, 0.6), cf(WX, GY+13.5, WZ), C.thatchDark, MAT.wood)
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 7: STREAM + BRIDGE
    -- ═══════════════════════════════════════════════════════════════
    
    -- Stream channel running E-W on the west edge of the village
    part("Stream_Water",
    	Vector3.new(5, 1, 80),
    	cf(-68, GY-0.5, 15), C.waterBlue, MAT.glass, 0.3)
    part("Stream_Bed",
    	Vector3.new(7, 1, 82),
    	cf(-68, GY-1.2, 15), C.dirtDark, MAT.stone)
    -- Stream banks
    part("StreamBank_L", Vector3.new(3, 1.5, 82), cf(-65, GY+0.2, 15), C.grassGreen, MAT.grass)
    part("StreamBank_R", Vector3.new(3, 1.5, 82), cf(-71, GY+0.2, 15), C.grassGreen, MAT.grass)
    
    -- Wooden bridge across stream
    for bPlank = -3, 3 do
    	part("Bridge_Plank",
    		Vector3.new(7, 0.5, 1.8),
    		cf(-68, GY+0.5, bPlank*2.2), C.wood, MAT.wood)
    end
    -- Bridge rails
    part("Bridge_Rail_L", Vector3.new(0.6, 2, 16), cf(-65, GY+1.5, 0), C.woodDark, MAT.wood)
    part("Bridge_Rail_R", Vector3.new(0.6, 2, 16), cf(-71, GY+1.5, 0), C.woodDark, MAT.wood)
    -- Rail posts
    for ri = -3, 3 do
    	part("Bridge_Post_L", Vector3.new(0.5, 2.5, 0.5), cf(-65.2, GY+1.25, ri*2.2), C.woodDark, MAT.wood)
    	part("Bridge_Post_R", Vector3.new(0.5, 2.5, 0.5), cf(-70.8, GY+1.25, ri*2.2), C.woodDark, MAT.wood)
    end
    -- Bridge supports (below water)
    part("Bridge_Support_L", Vector3.new(1.5, 3, 3), cf(-65.5, GY-0.8, 0), C.stoneDark, MAT.stone)
    part("Bridge_Support_R", Vector3.new(1.5, 3, 3), cf(-70.5, GY-0.8, 0), C.stoneDark, MAT.stone)
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 8: VILLAGE PERIMETER FOREST (spruce trees)
    -- ═══════════════════════════════════════════════════════════════
    
    local treeRing = {
    	-- {x, z, height, scale}
    	{-75, -65, 16, 1.0}, {-55, -72, 18, 1.1}, {-35, -75, 14, 0.9},
    	{-10, -72, 20, 1.2}, { 15, -70, 15, 0.85},{  40, -68, 17, 1.0},
    	{ 62, -60, 16, 0.9}, { 72, -38, 20, 1.15},{ 75, -10, 18, 1.0},
    	{ 72,  20, 16, 0.9}, { 65,  48, 14, 0.85},{ 45,  65, 18, 1.1},
    	{ 15,  75, 20, 1.2}, {-15,  72, 15, 0.9}, {-38,  68, 17, 1.05},
    	{-60,  55, 16, 1.0}, {-72,  35, 14, 0.8}, {-78,  10, 18, 1.1},
    	{-75, -20, 16, 0.9}, {-70, -45, 20, 1.2},
    	-- Inner accent trees
    	{-58, -28, 12, 0.75},{  55, -35, 13, 0.8},{ 58,  35, 11, 0.7},
    	{-55,  40, 14, 0.85},
    }
    
    for _, td in ipairs(treeRing) do
    	local tx, tz, th, ts = td[1], td[2], td[3], td[4]
    	-- Trunk
    	cyl("SpruceT", th*0.28, 1.4*ts,
    		cf(tx, GY + th*0.14, tz), C.trunkBrown, MAT.wood)
    	-- Foliage tiers (3-4 stacked cones via spheres)
    	local tiers = {
    		{0.75, 5.5*ts, C.treeSpruceD},
    		{0.55, 4.0*ts, C.treeSpruce},
    		{0.35, 3.0*ts, C.foliageLight},
    		{0.18, 2.0*ts, C.foliageMid},
    	}
    	for _, tier in ipairs(tiers) do
    		sphere("SpruceFoliage", tier[2],
    			cf(tx, GY + th*tier[1], tz), tier[3], MAT.grass)
    	end
    end
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 9: QUEST / SIGN MARKERS
    -- ═══════════════════════════════════════════════════════════════
    
    local markers = {
    	{ x=  0, z= 62, icon="❓", col=C.questYellow, label="Quest Board" },
    	{ x=-28, z= 55, icon="❓", col=C.questYellow, label="Side Quest"  },
    	{ x=-55, z=-60, icon="☠",  col=C.dangerRed,   label="Danger!"    },
    }
    
    for _, mk in ipairs(markers) do
    	-- Sign post
    	part("SignPost", Vector3.new(0.5, 5, 0.5),
    		cf(mk.x, GY+2.5, mk.z), C.woodDark, MAT.wood)
    	-- Sign board
    	part("SignBoard", Vector3.new(4, 2.5, 0.4),
    		cf(mk.x, GY+6, mk.z), C.signBoard, MAT.wood)
    	-- Crosspiece
    	part("SignCross", Vector3.new(5, 0.4, 0.4),
    		cf(mk.x, GY+7.2, mk.z), C.woodDark, MAT.wood)
    	-- Neon marker
    	local markerPart = part("SignMarker", Vector3.new(0.9, 0.9, 0.9),
    		cf(mk.x, GY+8.2, mk.z), mk.col, MAT.neon)
    	addLight(markerPart, mk.col, 2, 10)
    	billboard(markerPart, mk.icon, 40)
    	-- Label
    	local labelPart = part("SignLabel", Vector3.new(0.1, 0.1, 0.1),
    		cf(mk.x, GY+6, mk.z-0.5), C.black, MAT.plast, 1)
    	billboard(labelPart, mk.label, 85)
    end
    
    -- Notice board (quest board with papers)
    local NBX, NBZ = 0, 62
    part("NB_Post_L", Vector3.new(0.5, 5, 0.5), cf(NBX-2.5, GY+2.5, NBZ), C.woodDark, MAT.wood)
    part("NB_Post_R", Vector3.new(0.5, 5, 0.5), cf(NBX+2.5, GY+2.5, NBZ), C.woodDark, MAT.wood)
    part("NB_Board",  Vector3.new(5.5, 3.8, 0.5), cf(NBX, GY+5, NBZ), C.crateWood, MAT.wood)
    -- Notices / papers
    for _, pd in ipairs({{-1.5, 0.6, 0.3}, {0.5, 0.4, -0.2}, {-0.6, -0.5, 0.4}}) do
    	part("Notice", Vector3.new(1.3, 1.8, 0.15),
    		cfr(NBX+pd[1], GY+5+pd[2], NBZ-0.3, 0, 0, pd[3]),
    		Color3.fromRGB(228, 218, 192), MAT.plast)
    end
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 10: LANTERN POSTS (street lamps)
    -- ═══════════════════════════════════════════════════════════════
    
    local lampPositions = {
    	{-12, -5}, {12, -5}, {-20, 20}, {20, 20},
    	{-5, 42},  {18, 42}, {-35, 5},  {35, -15},
    }
    for _, lp in ipairs(lampPositions) do
    	local lx, lz = lp[1], lp[2]
    	part("LampBase", Vector3.new(1, 0.8, 1),   cf(lx, GY+0.4, lz), C.stone, MAT.stone)
    	part("LampPole", Vector3.new(0.4, 7, 0.4), cf(lx, GY+4,   lz), C.ironMetal, MAT.metal)
    	part("LampArm",  Vector3.new(0.3, 0.3, 2), cf(lx, GY+7.3, lz+1), C.ironMetal, MAT.metal)
    	local flame = part("LampFlame", Vector3.new(0.9, 1.4, 0.9),
    		cf(lx, GY+6.5, lz+2), C.lanternAmb, MAT.neon)
    	addLight(flame, Color3.fromRGB(255, 195, 80), 3.5, 16)
    	sphere("LampSmoke", 0.7,
    		cf(lx, GY+7.8, lz+2), Color3.fromRGB(60,58,55), MAT.plast, 0.72)
    end
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 11: NPC PLACEHOLDER VILLAGERS
    -- ═══════════════════════════════════════════════════════════════
    
    local npcs = {
    	{  -5,  -5, "Farmer",   C.npcBrown },
    	{  18,  15, "Merchant", C.npcGreen },
    	{ -28,  20, "Elder",    C.npcRobe  },
    	{  35,   5, "Guard",    C.npcArmor },
    	{ -10,  48, "Child",    C.npcRed   },
    	{   0,  28, "Villager", C.npcBrown },
    	{  15, -18, "Smith",    C.npcArmor },
    }
    
    local function spawnNPC(x, z, name, col)
    	part("NPC_Torso",   Vector3.new(2, 2.5, 1),    cf(x, GY+2.75, z), col, MAT.plast)
    	sphere("NPC_Head",  1.8, cf(x, GY+5, z), C.npcSkin, MAT.plast)
    	part("NPC_LegL",    Vector3.new(0.9, 2, 0.9),  cf(x-0.55, GY+1, z), col, MAT.plast)
    	part("NPC_LegR",    Vector3.new(0.9, 2, 0.9),  cf(x+0.55, GY+1, z), col, MAT.plast)
    	part("NPC_ArmL",    Vector3.new(0.8, 2.2, 0.8),
    		cfr(x-1.4, GY+2.5, z, 0, 0, math.rad(20)), col, MAT.plast)
    	part("NPC_ArmR",    Vector3.new(0.8, 2.2, 0.8),
    		cfr(x+1.4, GY+2.5, z, 0, 0, math.rad(-20)), col, MAT.plast)
    	local anchor = part("NPC_LblAnchor", Vector3.new(0.1, 0.1, 0.1),
    		cf(x, GY+7, z), C.black, MAT.plast, 1)
    	billboard(anchor, name, 90)
    end
    
    for _, npc in ipairs(npcs) do
    	spawnNPC(npc[1], npc[2], npc[3], npc[4])
    end
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 12: DECORATIVE PROPS (barrels, crates, sacks)
    -- ═══════════════════════════════════════════════════════════════
    
    local props = {
    	{38,  8, "barrel"},  {40, 12, "crate"},  {42, 5,  "sack"},
    	{-14,-12, "barrel"}, {-16,-8, "crate"},  {-42, 2, "barrel"},
    	{32, -18, "sack"},   {28, 10, "crate"},  {-25,-18, "barrel"},
    }
    for _, pp in ipairs(props) do
    	local px, pz, ptype = pp[1], pp[2], pp[3]
    	if ptype == "barrel" then
    		cyl("Barrel", 2.5, 2, cf(px, GY+1.25, pz), C.barrelDark, MAT.wood)
    		cyl("BarrelRingT", 2.7, 1.5, cf(px, GY+0.9, pz), C.ironMetal, MAT.metal)
    		cyl("BarrelRingB", 2.7, 1.5, cf(px, GY+1.7, pz), C.ironMetal, MAT.metal)
    	elseif ptype == "crate" then
    		part("Crate", Vector3.new(2, 2, 2),
    			cfr(px, GY+1, pz, 0, math.random()*math.pi, 0),
    			C.crateWood, MAT.wood)
    		part("CrateLid", Vector3.new(2.2, 0.3, 2.2),
    			cf(px, GY+2.15, pz), C.woodDark, MAT.wood)
    	else
    		sphere("Sack", 2, cf(px, GY+1, pz), C.sackColor, MAT.fabric)
    	end
    end
    
    -- ── FINAL REPORT ─────────────────────────────────────────────────
    local count = #folder:GetDescendants()
    print(string.format(
    	"[EmeraldHaven Zone2] ✅ Done!  %d objects created in workspace.EmeraldHaven_Zone2",
    	count
    ))
    end
    print("[HighgardPlugin] ✅ Zone2_EmeraldHaven complete.")
end


-- ────────────────────────────────────────────────────────────────
zoneFunctions["Zone3_SunScorch"] = function()
    print("[HighgardPlugin] 🔨 Building Zone3_SunScorch...")
    do
    local ORIGIN = CFrame.new(-300, 50, -60)
    
    -- ── Palette ─────────────────────────────────────────────────────
    local C = {
    	sand         = Color3.fromRGB(218, 182, 100),
    	sandLight    = Color3.fromRGB(238, 210, 138),
    	sandDark     = Color3.fromRGB(188, 148,  72),
    	sandDeep     = Color3.fromRGB(165, 122,  52),
    	sandstone    = Color3.fromRGB(210, 185, 140),
    	sandstoneDk  = Color3.fromRGB(175, 148, 105),
    	sandstoneWrm = Color3.fromRGB(225, 198, 152),
    	dune         = Color3.fromRGB(205, 168,  85),
    	duneShadow   = Color3.fromRGB(158, 128,  55),
    	oasisWater   = Color3.fromRGB( 68, 148, 205),
    	oasisWaterSh = Color3.fromRGB( 52, 115, 172),
    	oasisGrass   = Color3.fromRGB(115, 165,  72),
    	oasisGrassL  = Color3.fromRGB(142, 188,  95),
    	palmTrunk    = Color3.fromRGB(112,  82,  35),
    	palmFrond    = Color3.fromRGB( 48, 118,  45),
    	palmFrondL   = Color3.fromRGB( 72, 145,  62),
    	stone        = Color3.fromRGB(148, 142, 135),
    	stoneDark    = Color3.fromRGB(105,  98,  90),
    	stoneRuin    = Color3.fromRGB(128, 118, 100),
    	clay         = Color3.fromRGB(185, 148,  95),
    	dome         = Color3.fromRGB(195, 165, 115),
    	domeDark     = Color3.fromRGB(155, 125,  82),
    	wallCrenMat  = Color3.fromRGB(200, 175, 128),
    	archDark     = Color3.fromRGB(145, 115,  75),
    	wood         = Color3.fromRGB(128,  82,  38),
    	woodDark     = Color3.fromRGB( 78,  48,  18),
    	ironMetal    = Color3.fromRGB( 60,  60,  65),
    	ropeColor    = Color3.fromRGB(158, 128,  78),
    	potTerracot  = Color3.fromRGB(195, 105,  60),
    	potBrown     = Color3.fromRGB(148,  78,  38),
    	crateWood    = Color3.fromRGB(148, 108,  58),
    	barrelDark   = Color3.fromRGB( 92,  60,  28),
    	fabricOrange = Color3.fromRGB(205, 108,  38),
    	fabricBlue   = Color3.fromRGB( 55,  95, 168),
    	fabricWhite  = Color3.fromRGB(232, 222, 200),
    	lanternAmb   = Color3.fromRGB(255, 195,  55),
    	torchFlame   = Color3.fromRGB(255, 130,  20),
    	npcSkin      = Color3.fromRGB(190, 145,  88),  -- sun-tanned
    	npcArmor     = Color3.fromRGB(165, 135,  80),  -- desert guard
    	npcRobe      = Color3.fromRGB(232, 218, 185),  -- white robe
    	npcDark      = Color3.fromRGB( 38,  38,  50),
    	dangerRed    = Color3.fromRGB(195,  38,  38),
    	skullWhite   = Color3.fromRGB(228, 222, 210),
    	dustColor    = Color3.fromRGB(188, 158,  95),
    	black        = Color3.fromRGB( 20,  18,  15),
    	cactusDk     = Color3.fromRGB( 62, 105,  55),
    	cactusLt     = Color3.fromRGB( 80, 132,  68),
    	boneDry      = Color3.fromRGB(210, 195, 158),
    }
    
    local M = Enum.Material
    local MAT = {
    	stone  = M.SmoothPlastic,
    	cobble = M.Cobblestone,
    	wood   = M.Wood,
    	brick  = M.Brick,
    	metal  = M.Metal,
    	glass  = M.Glass,
    	neon   = M.Neon,
    	grass  = M.Grass,
    	slate  = M.Slate,
    	fabric = M.Fabric,
    	plast  = M.SmoothPlastic,
    	sand   = M.Sand,
    	ice    = M.Ice,
    }
    
    -- ── Root folder ──────────────────────────────────────────────────
    local folder = Instance.new("Folder")
    folder.Name   = "SunScorch_Zone3"
    folder.Parent = workspace
    
    -- ── Helper functions ─────────────────────────────────────────────
    local function cf(x, y, z)           return ORIGIN * CFrame.new(x, y, z) end
    local function cfr(x,y,z,rx,ry,rz)  return cf(x,y,z) * CFrame.Angles(rx,ry,rz) end
    
    local function part(name, size, cframe, color, material, transparency)
    	local p = Instance.new("Part")
    	p.Name          = name
    	p.Size          = size
    	p.CFrame        = cframe
    	p.Color         = color or C.sand
    	p.Material      = material or MAT.sand
    	p.Transparency  = transparency or 0
    	p.Anchored      = true
    	p.CastShadow    = true
    	p.TopSurface    = Enum.SurfaceType.Smooth
    	p.BottomSurface = Enum.SurfaceType.Smooth
    	p.Parent        = folder
    	return p
    end
    
    local function wedge(name, size, cframe, color, material)
    	local p = Instance.new("WedgePart")
    	p.Name          = name
    	p.Size          = size
    	p.CFrame        = cframe
    	p.Color         = color or C.dune
    	p.Material      = material or MAT.sand
    	p.Anchored      = true
    	p.TopSurface    = Enum.SurfaceType.Smooth
    	p.BottomSurface = Enum.SurfaceType.Smooth
    	p.Parent        = folder
    	return p
    end
    
    local function cyl(name, height, diam, cframe, color, material, transp)
    	local p = Instance.new("Part")
    	p.Name          = name
    	p.Shape         = Enum.PartType.Cylinder
    	p.Size          = Vector3.new(height, diam, diam)
    	p.CFrame        = cframe * CFrame.Angles(0, 0, math.pi/2)
    	p.Color         = color or C.sandstone
    	p.Material      = material or MAT.stone
    	p.Transparency  = transp or 0
    	p.Anchored      = true
    	p.TopSurface    = Enum.SurfaceType.Smooth
    	p.BottomSurface = Enum.SurfaceType.Smooth
    	p.Parent        = folder
    	return p
    end
    
    local function sphere(name, diam, cframe, color, material, transp)
    	local p = Instance.new("Part")
    	p.Name         = name
    	p.Shape        = Enum.PartType.Ball
    	p.Size         = Vector3.new(diam, diam, diam)
    	p.CFrame       = cframe
    	p.Color        = color or C.sand
    	p.Material     = material or MAT.plast
    	p.Transparency = transp or 0
    	p.Anchored     = true
    	p.Parent       = folder
    	return p
    end
    
    local function addLight(parent, color, brightness, range)
    	local l = Instance.new("PointLight", parent)
    	l.Color      = color
    	l.Brightness = brightness or 3
    	l.Range      = range or 18
    	l.Enabled    = true
    end
    
    local function billboard(parent, text, size)
    	local bg = Instance.new("BillboardGui", parent)
    	bg.Size        = UDim2.fromOffset(size or 60, 28)
    	bg.StudsOffset = Vector3.new(0, 3, 0)
    	bg.AlwaysOnTop = false
    	local lbl = Instance.new("TextLabel", bg)
    	lbl.Size                   = UDim2.fromScale(1, 1)
    	lbl.BackgroundTransparency = 1
    	lbl.Text                   = text
    	lbl.TextColor3             = Color3.new(1, 1, 1)
    	lbl.TextScaled             = true
    end
    
    local GY = 0  -- base ground Y (relative to ORIGIN)
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 1: DESERT BASE TERRAIN
    -- ═══════════════════════════════════════════════════════════════
    
    -- Flat sand base
    part("DesertBase",
    	Vector3.new(240, 4, 200),
    	cf(0, GY - 2, 0), C.sand, MAT.sand)
    
    -- Transition strip (east edge — grass fades to sand)
    part("BiomeTransition_E",
    	Vector3.new(18, 1, 200),
    	cf(112, GY + 0.5, 0), C.sandLight, MAT.grass)
    part("BiomeTransition_E2",
    	Vector3.new(8, 1, 200),
    	cf(120, GY + 0.5, 0), C.oasisGrass, MAT.grass)
    
    -- Top sand layer
    part("DesertTop",
    	Vector3.new(230, 1.5, 190),
    	cf(0, GY + 0.7, 0), C.sandLight, MAT.sand)
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 2: DUNES (large sand wave formations)
    -- ═══════════════════════════════════════════════════════════════
    
    -- Each dune = wedge pair (windward + leeward slope) + flat crest
    local duneData = {
    	-- { cx, cz, wX, wZ, h,   rot }
    	{  -55, -60,  80, 30, 18, math.rad( 0)  },
    	{   40, -65,  65, 25, 14, math.rad(15)  },
    	{ -100, -20,  50, 22, 22, math.rad(-10) },
    	{   85,  10,  70, 28, 16, math.rad( 5)  },
    	{  -30,  55,  90, 32, 20, math.rad( 8)  },
    	{   55,  72,  60, 24, 12, math.rad(-12) },
    	{ -105,  55,  45, 18, 25, math.rad( 4)  },
    	{   10, -88,  55, 20, 15, math.rad(-5)  },
    	{  -70,  85,  75, 26, 19, math.rad( 6)  },
    	{   95, -55,  50, 18, 10, math.rad(20)  },
    }
    
    for i, d in ipairs(duneData) do
    	local cx, cz, wX, wZ, h, rot = d[1], d[2], d[3], d[4], d[5], d[6]
    	-- Windward slope (gentle)
    	wedge("Dune_Wind_"..i,
    		Vector3.new(wX, h, wZ * 0.6),
    		cfr(cx, GY + h/2, cz - wZ*0.3, 0, rot, 0),
    		C.dune, MAT.sand)
    	-- Leeward slope (steeper)
    	wedge("Dune_Lee_"..i,
    		Vector3.new(wX, h, wZ * 0.4),
    		cfr(cx, GY + h/2, cz + wZ*0.2, 0, rot + math.pi, 0),
    		C.duneShadow, MAT.sand)
    	-- Crest top
    	part("Dune_Crest_"..i,
    		Vector3.new(wX, 1.5, 3),
    		cfr(cx, GY + h, cz, 0, rot, 0),
    		C.sandLight, MAT.sand)
    end
    
    -- Small ripple dunes (secondary, scattered)
    local ripples = {
    	{-15, -30, 30, 8, 6},  {30,  20, 22, 6, 4},
    	{-80,  30, 28, 8, 5},  {65, -30, 25, 5, 4},
    	{ 20,  90, 35, 9, 5},  {-40, -85,26, 7, 5},
    }
    for _, r in ipairs(ripples) do
    	wedge("Ripple",
    		Vector3.new(r[3], r[5], r[4]),
    		cfr(r[1], GY + r[5]/2, r[2], 0, math.random() * math.pi, 0),
    		C.sandLight, MAT.sand)
    end
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 3: OASIS (center of zone)
    -- ═══════════════════════════════════════════════════════════════
    
    local OX, OZ = 20, 25  -- oasis center (relative)
    
    -- Water pool (shallow oval)
    part("Oasis_Water",
    	Vector3.new(22, 1.2, 16),
    	cf(OX, GY - 0.4, OZ), C.oasisWater, MAT.glass, 0.22)
    part("Oasis_WaterDeep",
    	Vector3.new(18, 1.5, 12),
    	cf(OX, GY - 0.8, OZ), C.oasisWaterSh, MAT.glass, 0.35)
    
    -- Muddy bed under water
    part("Oasis_Bed",
    	Vector3.new(24, 1, 18),
    	cf(OX, GY - 1.5, OZ), C.sandDeep, MAT.sand)
    
    -- Grass strip around water
    part("Oasis_Grass",
    	Vector3.new(34, 0.8, 28),
    	cf(OX, GY + 0.3, OZ), C.oasisGrass, MAT.grass)
    part("Oasis_GrassInner",
    	Vector3.new(26, 0.6, 20),
    	cf(OX, GY + 0.5, OZ), C.oasisGrassL, MAT.grass)
    
    -- Small stones / rocks at water's edge
    local oasisRocks = {
    	{OX - 11, OZ + 6}, {OX + 10, OZ - 7}, {OX - 9, OZ - 5},
    	{OX + 11, OZ + 4}, {OX + 2, OZ + 8},  {OX - 4, OZ - 9},
    }
    for _, rk in ipairs(oasisRocks) do
    	local s = math.random(8, 16) * 0.1
    	sphere("OasisRock", s,
    		cf(rk[1] + (math.random()-0.5)*2, GY + s/2 - 0.1, rk[2] + (math.random()-0.5)*2),
    		C.stoneRuin, MAT.slate)
    end
    
    -- ── PALMS ────────────────────────────────────────────────────────
    
    local palmData = {
    	-- {x, z, height, lean_x, lean_z}
    	{ OX - 14, OZ - 4,  17, math.rad(-12), math.rad( 8) },
    	{ OX + 13, OZ + 3,  19, math.rad( 10), math.rad(-6) },
    	{ OX - 10, OZ + 9,  16, math.rad( 6),  math.rad(14) },
    	{ OX +  8, OZ - 10, 18, math.rad(-8),  math.rad(-10)},
    	{ OX - 16, OZ + 7,  15, math.rad(-15), math.rad( 5) },
    	{ OX + 15, OZ - 3,  20, math.rad( 8),  math.rad(-12)},
    	{ OX +  2, OZ + 12, 16, math.rad( 5),  math.rad(18) },
    }
    
    for pi2, pd in ipairs(palmData) do
    	local px, pz, ph = pd[1], pd[2], pd[3]
    	local lx, lz = pd[4], pd[5]
    
    	-- Trunk (segmented for lean effect)
    	local segments = 4
    	for s = 1, segments do
    		local sy = GY + (s - 0.5) * (ph / segments)
    		local lean_s = (s / segments)
    		local sx = px + math.sin(lx) * ph * lean_s * 0.5
    		local sz = pz + math.sin(lz) * ph * lean_s * 0.5
    		cyl("PalmTrunk_"..pi2.."_"..s,
    			ph / segments + 0.5,
    			1.4 - s * 0.08,
    			cfr(sx, sy, sz, lx * lean_s * 0.5, 0, lz * lean_s * 0.5),
    			C.palmTrunk, MAT.wood)
    	end
    
    	-- Crown base
    	local topX = px + math.sin(lx) * ph * 0.5
    	local topZ = pz + math.sin(lz) * ph * 0.5
    	sphere("PalmCrown_"..pi2, 3.5,
    		cf(topX, GY + ph + 0.5, topZ), C.palmFrond, MAT.grass)
    
    	-- Fronds (8 drooping branches)
    	for fi = 1, 8 do
    		local fa = (fi / 8) * 2 * math.pi
    		local fLen = 6 + math.random() * 2
    		local fdx  = math.cos(fa) * fLen
    		local fdz  = math.sin(fa) * fLen
    		wedge("PalmFrond_"..pi2.."_"..fi,
    			Vector3.new(1.2, 0.6, fLen),
    			cfr(topX + fdx*0.4, GY + ph - 0.5, topZ + fdz*0.4,
    				math.rad(-18), fa + math.pi/2, 0),
    			fi % 2 == 0 and C.palmFrond or C.palmFrondL, MAT.grass)
    	end
    
    	-- Coconuts cluster
    	for ci = 1, 3 do
    		local ca = (ci / 3) * 2 * math.pi + 0.5
    		sphere("Coconut_"..pi2.."_"..ci, 0.9,
    			cf(topX + math.cos(ca)*0.8, GY + ph - 1, topZ + math.sin(ca)*0.8),
    			Color3.fromRGB(88, 58, 22), MAT.wood)
    	end
    end
    
    -- ── OASIS RUINS (ancient stone blocks) ───────────────────────────
    
    part("Ruin_Wall1",
    	Vector3.new(8, 4, 1.5),
    	cfr(OX - 18, GY + 2, OZ - 12, 0, math.rad(25), 0),
    	C.stoneRuin, MAT.slate)
    part("Ruin_Wall2",
    	Vector3.new(5, 3, 1.5),
    	cfr(OX + 16, GY + 1.5, OZ + 14, 0, math.rad(-15), 0),
    	C.stoneRuin, MAT.slate)
    -- Toppled column
    cyl("Ruin_Column",
    	6, 2.5,
    	cfr(OX - 22, GY + 1.25, OZ + 8, 0, 0, math.pi/2),
    	C.stoneRuin, MAT.slate)
    -- Broken column stump
    cyl("Ruin_Stump",
    	3, 2.5,
    	cf(OX + 18, GY + 1.5, OZ - 8),
    	C.stoneRuin, MAT.slate)
    -- Scattered blocks
    local ruinBlocks = {
    	{OX - 20, OZ + 10, 3, 2, 2},
    	{OX + 20, OZ + 12, 2.5, 3, 2},
    	{OX - 19, OZ - 14, 4, 2, 3},
    	{OX + 22, OZ - 10, 2, 2, 2.5},
    }
    for _, rb in ipairs(ruinBlocks) do
    	part("RuinBlock",
    		Vector3.new(rb[3], rb[5], rb[4]),
    		cfr(rb[1], GY + rb[5]/2, rb[2], 0, math.random() * math.pi * 2, 0),
    		C.stoneRuin, MAT.slate)
    end
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 4: DESERT FORT / SETTLEMENT (northwest)
    -- ═══════════════════════════════════════════════════════════════
    
    local FX, FZ = -65, -60   -- fort center
    local FW, FD = 42, 32     -- fort width, depth (half = 21, 16)
    local FH     = 10         -- wall height
    local FT     = 2.5        -- wall thickness
    
    -- ── Fort ground ──────────────────────────────────────────────────
    part("Fort_Ground",
    	Vector3.new(FW + 8, 1, FD + 8),
    	cf(FX, GY - 0.5, FZ), C.sandDeep, MAT.sand)
    part("Fort_CourtFloor",
    	Vector3.new(FW - FT*2, 0.8, FD - FT*2),
    	cf(FX, GY + 0.4, FZ), C.sandstone, MAT.stone)
    
    -- ── Four perimeter walls ──────────────────────────────────────────
    
    -- North wall
    part("Fort_Wall_N",
    	Vector3.new(FW, FH, FT),
    	cf(FX, GY + FH/2, FZ - FD/2), C.sandstone, MAT.brick)
    -- South wall (has gate opening)
    part("Fort_Wall_S_L",
    	Vector3.new((FW/2 - 7), FH, FT),
    	cf(FX - (7 + (FW/2 - 7)/2), GY + FH/2, FZ + FD/2),
    	C.sandstone, MAT.brick)
    part("Fort_Wall_S_R",
    	Vector3.new((FW/2 - 7), FH, FT),
    	cf(FX + (7 + (FW/2 - 7)/2), GY + FH/2, FZ + FD/2),
    	C.sandstone, MAT.brick)
    -- Gate lintel (above opening)
    part("Fort_Wall_S_Top",
    	Vector3.new(14, FH * 0.35, FT),
    	cf(FX, GY + FH - FH * 0.175, FZ + FD/2), C.sandstone, MAT.brick)
    -- East wall
    part("Fort_Wall_E",
    	Vector3.new(FT, FH, FD),
    	cf(FX + FW/2, GY + FH/2, FZ), C.sandstone, MAT.brick)
    -- West wall
    part("Fort_Wall_W",
    	Vector3.new(FT, FH, FD),
    	cf(FX - FW/2, GY + FH/2, FZ), C.sandstone, MAT.brick)
    
    -- ── Wall battlements / merlons ────────────────────────────────────
    
    -- North wall merlons
    for mi = -4, 4 do
    	part("Merlon_N",
    		Vector3.new(2.2, 3, FT + 0.6),
    		cf(FX + mi*4.5, GY + FH + 1.5, FZ - FD/2), C.wallCrenMat, MAT.brick)
    end
    -- South wall merlons (both sides of gate)
    for mi = -5, -2 do
    	part("Merlon_S",
    		Vector3.new(2.2, 3, FT + 0.6),
    		cf(FX + mi*3.8, GY + FH + 1.5, FZ + FD/2), C.wallCrenMat, MAT.brick)
    end
    for mi = 2, 5 do
    	part("Merlon_S",
    		Vector3.new(2.2, 3, FT + 0.6),
    		cf(FX + mi*3.8, GY + FH + 1.5, FZ + FD/2), C.wallCrenMat, MAT.brick)
    end
    -- East/West merlons
    for mi = -3, 3 do
    	part("Merlon_E",
    		Vector3.new(FT + 0.6, 3, 2.2),
    		cf(FX + FW/2, GY + FH + 1.5, FZ + mi*4), C.wallCrenMat, MAT.brick)
    	part("Merlon_W",
    		Vector3.new(FT + 0.6, 3, 2.2),
    		cf(FX - FW/2, GY + FH + 1.5, FZ + mi*4), C.wallCrenMat, MAT.brick)
    end
    
    -- ── Corner towers (4, rectangular, lower) ────────────────────────
    
    local fortCorners = {
    	{ FX + FW/2 + 2.5, FZ - FD/2 - 2.5 },
    	{ FX - FW/2 - 2.5, FZ - FD/2 - 2.5 },
    	{ FX + FW/2 + 2.5, FZ + FD/2 + 2.5 },
    	{ FX - FW/2 - 2.5, FZ + FD/2 + 2.5 },
    }
    
    for ti2, tc in ipairs(fortCorners) do
    	local tx2, tz2 = tc[1], tc[2]
    	local tH = FH + 5   -- towers slightly taller than walls
    	-- Tower body
    	part("Fort_Tower_"..ti2,
    		Vector3.new(8, tH, 8),
    		cf(tx2, GY + tH/2, tz2), C.sandstone, MAT.brick)
    	-- Tower top platform
    	part("Fort_TowerTop_"..ti2,
    		Vector3.new(9.5, 1, 9.5),
    		cf(tx2, GY + tH + 0.5, tz2), C.sandstoneDk, MAT.brick)
    	-- Tower merlons (4 sides)
    	for mi2 = -1, 1, 2 do
    		part("Fort_TowerMerl_NS_"..ti2,
    			Vector3.new(2.2, 3, 2),
    			cf(tx2 + mi2*2.8, GY + tH + 2, tz2), C.wallCrenMat, MAT.brick)
    		part("Fort_TowerMerl_EW_"..ti2,
    			Vector3.new(2, 3, 2.2),
    			cf(tx2, GY + tH + 2, tz2 + mi2*2.8), C.wallCrenMat, MAT.brick)
    	end
    	-- Arrow slit windows
    	part("Fort_ArrowSlit_"..ti2,
    		Vector3.new(0.5, 3, 1),
    		cf(tx2 + (ti2 <= 2 and 4 or -4), GY + tH*0.6, tz2),
    		C.archDark, MAT.brick, 0)
    end
    
    -- ── Main Gate arch (south) ────────────────────────────────────────
    
    -- Gate pillars
    part("Gate_Pillar_L",
    	Vector3.new(4, FH, 4),
    	cf(FX - 8, GY + FH/2, FZ + FD/2), C.sandstoneDk, MAT.brick)
    part("Gate_Pillar_R",
    	Vector3.new(4, FH, 4),
    	cf(FX + 8, GY + FH/2, FZ + FD/2), C.sandstoneDk, MAT.brick)
    
    -- Gate arch (layered blocks approximating an arch)
    local archPairs = {
    	{ 6, FH - 1.5, 2.8 }, { 5, FH + 0.5, 2.8 },
    	{ 4, FH + 2,   2.4 }, { 3, FH + 3.2, 2.0 },
    	{ 2, FH + 4,   1.5 }, { 1, FH + 4.5, 1.0 },
    }
    for _, ap in ipairs(archPairs) do
    	part("ArchBlock_L",
    		Vector3.new(1.5, ap[3], FT + 1),
    		cf(FX - ap[1], GY + ap[2], FZ + FD/2), C.sandstoneWrm, MAT.brick)
    	part("ArchBlock_R",
    		Vector3.new(1.5, ap[3], FT + 1),
    		cf(FX + ap[1], GY + ap[2], FZ + FD/2), C.sandstoneWrm, MAT.brick)
    end
    -- Arch keystone
    part("ArchKeystone",
    	Vector3.new(2.5, 2, FT + 1),
    	cf(FX, GY + FH + 4.8, FZ + FD/2), C.sandstoneDk, MAT.brick)
    
    -- Wooden gate doors (two panels, slightly open)
    part("Gate_DoorL",
    	Vector3.new(6, FH - 2, 0.8),
    	cfr(FX - 3.5, GY + (FH-2)/2 + 1, FZ + FD/2 - 1, 0, math.rad(-20), 0),
    	C.wood, MAT.wood)
    part("Gate_DoorR",
    	Vector3.new(6, FH - 2, 0.8),
    	cfr(FX + 3.5, GY + (FH-2)/2 + 1, FZ + FD/2 - 1, 0, math.rad(20), 0),
    	C.wood, MAT.wood)
    -- Door iron banding
    for gi = 1, 4 do
    	part("DoorBand_L",
    		Vector3.new(6.2, 0.5, 0.9),
    		cfr(FX - 3.5, GY + 1 + gi*2.2, FZ + FD/2 - 1, 0, math.rad(-20), 0),
    		C.ironMetal, MAT.metal)
    	part("DoorBand_R",
    		Vector3.new(6.2, 0.5, 0.9),
    		cfr(FX + 3.5, GY + 1 + gi*2.2, FZ + FD/2 - 1, 0, math.rad(20), 0),
    		C.ironMetal, MAT.metal)
    end
    
    -- ── Dome building (inside fort, north side) ────────────────────────
    
    local DX, DZ = FX, FZ - 8   -- dome center
    
    -- Dome base (square building)
    part("Dome_Base",
    	Vector3.new(18, 8, 16),
    	cf(DX, GY + 4, DZ), C.clay, MAT.brick)
    -- Dome drum (cylindrical support)
    cyl("Dome_Drum", 16, 4,
    	cf(DX, GY + 8 + 2, DZ), C.sandstone, MAT.brick)
    -- Dome sphere
    sphere("Dome_Main", 14,
    	cf(DX, GY + 13, DZ), C.dome, MAT.plast)
    -- Dome highlight (lighter top cap)
    sphere("Dome_Cap", 8,
    	cf(DX, GY + 15.5, DZ), C.sandstoneWrm, MAT.plast)
    -- Dome finial
    cyl("Dome_Finial", 4, 0.8,
    	cf(DX, GY + 19.5, DZ), C.domeDark, MAT.metal)
    sphere("Dome_FinialBall", 1.2,
    	cf(DX, GY + 21.5, DZ), C.fabricOrange, MAT.plast)
    
    -- Dome entrance arches (4 sides)
    local domeArches = {
    	{ DX,        DZ - 8.2, 0           },
    	{ DX,        DZ + 8.2, math.pi     },
    	{ DX - 9.2,  DZ,       math.pi/2   },
    	{ DX + 9.2,  DZ,      -math.pi/2   },
    }
    for _, da in ipairs(domeArches) do
    	part("Dome_Arch",
    		Vector3.new(5, 6, 1.5),
    		cfr(da[1], GY + 3, da[2], 0, da[3], 0),
    		C.sandstoneDk, MAT.brick)
    	-- Arch opening (darker indent)
    	part("Dome_ArchOpen",
    		Vector3.new(3.5, 5, 1.6),
    		cfr(da[1], GY + 2.5, da[2], 0, da[3], 0),
    		C.archDark, MAT.brick)
    end
    
    -- Dome decorative horizontal band
    part("Dome_Band",
    	Vector3.new(18.5, 1, 16.5),
    	cf(DX, GY + 7.5, DZ), C.sandstoneDk, MAT.brick)
    
    -- Small side buildings (flanking dome)
    part("SideBldg_L",
    	Vector3.new(10, 6, 10),
    	cf(FX - 12, GY + 3, FZ - 6), C.clay, MAT.brick)
    part("SideBldg_R",
    	Vector3.new(10, 6, 10),
    	cf(FX + 12, GY + 3, FZ - 6), C.clay, MAT.brick)
    -- Flat roofs with parapet
    part("SideRoof_L",
    	Vector3.new(11, 0.8, 11),
    	cf(FX - 12, GY + 6.4, FZ - 6), C.sandstoneDk, MAT.stone)
    part("SideRoof_R",
    	Vector3.new(11, 0.8, 11),
    	cf(FX + 12, GY + 6.4, FZ - 6), C.sandstoneDk, MAT.stone)
    -- Roof parapets
    for _, px2 in ipairs({FX - 12, FX + 12}) do
    	part("Parapet_N", Vector3.new(11, 1.5, 0.8), cf(px2, GY+7.5, FZ - 11.4), C.wallCrenMat, MAT.brick)
    	part("Parapet_S", Vector3.new(11, 1.5, 0.8), cf(px2, GY+7.5, FZ - 0.6),  C.wallCrenMat, MAT.brick)
    	part("Parapet_E", Vector3.new(0.8, 1.5, 11), cf(px2 + 5.4, GY+7.5, FZ-6), C.wallCrenMat, MAT.brick)
    	part("Parapet_W", Vector3.new(0.8, 1.5, 11), cf(px2 - 5.4, GY+7.5, FZ-6), C.wallCrenMat, MAT.brick)
    end
    
    -- Side building windows (narrow, arched style)
    local winPositions = {
    	{FX - 12 - 5, FZ - 6}, {FX + 12 + 5, FZ - 6},
    	{FX - 12, FZ - 6 - 5}, {FX + 12, FZ - 6 - 5},
    }
    for _, wp in ipairs(winPositions) do
    	part("SideWindow",
    		Vector3.new(0.5, 2, 1.5),
    		cf(wp[1], GY + 4, wp[2]), C.archDark, MAT.plast)
    end
    
    -- ── Courtyard well (inside fort) ─────────────────────────────────
    
    local CWX, CWZ = FX + 10, FZ + 8
    cyl("Fort_Well_Wall", 4, 3,     cf(CWX, GY + 2, CWZ),   C.sandstone, MAT.brick)
    cyl("Fort_Well_Water", 2.8, 1,  cf(CWX, GY + 0.5, CWZ), C.oasisWater, MAT.glass, 0.3)
    part("Fort_Well_Beam",
    	Vector3.new(0.5, 0.5, 4), cf(CWX, GY + 4.5, CWZ), C.wood, MAT.wood)
    part("Fort_Well_Support_L",
    	Vector3.new(0.5, 3, 0.5), cf(CWX - 1.8, GY + 3, CWZ), C.wood, MAT.wood)
    part("Fort_Well_Support_R",
    	Vector3.new(0.5, 3, 0.5), cf(CWX + 1.8, GY + 3, CWZ), C.wood, MAT.wood)
    -- Well bucket
    part("Fort_Well_Bucket",
    	Vector3.new(1.2, 1.5, 1.2), cf(CWX, GY + 2.5, CWZ + 0.3), C.wood, MAT.wood)
    cyl("Fort_Well_Rope", 3.5, 0.4,
    	cf(CWX, GY + 3.8, CWZ + 0.3), C.ropeColor, MAT.plast)
    
    -- ── Fort props (barrels, pots, sacks) ────────────────────────────
    
    local fortProps = {
    	{ FX - 15, FZ + 8,  "barrel" },
    	{ FX - 13, FZ + 5,  "pot"    },
    	{ FX - 16, FZ + 5,  "barrel" },
    	{ FX + 15, FZ + 10, "sack"   },
    	{ FX + 13, FZ + 7,  "crate"  },
    	{ FX + 16, FZ + 7,  "pot"    },
    	{ FX - 6,  FZ + 12, "crate"  },
    	{ FX + 6,  FZ + 12, "barrel" },
    }
    for _, fp in ipairs(fortProps) do
    	local px3, pz3, ptype = fp[1], fp[2], fp[3]
    	if ptype == "barrel" then
    		cyl("Barrel", 2.5, 2, cf(px3, GY+1.25, pz3), C.barrelDark, MAT.wood)
    		cyl("BarrelRing", 2.7, 1.5, cf(px3, GY+0.8, pz3), C.ironMetal, MAT.metal)
    		cyl("BarrelRing2", 2.7, 1.5, cf(px3, GY+1.7, pz3), C.ironMetal, MAT.metal)
    	elseif ptype == "pot" then
    		sphere("Pot_Body", 2.2, cf(px3, GY+1, pz3), C.potTerracot, MAT.brick)
    		cyl("Pot_Neck", 1.5, 1.2, cf(px3, GY+1.8, pz3), C.potBrown, MAT.brick)
    	elseif ptype == "crate" then
    		part("Crate", Vector3.new(2, 2, 2),
    			cfr(px3, GY+1, pz3, 0, math.random()*math.pi, 0),
    			C.crateWood, MAT.wood)
    	elseif ptype == "sack" then
    		sphere("Sack", 2, cf(px3, GY+1, pz3), C.clay, MAT.fabric)
    	end
    end
    
    -- ── Fabric awnings on side buildings ─────────────────────────────
    
    -- Awning over south-east building entrance
    wedge("Awning_R_F",
    	Vector3.new(10, 2, 4),
    	cfr(FX + 12, GY + 7.5, FZ - 1.5, math.rad(-18), 0, 0),
    	C.fabricOrange, MAT.fabric)
    wedge("Awning_L_F",
    	Vector3.new(10, 2, 4),
    	cfr(FX - 12, GY + 7.5, FZ - 1.5, math.rad(-18), 0, 0),
    	C.fabricBlue, MAT.fabric)
    
    -- Hanging fabric strips (decorative, on walls)
    local stripCols = {C.fabricOrange, C.fabricWhite, C.fabricBlue}
    for si = 0, 4 do
    	part("FabricStrip",
    		Vector3.new(1.2, 4, 0.2),
    		cf(FX - 5 + si*2.5, GY + FH - 2, FZ + FD/2 - 0.5),
    		stripCols[(si % 3)+1], MAT.fabric)
    end
    
    -- ── Fort torches ─────────────────────────────────────────────────
    
    local torchSpots = {
    	{ FX - 8,  GY + FH/2 + 1, FZ - FD/2 - 1.8 },
    	{ FX + 8,  GY + FH/2 + 1, FZ - FD/2 - 1.8 },
    	{ FX - FW/2 - 1.8, GY + FH/2, FZ - 8 },
    	{ FX + FW/2 + 1.8, GY + FH/2, FZ - 8 },
    }
    for _, ts in ipairs(torchSpots) do
    	cyl("TorchStick", 3, 0.5, cf(ts[1], ts[2], ts[3]), C.wood, MAT.wood)
    	local flame = part("TorchFlame", Vector3.new(0.8, 1.2, 0.8),
    		cf(ts[1], ts[2] + 1.8, ts[3]), C.torchFlame, MAT.neon)
    	addLight(flame, Color3.fromRGB(255, 140, 30), 4, 20)
    	sphere("TorchEmber", 0.5,
    		cf(ts[1], ts[2] + 2.6, ts[3]),
    		Color3.fromRGB(255, 80, 10), MAT.neon)
    end
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 5: OASIS SMALL HOUSES (near water)
    -- ═══════════════════════════════════════════════════════════════
    
    local oasisHouses = {
    	{ OX - 26, OZ - 8,  10, 8, "small"  },
    	{ OX + 22, OZ + 12,  9, 7, "small"  },
    	{ OX - 24, OZ + 14, 12, 9, "medium" },
    }
    
    for hi, hd in ipairs(oasisHouses) do
    	local hx, hz2, hw, hd2 = hd[1], hd[2], hd[3], hd[4]
    	local hType = hd[5]
    	local wallH = (hType == "medium") and 7 or 5.5
    
    	-- Walls
    	part("House_"..hi.."_Wall",
    		Vector3.new(hw, wallH, hd2),
    		cf(hx, GY + wallH/2, hz2), C.clay, MAT.brick)
    	-- Flat roof
    	part("House_"..hi.."_Roof",
    		Vector3.new(hw + 0.8, 1, hd2 + 0.8),
    		cf(hx, GY + wallH + 0.5, hz2), C.sandstoneDk, MAT.stone)
    	-- Low parapet
    	part("House_"..hi.."_Parapet_N",
    		Vector3.new(hw + 1, 1.2, 0.6),
    		cf(hx, GY + wallH + 1.1, hz2 - hd2/2 - 0.3), C.wallCrenMat, MAT.brick)
    	part("House_"..hi.."_Parapet_S",
    		Vector3.new(hw + 1, 1.2, 0.6),
    		cf(hx, GY + wallH + 1.1, hz2 + hd2/2 + 0.3), C.wallCrenMat, MAT.brick)
    	-- Door
    	part("House_"..hi.."_Door",
    		Vector3.new(2, 3.5, 0.4),
    		cf(hx, GY + 1.75, hz2 + hd2/2 + 0.2), C.wood, MAT.wood)
    	-- Window
    	part("House_"..hi.."_Win",
    		Vector3.new(0.4, 1.8, 1.5),
    		cf(hx + hw/4, GY + wallH*0.6, hz2 - hd2/2 - 0.2), C.archDark, MAT.plast)
    	-- Foundation step
    	part("House_"..hi.."_Step",
    		Vector3.new(4, 0.5, 1.5),
    		cf(hx, GY + 0.25, hz2 + hd2/2 + 0.8), C.sandstone, MAT.brick)
    end
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 6: CACTI (scattered across desert)
    -- ═══════════════════════════════════════════════════════════════
    
    local cactiPositions = {
    	{-88,  20}, {-92, -30}, {-75,  70}, {-50,  85},
    	{ 60, -72}, { 80, -40}, { 88,  55}, { 72,  80},
    	{-18, -75}, { 35, -82}, {-45,  78}, { 10,  92},
    	{-95, -70}, { 95, -80}, {-85,  -5}, { 95,  30},
    }
    
    for _, cp in ipairs(cactiPositions) do
    	local cx2, cz2 = cp[1], cp[2]
    	local cH = 5 + math.random() * 5
    	-- Main stem
    	cyl("Cactus_Stem", cH, 1.8,
    		cf(cx2, GY + cH/2, cz2), C.cactusDk, MAT.grass)
    	-- Arm left
    	local armH = cH * 0.5
    	cyl("Cactus_ArmL_V", armH * 0.6, 1.2,
    		cf(cx2 - 2.5, GY + armH, cz2), C.cactusLt, MAT.grass)
    	cyl("Cactus_ArmL_H", 2.8, 1.2,
    		cfr(cx2 - 1.5, GY + armH, cz2, 0, 0, math.pi/2), C.cactusDk, MAT.grass)
    	-- Arm right (not all cacti have both arms)
    	if math.random() > 0.4 then
    		cyl("Cactus_ArmR_V", armH * 0.45, 1.2,
    			cf(cx2 + 2.2, GY + armH * 0.7, cz2), C.cactusLt, MAT.grass)
    		cyl("Cactus_ArmR_H", 2.5, 1.2,
    			cfr(cx2 + 1.3, GY + armH * 0.7, cz2, 0, 0, -math.pi/2), C.cactusDk, MAT.grass)
    	end
    	-- Cactus top bud
    	sphere("Cactus_Bud", 1.4,
    		cf(cx2, GY + cH + 0.5, cz2), C.cactusLt, MAT.grass)
    end
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 7: DRY BONES / DESERT ATMOSPHERE
    -- ═══════════════════════════════════════════════════════════════
    
    -- Animal skull decorations (scattered)
    local skullSpots = { {-35, -55}, {70, -60}, {-88, 60}, {45, 82} }
    for _, ss in ipairs(skullSpots) do
    	sphere("Skull",    2.2, cfr(ss[1], GY+0.8, ss[2], 0, math.random()*math.pi, 0),
    		C.boneDry, MAT.plast)
    	part("SkullSnout",
    		Vector3.new(0.8, 1, 1.2),
    		cfr(ss[1], GY+0.5, ss[2]+1.2, 0, 0, 0), C.boneDry, MAT.plast)
    	-- Rib bones
    	for ri2 = 1, 3 do
    		part("Rib",
    			Vector3.new(2.5, 0.3, 0.3),
    			cfr(ss[1], GY + 0.3, ss[2] - ri2*1.0, 0, math.random()*0.4, 0),
    			C.boneDry, MAT.plast)
    	end
    end
    
    -- Buried stone (partially submerged in sand)
    local buriedStones = {
    	{-55, -40, 5, 3}, {35, 55, 4, 2.5}, {80, -20, 6, 3.5},
    	{-80, -60, 5, 3}, {15, -60, 4, 2},
    }
    for _, bs in ipairs(buriedStones) do
    	part("BuriedStone",
    		Vector3.new(bs[3], bs[4], bs[3]*0.8),
    		cfr(bs[1], GY - bs[4]*0.5, bs[2], 0, math.random()*math.pi, 0),
    		C.stoneRuin, MAT.slate)
    end
    
    -- Sand dust particles (small flat discs, low transparent)
    for i = 1, 15 do
    	local angle = (i/15) * math.pi * 2
    	local r = 40 + math.sin(i*2.3)*25
    	part("DustSwirl",
    		Vector3.new(math.random(6,14), 0.3, math.random(4,8)),
    		cfr(math.cos(angle)*r, GY + 1, math.sin(angle)*r,
    			0, math.random()*math.pi, 0),
    		C.dustColor, MAT.sand, 0.65)
    end
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 8: PATHS
    -- ═══════════════════════════════════════════════════════════════
    
    local pathSand = Color3.fromRGB(228, 200, 135)
    
    -- Main path from east (from Highgard) — enters zone right side
    local pathNodes = {
    	{ x= 105, z=  0,  w= 7, l= 25 },
    	{ x=  80, z= 10,  w= 7, l= 35, rot=math.rad(-20) },
    	{ x=  52, z= 18,  w= 6, l= 35, rot=math.rad(-15) },
    	{ x=  28, z= 24,  w= 6, l= 32, rot=math.rad(-10) },  -- reaches oasis
    	{ x=   5, z= 28,  w= 6, l= 28  },
    	-- oasis to fort
    	{ x= -15, z= 15,  w= 6, l= 30, rot=math.rad(20)  },
    	{ x= -38, z= -5,  w= 6, l= 38, rot=math.rad(25)  },
    	{ x= -58, z=-30,  w= 6, l= 40, rot=math.rad(30)  },
    }
    
    for pi3, pn in ipairs(pathNodes) do
    	part("Path_Main_"..pi3,
    		Vector3.new(pn.w, 0.5, pn.l),
    		cfr(pn.x, GY + 0.25, pn.z, 0, pn.rot or 0, 0),
    		pathSand, MAT.sand)
    end
    
    -- Path edge markers (small rocks)
    for pDist = 1, 6 do
    	local d = pDist * 16
    	for _, side in ipairs({-1, 1}) do
    		sphere("PathMarker", 0.6,
    			cf(105 - d*0.6, GY+0.3, d*0.18 + side*3.8),
    			C.stoneRuin, MAT.slate)
    	end
    end
    
    -- North path (danger zone, toward mountain side)
    part("Path_North",
    	Vector3.new(5, 0.4, 70),
    	cfr(-30, GY+0.2, -72, 0, math.rad(5), 0),
    	pathSand, MAT.sand)
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 9: DANGER MARKER (north zone)
    -- ═══════════════════════════════════════════════════════════════
    
    local DMX, DMZ = -32, -90
    
    -- Warning post (wood stake)
    part("Danger_Post",
    	Vector3.new(0.5, 6, 0.5),
    	cf(DMX, GY + 3, DMZ), C.woodDark, MAT.wood)
    part("Danger_Cross",
    	Vector3.new(4, 0.5, 0.5),
    	cf(DMX, GY + 6.5, DMZ), C.woodDark, MAT.wood)
    -- Skull sign board
    part("Danger_Board",
    	Vector3.new(3.5, 3, 0.4),
    	cf(DMX, GY + 5.5, DMZ), C.woodDark, MAT.wood)
    -- Neon skull
    local dangerPt = part("Danger_Skull",
    	Vector3.new(1, 1, 1),
    	cf(DMX, GY + 9, DMZ), C.dangerRed, MAT.neon)
    addLight(dangerPt, Color3.fromRGB(255, 40, 40), 4, 16)
    billboard(dangerPt, "☠", 44)
    
    -- Second skull marker near fort north (hostile)
    local DM2X, DM2Z = FX + 5, FZ - FD/2 - 20
    part("Danger2_Post",  Vector3.new(0.5, 6, 0.5), cf(DM2X, GY+3, DM2Z), C.woodDark, MAT.wood)
    part("Danger2_Cross", Vector3.new(4, 0.5, 0.5), cf(DM2X, GY+6.5, DM2Z), C.woodDark, MAT.wood)
    local d2Pt = part("Danger2_Skull",
    	Vector3.new(1, 1, 1), cf(DM2X, GY+9, DM2Z), C.dangerRed, MAT.neon)
    addLight(d2Pt, Color3.fromRGB(255, 40, 40), 3, 14)
    billboard(d2Pt, "☠", 44)
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 10: NPC PLACEHOLDERS
    -- ═══════════════════════════════════════════════════════════════
    
    local npcs = {
    	{ FX - 4, FZ + FD/2 + 6, "Desert Guard",   C.npcArmor },
    	{ FX + 4, FZ + FD/2 + 6, "Desert Guard",   C.npcArmor },
    	{ FX + 10, FZ + 10,      "Merchant",        C.npcRobe  },
    	{ OX - 5,  OZ + 4,       "Wanderer",        C.npcRobe  },
    }
    
    local function spawnNPC(x, z, name, col)
    	part("NPC_Torso",  Vector3.new(2, 2.5, 1),   cf(x, GY+2.75, z), col, MAT.plast)
    	sphere("NPC_Head", 1.8,                        cf(x, GY+5, z), C.npcSkin, MAT.plast)
    	part("NPC_LegL",   Vector3.new(0.9, 2, 0.9),  cf(x-0.55, GY+1, z), col, MAT.plast)
    	part("NPC_LegR",   Vector3.new(0.9, 2, 0.9),  cf(x+0.55, GY+1, z), col, MAT.plast)
    	part("NPC_ArmL",   Vector3.new(0.8, 2.2, 0.8),
    		cfr(x-1.4, GY+2.5, z, 0, 0, math.rad(20)), col, MAT.plast)
    	part("NPC_ArmR",   Vector3.new(0.8, 2.2, 0.8),
    		cfr(x+1.4, GY+2.5, z, 0, 0, math.rad(-20)), col, MAT.plast)
    	local anchor = part("NPC_LblAnch", Vector3.new(0.1, 0.1, 0.1),
    		cf(x, GY+7, z), C.black, MAT.plast, 1)
    	billboard(anchor, name, 90)
    end
    
    for _, npc in ipairs(npcs) do
    	spawnNPC(npc[1], npc[2], npc[3], npc[4])
    end
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 11: LANTERNS (fort walls & oasis area)
    -- ═══════════════════════════════════════════════════════════════
    
    local lampSpots = {
    	{ FX - 14, GY + FH + 2, FZ + FD/2 + 1 },
    	{ FX + 14, GY + FH + 2, FZ + FD/2 + 1 },
    	{ FX - FW/2, GY + FH/2, FZ },
    	{ FX + FW/2, GY + FH/2, FZ },
    	{ OX - 5, GY + 7, OZ - 12 },
    	{ OX + 5, GY + 7, OZ + 13 },
    }
    
    for _, ls in ipairs(lampSpots) do
    	-- Bracket
    	part("WallBracket",
    		Vector3.new(0.4, 0.4, 2),
    		cf(ls[1], ls[2], ls[3]), C.ironMetal, MAT.metal)
    	-- Lantern cage
    	part("WallLantern",
    		Vector3.new(1.2, 1.8, 1.2),
    		cf(ls[1], ls[2] - 0.8, ls[3] + 0.8), C.ironMetal, MAT.metal, 0.5)
    	local flame2 = part("WallFlame",
    		Vector3.new(0.9, 1.3, 0.9),
    		cf(ls[1], ls[2] - 0.8, ls[3] + 0.8), C.lanternAmb, MAT.neon)
    	addLight(flame2, Color3.fromRGB(255, 190, 70), 3.5, 18)
    end
    
    -- ── FINAL REPORT ─────────────────────────────────────────────────
    
    local count = #folder:GetDescendants()
    print(string.format(
    	"[SunScorch Zone3] ✅ Done!  %d objects created in workspace.SunScorch_Zone3",
    	count
    ))
    end
    print("[HighgardPlugin] ✅ Zone3_SunScorch complete.")
end


-- ────────────────────────────────────────────────────────────────
zoneFunctions["Zone4_SnowDust"] = function()
    print("[HighgardPlugin] 🔨 Building Zone4_SnowDust...")
    do
    local ORIGIN = CFrame.new(0, 50, -320)
    
    -- ── Palette ─────────────────────────────────────────────────────
    local C = {
    	rockBase     = Color3.fromRGB( 95,  90,  85),
    	rockDark     = Color3.fromRGB( 68,  62,  58),
    	rockMid      = Color3.fromRGB(118, 112, 105),
    	rockLight    = Color3.fromRGB(145, 138, 130),
    	rockPeak     = Color3.fromRGB(158, 155, 150),
    	snowPure     = Color3.fromRGB(240, 242, 245),
    	snowShadow   = Color3.fromRGB(195, 205, 218),
    	snowDirty    = Color3.fromRGB(208, 212, 210),
    	iceBlue      = Color3.fromRGB(145, 200, 235),
    	iceDark      = Color3.fromRGB( 88, 145, 195),
    	iceGlow      = Color3.fromRGB(175, 225, 255),
    	iceCrystal   = Color3.fromRGB(120, 185, 230),
    	iceSheen     = Color3.fromRGB(200, 235, 255),
    	grassPatch   = Color3.fromRGB( 78, 108,  52),
    	mossGrey     = Color3.fromRGB( 88,  95,  80),
    	treeDark     = Color3.fromRGB( 32,  62,  38),
    	treeMid      = Color3.fromRGB( 48,  88,  52),
    	treeLight    = Color3.fromRGB( 68, 112,  68),
    	trunkBrown   = Color3.fromRGB( 68,  45,  22),
    	dragonBlack  = Color3.fromRGB( 28,  22,  18),
    	dragonDark   = Color3.fromRGB( 48,  35,  25),
    	dragonWing   = Color3.fromRGB( 38,  28,  20),
    	dragonSpike  = Color3.fromRGB( 62,  48,  32),
    	wolfGrey     = Color3.fromRGB(122, 118, 112),
    	wolfDark     = Color3.fromRGB( 72,  68,  62),
    	wolfLight    = Color3.fromRGB(162, 158, 150),
    	wolfSnout    = Color3.fromRGB(148, 135, 118),
    	wolfEye      = Color3.fromRGB(255, 175,  25),
    	pathStone    = Color3.fromRGB(128, 120, 108),
    	pathSnow     = Color3.fromRGB(218, 222, 220),
    	woodPost     = Color3.fromRGB( 88,  62,  28),
    	ropeColor    = Color3.fromRGB(155, 128,  75),
    	dangerRed    = Color3.fromRGB(195,  38,  38),
    	lanternAmb   = Color3.fromRGB(255, 195,  55),
    	torchFlame   = Color3.fromRGB(255, 140,  25),
    	npcSkin      = Color3.fromRGB(215, 178, 135),
    	npcArmor     = Color3.fromRGB( 95, 100, 110),
    	npcFur       = Color3.fromRGB(105,  82,  52),
    	black        = Color3.fromRGB( 15,  12,  10),
    }
    
    local M = Enum.Material
    local MAT = {
    	stone  = M.SmoothPlastic,
    	cobble = M.Cobblestone,
    	wood   = M.Wood,
    	metal  = M.Metal,
    	glass  = M.Glass,
    	neon   = M.Neon,
    	grass  = M.Grass,
    	slate  = M.Slate,
    	fabric = M.Fabric,
    	plast  = M.SmoothPlastic,
    	ice    = M.Ice,
    	snow   = M.SmoothPlastic,
    }
    
    -- ── Root folder ──────────────────────────────────────────────────
    local folder = Instance.new("Folder")
    folder.Name   = "SnowDust_Zone4"
    folder.Parent = workspace
    
    -- ── Helpers ──────────────────────────────────────────────────────
    local function cf(x,y,z)          return ORIGIN * CFrame.new(x,y,z) end
    local function cfr(x,y,z,rx,ry,rz) return cf(x,y,z)*CFrame.Angles(rx,ry,rz) end
    
    local function part(name, size, cframe, color, material, transparency)
    	local p = Instance.new("Part")
    	p.Name          = name
    	p.Size          = size
    	p.CFrame        = cframe
    	p.Color         = color or C.rockBase
    	p.Material      = material or MAT.stone
    	p.Transparency  = transparency or 0
    	p.Anchored      = true
    	p.CastShadow    = true
    	p.TopSurface    = Enum.SurfaceType.Smooth
    	p.BottomSurface = Enum.SurfaceType.Smooth
    	p.Parent        = folder
    	return p
    end
    
    local function wedge(name, size, cframe, color, material)
    	local p = Instance.new("WedgePart")
    	p.Name          = name
    	p.Size          = size
    	p.CFrame        = cframe
    	p.Color         = color or C.snowPure
    	p.Material      = material or MAT.snow
    	p.Anchored      = true
    	p.TopSurface    = Enum.SurfaceType.Smooth
    	p.BottomSurface = Enum.SurfaceType.Smooth
    	p.Parent        = folder
    	return p
    end
    
    local function cyl(name, height, diam, cframe, color, material, transp)
    	local p = Instance.new("Part")
    	p.Name          = name
    	p.Shape         = Enum.PartType.Cylinder
    	p.Size          = Vector3.new(height, diam, diam)
    	p.CFrame        = cframe * CFrame.Angles(0, 0, math.pi/2)
    	p.Color         = color or C.rockBase
    	p.Material      = material or MAT.stone
    	p.Transparency  = transp or 0
    	p.Anchored      = true
    	p.TopSurface    = Enum.SurfaceType.Smooth
    	p.BottomSurface = Enum.SurfaceType.Smooth
    	p.Parent        = folder
    	return p
    end
    
    local function sphere(name, diam, cframe, color, material, transp)
    	local p = Instance.new("Part")
    	p.Name         = name
    	p.Shape        = Enum.PartType.Ball
    	p.Size         = Vector3.new(diam, diam, diam)
    	p.CFrame       = cframe
    	p.Color        = color or C.snowPure
    	p.Material     = material or MAT.snow
    	p.Transparency = transp or 0
    	p.Anchored     = true
    	p.Parent       = folder
    	return p
    end
    
    local function coneMesh(name, height, diam, cframe, color, material)
    	local p = Instance.new("Part")
    	p.Name     = name
    	p.Size     = Vector3.new(diam, height, diam)
    	p.CFrame   = cframe
    	p.Color    = color or C.iceBlue
    	p.Material = material or MAT.ice
    	p.Anchored = true
    	p.TopSurface    = Enum.SurfaceType.Smooth
    	p.BottomSurface = Enum.SurfaceType.Smooth
    	p.Parent   = folder
    	local mesh = Instance.new("SpecialMesh", p)
    	mesh.MeshType = Enum.MeshType.FileMesh
    	mesh.MeshId   = "rbxassetid://1078075"
    	mesh.Scale    = Vector3.new(diam/5, height/5, diam/5)
    	return p
    end
    
    local function addLight(parent, color, brightness, range)
    	local l = Instance.new("PointLight", parent)
    	l.Color      = color
    	l.Brightness = brightness or 3
    	l.Range      = range or 18
    	l.Enabled    = true
    end
    
    local function billboard(parent, text, size)
    	local bg = Instance.new("BillboardGui", parent)
    	bg.Size        = UDim2.fromOffset(size or 60, 28)
    	bg.StudsOffset = Vector3.new(0, 3, 0)
    	bg.AlwaysOnTop = false
    	local lbl = Instance.new("TextLabel", bg)
    	lbl.Size                   = UDim2.fromScale(1, 1)
    	lbl.BackgroundTransparency = 1
    	lbl.Text                   = text
    	lbl.TextColor3             = Color3.new(1, 1, 1)
    	lbl.TextScaled             = true
    end
    
    local GY = 0  -- local ground zero (relative to ORIGIN)
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 1: MOUNTAIN BASE & FOOTHILLS
    -- ═══════════════════════════════════════════════════════════════
    
    -- Wide base platform
    part("Mountain_Base",
    	Vector3.new(210, 6, 185),
    	cf(0, GY - 3, 0), C.rockBase, MAT.slate)
    
    -- Transition grass strip (south edge — border with Highgard)
    part("Transition_S",
    	Vector3.new(200, 2, 20),
    	cf(0, GY + 1, 92), C.grassPatch, MAT.grass)
    
    -- Foothills — layer 1 (outer ring, lower)
    local foothillData = {
    	{ 0,   0, 180, 160, 14 },   -- central mass
    	{-75, -30, 60,  50, 18 },   -- left spur
    	{ 80,  20, 58,  48, 16 },   -- right spur
    	{  0, -55, 75,  55, 20 },   -- north protrusion
    	{-40,  40, 50,  42, 12 },   -- south-left shoulder
    	{ 45,  38, 48,  40, 12 },   -- south-right shoulder
    }
    for i, fd in ipairs(foothillData) do
    	part("Foothill_"..i,
    		Vector3.new(fd[3], fd[5], fd[4]),
    		cf(fd[1], GY + fd[5]/2, fd[2]), C.rockDark, MAT.slate)
    end
    
    -- Foothill snow dusting (top patches)
    for i, fd in ipairs(foothillData) do
    	part("Foothill_Snow_"..i,
    		Vector3.new(fd[3]*0.7, 1.5, fd[4]*0.7),
    		cf(fd[1], GY + fd[5] + 0.8, fd[2]), C.snowDirty, MAT.snow)
    end
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 2: MID TIER — Rocky slopes
    -- ═══════════════════════════════════════════════════════════════
    
    local midTiers = {
    	{ 0,    0,  130, 110, 38 },
    	{-45,  -25,  50,  40, 45 },
    	{ 50,   15,  48,  38, 42 },
    	{  5,  -50,  60,  45, 50 },
    }
    for i, mt in ipairs(midTiers) do
    	part("MidTier_"..i,
    		Vector3.new(mt[3], mt[5], mt[4]),
    		cf(mt[1], GY + mt[5]/2, mt[2]), C.rockMid, MAT.slate)
    end
    
    -- Rocky outcrops on mid tier
    local outcrops = {
    	{-48, 48, 22}, {55, 30, 18}, {-30, -60, 20},
    	{60, -35, 15}, {-65, -15, 25}, {35, -58, 18},
    	{-20, 55, 16}, {70, 5, 14},
    }
    for i, oc in ipairs(outcrops) do
    	local h = oc[3]
    	part("Outcrop_"..i,
    		Vector3.new(h*0.8, h, h*0.7),
    		cfr(oc[1], GY + h * 0.5 + 22, oc[2], 0, math.random()*math.pi, 0),
    		C.rockLight, MAT.slate)
    	-- Snow cap on outcrop
    	part("Outcrop_Snow_"..i,
    		Vector3.new(h*0.65, 2, h*0.55),
    		cf(oc[1], GY + h + 24, oc[2]), C.snowPure, MAT.snow)
    end
    
    -- Snow coverage mid slopes
    part("MidSnow_Main",
    	Vector3.new(105, 2, 90),
    	cf(0, GY + 42, 0), C.snowShadow, MAT.snow)
    part("MidSnow_Accent",
    	Vector3.new(80, 1.5, 68),
    	cf(8, GY + 44, -5), C.snowPure, MAT.snow)
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 3: UPPER PEAK
    -- ═══════════════════════════════════════════════════════════════
    
    -- Main peak body
    part("Peak_Main",
    	Vector3.new(72, 55, 60),
    	cf(0, GY + 50 + 27, -8), C.rockPeak, MAT.slate)
    
    -- Peak sides / spires
    local peakSpires = {
    	{-28, -12, 18, 42}, { 30, -15, 16, 38},
    	{ -8,  20, 14, 35}, { 20,  18, 15, 36},
    	{  0, -30, 22, 48},
    }
    for i, ps in ipairs(peakSpires) do
    	part("PeakSpire_"..i,
    		Vector3.new(ps[3], ps[4], ps[3]*0.9),
    		cfr(ps[1], GY + 65 + ps[4]/2, ps[2], 0, math.random()*math.pi, 0),
    		C.rockLight, MAT.slate)
    end
    
    -- Summit platform (flat top)
    part("Summit_Platform",
    	Vector3.new(45, 4, 38),
    	cf(0, GY + 102, -8), C.rockPeak, MAT.slate)
    part("Summit_Snow",
    	Vector3.new(44, 2, 37),
    	cf(0, GY + 104.5, -8), C.snowPure, MAT.snow)
    
    -- Peak snow wedges (dramatic snow caps on spires)
    for i, ps in ipairs(peakSpires) do
    	wedge("SpireSnow_"..i,
    		Vector3.new(ps[3]*0.9, ps[4]*0.25, ps[3]*0.7),
    		cfr(ps[1], GY + 65 + ps[4] - ps[4]*0.1, ps[2], math.rad(15), math.random()*math.pi, 0),
    		C.snowPure, MAT.snow)
    end
    
    -- Large diagonal rock faces (scenic cliff walls)
    wedge("CliffFace_W",
    	Vector3.new(60, 45, 30),
    	cfr(-35, GY + 55, -5, 0, 0, math.rad(-15)), C.rockDark, MAT.slate)
    wedge("CliffFace_E",
    	Vector3.new(55, 40, 28),
    	cfr( 35, GY + 58, -10, 0, math.pi, math.rad(12)), C.rockDark, MAT.slate)
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 4: ICE CRYSTALS (summit feature)
    -- ═══════════════════════════════════════════════════════════════
    
    local crystalData = {
    	--  x,   z,  height, diam, tilt_x, tilt_z
    	{  -14, -12,   18,   3.5,  math.rad( 8), math.rad(-5) },
    	{   12, -10,   22,   4.0,  math.rad(-6), math.rad( 7) },
    	{   -5,  10,   16,   3.0,  math.rad( 5), math.rad(-8) },
    	{   16,   8,   20,   3.8,  math.rad(-9), math.rad( 4) },
    	{    0,  -6,   25,   5.0,  math.rad( 3), math.rad(-3) },
    	{  -18,   5,   14,   2.8,  math.rad(12), math.rad( 6) },
    	{   10,  14,   12,   2.5,  math.rad(-7), math.rad(-9) },
    }
    
    for i, cd in ipairs(crystalData) do
    	local cx2, cz2 = cd[1], cd[2]
    	local ch, cdiam = cd[3], cd[4]
    	local tx, tz = cd[5], cd[6]
    
    	-- Crystal shaft
    	coneMesh("Crystal_"..i, ch, cdiam,
    		cfr(cx2, GY + 105 + ch/2, cz2 - 8, tx, 0, tz),
    		C.iceCrystal, MAT.ice)
    	-- Crystal inner glow
    	local glowPart = part("CrystalGlow_"..i,
    		Vector3.new(cdiam*0.5, ch*0.7, cdiam*0.5),
    		cfr(cx2, GY + 105 + ch*0.35, cz2 - 8, tx, 0, tz),
    		C.iceGlow, MAT.neon, 0.3)
    	addLight(glowPart, Color3.fromRGB(160, 215, 255), 3, 14)
    	-- Base shard cluster
    	for s = 1, 3 do
    		local sa = (s/3) * math.pi * 2
    		coneMesh("CrystalShard_"..i.."_"..s,
    			ch * 0.4, cdiam * 0.6,
    			cfr(cx2 + math.cos(sa)*cdiam*0.8, GY + 105 + ch*0.2,
    				cz2 - 8 + math.sin(sa)*cdiam*0.8, math.rad(15), sa, 0),
    			C.iceBlue, MAT.ice)
    	end
    end
    
    -- Frost ring around crystal cluster
    part("FrostRing",
    	Vector3.new(50, 0.8, 44),
    	cf(0, GY + 104.8, -8), C.snowShadow, MAT.ice, 0.15)
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 5: DRAGON (anchored above peak)
    -- ═══════════════════════════════════════════════════════════════
    
    local DRY = GY + 145   -- dragon altitude
    local DRX, DRZ = 5, -12
    
    -- Dragon body (main torso)
    part("Dragon_Body",
    	Vector3.new(6, 5, 18),
    	cfr(DRX, DRY, DRZ, 0, math.rad(-15), 0),
    	C.dragonBlack, MAT.plast)
    
    -- Chest/underbelly (slightly lighter)
    part("Dragon_Belly",
    	Vector3.new(4.5, 3.5, 14),
    	cfr(DRX, DRY - 0.5, DRZ, 0, math.rad(-15), 0),
    	C.dragonDark, MAT.plast)
    
    -- Neck
    part("Dragon_Neck",
    	Vector3.new(3.5, 4, 8),
    	cfr(DRX + 1, DRY + 1.5, DRZ + 11, math.rad(-25), math.rad(-12), 0),
    	C.dragonBlack, MAT.plast)
    
    -- Head
    part("Dragon_Head",
    	Vector3.new(4.5, 3.5, 6),
    	cfr(DRX + 2, DRY + 4, DRZ + 18, math.rad(-15), math.rad(-18), 0),
    	C.dragonBlack, MAT.plast)
    
    -- Snout
    part("Dragon_Snout",
    	Vector3.new(2.5, 2, 5),
    	cfr(DRX + 2.5, DRY + 3, DRZ + 22, math.rad(-10), math.rad(-18), 0),
    	C.dragonDark, MAT.plast)
    
    -- Jaw (lower)
    part("Dragon_Jaw",
    	Vector3.new(2, 1.5, 4),
    	cfr(DRX + 2.5, DRY + 1.5, DRZ + 22, math.rad(15), math.rad(-18), 0),
    	C.dragonDark, MAT.plast)
    
    -- Eyes (glowing amber)
    for _, ex in ipairs({DRX + 1.5, DRX + 3.5}) do
    	local eyePart = sphere("Dragon_Eye", 0.8,
    		cf(ex, DRY + 5, DRZ + 20), Color3.fromRGB(255, 140, 0), MAT.neon)
    	addLight(eyePart, Color3.fromRGB(255, 100, 0), 5, 20)
    end
    
    -- Head spikes / horns
    for hi2 = 1, 3 do
    	coneMesh("Dragon_Horn_L_"..hi2, 3, 1.2,
    		cf(DRX + 0.5, DRY + 6 - hi2*0.5, DRZ + 18 + hi2, C.dragonSpike))
    	coneMesh("Dragon_Horn_R_"..hi2, 3, 1.2,
    		cf(DRX + 3.5, DRY + 6 - hi2*0.5, DRZ + 18 + hi2, C.dragonSpike))
    end
    
    -- Left wing (3 segments)
    local wingSegs_L = {
    	{ dx=-8,  dy= 2, dz= 2,  w=14, h=1.2, d=6,   rx=0,            rz= math.rad(-18) },
    	{ dx=-18, dy= 0, dz= 0,  w=12, h=1.0, d=5,   rx=0,            rz= math.rad(-25) },
    	{ dx=-26, dy=-3, dz=-4,  w=10, h=0.8, d=7,   rx=math.rad(10), rz= math.rad(-30) },
    }
    for i, ws in ipairs(wingSegs_L) do
    	part("Dragon_WingL_"..i,
    		Vector3.new(ws.w, ws.h, ws.d),
    		cfr(DRX + ws.dx, DRY + ws.dy, DRZ + ws.dz, ws.rx, math.rad(-15), ws.rz),
    		C.dragonWing, MAT.fabric)
    end
    -- Wing membrane veins
    for vi = 1, 3 do
    	part("Dragon_VeinL_"..vi,
    		Vector3.new(0.4, 0.4, 5),
    		cfr(DRX - 6 - vi*3.5, DRY + 1 - vi*0.8, DRZ + vi*0.5,
    			math.rad(5), 0, math.rad(-15 - vi*5)),
    		C.dragonBlack, MAT.plast)
    end
    
    -- Right wing
    local wingSegs_R = {
    	{ dx= 8,  dy= 2, dz= 2,  w=14, h=1.2, d=6,   rx=0,            rz= math.rad( 18) },
    	{ dx= 18, dy= 0, dz= 0,  w=12, h=1.0, d=5,   rx=0,            rz= math.rad( 25) },
    	{ dx= 25, dy=-3, dz=-4,  w=10, h=0.8, d=7,   rx=math.rad(10), rz= math.rad( 30) },
    }
    for i, ws in ipairs(wingSegs_R) do
    	part("Dragon_WingR_"..i,
    		Vector3.new(ws.w, ws.h, ws.d),
    		cfr(DRX + ws.dx, DRY + ws.dy, DRZ + ws.dz, ws.rx, math.rad(-15), ws.rz),
    		C.dragonWing, MAT.fabric)
    end
    for vi = 1, 3 do
    	part("Dragon_VeinR_"..vi,
    		Vector3.new(0.4, 0.4, 5),
    		cfr(DRX + 6 + vi*3.5, DRY + 1 - vi*0.8, DRZ + vi*0.5,
    			math.rad(5), 0, math.rad(15 + vi*5)),
    		C.dragonBlack, MAT.plast)
    end
    
    -- Tail (4 segments tapering)
    local tailSegs = {
    	{ 0, -0.5, -10, 5, 4, 4.5 },
    	{-2, -1.5, -20, 4, 3, 4.0 },
    	{-5, -3.0, -30, 3, 2, 3.5 },
    	{-8, -5.0, -38, 2, 1.5, 3.0 },
    }
    for i, ts in ipairs(tailSegs) do
    	part("Dragon_Tail_"..i,
    		Vector3.new(ts[4], ts[5], ts[6]),
    		cfr(DRX + ts[1], DRY + ts[2], DRZ + ts[3], 0, math.rad(-10), 0),
    		C.dragonBlack, MAT.plast)
    end
    -- Tail tip spike
    coneMesh("Dragon_TailSpike", 5, 2,
    	cf(DRX - 10, DRY - 6.5, DRZ - 42), C.dragonSpike)
    
    -- Back spines
    for si = 1, 6 do
    	coneMesh("Dragon_Spine_"..si, 2 + si*0.3, 1,
    		cfr(DRX + 2, DRY + 3.5, DRZ - 8 + si*2.5, 0, math.rad(-15), 0),
    		C.dragonSpike)
    end
    
    -- Breath effect (faint neon glow near mouth)
    local breathPart = sphere("Dragon_Breath", 4,
    	cf(DRX + 3, DRY + 2.5, DRZ + 27), Color3.fromRGB(255, 80, 10), MAT.neon, 0.45)
    addLight(breathPart, Color3.fromRGB(255, 70, 0), 6, 28)
    sphere("Dragon_BreathTip", 2.5,
    	cf(DRX + 3.5, DRY + 2, DRZ + 30), Color3.fromRGB(255, 200, 0), MAT.neon, 0.5)
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 6: WOLVES (mid-tier patrols)
    -- ═══════════════════════════════════════════════════════════════
    
    local wolfPositions = {
    	{-42,  30, math.rad(30)  },
    	{ 38,  18, math.rad(-20) },
    	{ -8, -52, math.rad(5)   },
    }
    
    for wi, wp in ipairs(wolfPositions) do
    	local wx2, wz2, wr = wp[1], wp[2], wp[3]
    	local wy = GY + 32   -- mid slope height
    
    	-- Body
    	part("Wolf_Body_"..wi,
    		Vector3.new(3.5, 2.5, 5.5),
    		cfr(wx2, wy + 1.8, wz2, 0, wr, 0), C.wolfGrey, MAT.plast)
    	-- Underbelly
    	part("Wolf_Belly_"..wi,
    		Vector3.new(2.8, 2.0, 5.0),
    		cfr(wx2, wy + 1.5, wz2, 0, wr, 0), C.wolfLight, MAT.plast)
    	-- Head
    	part("Wolf_Head_"..wi,
    		Vector3.new(3.0, 2.8, 3.0),
    		cfr(wx2 + math.sin(wr)*3.5, wy + 3.2, wz2 + math.cos(wr)*3.5,
    			0, wr, 0), C.wolfGrey, MAT.plast)
    	-- Snout
    	part("Wolf_Snout_"..wi,
    		Vector3.new(1.6, 1.4, 2.2),
    		cfr(wx2 + math.sin(wr)*5.2, wy + 2.5, wz2 + math.cos(wr)*5.2,
    			math.rad(-5), wr, 0), C.wolfSnout, MAT.plast)
    	-- Eyes
    	for _, ex in ipairs({-0.7, 0.7}) do
    		local eyePt = sphere("Wolf_Eye_"..wi, 0.4,
    			cf(wx2 + math.sin(wr)*4 + ex, wy + 3.6, wz2 + math.cos(wr)*4),
    			C.wolfEye, MAT.neon)
    		addLight(eyePt, C.wolfEye, 1.5, 8)
    	end
    	-- Ears
    	for _, ex in ipairs({-0.8, 0.8}) do
    		coneMesh("Wolf_Ear_"..wi, 1.5, 0.8,
    			cf(wx2 + math.sin(wr)*3.8 + ex*0.5, wy + 5, wz2 + math.cos(wr)*3.8),
    			C.wolfDark)
    	end
    	-- Legs (4)
    	local legOffsets = {
    		{-1.2, -4.2}, {1.2, -4.2}, {-1.2, 4.2}, {1.2, 4.2}
    	}
    	for _, lo in ipairs(legOffsets) do
    		part("Wolf_Leg_"..wi,
    			Vector3.new(0.9, 2.5, 0.9),
    			cfr(wx2 + lo[1], wy + 0.3, wz2 + lo[2]*math.cos(wr),
    				0, wr, 0), C.wolfDark, MAT.plast)
    	end
    	-- Tail
    	part("Wolf_Tail_"..wi,
    		Vector3.new(0.9, 0.9, 4.5),
    		cfr(wx2 - math.sin(wr)*4, wy + 3, wz2 - math.cos(wr)*4,
    			math.rad(-30), wr, 0), C.wolfLight, MAT.plast)
    	-- Name label
    	local anchor = part("Wolf_Label_"..wi, Vector3.new(0.1, 0.1, 0.1),
    		cf(wx2, wy + 7, wz2), C.black, MAT.plast, 1)
    	billboard(anchor, "🐺 Snow Wolf", 75)
    end
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 7: MOUNTAIN PATH
    -- ═══════════════════════════════════════════════════════════════
    
    -- Winding path from south base to mid tier
    local pathNodes = {
    	{ 0,   82, 8, 25, 0             },
    	{ 5,   58, 7, 28, math.rad( 8)  },
    	{-8,   32, 7, 28, math.rad(10)  },
    	{-18,  10, 6, 25, math.rad(15)  },
    	{-22, -15, 6, 22, math.rad(12)  },
    	{-15, -38, 6, 20, math.rad(-10) },
    	{ -5, -58, 6, 18, 0             },
    }
    for i, pn in ipairs(pathNodes) do
    	local yOff = (i-1) * 5.5   -- path climbs
    	part("MountainPath_"..i,
    		Vector3.new(pn[3], 1, pn[4]),
    		cfr(pn[1], GY + 1.5 + yOff, pn[2], 0, pn[5], 0),
    		C.pathStone, MAT.cobble)
    	-- Snow dusting on path
    	part("PathSnow_"..i,
    		Vector3.new(pn[3] - 1, 0.6, pn[4] - 1),
    		cfr(pn[1], GY + 2.2 + yOff, pn[2], 0, pn[5], 0),
    		C.snowDirty, MAT.snow, 0.2)
    end
    
    -- Path edge marker stones / cairns
    local cairnPositions = {
    	{ 5, 70}, {-5, 48}, {-14, 24}, {-20, 0}, {-22, -28}
    }
    for ci2, cp in ipairs(cairnPositions) do
    	local cy = GY + (ci2-1) * 5.5 + 2.5
    	-- Cairn stack of 3 rocks
    	for cr = 1, 3 do
    		local cSize = 1.6 - cr * 0.2
    		part("Cairn_"..ci2.."_"..cr,
    			Vector3.new(cSize, cSize, cSize),
    			cfr(cp[1] + 5, cy + (cr-1)*cSize*0.8, cp[2],
    				0, math.random()*math.pi, 0),
    			C.rockLight, MAT.slate)
    	end
    end
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 8: MOUNTAIN FOREST (low slopes, south face)
    -- ═══════════════════════════════════════════════════════════════
    
    local mountainTrees = {
    	-- outer ring, lower slopes
    	{-70, 58, 18, 1.1}, {-52, 68, 16, 0.9}, {-28, 78, 20, 1.2},
    	{ 25, 76, 17, 1.0}, { 55, 65, 18, 1.1}, { 72, 48, 15, 0.85},
    	{ 78, 22, 16, 0.9}, { 75, -8, 20, 1.2}, { 65,-35, 17, 1.0},
    	{ 52,-58, 15, 0.9}, {-50,-62, 18, 1.1}, {-68,-42, 16, 0.9},
    	{-78,-15, 20, 1.2}, {-80, 15, 17, 1.0}, {-72, 42, 15, 0.85},
    	-- inner ring (slightly higher)
    	{-40, 45, 14, 0.8}, { 38, 42, 15, 0.85}, {-22, 52, 16, 0.9},
    	{ 20, 55, 13, 0.75},{-55, 22, 17, 1.0},  { 58, 18, 16, 0.95},
    }
    
    for _, td in ipairs(mountainTrees) do
    	local tx, tz2, th, ts = td[1], td[2], td[3], td[4]
    	-- Trunk
    	cyl("MtnTree_Trunk", th*0.3, 1.6*ts,
    		cf(tx, GY + th*0.15, tz2), C.trunkBrown, MAT.wood)
    	-- Snow-tipped foliage tiers
    	local foliageTiers = {
    		{0.7, 6.5*ts, C.treeDark,  0   },
    		{0.5, 5.0*ts, C.treeMid,   0   },
    		{0.3, 3.8*ts, C.treeLight, 0   },
    		{0.15,2.2*ts, C.snowDirty, 0.1 },  -- snow on top
    	}
    	for _, tier in ipairs(foliageTiers) do
    		sphere("MtnTree_Foliage", tier[2],
    			cf(tx, GY + th*tier[1], tz2), tier[3], MAT.grass, tier[4])
    	end
    end
    
    -- Snow piles at tree bases
    for _, td in ipairs(mountainTrees) do
    	if td[3] >= 16 then
    		sphere("TreeSnowPile", td[4] * 2.5,
    			cf(td[1], GY + 0.8, td[2]), C.snowShadow, MAT.snow, 0.1)
    	end
    end
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 9: MOUNTAIN SHELTER / RUINS (mid-slope)
    -- ═══════════════════════════════════════════════════════════════
    
    -- Small collapsed stone shelter (explorer's rest)
    local SX, SZ = -30, 20
    local sY = GY + 26   -- mid slope level
    
    part("Shelter_Wall_N",
    	Vector3.new(8, 4, 0.8),
    	cf(SX, sY + 2, SZ - 3), C.rockMid, MAT.slate)
    part("Shelter_Wall_W",
    	Vector3.new(0.8, 4, 6),
    	cf(SX - 4, sY + 2, SZ), C.rockMid, MAT.slate)
    -- Collapsed section
    part("Shelter_Wall_S_Partial",
    	Vector3.new(4.5, 3.5, 0.8),
    	cfr(SX - 1.5, sY + 1.8, SZ + 3, 0, 0, math.rad(-8)),
    	C.rockDark, MAT.slate)
    -- Fallen wall block
    part("Shelter_FallenBlock",
    	Vector3.new(4, 2.5, 0.8),
    	cfr(SX + 2, sY + 1.2, SZ + 3, math.rad(72), 0, 0),
    	C.rockDark, MAT.slate)
    -- Snow inside shelter
    part("Shelter_SnowFloor",
    	Vector3.new(7, 0.6, 5),
    	cf(SX, sY + 0.3, SZ), C.snowPure, MAT.snow)
    -- Abandoned gear: frozen crate
    part("FrozenCrate",
    	Vector3.new(2, 2, 2),
    	cfr(SX + 1.5, sY + 1, SZ - 1, 0, math.rad(20), 0),
    	Color3.fromRGB(88, 78, 68), MAT.stone)
    part("FrozenCrate_IceCoat",
    	Vector3.new(2.2, 2.2, 2.2),
    	cfr(SX + 1.5, sY + 1, SZ - 1, 0, math.rad(20), 0),
    	C.iceBlue, MAT.ice, 0.55)
    -- Torch (unlit, frozen)
    part("FrozenTorch",
    	Vector3.new(0.4, 3, 0.4),
    	cfr(SX - 3.5, sY + 1.5, SZ - 2.8, math.rad(-12), 0, 0),
    	C.woodPost, MAT.wood)
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 10: ATMOSPHERIC — SNOW SCATTER & ICE FORMATIONS
    -- ═══════════════════════════════════════════════════════════════
    
    -- Snow clumps (random scatter on slopes)
    for i = 1, 18 do
    	local angle = (i/18) * math.pi * 2
    	local r = 35 + math.sin(i*2.7)*18
    	local sH = GY + 15 + math.cos(i*1.3)*8
    	part("SnowClump",
    		Vector3.new(math.random(4,9), math.random(1,3), math.random(4,8)),
    		cfr(math.cos(angle)*r, sH, math.sin(angle)*r,
    			0, math.random()*math.pi, 0),
    		C.snowPure, MAT.snow, 0.1)
    end
    
    -- Ice shelf formations (horizontal ledges)
    local iceShelvesData = {
    	{-22, 62, 28, 18, 2}, { 20, 55, 24, 14, 2},
    	{-38, 48, 20, 12, 1.5}, {30, 44, 18, 10, 1.5},
    }
    for i, isd in ipairs(iceShelvesData) do
    	part("IceShelf_"..i,
    		Vector3.new(isd[3], isd[5], isd[4]),
    		cf(isd[1], GY + 44, isd[2]), C.iceBlue, MAT.ice, 0.3)
    	-- Icicles hanging from shelf
    	for ic = 1, 4 do
    		local iOff = -isd[3]/2 + ic * (isd[3]/4)
    		coneMesh("Icicle_"..i.."_"..ic, math.random(3,6), 1.2,
    			cfr(isd[1] + iOff, GY + 42, isd[2],
    				math.pi, 0, 0), C.iceSheen, MAT.ice)
    	end
    end
    
    -- Ground icicles (summit area)
    for ic = 1, 10 do
    	local angle = (ic/10)*math.pi*2
    	local r2 = 22
    	coneMesh("GroundIcicle_"..ic, math.random(4,8), math.random(1,2)*0.8,
    		cf(math.cos(angle)*r2, GY + 104 + math.random(0,4), math.sin(angle)*r2 - 8),
    		C.iceCrystal, MAT.ice)
    end
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 11: DANGER MARKER + NPC (mountain guide)
    -- ═══════════════════════════════════════════════════════════════
    
    -- Danger post at the high path entrance
    local DPX, DPZ = 8, 65
    part("DangerPost",    Vector3.new(0.5, 7, 0.5), cf(DPX, GY+3.5, DPZ), C.woodPost, MAT.wood)
    part("DangerCross",   Vector3.new(5, 0.5, 0.5), cf(DPX, GY+7.5, DPZ), C.woodPost, MAT.wood)
    part("DangerBoard",   Vector3.new(4, 3, 0.4),   cf(DPX, GY+6, DPZ), C.woodPost, MAT.wood)
    local dPt = part("DangerSkull",
    	Vector3.new(1, 1, 1), cf(DPX, GY+10, DPZ), C.dangerRed, MAT.neon)
    addLight(dPt, Color3.fromRGB(255, 40, 40), 4, 16)
    billboard(dPt, "☠", 44)
    
    -- Rope guide line along path (wooden posts with rope)
    for i = 0, 5 do
    	local py = GY + i*5.2 + 2
    	local pz3 = 68 - i*20
    	part("RopePost_L",
    		Vector3.new(0.4, 4, 0.4),
    		cf(-6, py, pz3), C.woodPost, MAT.wood)
    	if i > 0 then
    		part("GuideRope_L",
    			Vector3.new(0.3, 0.3, 20),
    			cfr(-6, py + 1.5, pz3 + 10, 0, 0, math.rad(-3)),
    			C.ropeColor, MAT.plast)
    	end
    end
    
    -- Mountain guide NPC
    local gNPCx, gNPCz = -12, 72
    part("Guide_Torso",   Vector3.new(2, 2.5, 1),   cf(gNPCx, GY+2.75, gNPCz), C.npcFur, MAT.plast)
    sphere("Guide_Head",  1.8,                        cf(gNPCx, GY+5, gNPCz), C.npcSkin, MAT.plast)
    part("Guide_LegL",    Vector3.new(0.9, 2, 0.9),  cf(gNPCx-0.55, GY+1, gNPCz), C.npcFur, MAT.plast)
    part("Guide_LegR",    Vector3.new(0.9, 2, 0.9),  cf(gNPCx+0.55, GY+1, gNPCz), C.npcFur, MAT.plast)
    part("Guide_ArmL",    Vector3.new(0.8, 2.2, 0.8),
    	cfr(gNPCx-1.4, GY+2.5, gNPCz, 0, 0, math.rad(20)), C.npcFur, MAT.plast)
    part("Guide_ArmR",    Vector3.new(0.8, 2.2, 0.8),
    	cfr(gNPCx+1.4, GY+2.5, gNPCz, 0, 0, math.rad(-20)), C.npcFur, MAT.plast)
    -- Hood (fur-trimmed cap)
    sphere("Guide_Hood", 2.2, cf(gNPCx, GY+5.8, gNPCz), C.wolfDark, MAT.fabric, 0)
    -- Staff
    part("Guide_Staff",
    	Vector3.new(0.4, 8, 0.4),
    	cfr(gNPCx+1.6, GY+3, gNPCz, math.rad(10), 0, math.rad(-5)),
    	C.woodPost, MAT.wood)
    sphere("Guide_StaffOrb", 1.0,
    	cf(gNPCx+2.2, GY+7.5, gNPCz), C.iceGlow, MAT.neon)
    addLight(part("Guide_OrbGlow", Vector3.new(0.1,0.1,0.1), cf(gNPCx+2.2,GY+7.5,gNPCz), C.iceGlow, MAT.neon, 1),
    	Color3.fromRGB(160, 215, 255), 3, 14)
    local gAnchor = part("Guide_Label", Vector3.new(0.1, 0.1, 0.1),
    	cf(gNPCx, GY+8, gNPCz), C.black, MAT.plast, 1)
    billboard(gAnchor, "Mountain Guide", 95)
    
    -- ── FINAL REPORT ─────────────────────────────────────────────────
    local count = #folder:GetDescendants()
    print(string.format(
    	"[SnowDust Zone4] ✅ Done!  %d objects created in workspace.SnowDust_Zone4",
    	count
    ))
    end
    print("[HighgardPlugin] ✅ Zone4_SnowDust complete.")
end


-- ────────────────────────────────────────────────────────────────
zoneFunctions["Zone5_GloomWood"] = function()
    print("[HighgardPlugin] 🔨 Building Zone5_GloomWood...")
    do
    local ORIGIN = CFrame.new(320, 50, 0)
    
    -- ── Palette ─────────────────────────────────────────────────────
    local C = {
    	groundDark   = Color3.fromRGB( 42,  48,  38),
    	groundMid    = Color3.fromRGB( 55,  62,  48),
    	groundMoss   = Color3.fromRGB( 48,  62,  42),
    	deadGrass    = Color3.fromRGB( 72,  72,  58),
    	mudGrey      = Color3.fromRGB( 62,  58,  52),
    
    	-- Normal spruce
    	treeDarkGreen  = Color3.fromRGB( 28,  58,  32),
    	treeMidGreen   = Color3.fromRGB( 42,  78,  45),
    	treeLightGreen = Color3.fromRGB( 58,  98,  60),
    	trunkBrown     = Color3.fromRGB( 52,  35,  18),
    
    	-- Anomalous purple trees
    	treePurpleDk   = Color3.fromRGB( 52,  28,  72),
    	treePurpleMid  = Color3.fromRGB( 72,  38,  105),
    	treePurpleLt   = Color3.fromRGB( 95,  52,  135),
    	trunkDark      = Color3.fromRGB( 35,  22,  42),
    	glowPurple     = Color3.fromRGB(145,  55,  210),
    
    	-- Ruins
    	ruinStone    = Color3.fromRGB(105, 100,  92),
    	ruinDark     = Color3.fromRGB( 72,  68,  62),
    	ruinMoss     = Color3.fromRGB( 62,  82,  52),
    	ruinLight    = Color3.fromRGB(132, 125, 115),
    
    	-- Skeletons
    	boneWhite    = Color3.fromRGB(228, 222, 208),
    	boneGrey     = Color3.fromRGB(185, 180, 168),
    	weaponMetal  = Color3.fromRGB( 78,  78,  85),
    	weaponWood   = Color3.fromRGB( 85,  58,  25),
    
    	-- Wolf
    	wolfGrey     = Color3.fromRGB(115, 110, 105),
    	wolfDark     = Color3.fromRGB( 68,  65,  60),
    	wolfSnout    = Color3.fromRGB(135, 122, 108),
    	wolfEye      = Color3.fromRGB(255, 165,  15),
    
    	-- Misc
    	dangerRed    = Color3.fromRGB(195,  38,  38),
    	fogColor     = Color3.fromRGB( 88,  75, 105),
    	bushGrey     = Color3.fromRGB( 72,  72,  65),
    	pathDirt     = Color3.fromRGB( 58,  52,  42),
    	pathStone    = Color3.fromRGB( 72,  68,  62),
    	woodPost     = Color3.fromRGB( 72,  48,  20),
    	lanternGreen = Color3.fromRGB( 55, 185,  75),
    	npcSkin      = Color3.fromRGB(215, 178, 135),
    	npcArmor     = Color3.fromRGB( 85,  85,  92),
    	black        = Color3.fromRGB( 15,  12,  10),
    	waterDark    = Color3.fromRGB( 28,  42,  35),
    }
    
    local M = Enum.Material
    local MAT = {
    	stone  = M.SmoothPlastic,
    	cobble = M.Cobblestone,
    	wood   = M.Wood,
    	metal  = M.Metal,
    	glass  = M.Glass,
    	neon   = M.Neon,
    	grass  = M.Grass,
    	slate  = M.Slate,
    	fabric = M.Fabric,
    	plast  = M.SmoothPlastic,
    }
    
    -- ── Root folder ──────────────────────────────────────────────────
    local folder = Instance.new("Folder")
    folder.Name   = "GloomWood_Zone5"
    folder.Parent = workspace
    
    -- ── Helpers ──────────────────────────────────────────────────────
    local function cf(x,y,z)          return ORIGIN * CFrame.new(x,y,z) end
    local function cfr(x,y,z,rx,ry,rz) return cf(x,y,z)*CFrame.Angles(rx,ry,rz) end
    
    local function part(name, size, cframe, color, material, transparency)
    	local p = Instance.new("Part")
    	p.Name          = name
    	p.Size          = size
    	p.CFrame        = cframe
    	p.Color         = color or C.ruinStone
    	p.Material      = material or MAT.stone
    	p.Transparency  = transparency or 0
    	p.Anchored      = true
    	p.CastShadow    = true
    	p.TopSurface    = Enum.SurfaceType.Smooth
    	p.BottomSurface = Enum.SurfaceType.Smooth
    	p.Parent        = folder
    	return p
    end
    
    local function wedge(name, size, cframe, color, material)
    	local p = Instance.new("WedgePart")
    	p.Name          = name
    	p.Size          = size
    	p.CFrame        = cframe
    	p.Color         = color or C.ruinStone
    	p.Material      = material or MAT.stone
    	p.Anchored      = true
    	p.TopSurface    = Enum.SurfaceType.Smooth
    	p.BottomSurface = Enum.SurfaceType.Smooth
    	p.Parent        = folder
    	return p
    end
    
    local function cyl(name, height, diam, cframe, color, material, transp)
    	local p = Instance.new("Part")
    	p.Name          = name
    	p.Shape         = Enum.PartType.Cylinder
    	p.Size          = Vector3.new(height, diam, diam)
    	p.CFrame        = cframe * CFrame.Angles(0, 0, math.pi/2)
    	p.Color         = color or C.ruinStone
    	p.Material      = material or MAT.stone
    	p.Transparency  = transp or 0
    	p.Anchored      = true
    	p.TopSurface    = Enum.SurfaceType.Smooth
    	p.BottomSurface = Enum.SurfaceType.Smooth
    	p.Parent        = folder
    	return p
    end
    
    local function sphere(name, diam, cframe, color, material, transp)
    	local p = Instance.new("Part")
    	p.Name         = name
    	p.Shape        = Enum.PartType.Ball
    	p.Size         = Vector3.new(diam, diam, diam)
    	p.CFrame       = cframe
    	p.Color        = color or C.ruinStone
    	p.Material     = material or MAT.plast
    	p.Transparency = transp or 0
    	p.Anchored     = true
    	p.Parent       = folder
    	return p
    end
    
    local function addLight(parent, color, brightness, range)
    	local l = Instance.new("PointLight", parent)
    	l.Color      = color
    	l.Brightness = brightness or 3
    	l.Range      = range or 18
    	l.Enabled    = true
    end
    
    local function billboard(parent, text, size)
    	local bg = Instance.new("BillboardGui", parent)
    	bg.Size        = UDim2.fromOffset(size or 60, 28)
    	bg.StudsOffset = Vector3.new(0, 3, 0)
    	bg.AlwaysOnTop = false
    	local lbl = Instance.new("TextLabel", bg)
    	lbl.Size                   = UDim2.fromScale(1, 1)
    	lbl.BackgroundTransparency = 1
    	lbl.Text                   = text
    	lbl.TextColor3             = Color3.new(1, 1, 1)
    	lbl.TextScaled             = true
    end
    
    local GY = 0
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 1: FOREST FLOOR BASE
    -- ═══════════════════════════════════════════════════════════════
    
    -- Ground base (dark, mossy)
    part("Forest_Floor",
    	Vector3.new(200, 4, 240),
    	cf(0, GY - 2, 0), C.groundDark, MAT.grass)
    
    part("Forest_Floor_Top",
    	Vector3.new(190, 1.5, 230),
    	cf(0, GY + 0.6, 0), C.groundMid, MAT.grass)
    
    -- Moss patches
    local mossSpots = {
    	{-40, -30}, {30, -60}, {-70, 20}, {55, 45},
    	{-20, 80},  {70, -20}, {-85, -55},{40, -90},
    	{-50, 55},  {80, 70},  {-30, -90},{10, 60},
    }
    for _, ms in ipairs(mossSpots) do
    	part("MossPatch",
    		Vector3.new(math.random(6,16), 0.4, math.random(5,12)),
    		cfr(ms[1], GY + 0.8, ms[2], 0, math.random() * math.pi, 0),
    		C.groundMoss, MAT.grass, 0.1)
    end
    
    -- Dead grass tufts
    for i = 1, 18 do
    	local angle = (i/18)*math.pi*2
    	local r = 50 + math.sin(i*3.1)*28
    	part("DeadGrass",
    		Vector3.new(math.random(2,5), math.random(1,3), math.random(2,5)),
    		cfr(math.cos(angle)*r, GY+1, math.sin(angle)*r, 0, math.random()*math.pi, 0),
    		C.deadGrass, MAT.grass, 0.2)
    end
    
    -- Biome transition W edge (border with Highgard paths)
    part("Transition_W",
    	Vector3.new(20, 1.5, 230),
    	cf(-100, GY + 1, 0), C.groundMid, MAT.grass)
    part("Transition_W2",
    	Vector3.new(10, 1, 230),
    	cf(-108, GY + 0.8, 0), C.deadGrass, MAT.grass)
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 2: DARK SPRUCE TREES (60% of forest)
    -- ═══════════════════════════════════════════════════════════════
    
    local spruceData = {
    	-- outer perimeter
    	{-85, -100, 20, 1.2}, {-60, -105, 18, 1.0}, {-30, -108, 22, 1.3},
    	{  5, -105, 17, 0.9}, { 40, -100, 21, 1.2}, { 75, -95,  19, 1.1},
    	{ 98,  -70, 20, 1.0}, {102,  -35, 18, 0.9}, {100,   0, 22, 1.2},
    	{ 98,   35, 17, 0.9}, { 95,   70, 20, 1.1}, { 72,  98, 19, 1.0},
    	{ 35,  105, 21, 1.2}, {  0,  108, 18, 1.0}, {-35,  102, 20, 1.1},
    	{-68,   95, 17, 0.9}, {-92,   68, 22, 1.3}, {-98,   35, 19, 1.0},
    	{-100,   0, 20, 1.1}, {-95,  -35, 18, 0.9}, {-92,  -70, 21, 1.2},
    	-- inner fill
    	{-55, -60, 16, 0.85},{-20, -72, 19, 1.0}, { 25, -65, 17, 0.9},
    	{ 65, -48, 18, 1.0}, { 78,  12, 15, 0.8}, { 65,  55, 16, 0.85},
    	{ 25,  80, 18, 1.0}, {-30,  75, 16, 0.9}, {-68,  45, 17, 0.85},
    	{-78, -12, 19, 1.1}, {-55,  25, 14, 0.8}, { 30,  30, 15, 0.75},
    	{-15, -45, 16, 0.9}, { 50,  -5, 17, 0.9}, {-40, -10, 15, 0.8},
    }
    
    for _, td in ipairs(spruceData) do
    	local tx, tz, th, ts = td[1], td[2], td[3], td[4]
    	cyl("SprT", th*0.28, 1.5*ts, cf(tx, GY+th*0.14, tz), C.trunkBrown, MAT.wood)
    	local tiers = {
    		{0.72, 6*ts,   C.treeDarkGreen,  0   },
    		{0.52, 4.5*ts, C.treeMidGreen,   0   },
    		{0.33, 3.2*ts, C.treeLightGreen, 0   },
    		{0.16, 2.0*ts, C.treeDarkGreen,  0   },
    	}
    	for _, tier in ipairs(tiers) do
    		sphere("SprF", tier[2], cf(tx, GY+th*tier[1], tz), tier[3], MAT.grass, tier[4])
    	end
    end
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 3: ANOMALOUS PURPLE TREES (~40%)
    -- ═══════════════════════════════════════════════════════════════
    
    local purpleData = {
    	{-48, -30, 18, 1.1}, { 42,  18, 20, 1.2}, {-22,  50, 17, 1.0},
    	{ 62, -25, 19, 1.0}, {-70,  15, 22, 1.3}, { 35, -38, 16, 0.9},
    	{-30,  22, 21, 1.2}, { 58,  40, 18, 1.0}, {-62, -45, 20, 1.1},
    	{ 18,  65, 17, 0.9}, {-80,  58, 22, 1.3}, { 82, -55, 19, 1.1},
    	{-12, -58, 16, 0.85},{  5,  88, 20, 1.1}, {-88, -28, 18, 1.0},
    }
    
    for _, td in ipairs(purpleData) do
    	local tx, tz, th, ts = td[1], td[2], td[3], td[4]
    	-- Twisted dark trunk
    	cyl("PurT", th*0.32, 1.4*ts, cf(tx, GY+th*0.16, tz), C.trunkDark, MAT.wood)
    	-- Tilted trunk section
    	cyl("PurTilt", th*0.2, 1.2*ts,
    		cfr(tx+1, GY+th*0.3, tz, 0, 0, math.rad(8)), C.trunkDark, MAT.wood)
    	-- Purple foliage — irregular blobs
    	local purTiers = {
    		{0.68, 6.5*ts, C.treePurpleDk},
    		{0.50, 5.0*ts, C.treePurpleMid},
    		{0.32, 3.5*ts, C.treePurpleLt},
    		{0.18, 2.2*ts, C.treePurpleMid},
    	}
    	for _, tier in ipairs(purTiers) do
    		sphere("PurF", tier[2], cf(tx, GY+th*tier[1], tz), tier[3], MAT.grass)
    		-- Offset "wisp" blob
    		sphere("PurFW", tier[2]*0.4,
    			cf(tx+tier[2]*0.35, GY+th*tier[1]+0.5, tz-tier[2]*0.3),
    			C.treePurpleLt, MAT.grass, 0.15)
    	end
    	-- Faint purple glow at base
    	local glowPt = part("PurGlow", Vector3.new(0.2, 0.2, 0.2),
    		cf(tx, GY+1, tz), C.glowPurple, MAT.neon, 0.8)
    	addLight(glowPt, Color3.fromRGB(120, 40, 180), 1.5, 12)
    end
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 4: UNDERGROWTH — Grey bushes & dead wood
    -- ═══════════════════════════════════════════════════════════════
    
    local bushPositions = {
    	{-35, -20},{25, -45},{-62, 30},{44, -10},{-18, 42},
    	{ 70,  25},{-45, 65},{20,  55},{-75,-15},{ 55,-65},
    	{-10, -70},{38,  70},{-55,-80},{ 80, 50},{-25, -5},
    }
    for _, bp in ipairs(bushPositions) do
    	sphere("Bush", 2.5 + math.random()*1.5,
    		cf(bp[1], GY+1.2, bp[2]), C.bushGrey, MAT.grass)
    	-- extra small cluster
    	sphere("BushSmall", 1.4,
    		cf(bp[1]+2, GY+0.8, bp[2]+1.5), C.bushGrey, MAT.grass, 0.1)
    end
    
    -- Dead fallen logs (scattered)
    local fallenLogs = {
    	{-38,  10, math.rad(35)}, { 28, -32, math.rad(-20)},
    	{ 55,  30, math.rad(10)}, {-60, -50, math.rad(55)},
    	{ 10,  75, math.rad(-5)}, {-20, -85, math.rad(40)},
    }
    for _, fl in ipairs(fallenLogs) do
    	cyl("FallenLog", 18, 2.5,
    		cfr(fl[1], GY+0.6, fl[2], 0, fl[3], math.pi/2),
    		C.trunkBrown, MAT.wood)
    	-- Moss on log
    	part("LogMoss", Vector3.new(10, 0.5, 2.5),
    		cfr(fl[1], GY+1.6, fl[2], 0, fl[3], 0),
    		C.ruinMoss, MAT.grass, 0.2)
    end
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 5: RUINS — BROKEN COLUMNS
    -- ═══════════════════════════════════════════════════════════════
    
    -- Ruin cluster 1 (NE area)
    local RC1X, RC1Z = 45, -50
    
    -- Standing columns (partial heights)
    local col1Data = {
    	{RC1X - 8, RC1Z - 5, 12}, {RC1X + 8, RC1Z - 5, 7},
    	{RC1X - 8, RC1Z + 5, 4},  {RC1X + 8, RC1Z + 5, 9},
    }
    for i, cd in ipairs(col1Data) do
    	cyl("Col1_"..i, cd[3], 3, cf(cd[1], GY+cd[3]/2, cd[2]), C.ruinStone, MAT.slate)
    	-- Capital
    	part("ColCap1_"..i, Vector3.new(4, 1, 4),
    		cf(cd[1], GY+cd[3]+0.5, cd[2]), C.ruinLight, MAT.slate)
    	-- Moss
    	part("ColMoss1_"..i, Vector3.new(3.5, math.random(2,5), 0.5),
    		cfr(cd[1], GY+cd[3]*0.4, cd[2]+1.5, 0, math.random()*0.3, 0),
    		C.ruinMoss, MAT.grass, 0.2)
    end
    
    -- Fallen column (horizontal)
    cyl("FallenCol1", 14, 3,
    	cfr(RC1X, GY+1.2, RC1Z+12, 0, math.rad(20), math.pi/2),
    	C.ruinDark, MAT.slate)
    cyl("FallenCol1b", 8, 3,
    	cfr(RC1X-5, GY+0.8, RC1Z+16, 0, math.rad(-15), math.pi/2),
    	C.ruinDark, MAT.slate)
    
    -- Wall fragment
    part("WallFrag1", Vector3.new(14, 8, 1.5),
    	cfr(RC1X, GY+4, RC1Z-10, 0, math.rad(5), 0),
    	C.ruinStone, MAT.slate)
    part("WallFrag1b", Vector3.new(6, 5, 1.5),
    	cfr(RC1X+10, GY+2.5, RC1Z-10, 0, math.rad(5), math.rad(12)),
    	C.ruinDark, MAT.slate)
    
    -- Ruin cluster 2 (South area)
    local RC2X, RC2Z = -30, 70
    
    local col2Data = {
    	{RC2X - 6, RC2Z - 4, 10}, {RC2X + 6, RC2Z - 4, 6},
    	{RC2X,     RC2Z + 8, 8},
    }
    for i, cd in ipairs(col2Data) do
    	cyl("Col2_"..i, cd[3], 3, cf(cd[1], GY+cd[3]/2, cd[2]), C.ruinStone, MAT.slate)
    	part("ColCap2_"..i, Vector3.new(4, 1, 4),
    		cf(cd[1], GY+cd[3]+0.5, cd[2]), C.ruinLight, MAT.slate)
    end
    -- Fallen column rc2
    cyl("FallenCol2", 12, 3,
    	cfr(RC2X+8, GY+1, RC2Z+2, 0, math.rad(-30), math.pi/2),
    	C.ruinDark, MAT.slate)
    
    -- Wall fragment rc2
    part("WallFrag2", Vector3.new(10, 6, 1.5),
    	cfr(RC2X - 8, GY+3, RC2Z, 0, math.rad(-10), 0),
    	C.ruinStone, MAT.slate)
    part("WallFrag2b", Vector3.new(5, 3, 1.5),
    	cfr(RC2X - 12, GY+1.5, RC2Z+2, 0, math.rad(-10), math.rad(-18)),
    	C.ruinDark, MAT.slate)
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 6: RUINED ARCH (main landmark, SE area)
    -- ═══════════════════════════════════════════════════════════════
    
    local AX, AZ = 62, 62
    
    -- Left pillar
    cyl("Arch_PillarL", 14, 4, cf(AX - 7, GY+7, AZ), C.ruinStone, MAT.slate)
    part("Arch_CapL", Vector3.new(5, 1.5, 5), cf(AX-7, GY+14.8, AZ), C.ruinLight, MAT.slate)
    -- Right pillar
    cyl("Arch_PillarR", 14, 4, cf(AX + 7, GY+7, AZ), C.ruinStone, MAT.slate)
    part("Arch_CapR", Vector3.new(5, 1.5, 5), cf(AX+7, GY+14.8, AZ), C.ruinLight, MAT.slate)
    -- Lintel (top beam — cracked)
    part("Arch_Lintel", Vector3.new(18, 2.5, 3.5), cf(AX, GY+15.5, AZ), C.ruinStone, MAT.slate)
    -- Lintel crack (dark wedge)
    wedge("Arch_Crack", Vector3.new(3, 2.5, 3.5),
    	cfr(AX+2, GY+15.5, AZ, 0, 0, math.rad(15)), C.ruinDark, MAT.slate)
    -- Fallen lintel chunk
    part("Arch_Chunk", Vector3.new(4, 2.5, 3.5),
    	cfr(AX+5, GY+1, AZ+2, 0, math.rad(25), math.rad(30)), C.ruinDark, MAT.slate)
    -- Rubble around arch
    local archRubble = {
    	{AX-5, AZ+3, 2, 1.5, 2}, {AX+3, AZ-3, 1.5, 1, 1.5}, {AX-9, AZ+1, 3, 2, 3},
    	{AX+8, AZ+4, 2, 1.5, 2}, {AX-2, AZ+5, 1.2, 1, 1.2},
    }
    for _, rb in ipairs(archRubble) do
    	part("ArchRubble",
    		Vector3.new(rb[3], rb[4], rb[5]),
    		cfr(rb[1], GY+rb[4]/2, rb[2], 0, math.random()*math.pi, 0),
    		C.ruinDark, MAT.slate)
    end
    -- Moss on arch pillars
    for _, px in ipairs({AX-7, AX+7}) do
    	part("ArchMoss", Vector3.new(4.5, math.random(4,8), 0.4),
    		cfr(px, GY+6, AZ+2, 0, 0, 0),
    		C.ruinMoss, MAT.grass, 0.2)
    end
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 7: DARK PUDDLES / POOLS
    -- ═══════════════════════════════════════════════════════════════
    
    local puddles = {
    	{-25, -15, 12, 8}, { 50, -40, 8, 6},
    	{-55,  40, 10, 7}, { 20,  45, 14, 9},
    	{ 75,  10, 6,  5},
    }
    for _, pd in ipairs(puddles) do
    	part("Puddle",
    		Vector3.new(pd[3], 0.4, pd[4]),
    		cf(pd[1], GY+0.1, pd[2]), C.waterDark, MAT.glass, 0.35)
    	-- Dark reflection rim
    	part("PuddleRim",
    		Vector3.new(pd[3]+2, 0.2, pd[4]+2),
    		cf(pd[1], GY+0.0, pd[2]), C.mudGrey, MAT.stone, 0.1)
    end
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 8: PATH FROM HIGHGARD (entering W edge)
    -- ═══════════════════════════════════════════════════════════════
    
    local pathColor = C.pathDirt
    
    -- Path enters from west, narrows and fades into forest
    local pathNodes = {
    	{ x=-95, z= 0,  w=6, l=20 },
    	{ x=-80, z= 2,  w=5, l=25, rot=math.rad(-8) },
    	{ x=-60, z= 5,  w=5, l=30, rot=math.rad(-5) },
    	{ x=-38, z= 8,  w=4, l=30, rot=math.rad(-3) },
    	{ x=-18, z= 12, w=4, l=30, rot=math.rad( 5) },
    }
    for i, pn in ipairs(pathNodes) do
    	part("Path_E_"..i,
    		Vector3.new(pn.w, 0.4, pn.l),
    		cfr(pn.x, GY+0.2, pn.z, 0, pn.rot or 0, 0),
    		pathColor, MAT.stone, i*0.1)
    	-- Stones along path edge
    	for _, side in ipairs({-1, 1}) do
    		sphere("PathStone", 0.5,
    			cf(pn.x + side*(pn.w/2+0.5), GY+0.3, pn.z),
    			C.ruinLight, MAT.slate)
    	end
    end
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 9: DANGER SKULL MARKER (entrance to forest)
    -- ═══════════════════════════════════════════════════════════════
    
    local DMX, DMZ = -88, -5
    
    part("Danger_Post",  Vector3.new(0.5, 6, 0.5), cf(DMX, GY+3, DMZ), C.woodPost, MAT.wood)
    part("Danger_Cross", Vector3.new(4, 0.5, 0.5), cf(DMX, GY+6.5, DMZ), C.woodPost, MAT.wood)
    part("Danger_Board", Vector3.new(3.5, 3, 0.4), cf(DMX, GY+5.5, DMZ), C.woodPost, MAT.wood)
    local dPt = part("Danger_Skull", Vector3.new(1, 1, 1),
    	cf(DMX, GY+9, DMZ), C.dangerRed, MAT.neon)
    addLight(dPt, Color3.fromRGB(255, 40, 40), 4, 16)
    billboard(dPt, "☠", 44)
    
    -- Second marker deeper in forest (near arch)
    local DM2X, DM2Z = AX-20, AZ-15
    part("Danger2_Post",  Vector3.new(0.5, 5, 0.5), cf(DM2X, GY+2.5, DM2Z), C.woodPost, MAT.wood)
    part("Danger2_Cross", Vector3.new(3.5, 0.4, 0.4), cf(DM2X, GY+5.5, DM2Z), C.woodPost, MAT.wood)
    local d2Pt = part("Danger2_Skull", Vector3.new(0.8, 0.8, 0.8),
    	cf(DM2X, GY+7, DM2Z), C.dangerRed, MAT.neon)
    addLight(d2Pt, Color3.fromRGB(255, 40, 40), 3, 12)
    billboard(d2Pt, "☠", 38)
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 10: SKELETON NPCs
    -- ═══════════════════════════════════════════════════════════════
    
    local function spawnSkeleton(x, z, name, withSword)
    	-- Bones
    	part("Skel_Torso",  Vector3.new(2, 2.5, 1),   cf(x, GY+2.75, z), C.boneWhite, MAT.plast)
    	-- Rib detail
    	part("Skel_Rib1",   Vector3.new(1.8, 0.3, 0.9), cf(x, GY+2.5, z), C.boneGrey, MAT.plast)
    	part("Skel_Rib2",   Vector3.new(1.8, 0.3, 0.9), cf(x, GY+3.2, z), C.boneGrey, MAT.plast)
    	sphere("Skel_Head",  1.8, cf(x, GY+5, z), C.boneWhite, MAT.plast)
    	-- Hollow eye sockets
    	sphere("Skel_EyeL", 0.5, cf(x-0.45, GY+5.15, z-0.75), C.black, MAT.plast)
    	sphere("Skel_EyeR", 0.5, cf(x+0.45, GY+5.15, z-0.75), C.black, MAT.plast)
    	part("Skel_LegL",   Vector3.new(0.7, 2.2, 0.7), cf(x-0.5, GY+1, z), C.boneWhite, MAT.plast)
    	part("Skel_LegR",   Vector3.new(0.7, 2.2, 0.7), cf(x+0.5, GY+1, z), C.boneWhite, MAT.plast)
    	part("Skel_ArmL",   Vector3.new(0.6, 2.0, 0.6),
    		cfr(x-1.3, GY+2.5, z, 0, 0, math.rad(25)), C.boneWhite, MAT.plast)
    	part("Skel_ArmR",   Vector3.new(0.6, 2.0, 0.6),
    		cfr(x+1.3, GY+2.5, z, 0, 0, math.rad(-25)), C.boneWhite, MAT.plast)
    	if withSword then
    		-- Sword: blade
    		part("Skel_Blade",
    			Vector3.new(0.3, 8, 0.5),
    			cfr(x+1.8, GY+3.5, z, 0, 0, math.rad(-10)), C.weaponMetal, MAT.metal)
    		-- Crossguard
    		part("Skel_Guard",
    			Vector3.new(3, 0.4, 0.6),
    			cfr(x+1.8, GY+2.5, z, 0, 0, 0), C.weaponMetal, MAT.metal)
    		-- Handle
    		part("Skel_Handle",
    			Vector3.new(0.4, 2.5, 0.5),
    			cfr(x+1.8, GY+1.5, z, 0, 0, math.rad(-5)), C.weaponWood, MAT.wood)
    	else
    		-- Spear
    		cyl("Skel_SpearShaft", 10, 0.5,
    			cfr(x+1.8, GY+5, z, 0, 0, math.rad(-8)), C.weaponWood, MAT.wood)
    		part("Skel_SpearTip",
    			Vector3.new(0.6, 3, 0.6),
    			cfr(x+2.2, GY+9.5, z, 0, 0, math.rad(-8)), C.weaponMetal, MAT.metal)
    	end
    	local anchor = part("Skel_Label", Vector3.new(0.1,0.1,0.1),
    		cf(x, GY+7, z), C.black, MAT.plast, 1)
    	billboard(anchor, name, 90)
    end
    
    spawnSkeleton(RC1X + 3, RC1Z + 2, "Skeleton", true)
    spawnSkeleton(AX - 10, AZ - 8,    "Skeleton", false)
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 11: WOLF NPC
    -- ═══════════════════════════════════════════════════════════════
    
    local WFX, WFZ = -30, -35
    
    -- Body
    part("Wolf_Body",  Vector3.new(3.5, 2.2, 2),   cf(WFX, GY+2, WFZ), C.wolfGrey, MAT.plast)
    -- Head
    part("Wolf_Head",  Vector3.new(2, 1.8, 2.5),   cf(WFX, GY+3.2, WFZ-1.5), C.wolfGrey, MAT.plast)
    part("Wolf_Snout", Vector3.new(1.2, 1, 1.8),   cf(WFX, GY+2.8, WFZ-2.8), C.wolfSnout, MAT.plast)
    -- Ears
    part("Wolf_EarL",  Vector3.new(0.5, 0.8, 0.3), cf(WFX-0.7, GY+4.2, WFZ-1.2), C.wolfDark, MAT.plast)
    part("Wolf_EarR",  Vector3.new(0.5, 0.8, 0.3), cf(WFX+0.7, GY+4.2, WFZ-1.2), C.wolfDark, MAT.plast)
    -- Eyes (amber glow)
    local eyeL = part("Wolf_EyeL", Vector3.new(0.35, 0.35, 0.2),
    	cf(WFX-0.55, GY+3.3, WFZ-2.6), C.wolfEye, MAT.neon)
    local eyeR = part("Wolf_EyeR", Vector3.new(0.35, 0.35, 0.2),
    	cf(WFX+0.55, GY+3.3, WFZ-2.6), C.wolfEye, MAT.neon)
    addLight(eyeL, Color3.fromRGB(255, 165, 15), 1.5, 8)
    addLight(eyeR, Color3.fromRGB(255, 165, 15), 1.5, 8)
    -- Legs
    local wolfLegPos = {
    	{WFX-1, WFZ-0.8}, {WFX+1, WFZ-0.8}, {WFX-1, WFZ+0.8}, {WFX+1, WFZ+0.8}
    }
    for _, lp in ipairs(wolfLegPos) do
    	part("Wolf_Leg", Vector3.new(0.7, 2, 0.7), cf(lp[1], GY+0.8, lp[2]), C.wolfDark, MAT.plast)
    end
    -- Tail
    cyl("Wolf_Tail", 3, 0.8,
    	cfr(WFX, GY+3.2, WFZ+2, math.rad(-30), 0, 0), C.wolfGrey, MAT.plast)
    local anchor2 = part("Wolf_Label", Vector3.new(0.1,0.1,0.1),
    	cf(WFX, GY+6, WFZ), C.black, MAT.plast, 1)
    billboard(anchor2, "Wolf", 70)
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 12: PURPLE GLOW WISPS (atmospheric)
    -- ═══════════════════════════════════════════════════════════════
    
    local wispPositions = {
    	{ 18, -28, 8}, {-42, 32, 6}, {55, 60, 10},
    	{-68, -42, 7}, {30,  80, 9}, {-15, 15, 5},
    }
    for _, wp in ipairs(wispPositions) do
    	-- Floating glow orb
    	local wisp = sphere("Wisp", 1.2,
    		cf(wp[1], GY+wp[3], wp[2]), C.glowPurple, MAT.neon, 0.2)
    	addLight(wisp, Color3.fromRGB(130, 45, 200), 2.5, 14)
    	-- Outer haze
    	sphere("WispHaze", 2.8,
    		cf(wp[1], GY+wp[3], wp[2]), C.glowPurple, MAT.plast, 0.82)
    end
    
    -- ═══════════════════════════════════════════════════════════════
    -- SECTION 13: ATMOSPHERIC FOG VOLUMES (translucent slabs)
    -- ═══════════════════════════════════════════════════════════════
    
    local fogSlabs = {
    	{ 0,  20, 80, 8, 60}, {-40, 28, 70, 8, 50},
    	{ 40, 18, 65, 6, 55}, {-10, 22, 90, 6, 70},
    }
    for i, fs in ipairs(fogSlabs) do
    	part("FogSlab_"..i,
    		Vector3.new(fs[3], fs[4], fs[5]),
    		cf(fs[1], GY+fs[2], 0), C.fogColor, MAT.plast, 0.88)
    end
    
    -- ── FINAL REPORT ─────────────────────────────────────────────────
    local count = #folder:GetDescendants()
    print(string.format(
    	"[GloomWood Zone5] ✅ Done!  %d objects created in workspace.GloomWood_Zone5",
    	count
    ))
    end
    print("[HighgardPlugin] ✅ Zone5_GloomWood complete.")
end


-- ────────────────────────────────────────────────────────────────
zoneFunctions["Zone6_FensOfDespair"] = function()
    print("[HighgardPlugin] 🔨 Building Zone6_FensOfDespair...")
    do
    local ORIGIN = CFrame.new(280, 50, 280)
    
    -- ── Palette ─────────────────────────────────────────────────────
    local C = {
    	-- Ground / terrain
    	mudDark      = Color3.fromRGB( 38,  32,  22),
    	mudMid       = Color3.fromRGB( 52,  44,  30),
    	mudLight     = Color3.fromRGB( 68,  58,  38),
    	swampGrass   = Color3.fromRGB( 52,  68,  35),
    	swampMoss    = Color3.fromRGB( 42,  72,  30),
    	dirtGrey     = Color3.fromRGB( 58,  55,  48),
    	peatBrown    = Color3.fromRGB( 48,  38,  22),
    
    	-- Water / bog
    	waterBlack   = Color3.fromRGB( 18,  28,  22),
    	waterDark    = Color3.fromRGB( 22,  42,  30),
    	waterMid     = Color3.fromRGB( 28,  55,  38),
    	waterMurky   = Color3.fromRGB( 35,  62,  40),
    	waterGlow    = Color3.fromRGB( 45, 120,  58),   -- eerie bioluminescent
    
    	-- Temple ruins
    	ruinBase     = Color3.fromRGB(105,  98,  88),
    	ruinDark     = Color3.fromRGB( 72,  65,  55),
    	ruinMid      = Color3.fromRGB( 88,  82,  72),
    	ruinLight    = Color3.fromRGB(135, 128, 118),
    	ruinMoss     = Color3.fromRGB( 58,  82,  45),
    	ruinStain    = Color3.fromRGB( 62,  55,  45),
    	marbleWhite  = Color3.fromRGB(198, 192, 182),
    	marbleCrack  = Color3.fromRGB(155, 148, 138),
    
    	-- Dead trees
    	deadTrunk    = Color3.fromRGB( 42,  35,  25),
    	deadBranch   = Color3.fromRGB( 52,  42,  30),
    	deadBark     = Color3.fromRGB( 62,  50,  35),
    	rottenWood   = Color3.fromRGB( 38,  30,  20),
    	lichGrey     = Color3.fromRGB( 82,  80,  72),
    
    	-- Skeleton / undead NPCs
    	boneWhite    = Color3.fromRGB(225, 218, 202),
    	boneMid      = Color3.fromRGB(188, 182, 165),
    	boneYellow   = Color3.fromRGB(198, 185, 138),
    	rotFlesh     = Color3.fromRGB( 88,  68,  48),
    	reapRobe     = Color3.fromRGB( 28,  25,  22),
    	reapCloth    = Color3.fromRGB( 42,  38,  32),
    	glowGreen    = Color3.fromRGB( 55, 215,  75),   -- undead eye glow
    	glowYellow   = Color3.fromRGB(215, 195,  25),
    
    	-- Wisps / atmosphere
    	wispGreen    = Color3.fromRGB( 60, 220,  80),
    	wispTeal     = Color3.fromRGB( 45, 185, 145),
    	wispBlue     = Color3.fromRGB( 55, 135, 210),
    	fogGrey      = Color3.fromRGB( 65,  72,  60),
    
    	-- Metal / iron
    	ironRust     = Color3.fromRGB( 88,  52,  28),
    	ironDark     = Color3.fromRGB( 45,  42,  38),
    	chainOld     = Color3.fromRGB( 55,  50,  45),
    
    	-- Misc
    	mushCap      = Color3.fromRGB(175,  62,  38),
    	mushStem     = Color3.fromRGB(198, 178, 148),
    	mushPurple   = Color3.fromRGB(125,  45, 155),
    	mushGlow     = Color3.fromRGB( 95, 215,  95),
    	pathMud      = Color3.fromRGB( 50,  42,  28),
    	signWood     = Color3.fromRGB( 78,  52,  22),
    	ropeOld      = Color3.fromRGB(115,  92,  55),
    	black        = Color3.fromRGB( 12,  10,   8),
    	npcSkin      = Color3.fromRGB(215, 178, 135),
    }
    
    local M = Enum.Material
    local MAT = {
    	stone  = M.SmoothPlastic,
    	cobble = M.Cobblestone,
    	wood   = M.Wood,
    	metal  = M.Metal,
    	glass  = M.Glass,
    	neon   = M.Neon,
    	grass  = M.Grass,
    	slate  = M.Slate,
    	fabric = M.Fabric,
    	sand   = M.Sand,
    	plast  = M.SmoothPlastic,
    	ice    = M.Ice,
    }
    
    -- ── Root folder ──────────────────────────────────────────────────
    local folder = Instance.new("Folder")
    folder.Name   = "FensOfDespair_Zone6"
    folder.Parent = workspace
    
    -- ── Helpers ──────────────────────────────────────────────────────
    local function cf(x,y,z)              return ORIGIN * CFrame.new(x,y,z) end
    local function cfr(x,y,z,rx,ry,rz)   return cf(x,y,z)*CFrame.Angles(rx,ry,rz) end
    
    local function part(name, size, cframe, color, material, transparency)
    	local p = Instance.new("Part")
    	p.Name          = name
    	p.Size          = size
    	p.CFrame        = cframe
    	p.Color         = color or C.ruinBase
    	p.Material      = material or MAT.stone
    	p.Transparency  = transparency or 0
    	p.Anchored      = true
    	p.CastShadow    = true
    	p.TopSurface    = Enum.SurfaceType.Smooth
    	p.BottomSurface = Enum.SurfaceType.Smooth
    	p.Parent        = folder
    	return p
    end
    
    local function wedge(name, size, cframe, color, material)
    	local p = Instance.new("WedgePart")
    	p.Name          = name
    	p.Size          = size
    	p.CFrame        = cframe
    	p.Color         = color or C.ruinBase
    	p.Material      = material or MAT.stone
    	p.Anchored      = true
    	p.TopSurface    = Enum.SurfaceType.Smooth
    	p.BottomSurface = Enum.SurfaceType.Smooth
    	p.Parent        = folder
    	return p
    end
    
    local function cyl(name, height, diam, cframe, color, material, transp)
    	local p = Instance.new("Part")
    	p.Name          = name
    	p.Shape         = Enum.PartType.Cylinder
    	p.Size          = Vector3.new(height, diam, diam)
    	p.CFrame        = cframe * CFrame.Angles(0, 0, math.pi/2)
    	p.Color         = color or C.ruinBase
    	p.Material      = material or MAT.stone
    	p.Transparency  = transp or 0
    	p.Anchored      = true
    	p.TopSurface    = Enum.SurfaceType.Smooth
    	p.BottomSurface = Enum.SurfaceType.Smooth
    	p.Parent        = folder
    	return p
    end
    
    local function sphere(name, diam, cframe, color, material, transp)
    	local p = Instance.new("Part")
    	p.Name          = name
    	p.Shape         = Enum.PartType.Ball
    	p.Size          = Vector3.new(diam,diam,diam)
    	p.CFrame        = cframe
    	p.Color         = color or C.ruinBase
    	p.Material      = material or MAT.stone
    	p.Transparency  = transp or 0
    	p.Anchored      = true
    	p.Parent        = folder
    	return p
    end
    
    local function addPointLight(parent, color, brightness, range)
    	local l = Instance.new("PointLight", parent)
    	l.Color      = color
    	l.Brightness = brightness or 2
    	l.Range      = range or 16
    	l.Enabled    = true
    end
    
    local function addBillboard(parent, text, size)
    	local bg = Instance.new("BillboardGui", parent)
    	bg.Size        = UDim2.fromOffset(size or 80, 28)
    	bg.StudsOffset = Vector3.new(0, 3, 0)
    	bg.AlwaysOnTop = false
    	local lbl = Instance.new("TextLabel", bg)
    	lbl.Size                  = UDim2.fromScale(1,1)
    	lbl.BackgroundTransparency = 1
    	lbl.Text                  = text
    	lbl.TextColor3            = Color3.fromRGB(100, 220, 100)
    	lbl.TextScaled            = true
    end
    
    local GY = 0   -- local ground Y
    
    -- ================================================================
    -- SECTION 1: TERRAIN BASE — swampy ground layers
    -- ================================================================
    
    -- Main bog ground
    part("FenGround",
    	Vector3.new(320, 2, 320),
    	cf(0, GY - 1, 0), C.mudDark, MAT.grass)
    
    -- Mud variation patches
    local mudPatches = {
    	{ 40,  30, 10, 18}, {-50,  20,  8, 14}, { 20, -45, 12, 16},
    	{-30, -35,  9, 15}, { 70, -20,  7, 12}, {-65,  55, 10, 18},
    	{ 15,  65,  8, 13}, {-10, -70, 11, 17}, { 55,  55, 9, 14},
    	{-55, -55, 10, 16},
    }
    for _, mp in ipairs(mudPatches) do
    	part("MudPatch",
    		Vector3.new(mp[3], 0.6, mp[4]),
    		cfr(mp[1], GY + 0.3, mp[2], 0, math.random()*math.pi, 0),
    		C.mudMid, MAT.grass)
    end
    
    -- Raised hummocks (tussock mounds)
    local hummocks = {
    	{ 80,  80}, {-90,  75}, { 85, -85}, {-80, -90},
    	{ 45, 110}, {-50, -110},{ 110, 40}, {-112, -35},
    }
    for _, h in ipairs(hummocks) do
    	local hw = math.random(6,14)
    	local hh = math.random(2,5)
    	sphere("Hummock", hw,
    		cf(h[1], GY + hh*0.5 - 1, h[2]), C.swampGrass, MAT.grass)
    	sphere("HummockTop", hw*0.6,
    		cf(h[1], GY + hh*0.5 + hw*0.2, h[2]),
    		Color3.fromRGB(48, 72, 30), MAT.grass)
    end
    
    -- Moss strips
    for i = 1, 16 do
    	local angle = (i/16)*2*math.pi
    	local r = 80 + math.sin(i*2.3)*25
    	part("MossStrip",
    		Vector3.new(math.random(4,10), 0.4, math.random(3,8)),
    		cfr(math.cos(angle)*r, GY+0.2, math.sin(angle)*r,
    			0, math.random()*math.pi, 0),
    		C.swampMoss, MAT.grass)
    end
    
    -- ================================================================
    -- SECTION 2: BOG POOLS — dark murky water
    -- ================================================================
    
    -- Main central bog pool
    part("BogPool_Main",
    	Vector3.new(60, 1.5, 45),
    	cf(30, GY - 0.75, 20), C.waterDark, MAT.glass, 0.3)
    
    -- Bioluminescent shimmer layer on top
    local glowPool = part("BogPool_Glow",
    	Vector3.new(58, 0.4, 43),
    	cf(30, GY + 0.1, 20), C.waterGlow, MAT.neon, 0.65)
    addPointLight(glowPool, Color3.fromRGB(45, 185, 65), 1.2, 22)
    
    -- Secondary bog pools
    local bogPoolData = {
    	{-55,  45, 28, 22}, { 65, -30, 22, 18}, {-40, -60, 32, 25},
    	{ 90,  60, 18, 14}, {-80, -80, 20, 16}, { 10,  90, 24, 18},
    }
    for _, bp in ipairs(bogPoolData) do
    	part("BogPool",
    		Vector3.new(bp[3], 1.2, bp[4]),
    		cf(bp[1], GY - 0.6, bp[2]), C.waterBlack, MAT.glass, 0.35)
    	-- Glowing edges (bioluminescence)
    	local ge = part("BogGlow",
    		Vector3.new(bp[3]+2, 0.3, bp[4]+2),
    		cf(bp[1], GY, bp[2]), C.waterGlow, MAT.neon, 0.75)
    	addPointLight(ge, Color3.fromRGB(40, 160, 55), 0.8, 14)
    end
    
    -- Mud bubble rings (surface detail)
    for i = 1, 10 do
    	local bx = math.random(-60, 90)
    	local bz = math.random(-80, 80)
    	cyl("BubbleRing", 0.3, math.random(2,5),
    		cf(bx, GY+0.05, bz), C.waterMurky, MAT.glass, 0.5)
    end
    
    -- ================================================================
    -- SECTION 3: ANCIENT RUINED TEMPLE COMPLEX
    -- ================================================================
    
    -- Temple sits on a raised stone platform (NE quadrant of zone)
    local TX, TZ = -20, -30   -- temple center offset
    local TPH = GY + 3        -- platform top Y
    
    -- Platform base (3 stacked layers for crumbled effect)
    part("TemplePlatform_1",
    	Vector3.new(90, 5, 85),
    	cf(TX, GY + 2.5, TZ), C.ruinDark, MAT.slate)
    part("TemplePlatform_2",
    	Vector3.new(82, 3, 78),
    	cf(TX, GY + 6.5, TZ), C.ruinMid, MAT.slate)
    part("TemplePlatform_3",
    	Vector3.new(74, 2, 70),
    	cf(TX, GY + 8.5, TZ), C.ruinBase, MAT.cobble)
    
    -- Platform steps (south face)
    for step = 0, 3 do
    	part("TempleStep_S_"..step,
    		Vector3.new(30, 1.5, 4),
    		cf(TX, TPH - step*1.5, TZ + 35 + step*4),
    		Color3.fromRGB(95 + step*5, 90 + step*4, 80 + step*3), MAT.cobble)
    end
    
    -- Platform cracks (dark thin parts across the floor)
    for ci = 1, 5 do
    	local crackX = TX + math.random(-35, 35)
    	local crackLen = math.random(10, 30)
    	part("PlatformCrack_"..ci,
    		Vector3.new(crackLen, 0.3, 0.5),
    		cfr(crackX, TPH + 0.2, TZ + math.random(-30,30),
    			0, math.random()*math.pi, 0),
    		C.ruinDark, MAT.slate)
    end
    
    -- Moss on platform surface
    for mi = 1, 8 do
    	part("PlatformMoss_"..mi,
    		Vector3.new(math.random(4,10), 0.3, math.random(3,7)),
    		cfr(TX + math.random(-35,35), TPH + 0.15, TZ + math.random(-32,32),
    			0, math.random()*math.pi, 0),
    		C.ruinMoss, MAT.grass)
    end
    
    -- ── Standing columns (8 around the temple perimeter) ────────────
    local colPositions = {
    	{TX-32, TZ-28}, {TX-32, TZ},    {TX-32, TZ+28},
    	{TX+32, TZ-28}, {TX+32, TZ},    {TX+32, TZ+28},
    	{TX,    TZ-28}, {TX,    TZ+28},
    }
    local colHeights = { 20, 15, 22, 18, 12, 20, 16, 14 }  -- some broken
    
    for i, cp in ipairs(colPositions) do
    	local ch = colHeights[i]
    	-- Column shaft (cylinder)
    	cyl("Col_Shaft_"..i, 3.5, ch,
    		cf(cp[1], TPH + ch/2, cp[2]), C.marbleWhite, MAT.stone)
    	-- Base plinth
    	part("Col_Base_"..i,
    		Vector3.new(5, 2.5, 5),
    		cf(cp[1], TPH + 1.25, cp[2]), C.ruinBase, MAT.cobble)
    	-- Capital (top block) — only full columns
    	if ch >= 18 then
    		part("Col_Capital_"..i,
    			Vector3.new(5.5, 2, 5.5),
    			cf(cp[1], TPH + ch + 1, cp[2]), C.marbleCrack, MAT.cobble)
    	else
    		-- Broken top: jagged wedge
    		wedge("Col_Broken_"..i,
    			Vector3.new(4, 3, 4),
    			cfr(cp[1], TPH + ch + 1.5, cp[2], 0, math.random()*math.pi, 0),
    			C.ruinMid, MAT.slate)
    	end
    	-- Moss creep on column
    	part("Col_Moss_"..i,
    		Vector3.new(3.6, math.random(2,5), 3.6),
    		cf(cp[1], TPH + 2.5, cp[2]), C.ruinMoss, MAT.grass, 0.2)
    end
    
    -- Fallen columns (lying on platform)
    local fallenCols = {
    	{TX-10, TZ-20, math.rad(90), math.rad(35)},
    	{TX+15, TZ+18, math.rad(90), math.rad(-20)},
    	{TX-25, TZ+10, math.rad(90), math.rad(80)},
    }
    for i, fc in ipairs(fallenCols) do
    	cyl("FallenCol_"..i, 3.5, 16,
    		cfr(fc[1], TPH + 1.75, fc[2], fc[3], fc[4], 0),
    		C.marbleCrack, MAT.stone)
    	-- Broken pieces
    	for pi2 = 1, 2 do
    		part("FallenChunk_"..i.."_"..pi2,
    			Vector3.new(math.random(3,5), math.random(2,4), math.random(3,5)),
    			cfr(fc[1] + math.random(-8,8), TPH + 1.5, fc[2] + math.random(-8,8),
    				0, math.random()*math.pi, 0),
    			C.ruinDark, MAT.slate)
    	end
    end
    
    -- ── Temple inner sanctum walls (partial, crumbled) ───────────────
    local IW = 36   -- inner wall half-width
    local IH = 14   -- inner wall height
    
    -- North wall (partially standing)
    part("TempleWall_N",
    	Vector3.new(IW*2, IH, 3.5),
    	cf(TX, TPH + IH/2, TZ - IW), C.ruinMid, MAT.slate)
    -- Crack in north wall
    part("TempleWallCrack_N",
    	Vector3.new(2, IH, 3.6),
    	cf(TX+8, TPH + IH/2, TZ - IW), C.ruinDark, MAT.slate, 0.1)
    
    -- South wall (heavily ruined — only fragments)
    part("TempleWall_S_L",
    	Vector3.new(22, IH*0.6, 3.5),
    	cf(TX - IW*0.4, TPH + IH*0.3, TZ + IW), C.ruinBase, MAT.slate)
    part("TempleWall_S_R",
    	Vector3.new(14, IH*0.4, 3.5),
    	cfr(TX + IW*0.3, TPH + IH*0.2, TZ + IW, 0, math.rad(3), 0),
    	C.ruinDark, MAT.slate)
    
    -- East wall
    part("TempleWall_E",
    	Vector3.new(3.5, IH, IW*2),
    	cf(TX + IW, TPH + IH/2, TZ), C.ruinMid, MAT.slate)
    -- East wall collapse gap
    part("TempleWall_E_Top",
    	Vector3.new(3.5, IH*0.35, 26),
    	cf(TX + IW, TPH + IH*0.82, TZ + 8), C.ruinBase, MAT.cobble)
    
    -- West wall (most intact)
    part("TempleWall_W",
    	Vector3.new(3.5, IH, IW*2),
    	cf(TX - IW, TPH + IH/2, TZ), C.ruinLight, MAT.slate)
    -- Arched opening in west wall (simulated with two parts)
    part("TempleArch_W_L",
    	Vector3.new(3.6, IH*0.6, 8),
    	cf(TX - IW, TPH + IH*0.3, TZ - 12), C.ruinLight, MAT.slate)
    part("TempleArch_W_R",
    	Vector3.new(3.6, IH*0.6, 8),
    	cf(TX - IW, TPH + IH*0.3, TZ + 12), C.ruinLight, MAT.slate)
    part("TempleArch_W_Top",
    	Vector3.new(3.6, IH*0.4, 30),
    	cf(TX - IW, TPH + IH*0.8, TZ), C.ruinMid, MAT.slate)
    
    -- ── Temple inner floor decoration ────────────────────────────────
    
    -- Central altar
    part("Altar_Base",
    	Vector3.new(10, 3, 8),
    	cf(TX, TPH + 1.5, TZ), C.ruinDark, MAT.slate)
    part("Altar_Top",
    	Vector3.new(8, 1.5, 6),
    	cf(TX, TPH + 3.75, TZ), C.marbleCrack, MAT.cobble)
    -- Altar stain (dark splash)
    part("Altar_Stain",
    	Vector3.new(5, 0.3, 4),
    	cf(TX, TPH + 4.6, TZ), C.ruinStain, MAT.plast, 0.2)
    -- Candles on altar
    for ci2 = 1, 3 do
    	local candleX = TX - 3 + ci2*3
    	part("Candle_"..ci2, Vector3.new(0.5, 1.5, 0.5),
    		cf(candleX, TPH + 4.75, TZ), C.marbleWhite, MAT.plast)
    	local flame = part("CandleFlame_"..ci2, Vector3.new(0.4, 0.6, 0.4),
    		cf(candleX, TPH + 5.55, TZ), C.wispGreen, MAT.neon, 0.3)
    	addPointLight(flame, Color3.fromRGB(50, 200, 70), 1.5, 10)
    end
    
    -- Floor tiles (large slabs, some cracked)
    for txi = -2, 2 do
    	for tzi = -2, 2 do
    		local tileColor = (math.abs(txi + tzi) % 2 == 0) and C.ruinBase or C.ruinMid
    		part("Tile",
    			Vector3.new(11.5, 0.5, 11.5),
    			cf(TX + txi*12, TPH + 0.25, TZ + tzi*12),
    			tileColor, MAT.cobble)
    	end
    end
    
    -- ── Decorative urns / pots around temple ─────────────────────────
    local urnPositions = {
    	{TX-28, TZ+32}, {TX+28, TZ+32}, {TX-28, TZ-32}, {TX+28, TZ-32},
    	{TX-12, TZ+18}, {TX+12, TZ+18},
    }
    for _, up in ipairs(urnPositions) do
    	cyl("Urn_Body", 5, 3, cf(up[1], TPH + 2.5, up[2]), C.ruinMid, MAT.stone)
    	sphere("Urn_Belly", 4.5, cf(up[1], TPH + 2.5, up[2]), C.ruinBase, MAT.cobble)
    	cyl("Urn_Neck",  2, 2, cf(up[1], TPH + 5,   up[2]), C.ruinMid,  MAT.stone)
    	-- Broken urns get a scattered piece
    	if math.random() > 0.5 then
    		part("UrnShard",
    			Vector3.new(2, 1, 1.5),
    			cfr(up[1]+2, TPH+0.6, up[2]+1.5, 0, math.random()*math.pi, 0.4),
    			C.ruinDark, MAT.slate)
    	end
    end
    
    -- ================================================================
    -- SECTION 4: DEAD / TWISTED TREES
    -- ================================================================
    
    local function deadTree(x, z, height, lean)
    	local lean = lean or 0
    	-- Main trunk
    	cyl("DeadTrunk", math.random(2,3)+0.5, height,
    		cfr(x, GY + height/2, z, math.rad(lean), math.random()*math.pi, 0),
    		C.deadTrunk, MAT.wood)
    	-- Major branches
    	local branchCount = math.random(3, 5)
    	for bi = 1, branchCount do
    		local bAngle = (bi/branchCount)*math.pi*2
    		local bLen   = math.random(4, 9)
    		local bY     = height * (0.5 + math.random()*0.4)
    		local bTiltX = math.rad(math.random(20,50))
    		cyl("Branch_"..bi, 1.2, bLen,
    			cfr(x + math.cos(bAngle)*2, GY + bY, z + math.sin(bAngle)*2,
    				bTiltX, bAngle, 0),
    			C.deadBranch, MAT.wood)
    		-- Sub-branches
    		for sbi = 1, 2 do
    			local sbLen = math.random(2,4)
    			local sbAng = bAngle + math.rad(math.random(-60,60))
    			cyl("SubBranch",  0.6, sbLen,
    				cfr(x + math.cos(bAngle)*4, GY + bY + 2, z + math.sin(bAngle)*4,
    					math.rad(math.random(30,70)), sbAng, 0),
    				C.deadBark, MAT.wood)
    		end
    	end
    	-- Exposed roots
    	for ri = 1, 3 do
    		local rAngle = (ri/3)*math.pi*2
    		local rLen   = math.random(3,6)
    		part("Root_"..ri,
    			Vector3.new(rLen, 0.8, 1),
    			cfr(x + math.cos(rAngle)*rLen*0.5, GY + 0.4,
    				z + math.sin(rAngle)*rLen*0.5,
    				0, rAngle, 0.2),
    			C.deadTrunk, MAT.wood)
    	end
    end
    
    local deadTreeData = {
    	{ 70,  10, 12,  8}, {-65,  25, 10,  5}, { 55, -55, 14, -6},
    	{-70, -40, 11,  4}, { 95,  80, 15,  7}, {-85,  90, 13, -5},
    	{ 45,  85, 10,  3}, {-45, -85, 12,  6}, {100, -60, 16, -8},
    	{-95, -70, 11,  5}, { 30,  45,  9,  2}, {-35,  -5, 10,  4},
    	{ 15, -45,  8,  6}, { 80, -10, 13, -4}, {-50,  65, 14,  7},
    }
    
    for _, td in ipairs(deadTreeData) do
    	deadTree(td[1], td[2], td[3], td[4])
    end
    
    -- ================================================================
    -- SECTION 5: STANDING STONES / SCATTERED RUINS
    -- ================================================================
    
    -- Menhir standing stones (ancient markers)
    local menhirData = {
    	{ 55, -15, 6, 18, 3, 2}, {-40,  35, 5, 15, 2.5, 2}, { 25, 70, 7, 20, 3, 2.5},
    	{-60, -25, 4, 12, 2, 1.5},{ 75,  65, 6, 18, 3, 2}, {-70,  5, 5, 16, 2.5, 2},
    }
    for i, ms in ipairs(menhirData) do
    	-- Menhir block
    	part("Menhir_"..i,
    		Vector3.new(ms[5], ms[4], ms[6]),
    		cfr(ms[1], GY + ms[4]/2, ms[2], 0, math.rad(ms[3]*10), 0),
    		C.ruinBase, MAT.slate)
    	-- Etched symbol (dark strip)
    	part("MenhirRune_"..i,
    		Vector3.new(ms[5]*0.8, ms[4]*0.5, 0.3),
    		cfr(ms[1], GY + ms[4]*0.6, ms[2] - ms[6]/2 - 0.2, 0, math.rad(ms[3]*10), 0),
    		C.ruinDark, MAT.stone)
    	-- Moss on menhir
    	part("MenhirMoss_"..i,
    		Vector3.new(ms[5], ms[4]*0.3, ms[6]),
    		cfr(ms[1], GY + ms[4]*0.15, ms[2], 0, math.rad(ms[3]*10), 0),
    		C.ruinMoss, MAT.grass, 0.2)
    end
    
    -- Ruined archway (separate from temple)
    local AX, AZ = 60, -65
    -- Left pillar
    part("Arch_PillarL",
    	Vector3.new(4, 14, 4),
    	cf(AX - 6, GY + 7, AZ), C.ruinLight, MAT.cobble)
    part("Arch_CapL",
    	Vector3.new(5, 2, 5),
    	cf(AX - 6, GY + 15, AZ), C.ruinMid, MAT.cobble)
    -- Right pillar
    part("Arch_PillarR",
    	Vector3.new(4, 14, 4),
    	cf(AX + 6, GY + 7, AZ), C.ruinLight, MAT.cobble)
    part("Arch_CapR",
    	Vector3.new(5, 2, 5),
    	cf(AX + 6, GY + 15, AZ), C.ruinMid, MAT.cobble)
    -- Lintel (top beam)
    part("Arch_Lintel",
    	Vector3.new(16, 3, 4.5),
    	cf(AX, GY + 17.5, AZ), C.marbleCrack, MAT.cobble)
    -- Fallen fragment from arch
    part("Arch_Fragment",
    	Vector3.new(7, 2.5, 4),
    	cfr(AX + 14, GY + 1.25, AZ + 3, 0, math.rad(25), 0.3),
    	C.ruinDark, MAT.slate)
    -- Moss on arch
    part("Arch_Moss",
    	Vector3.new(4.2, 5, 4.2),
    	cf(AX - 6, GY + 2.5, AZ), C.ruinMoss, MAT.grass, 0.3)
    part("Arch_Moss2",
    	Vector3.new(4.2, 5, 4.2),
    	cf(AX + 6, GY + 2.5, AZ), C.ruinMoss, MAT.grass, 0.3)
    
    -- Scattered wall rubble piles
    local rubbleData = {
    	{-15, 55, 8, 6}, { 35, -70, 10, 7}, {-55,  10, 7, 5},
    	{ 75, -45, 9, 6}, {-20, -50, 6, 5}, { 50,  30, 7, 5},
    }
    for i, rb in ipairs(rubbleData) do
    	-- Base pile
    	part("Rubble_"..i,
    		Vector3.new(rb[3], math.random(2,4), rb[4]),
    		cfr(rb[1], GY + 1.5, rb[2], 0, math.random()*math.pi, 0),
    		C.ruinDark, MAT.slate)
    	-- Top chunks
    	for ci3 = 1, 3 do
    		part("RubbleChunk_"..i.."_"..ci3,
    			Vector3.new(math.random(2,4), math.random(1,2), math.random(2,4)),
    			cfr(rb[1]+math.random(-3,3), GY+math.random(2,4), rb[2]+math.random(-3,3),
    				0, math.random()*math.pi, math.random()*0.5-0.25),
    			C.ruinMid, MAT.cobble)
    	end
    end
    
    -- ================================================================
    -- SECTION 6: MUSHROOMS — glowing bioluminescent
    -- ================================================================
    
    local function mushroom(x, z, scale, glowing)
    	local sc = scale or 1
    	-- Stem
    	cyl("MushStem", 0.8*sc, 1.2*sc,
    		cf(x, GY + 0.8*sc*0.5, z), C.mushStem, MAT.plast)
    	-- Cap
    	local capColor = glowing and C.mushGlow or (math.random() > 0.5 and C.mushCap or C.mushPurple)
    	local cap = sphere("MushCap", 2*sc,
    		cf(x, GY + 1.6*sc, z), capColor, MAT.plast)
    	-- Flatten cap
    	cap.Size = Vector3.new(2.2*sc, 1.2*sc, 2.2*sc)
    	-- Spots on cap
    	for si = 1, 3 do
    		local spotAngle = (si/3)*math.pi*2
    		sphere("MushSpot", 0.35*sc,
    			cf(x + math.cos(spotAngle)*0.7*sc, GY + 1.9*sc,
    				z + math.sin(spotAngle)*0.7*sc),
    			C.mushStem, MAT.plast)
    	end
    	if glowing then
    		addPointLight(cap, Color3.fromRGB(60, 220, 80), 1.5, 12*sc)
    	end
    end
    
    local mushData = {
    	{ 40, -20, 1.5, true},  {-30,  40, 1.2, true},  { 60,  45, 1.0, false},
    	{-55, -35, 1.8, true},  { 20,  30, 0.8, false},  {-15, -30, 1.0, true},
    	{ 85,  35, 1.4, false},  {-75,  55, 1.0, true},  { 35, -55, 1.2, false},
    	{ 15,  55, 0.9, true},  {-45,  -5, 1.3, false},  { 55,  75, 1.1, true},
    }
    -- Clusters: 3-5 small mushrooms around each anchor
    for _, md in ipairs(mushData) do
    	mushroom(md[1], md[2], md[3], md[4])
    	for ci4 = 1, math.random(2,4) do
    		local angle = math.random()*math.pi*2
    		local dist  = math.random(2,5)
    		mushroom(md[1]+math.cos(angle)*dist, md[2]+math.sin(angle)*dist,
    			md[3]*math.random(50,80)*0.01, false)
    	end
    end
    
    -- ================================================================
    -- SECTION 7: WILL-O'-WISPS (floating atmospheric lights)
    -- ================================================================
    
    local wispData = {
    	{ 25,  8,  15}, {-40, 10,  30}, { 55,  6, -20}, {-25, 12, -45},
    	{ 70, 14,  50}, {-60,  7, -30}, { 10,  9,  60}, {-80, 11,  10},
    	{ 45, 13, -60}, {-10,  8, -20}, { 90,  6,  25}, {-90, 10, -55},
    }
    
    local wispColors = {C.wispGreen, C.wispTeal, C.wispBlue}
    for i, wp in ipairs(wispData) do
    	local wColor = wispColors[(i-1)%3 + 1]
    	local wispCore = sphere("Wisp_"..i, 1.2,
    		cf(wp[1], GY + wp[2], wp[3]), wColor, MAT.neon, 0.1)
    	addPointLight(wispCore, wColor, 2.5, 14)
    	-- Outer glow halo
    	sphere("WispHalo_"..i, 3,
    		cf(wp[1], GY + wp[2], wp[3]), wColor, MAT.neon, 0.8)
    end
    
    -- ================================================================
    -- SECTION 8: UNDEAD / SKELETON NPC PLACEHOLDERS
    -- ================================================================
    
    local function skeletonNPC(x, z, name, armed)
    	local boneC = C.boneWhite
    	-- Torso
    	part("SK_Torso", Vector3.new(2, 2.5, 1),
    		cf(x, GY + 2.75, z), boneC, MAT.plast)
    	-- Ribcage detail lines
    	for ri2 = 1, 3 do
    		part("SK_Rib_"..ri2, Vector3.new(1.8, 0.2, 1.1),
    			cf(x, GY + 2.2 + ri2*0.45, z), C.boneMid, MAT.plast)
    	end
    	-- Pelvis
    	part("SK_Pelvis", Vector3.new(1.8, 0.8, 1),
    		cf(x, GY + 1.4, z), C.boneMid, MAT.plast)
    	-- Head (skull)
    	sphere("SK_Head", 1.6,
    		cf(x, GY + 5.0, z), C.boneYellow, MAT.plast)
    	-- Eye sockets (dark holes + glow)
    	for side = -1, 1, 2 do
    		sphere("SK_Eye", 0.4,
    			cf(x + side*0.35, GY + 5.15, z - 0.7), C.black, MAT.plast)
    		local eyeGlow = sphere("SK_EyeGlow", 0.25,
    			cf(x + side*0.35, GY + 5.15, z - 0.72), C.glowGreen, MAT.neon)
    		addPointLight(eyeGlow, Color3.fromRGB(50, 220, 60), 2, 8)
    	end
    	-- Jaw
    	part("SK_Jaw", Vector3.new(0.9, 0.4, 0.6),
    		cf(x, GY + 4.3, z - 0.3), C.boneYellow, MAT.plast)
    	-- Legs
    	part("SK_LegL", Vector3.new(0.7, 2.2, 0.7),
    		cf(x - 0.5, GY + 1.1, z), C.boneMid, MAT.plast)
    	part("SK_LegR", Vector3.new(0.7, 2.2, 0.7),
    		cf(x + 0.5, GY + 1.1, z), C.boneMid, MAT.plast)
    	-- Feet
    	part("SK_FootL", Vector3.new(0.7, 0.5, 1.2),
    		cf(x - 0.5, GY + 0.25, z + 0.3), C.boneWhite, MAT.plast)
    	part("SK_FootR", Vector3.new(0.7, 0.5, 1.2),
    		cf(x + 0.5, GY + 0.25, z + 0.3), C.boneWhite, MAT.plast)
    	-- Arms
    	part("SK_ArmL", Vector3.new(0.65, 2.2, 0.65),
    		cfr(x - 1.35, GY + 2.5, z, 0, 0, math.rad(18)), C.boneMid, MAT.plast)
    	part("SK_ArmR", Vector3.new(0.65, 2.2, 0.65),
    		cfr(x + 1.35, GY + 2.5, z, 0, 0, math.rad(-18)), C.boneMid, MAT.plast)
    
    	if armed then
    		-- Rusty scythe handle
    		part("SK_WeaponHandle", Vector3.new(0.4, 5, 0.4),
    			cfr(x + 1.8, GY + 4, z, 0, 0, math.rad(-15)), C.ironRust, MAT.metal)
    		-- Blade
    		wedge("SK_WeaponBlade", Vector3.new(0.3, 5, 2),
    			cfr(x + 2.2, GY + 7, z, 0, 0, math.rad(-70)), C.ironDark, MAT.metal)
    	end
    
    	-- Name label
    	local nameAnchor = part("SK_NameAnchor", Vector3.new(0.1,0.1,0.1),
    		cf(x, GY + 7.5, z), C.black, MAT.plast, 1)
    	addBillboard(nameAnchor, name, 110)
    end
    
    -- Place skeletons
    skeletonNPC(-20,  55, "Bog Wraith",      true)
    skeletonNPC( 60, -40, "Skeleton Guard",  true)
    skeletonNPC(-45,  -5, "Restless Dead",   false)
    skeletonNPC( 80,  25, "Rotting Archer",  false)
    skeletonNPC( TX - 5, TZ + 8, "Temple Warden", true)
    
    -- ================================================================
    -- SECTION 9: IRON CAGES & CHAINS (dungeon atmosphere)
    -- ================================================================
    
    local cagePositions = {
    	{-25, 50, 8}, { 50, -35, 7}, {-65, -15, 9},
    }
    for i, cg in ipairs(cagePositions) do
    	-- Chain hanging from dead tree (attach to nearby branch height)
    	local chainTop = cg[3]
    	for ci5 = 0, 3 do
    		part("Chain_"..i.."_"..ci5,
    			Vector3.new(0.4, 0.8, 0.4),
    			cf(cg[1], GY + chainTop - ci5*1.2, cg[2]), C.chainOld, MAT.metal)
    	end
    	-- Cage bars (simple box frame)
    	local cageY = GY + chainTop - 5
    	-- Vertical bars
    	for bx = -1, 1 do
    		for bz = -1, 1 do
    			if math.abs(bx) == 1 or math.abs(bz) == 1 then
    				part("CageBar", Vector3.new(0.3, 4, 0.3),
    					cf(cg[1]+bx*1.5, cageY, cg[2]+bz*1.5), C.ironDark, MAT.metal)
    			end
    		end
    	end
    	-- Horizontal cage rings
    	for ry = 0, 1 do
    		part("CageRing_"..i.."_"..ry,
    			Vector3.new(3.2, 0.3, 3.2),
    			cf(cg[1], cageY - 1.8 + ry*3.6, cg[2]), C.chainOld, MAT.metal, 0.5)
    	end
    	-- Bone inside cage
    	part("CageBone",
    		Vector3.new(1.5, 0.5, 0.5),
    		cfr(cg[1], cageY - 1, cg[2], 0, math.random()*math.pi, 0),
    		C.boneYellow, MAT.plast)
    end
    
    -- ================================================================
    -- SECTION 10: MUD TRAIL & WARNING SIGNS
    -- ================================================================
    
    -- Muddy trail entering from north-west (from Highgard direction)
    local trailNodes = {
    	{x= 0,  z=-140, w=7, l=40},
    	{x=-10, z=-100, w=7, l=40, rot=math.rad(5)},
    	{x=-20, z=-60,  w=8, l=40, rot=math.rad(8)},
    	{x=-28, z=-22,  w=8, l=40, rot=math.rad(12)},
    	{x=-30, z= 15,  w=9, l=35},
    }
    for i, tn in ipairs(trailNodes) do
    	part("Trail_"..i,
    		Vector3.new(tn.w, 0.4, tn.l),
    		cfr(tn.x, GY + 0.2, tn.z, 0, tn.rot or 0, 0),
    		C.pathMud, MAT.grass)
    	-- Trail edge reeds (thin cylinders)
    	for _, side in ipairs({-1, 1}) do
    		cyl("TrailReed", 0.3, math.random(2,4),
    			cf(tn.x + side*(tn.w/2+1), GY+math.random(1,2), tn.z),
    			C.swampGrass, MAT.plast)
    	end
    end
    
    -- Wooden warning signs
    local signData = {
    	{-35,  -80, "DANGER",         math.rad(-15)},
    	{ 45,  -95, "TURN BACK",      math.rad(10) },
    	{-70,   30, "BEWARE",         math.rad(-8) },
    	{ 0,   -40, "THE FENS",       math.rad(5)  },
    }
    for _, sd in ipairs(signData) do
    	-- Post
    	part("SignPost", Vector3.new(0.5, 5, 0.5),
    		cf(sd[1], GY + 2.5, sd[2]), C.signWood, MAT.wood)
    	-- Board
    	part("SignBoard", Vector3.new(4.5, 2.5, 0.4),
    		cfr(sd[1], GY + 5.5, sd[2], 0, sd[4], 0), C.signWood, MAT.wood)
    	-- Text label anchor
    	local signAnchor = part("SignAnchor", Vector3.new(0.1,0.1,0.1),
    		cf(sd[1], GY + 6.8, sd[2]), C.black, MAT.plast, 1)
    	local bg2 = Instance.new("BillboardGui", signAnchor)
    	bg2.Size = UDim2.fromOffset(80, 22)
    	bg2.StudsOffset = Vector3.new(0, 0, 0)
    	local lbl2 = Instance.new("TextLabel", bg2)
    	lbl2.Size = UDim2.fromScale(1,1)
    	lbl2.BackgroundTransparency = 1
    	lbl2.Text = sd[3]
    	lbl2.TextColor3 = Color3.fromRGB(220, 50, 50)
    	lbl2.TextScaled = true
    end
    
    -- Rickety bridge over small bog channel (south path)
    local BRX, BRZ = -28, 40
    part("Bridge_Deck",
    	Vector3.new(8, 0.6, 18),
    	cf(BRX, GY + 0.3, BRZ), C.signWood, MAT.wood)
    -- Planks (cross-pieces)
    for pi3 = -3, 3 do
    	part("BridgePlank_"..pi3,
    		Vector3.new(8.5, 0.5, 1.5),
    		cf(BRX, GY + 0.65, BRZ + pi3*2.5),
    		Color3.fromRGB(58, 38, 18), MAT.wood)
    end
    -- Rope railings
    part("BridgeRope_L",
    	Vector3.new(0.4, 0.4, 18),
    	cf(BRX - 3.8, GY + 2.0, BRZ), C.ropeOld, MAT.plast)
    part("BridgeRope_R",
    	Vector3.new(0.4, 0.4, 18),
    	cf(BRX + 3.8, GY + 2.0, BRZ), C.ropeOld, MAT.plast)
    -- Support posts
    for _, pz in ipairs({BRZ - 8, BRZ, BRZ + 8}) do
    	for _, px in ipairs({BRX - 3.8, BRX + 3.8}) do
    		part("BridgePillar", Vector3.new(0.6, 4, 0.6),
    			cf(px, GY + 2, pz), C.deadBranch, MAT.wood)
    	end
    end
    -- Damaged section: one broken plank
    part("BrokenPlank",
    	Vector3.new(3, 0.4, 1.5),
    	cfr(BRX + 1.5, GY + 0.1, BRZ - 2, 0.2, 0, 0.3),
    	Color3.fromRGB(38, 25, 10), MAT.wood)
    
    -- ================================================================
    -- SECTION 11: FOG PATCHES (translucent low-lying clouds)
    -- ================================================================
    
    local fogPatches = {
    	{ 20,  25, 35, 28}, {-45,  50, 28, 22}, { 60, -30, 32, 25},
    	{-20, -55, 24, 18}, { 80,  60, 20, 16}, {-65,  -5, 26, 20},
    	{ 10, -15, 40, 30}, {-30,  10, 22, 18},
    }
    for i, fp in ipairs(fogPatches) do
    	local fogH = math.random(2,4)
    	part("Fog_"..i,
    		Vector3.new(fp[3], fogH, fp[4]),
    		cfr(fp[1], GY + fogH/2 + 1, fp[2],
    			0, math.random()*math.pi, 0),
    		C.fogGrey, MAT.plast,
    		0.82 + math.random()*0.08)
    end
    
    -- ================================================================
    -- SECTION 12: EXTERIOR BORDER — treeline framing the zone
    -- ================================================================
    
    -- Dark spruce border trees (NW and W edges facing Gloom-Wood)
    local function borderTree(x, z, h)
    	cyl("BorderTrunk", 2, h,
    		cf(x, GY + h/2, z), C.deadTrunk, MAT.wood)
    	sphere("BorderFoliage_1", h*0.55,
    		cf(x, GY + h*0.68, z), Color3.fromRGB(28, 45, 22), MAT.grass)
    	sphere("BorderFoliage_2", h*0.42,
    		cf(x, GY + h*0.82, z), Color3.fromRGB(35, 55, 28), MAT.grass)
    	sphere("BorderFoliage_3", h*0.28,
    		cf(x, GY + h*0.94, z), Color3.fromRGB(42, 68, 32), MAT.grass)
    end
    
    -- North border
    for bi = -5, 5 do
    	borderTree(bi * 22, -140, math.random(12, 18))
    end
    -- West border
    for bi = -4, 4 do
    	borderTree(-145, bi * 22, math.random(10, 16))
    end
    -- South border
    for bi = -5, 5 do
    	borderTree(bi * 20, 145, math.random(10, 14))
    end
    -- East border
    for bi = -4, 4 do
    	borderTree(145, bi * 22, math.random(11, 16))
    end
    
    -- ================================================================
    -- SECTION 13: SCATTERED ATMOSPHERIC PROPS
    -- ================================================================
    
    -- Old boat half-submerged in bog
    part("OldBoat_Hull",
    	Vector3.new(12, 2.5, 4),
    	cfr(35, GY + 0.5, 30, 0.18, math.rad(25), 0),
    	C.deadBark, MAT.wood)
    for pi4 = 1, 4 do
    	part("BoatRib_"..pi4,
    		Vector3.new(4, 2.5, 0.6),
    		cfr(30 + pi4*1.8, GY + 1.0, 30, 0.18, math.rad(25), 0),
    		C.rottenWood, MAT.wood)
    end
    -- Boat algae
    part("BoatAlgae",
    	Vector3.new(8, 0.4, 3),
    	cfr(35, GY + 1.3, 30, 0.18, math.rad(25), 0),
    	C.swampMoss, MAT.grass, 0.2)
    
    -- Scattered bones on ground
    local boneScatter = {
    	{ 40,  15}, {-25,  42}, { 65, -50}, {-50, -12},
    	{ 20, -35}, {-70,  65}, { 85, -75}, {-10,  70},
    }
    for i, bs in ipairs(boneScatter) do
    	-- Long bone
    	part("ScatBone_"..i,
    		Vector3.new(math.random(2,5), 0.5, 0.6),
    		cfr(bs[1], GY + 0.25, bs[2], 0, math.random()*math.pi, 0),
    		C.boneYellow, MAT.plast)
    	-- Skull fragment
    	if i % 2 == 0 then
    		sphere("ScatSkull_"..i, 1.2,
    			cf(bs[1]+1, GY + 0.6, bs[2]+0.5), C.boneMid, MAT.plast)
    	end
    end
    
    -- Cauldron (ritual pot) near altar
    local CX, CZ = TX + 20, TZ - 10
    cyl("Cauldron_Outer", 5, 8, cf(CX, TPH + 2.5, CZ), C.ironDark, MAT.metal)
    cyl("Cauldron_Inner", 4, 7, cf(CX, TPH + 3.0, CZ), C.waterBlack, MAT.glass, 0.2)
    local cauldronGlow = part("Cauldron_Glow",
    	Vector3.new(6, 0.5, 6),
    	cf(CX, TPH + 5.2, CZ), C.wispGreen, MAT.neon, 0.55)
    addPointLight(cauldronGlow, Color3.fromRGB(45, 200, 65), 3, 20)
    -- Cauldron stand (3 legs)
    for li = 0, 2 do
    	local legAngle = (li/3)*math.pi*2
    	part("CauldronLeg_"..li,
    		Vector3.new(0.8, 3, 0.8),
    		cfr(CX + math.cos(legAngle)*3, TPH + 1.5, CZ + math.sin(legAngle)*3,
    			math.rad(-20)*math.sign(math.cos(legAngle)), legAngle, 0),
    		C.ironDark, MAT.metal)
    end
    
    -- ================================================================
    -- SECTION 14: CONNECTION PATH TO HIGHGARD
    -- ================================================================
    
    -- Stone path going NW toward Highgard
    local pathColor2 = C.pathMud
    local pathNodes2 = {
    	{x= -5, z=-155, w=8, l=30},
    	{x=-15, z=-185, w=8, l=30, rot=math.rad(-8)},
    	{x=-28, z=-215, w=7, l=30, rot=math.rad(-12)},
    	{x=-42, z=-245, w=7, l=30, rot=math.rad(-15)},
    }
    for i, pn in ipairs(pathNodes2) do
    	part("FenPath_"..i,
    		Vector3.new(pn.w, 0.4, pn.l),
    		cfr(pn.x, GY + 0.2, pn.z, 0, pn.rot or 0, 0),
    		pathColor2, MAT.cobble)
    	-- Path stones
    	for _, side in ipairs({-1, 1}) do
    		sphere("FenPathStone",
    			0.7, cf(pn.x + side*(pn.w/2 + 0.5), GY+0.35, pn.z),
    			C.ruinBase, MAT.stone)
    	end
    end
    
    -- ================================================================
    -- FINAL REPORT
    -- ================================================================
    
    local count = #folder:GetDescendants()
    print(string.format(
    	"[FensOfDespair Zone6] ✅ Done!  %d objects created in workspace.FensOfDespair_Zone6",
    	count
    ))
    end
    print("[HighgardPlugin] ✅ Zone6_FensOfDespair complete.")
end


-- ────────────────────────────────────────────────────────────────
zoneFunctions["Zone7_Environment"] = function()
    print("[HighgardPlugin] 🔨 Building Zone7_Environment...")
    do
    local Lighting    = game:GetService("Lighting")
    local RunService  = game:GetService("RunService")
    
    -- ── 1. GLOBAL LIGHTING ──────────────────────────────────────────
    
    Lighting.ClockTime          = 14.2          -- ~2:14 PM, long afternoon shadows
    Lighting.GeographicLatitude = 45            -- mid-latitude sun arc
    Lighting.Brightness         = 2.2
    Lighting.Ambient            = Color3.fromRGB(115, 118, 128)   -- cool blue-grey fill
    Lighting.OutdoorAmbient     = Color3.fromRGB(148, 155, 165)
    Lighting.ShadowSoftness     = 0.25
    Lighting.GlobalShadows      = true
    Lighting.FogEnd             = 1800
    Lighting.FogStart           = 900
    Lighting.FogColor           = Color3.fromRGB(195, 205, 215)
    
    print("[Env] Lighting base applied.")
    
    -- ── 2. ATMOSPHERE ────────────────────────────────────────────────
    
    local atmo = Instance.new("Atmosphere", Lighting)
    atmo.Density     = 0.28
    atmo.Offset      = 0.20
    atmo.Color       = Color3.fromRGB(182, 198, 218)    -- pale sky-blue haze
    atmo.Decay       = Color3.fromRGB(105, 115, 128)
    atmo.Glare       = 0.12
    atmo.Haze        = 1.4
    
    print("[Env] Atmosphere applied.")
    
    -- ── 3. SKY ───────────────────────────────────────────────────────
    
    local sky = Instance.new("Sky", Lighting)
    -- Uses Roblox default skybox; swap SkyboxXx with custom asset IDs if needed.
    sky.SkyboxBk = "rbxassetid://159454296"
    sky.SkyboxDn = "rbxassetid://159454296"
    sky.SkyboxFt = "rbxassetid://159454296"
    sky.SkyboxLf = "rbxassetid://159454296"
    sky.SkyboxRt = "rbxassetid://159454296"
    sky.SkyboxUp = "rbxassetid://159454296"
    sky.StarCount = 4000
    sky.SunAngularSize = 6
    sky.MoonAngularSize = 10
    
    print("[Env] Sky applied.")
    
    -- ── 4. POST-PROCESSING EFFECTS ───────────────────────────────────
    
    -- Colour correction — warm saturation boost for biome richness
    local cc = Instance.new("ColorCorrectionEffect", Lighting)
    cc.Brightness  =  0.02
    cc.Contrast    =  0.06
    cc.Saturation  =  0.12
    cc.TintColor   = Color3.fromRGB(252, 248, 242)    -- very slight warm tint
    cc.Enabled     = true
    
    -- Bloom — subtle glow on bright neon objects (lanterns, crystals, wisps)
    local bloom = Instance.new("BloomEffect", Lighting)
    bloom.Intensity  = 0.55
    bloom.Size       = 24
    bloom.Threshold  = 0.92
    bloom.Enabled    = true
    
    -- Sun rays (God rays from mountain/castle direction)
    local sunRays = Instance.new("SunRaysEffect", Lighting)
    sunRays.Intensity = 0.08
    sunRays.Spread    = 0.55
    sunRays.Enabled   = true
    
    -- Depth of field (very subtle — keeps game readable)
    local dof = Instance.new("DepthOfFieldEffect", Lighting)
    dof.FarIntensity  = 0.18
    dof.FocusDistance = 120
    dof.InFocusRadius = 60
    dof.NearIntensity = 0.05
    dof.Enabled       = true
    
    print("[Env] Post-processing effects applied.")
    
    -- ── 5. ZONE-LOCAL ATMOSPHERE OVERRIDES ──────────────────────────
    --  We use SelectionBoxes + SpecialMeshes only for zone
    --  atmosphere hints.  Real per-zone fog is done via LocalScript
    --  in each zone's root folder, but here we set up the zone folders
    --  with Atmosphere tags so a future LocalScript can detect them.
    
    local zoneAtmoData = {
        -- { folderName,  fogColor,               fogEnd, fogStart }
        { "Highgard_Zone1",       Color3.fromRGB(185,192,200),  1600, 800 },
        { "EmeraldHaven_Zone2",   Color3.fromRGB(168,195,172),  1400, 700 },
        { "SunScorch_Zone3",      Color3.fromRGB(225,200,148),  1200, 500 },
        { "SnowDust_Zone4",       Color3.fromRGB(210,218,232),   900, 300 },
        { "GloomWood_Zone5",      Color3.fromRGB( 88, 78,108),   600, 150 },
        { "FensOfDespair_Zone6",  Color3.fromRGB( 55, 72, 52),   500, 100 },
    }
    
    for _, zd in ipairs(zoneAtmoData) do
        local folder = workspace:FindFirstChild(zd[1])
        if folder then
            -- Tag the folder so LocalScripts can read zone atmosphere
            local tag = Instance.new("StringValue", folder)
            tag.Name  = "ZoneFogColor"
            tag.Value = string.format("%d,%d,%d",
                math.round(zd[2].R*255),
                math.round(zd[2].G*255),
                math.round(zd[2].B*255))
    
            local fEnd   = Instance.new("NumberValue", folder)
            fEnd.Name    = "ZoneFogEnd"
            fEnd.Value   = zd[3]
    
            local fStart = Instance.new("NumberValue", folder)
            fStart.Name  = "ZoneFogStart"
            fStart.Value = zd[4]
    
            print(string.format("[Env]  Zone atmo tagged: %s", zd[1]))
        else
            warn(string.format("[Env]  Zone folder not found: %s (run its script first)", zd[1]))
        end
    end
    
    -- ── 6. AMBIENT SOUND SETUP ───────────────────────────────────────
    --  Creates a Sound object in each zone folder.
    --  Replace the SoundId with real Roblox asset IDs as needed.
    
    local zoneSounds = {
        { "Highgard_Zone1",      "rbxassetid://0",   -- castle ambience
            "CastleAmbience",   0.55, true  },
        { "EmeraldHaven_Zone2",  "rbxassetid://0",   -- birds + village
            "VillageAmbience",  0.65, true  },
        { "SunScorch_Zone3",     "rbxassetid://0",   -- wind + sand
            "DesertWind",       0.60, true  },
        { "SnowDust_Zone4",      "rbxassetid://0",   -- blizzard wind
            "MountainWind",     0.70, true  },
        { "GloomWood_Zone5",     "rbxassetid://0",   -- eerie forest
            "GloomAmbience",    0.50, true  },
        { "FensOfDespair_Zone6", "rbxassetid://0",   -- swamp frogs + drips
            "SwampAmbience",    0.55, true  },
    }
    
    for _, sd in ipairs(zoneSounds) do
        local folder = workspace:FindFirstChild(sd[1])
        if folder then
            local snd          = Instance.new("Sound", folder)
            snd.SoundId        = sd[2]
            snd.Name           = sd[3]
            snd.Volume         = sd[4]
            snd.Looped         = sd[5]
            snd.RollOffMaxDistance = 300
            snd.RollOffMinDistance = 20
            -- snd:Play()   -- Uncomment when real asset IDs are set
            print(string.format("[Env]  Sound slot added: %s → %s", sd[1], sd[3]))
        end
    end
    
    -- ── 7. DIRECTIONAL LIGHT SUPPLEMENT ─────────────────────────────
    --  Sun at 14:00 from the SW — extra SpotLight over Highgard keep
    --  to guarantee the castle always reads well.
    
    local keepFolder = workspace:FindFirstChild("Highgard_Zone1")
    if keepFolder then
        local sunProxy = Instance.new("Part", keepFolder)
        sunProxy.Name        = "SunProxy"
        sunProxy.Size        = Vector3.new(1,1,1)
        sunProxy.CFrame      = CFrame.new(0, 200, 0) * CFrame.Angles(math.rad(-55), math.rad(220), 0)
        sunProxy.Anchored    = true
        sunProxy.Transparency = 1
        sunProxy.CanCollide  = false
    
        local sl = Instance.new("SpotLight", sunProxy)
        sl.Brightness = 2.8
        sl.Range      = 340
        sl.Angle      = 55
        sl.Color      = Color3.fromRGB(255, 248, 225)
        sl.Enabled    = true
        print("[Env] Highgard sun proxy light placed.")
    end
    
    -- ── 8. GLOOM-WOOD LOCAL FOG VOLUME ───────────────────────────────
    --  Creates a dense FogPart cluster inside the wood zone to sell
    --  the dark-forest feel without changing global fog.
    
    local gwFolder = workspace:FindFirstChild("GloomWood_Zone5")
    if gwFolder then
        local GW_ORIGIN = CFrame.new(320, 50, 0)
    
        local function fogPart(x, y, z, sx, sz)
            local p = Instance.new("Part", gwFolder)
            p.Name            = "LocalFog"
            p.Size            = Vector3.new(sx, 6, sz)
            p.CFrame          = GW_ORIGIN * CFrame.new(x, y, z)
            p.Color           = Color3.fromRGB(55, 45, 68)
            p.Material        = Enum.Material.SmoothPlastic
            p.Transparency    = 0.92
            p.Anchored        = true
            p.CanCollide      = false
            p.CastShadow      = false
        end
    
        local fogGrid = {
            {  0,  3,   0,  90, 110},
            { 40,  4,  40,  70,  80},
            {-45,  3, -30,  80,  70},
            { 20,  5, -60,  60,  60},
            {-25,  4,  55,  65,  75},
        }
        for _, fg in ipairs(fogGrid) do
            fogPart(fg[1], fg[2], fg[3], fg[4], fg[5])
        end
        print("[Env] Gloom-Wood local fog volumes created.")
    end
    
    -- ── 9. FENS LOCAL FOG ────────────────────────────────────────────
    
    local fenFolder = workspace:FindFirstChild("FensOfDespair_Zone6")
    if fenFolder then
        local FEN_ORIGIN = CFrame.new(280, 50, 280)
    
        local function fenFog(x, y, z, sx, sz)
            local p = Instance.new("Part", fenFolder)
            p.Name         = "FenFog"
            p.Size         = Vector3.new(sx, 4, sz)
            p.CFrame       = FEN_ORIGIN * CFrame.new(x, y, z)
            p.Color        = Color3.fromRGB(45, 60, 42)
            p.Material     = Enum.Material.SmoothPlastic
            p.Transparency = 0.90
            p.Anchored     = true
            p.CanCollide   = false
            p.CastShadow   = false
        end
    
        local fenFogGrid = {
            {  0,  2,   0, 110, 110},
            { 45,  3,  40,  80,  70},
            {-40,  2, -35,  75,  80},
            { 20,  3, -55,  60,  60},
            {-30,  2,  55,  70,  65},
        }
        for _, ff in ipairs(fenFogGrid) do
            fenFog(ff[1], ff[2], ff[3], ff[4], ff[5])
        end
        print("[Env] Fens of Despair fog volumes created.")
    end
    
    -- ── 10. SNOW-DUST MOUNTAIN — ICE SHIMMER ─────────────────────────
    --  Adds a gentle PointLight pulse to each IceCrystal already in
    --  the zone (created by Zone 4 script).
    
    local snowFolder = workspace:FindFirstChild("SnowDust_Zone4")
    if snowFolder then
        for _, obj in ipairs(snowFolder:GetDescendants()) do
            if obj:IsA("Part") and obj.Name == "IceCrystal" then
                local pl = Instance.new("PointLight", obj)
                pl.Color      = Color3.fromRGB(155, 215, 255)
                pl.Brightness = 2.8
                pl.Range      = 22
                pl.Enabled    = true
            end
        end
        print("[Env] Mountain ice-crystal lights enhanced.")
    end
    
    -- ── 11. DESERT SUN GLARE ─────────────────────────────────────────
    --  Adds a warm PointLight to each DustSwirl in Zone 3 to simulate
    --  heat-shimmer.
    
    local sunFolder = workspace:FindFirstChild("SunScorch_Zone3")
    if sunFolder then
        for _, obj in ipairs(sunFolder:GetDescendants()) do
            if obj:IsA("Part") and obj.Name == "DustSwirl" then
                obj.Color = Color3.fromRGB(215, 188, 115)
                obj.Transparency = math.clamp(obj.Transparency + 0.05, 0, 0.98)
            end
        end
        print("[Env] Desert dust shimmer adjusted.")
    end
    
    -- ── FINAL REPORT ─────────────────────────────────────────────────
    
    local totalParts = 0
    for _, folder in ipairs(workspace:GetChildren()) do
        if folder:IsA("Folder") and string.find(folder.Name, "Zone") then
            totalParts = totalParts + #folder:GetDescendants()
        end
    end
    
    print(string.format(
        "\n[Environment Zone7] ✅ Done!\n" ..
        "  Lighting   : ClockTime %.1f, Brightness %.1f\n" ..
        "  Atmosphere : Density %.2f, Offset %.2f\n" ..
        "  Post-FX    : ColorCorrection, Bloom, SunRays, DoF\n" ..
        "  Zone fog   : GloomWood + Fens local volumes\n" ..
        "  Ice lights : SnowDust crystals\n" ..
        "  Sounds     : %d slots created (set SoundId to activate)\n" ..
        "  Total parts across all zones: %d",
        Lighting.ClockTime, Lighting.Brightness,
        atmo.Density, atmo.Offset,
        #zoneSounds, totalParts
    ))
    end
    print("[HighgardPlugin] ✅ Zone7_Environment complete.")
end


-- ════════════════════════════════════════════════════════════════
-- BUILD ALL — click handler
-- ════════════════════════════════════════════════════════════════

local ZONE_ORDER = {
    "Zone1_Highgard",
    "Zone2_EmeraldHaven",
    "Zone3_SunScorch",
    "Zone4_SnowDust",
    "Zone5_GloomWood",
    "Zone6_FensOfDespair",
    "Zone7_Environment",
}

local function runBuild()
    if isRunning then
        warn("[HighgardPlugin] Already building — please wait.")
        return
    end

    isRunning = true
    btnBuild:SetActive(true)

    print("\n" .. string.rep("=", 60))
    print("  HIGHGARD MAP — PLUGIN BUILD START")
    print(string.rep("=", 60))

    local built   = 0
    local skipped = 0
    local failed  = 0

    for i, zoneName in ipairs(ZONE_ORDER) do
        print(string.format("  [%d/%d] %s", i, #ZONE_ORDER, zoneName))

        -- Skip if folder already exists (zones 1-6)
        local folderNames = {
            Zone1_Highgard      = "Highgard_Zone1",
            Zone2_EmeraldHaven  = "EmeraldHaven_Zone2",
            Zone3_SunScorch     = "SunScorch_Zone3",
            Zone4_SnowDust      = "SnowDust_Zone4",
            Zone5_GloomWood     = "GloomWood_Zone5",
            Zone6_FensOfDespair = "FensOfDespair_Zone6",
        }
        local fName = folderNames[zoneName]
        if (not forceRebuild) and fName and workspace:FindFirstChild(fName) then
            print(string.format("  ⏭  %s already exists, skipping.", fName))
            skipped += 1
        else
            local fn = zoneFunctions[zoneName]
            if fn then
                local ok, err = pcall(fn)
                if ok then
                    built += 1
                else
                    warn(string.format("[HighgardPlugin] ❌ %s failed: %s", zoneName, tostring(err)))
                    failed += 1
                end
            else
                warn("[HighgardPlugin] No function found for: " .. zoneName)
                failed += 1
            end
        end

        task.wait(0.05)   -- keep Studio responsive
    end

    -- Count total parts
    local totalParts = 0
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Folder") then
            totalParts += #obj:GetDescendants()
        end
    end

    print("\n" .. string.rep("=", 60))
    print("  HIGHGARD MAP — BUILD COMPLETE")
    print(string.rep("=", 60))
    print(string.format("  Built   : %d zone(s)", built))
    print(string.format("  Skipped : %d zone(s) (already in workspace)", skipped))
    print(string.format("  Failed  : %d zone(s)", failed))
    print(string.format("  Total workspace parts: ~%d", totalParts))
    print(string.rep("=", 60) .. "\n")

    isRunning = false
    btnBuild:SetActive(false)
end

btnBuild.Click:Connect(runBuild)

btnRebuild.Click:Connect(function()
    if isRunning then
        warn("[HighgardPlugin] Already building — please wait.")
        return
    end

    forceRebuild = true
    clearGeneratedMap()
    runBuild()
    forceRebuild = false
end)

print("[HighgardPlugin] ✅ Plugin loaded — click '🗺 Build Map' in the Plugins toolbar.")
