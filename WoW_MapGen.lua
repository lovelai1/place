-- Medieval Arena Map Generator (simple, from scratch)
-- Run this Script in Roblox Studio (ServerScriptService or Command Bar).

local Workspace = game:GetService("Workspace")

local ROOT_NAME = "MedievalArenaMap"
local root = Workspace:FindFirstChild(ROOT_NAME)
if root then
    root:Destroy()
end

root = Instance.new("Folder")
root.Name = ROOT_NAME
root.Parent = Workspace

local M = Enum.Material
local C = {
    grass = Color3.fromRGB(95, 145, 75),
    dirt = Color3.fromRGB(106, 84, 60),
    stone = Color3.fromRGB(142, 137, 128),
    stoneDark = Color3.fromRGB(95, 91, 85),
    wood = Color3.fromRGB(128, 86, 52),
    woodDark = Color3.fromRGB(88, 58, 32),
    roof = Color3.fromRGB(134, 68, 52),
    roofDark = Color3.fromRGB(105, 48, 35),
    bannerRed = Color3.fromRGB(160, 45, 45),
    bannerBlue = Color3.fromRGB(44, 82, 158),
    sand = Color3.fromRGB(198, 175, 130),
    torch = Color3.fromRGB(255, 184, 70),
}

local function part(name, size, cf, color, mat, parent)
    local p = Instance.new("Part")
    p.Name = name
    p.Size = size
    p.CFrame = cf
    p.Anchored = true
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Material = mat or M.SmoothPlastic
    p.Color = color or Color3.new(1, 1, 1)
    p.Parent = parent or root
    return p
end

local function addTorch(pos)
    local post = part("TorchPost", Vector3.new(0.5, 4, 0.5), CFrame.new(pos + Vector3.new(0,2,0)), C.woodDark, M.Wood)
    local flame = part("TorchFlame", Vector3.new(0.65,0.65,0.65), CFrame.new(pos + Vector3.new(0,4.35,0)), C.torch, M.Neon)
    flame.Shape = Enum.PartType.Ball
    flame.Parent = post.Parent

    local light = Instance.new("PointLight")
    light.Color = C.torch
    light.Brightness = 2.2
    light.Range = 18
    light.Parent = flame
end

-- Ground
part("BaseGrass", Vector3.new(520, 2, 520), CFrame.new(0, -1, 0), C.grass, M.Grass)
part("ArenaFloor", Vector3.new(120, 1, 120), CFrame.new(0, 0.5, 0), C.sand, M.Sand)
part("ArenaRing", Vector3.new(132, 2, 132), CFrame.new(0, 0, 0), C.dirt, M.Ground)

-- Arena walls
local wallH = 18
local wallT = 4
local wallL = 140
part("Wall_N", Vector3.new(wallL, wallH, wallT), CFrame.new(0, wallH/2, -70), C.stone, M.Slate)
part("Wall_S", Vector3.new(wallL, wallH, wallT), CFrame.new(0, wallH/2, 70), C.stone, M.Slate)
part("Wall_W", Vector3.new(wallT, wallH, wallL), CFrame.new(-70, wallH/2, 0), C.stone, M.Slate)
part("Wall_E", Vector3.new(wallT, wallH, wallL), CFrame.new(70, wallH/2, 0), C.stone, M.Slate)

-- Gate openings (simple doorway frames)
part("GateFrame_N", Vector3.new(22, 5, 4.2), CFrame.new(0, 2.5, -70), C.woodDark, M.Wood)
part("GateFrame_S", Vector3.new(22, 5, 4.2), CFrame.new(0, 2.5, 70), C.woodDark, M.Wood)

-- Corner towers
local towerPos = {
    Vector3.new(-70, 0, -70), Vector3.new(70, 0, -70),
    Vector3.new(-70, 0, 70),  Vector3.new(70, 0, 70),
}
for i, p0 in ipairs(towerPos) do
    local t = part("Tower_"..i, Vector3.new(14, 28, 14), CFrame.new(p0 + Vector3.new(0,14,0)), C.stoneDark, M.Cobblestone)
    local cap = part("TowerCap_"..i, Vector3.new(16, 3, 16), CFrame.new(p0 + Vector3.new(0,29.5,0)), C.stone, M.Slate)
    cap.Parent = t.Parent
end

-- Stands
part("StandWest", Vector3.new(16, 8, 90), CFrame.new(-48, 4, 0), C.stoneDark, M.Concrete)
part("StandEast", Vector3.new(16, 8, 90), CFrame.new(48, 4, 0), C.stoneDark, M.Concrete)

-- Banners
local function banner(name, pos, isBlue)
    local pole = part(name.."Pole", Vector3.new(0.5, 14, 0.5), CFrame.new(pos + Vector3.new(0,7,0)), C.woodDark, M.Wood)
    local cloth = part(name.."Cloth", Vector3.new(0.25, 6, 4), CFrame.new(pos + Vector3.new(1.5, 10, 0)), isBlue and C.bannerBlue or C.bannerRed, M.Fabric)
    cloth.Parent = pole.Parent
end
banner("BannerA", Vector3.new(-10, 0, -62), true)
banner("BannerB", Vector3.new(10, 0, -62), false)
banner("BannerC", Vector3.new(-10, 0, 62), false)
banner("BannerD", Vector3.new(10, 0, 62), true)

-- Village houses around arena
local houses = Instance.new("Folder")
houses.Name = "Village"
houses.Parent = root

local function buildHouse(id, x, z, rot)
    local baseCf = CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(rot), 0)
    local wall = part("House"..id.."_Body", Vector3.new(18, 10, 14), baseCf * CFrame.new(0,5,0), C.stone, M.Brick, houses)
    local roofL = part("House"..id.."_RoofL", Vector3.new(19, 1.2, 8), baseCf * CFrame.new(0,10.8,-2.2) * CFrame.Angles(math.rad(28),0,0), C.roof, M.WoodPlanks, houses)
    local roofR = part("House"..id.."_RoofR", Vector3.new(19, 1.2, 8), baseCf * CFrame.new(0,10.8,2.2) * CFrame.Angles(math.rad(-28),0,0), C.roofDark, M.WoodPlanks, houses)
    local door = part("House"..id.."_Door", Vector3.new(2.5,5,0.6), baseCf * CFrame.new(0,2.5,7.3), C.woodDark, M.Wood, houses)
    wall.Parent, roofL.Parent, roofR.Parent, door.Parent = houses, houses, houses, houses
end

local ring = {
    {-145, -95, 20}, {-180, 0, 90}, {-145, 95, 160},
    {145, -95, -20}, {180, 0, -90}, {145, 95, -160},
    {-120, -170, 0}, {120, 170, 180},
}
for i, h in ipairs(ring) do
    buildHouse(i, h[1], h[2], h[3])
end

-- Paths between houses and arena
local paths = Instance.new("Folder")
paths.Name = "Paths"
paths.Parent = root
local function path(x,z,dx,dz,len,w)
    part("Path", Vector3.new(w or 8,0.4,len), CFrame.new(x,0.2,z) * CFrame.Angles(0, math.rad((dx==1 and 90) or (dx==-1 and -90) or (dz==1 and 180) or 0), 0), C.dirt, M.Ground, paths)
end
path(-95,0,1,0,130,10)
path(95,0,-1,0,130,10)
path(0,-95,0,1,130,10)
path(0,95,0,-1,130,10)

-- Trees/simple props
local props = Instance.new("Folder")
props.Name = "Props"
props.Parent = root
for i = 1, 36 do
    local x = math.random(-240, 240)
    local z = math.random(-240, 240)
    if math.abs(x) > 80 or math.abs(z) > 80 then
        local trunk = part("TreeTrunk", Vector3.new(1.2, 6, 1.2), CFrame.new(x,3,z), C.wood, M.Wood, props)
        local crown = part("TreeCrown", Vector3.new(5,5,5), CFrame.new(x,7.5,z), Color3.fromRGB(70, 122, 64), M.Grass, props)
        crown.Shape = Enum.PartType.Ball
        trunk.Parent, crown.Parent = props, props
    end
end

for _, p in ipairs({
    Vector3.new(-45,0,-45), Vector3.new(45,0,-45), Vector3.new(-45,0,45), Vector3.new(45,0,45),
    Vector3.new(0,0,-62), Vector3.new(0,0,62),
}) do
    addTorch(p)
end

print("[MedievalArenaMap] ✅ Generated simple medieval arena with village.")
