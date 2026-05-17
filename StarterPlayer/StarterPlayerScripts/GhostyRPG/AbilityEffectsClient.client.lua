--!strict
--------------------------------------------------------------------------------
-- GhostyRPG | AbilityEffectsClient.client.lua
-- StarterPlayer/StarterPlayerScripts/GhostyRPG/AbilityEffectsClient.client.lua
--
-- PURPOSE:
--   Pure cosmetic layer. Listens to the AbilityCast RemoteEvent broadcast from
--   the server and spawns client-side VFX (BillboardGui labels, beam highlights,
--   particle-style colour flashes) and plays sounds.
--
-- DOES NOT:
--   Affect any game logic, HP, cooldowns, or resources.
--   All decisions have already been made server-side when this fires.
--
-- ARCHITECTURE:
--   • AbilityRemotes.GetEvent("AbilityCast").OnClientEvent → handleCast()
--   • handleCast() maps abilityId → animationTag → effect profile
--   • Effects use BillboardGui + UIStroke colour flash (no asset IDs needed)
--     Real game would swap these for server-uploaded ParticleEmitter assets.
--
-- BOOT NOTE:
--   This is a LocalScript. No Init() needed — it runs on client start.
--------------------------------------------------------------------------------

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local SoundService      = game:GetService("SoundService")

local player = Players.LocalPlayer

local Shared         = ReplicatedStorage:WaitForChild("Shared")
local AbilityConfig  = require(Shared:WaitForChild("Config"):WaitForChild("AbilityConfig"))
local AbilityRemotes = require(Shared:WaitForChild("Remotes"):WaitForChild("AbilityRemotes"))

--------------------------------------------------------------------------------
-- EFFECT PROFILES
-- Maps animationTag → { colour, label, duration, sound (optional SoundId) }
-- Colours approximate the spell school; label is a unicode glyph stand-in.
-- In a shipped game replace `label` with actual ParticleEmitter templates.
--------------------------------------------------------------------------------

type EffectProfile = {
	colour   : Color3,
	label    : string,
	duration : number,   -- seconds the billboard stays visible
	size     : number,   -- billboard size in studs
}

local EFFECT_PROFILES: { [string]: EffectProfile } = {
	-- Generic fallback
	Default          = { colour = Color3.fromRGB(200,200,200), label = "✦",  duration = 0.6, size = 4 },

	-- Shadow school
	ShadowCast       = { colour = Color3.fromRGB(170, 60, 220),  label = "☽",  duration = 0.7, size = 5 },
	ShadowDrain      = { colour = Color3.fromRGB(130, 40, 190),  label = "⊗",  duration = 1.2, size = 4 },
	DarkBarrage      = { colour = Color3.fromRGB(200, 80, 255),  label = "⚡",  duration = 0.5, size = 6 },

	-- Arcane / Rune school
	CastRanged       = { colour = Color3.fromRGB(100, 140, 255),  label = "◈",  duration = 0.6, size = 5 },
	CastAoE          = { colour = Color3.fromRGB( 80, 120, 240),  label = "◉",  duration = 0.9, size = 7 },
	RuneCast         = { colour = Color3.fromRGB(120, 200, 255),  label = "ᚱ",  duration = 0.7, size = 5 },
	RuneExplosion    = { colour = Color3.fromRGB(160, 220, 255),  label = "✸",  duration = 1.0, size = 9 },
	RuneShield       = { colour = Color3.fromRGB( 80, 200, 255),  label = "⬡",  duration = 0.8, size = 5 },
	TimeStop         = { colour = Color3.fromRGB(200, 230, 255),  label = "⏸",  duration = 2.0, size = 12 },
	LichCast         = { colour = Color3.fromRGB(150, 180, 255),  label = "☆",  duration = 0.9, size = 6 },
	LichProjectile   = { colour = Color3.fromRGB(180, 200, 255),  label = "⊕",  duration = 0.8, size = 5 },
	LichHeal         = { colour = Color3.fromRGB(200, 220, 255),  label = "✚",  duration = 1.0, size = 6 },
	VoidCrush        = { colour = Color3.fromRGB(100,  60, 200),  label = "⊛",  duration = 1.2, size = 14 },
	OverlordAura     = { colour = Color3.fromRGB(255, 220, 100),  label = "♛",  duration = 1.5, size = 18 },

	-- Fire school
	CastFire         = { colour = Color3.fromRGB(255, 120, 40),  label = "🔥", duration = 0.7, size = 6 },

	-- Frost school
	FrostStrike      = { colour = Color3.fromRGB( 80, 210, 255),  label = "❄",  duration = 0.6, size = 5 },

	-- Holy school
	HolyHeal         = { colour = Color3.fromRGB(255, 250, 150),  label = "✚",  duration = 0.8, size = 5 },
	HolyAoE          = { colour = Color3.fromRGB(255, 240, 100),  label = "☀",  duration = 1.0, size = 8 },
	LayOnHands       = { colour = Color3.fromRGB(255, 255, 200),  label = "✋",  duration = 1.0, size = 6 },
	DivineShield     = { colour = Color3.fromRGB(255, 255, 220),  label = "⬡",  duration = 0.9, size = 7 },

	-- Physical school
	HeavySwing       = { colour = Color3.fromRGB(210, 180, 100),  label = "⚔",  duration = 0.4, size = 4 },
	ShieldSlam       = { colour = Color3.fromRGB(180, 160,  80),  label = "🛡",  duration = 0.4, size = 4 },
	QuickStab        = { colour = Color3.fromRGB(200, 190, 120),  label = "†",   duration = 0.3, size = 3 },
	BackStab         = { colour = Color3.fromRGB(230, 200, 100),  label = "⚡",  duration = 0.3, size = 4 },
	Whirlwind        = { colour = Color3.fromRGB(220, 190, 110),  label = "⟳",  duration = 0.8, size = 7 },
	Lunge            = { colour = Color3.fromRGB(200, 170, 100),  label = "➤",  duration = 0.4, size = 4 },
	ClawStrike       = { colour = Color3.fromRGB(190, 160,  80),  label = "✌",  duration = 0.4, size = 4 },
	BoneLaunch       = { colour = Color3.fromRGB(230, 210, 160),  label = "∦",  duration = 0.5, size = 4 },
	VoidSwipe        = { colour = Color3.fromRGB(140,  80, 200),  label = "⌬",  duration = 0.6, size = 6 },

	-- Utility / misc
	ShieldUp         = { colour = Color3.fromRGB(120, 180, 120),  label = "⬡",  duration = 0.5, size = 5 },
	Taunt            = { colour = Color3.fromRGB(220, 100,  80),  label = "!",   duration = 0.4, size = 4 },
	Blink            = { colour = Color3.fromRGB(140, 160, 255),  label = "↯",  duration = 0.3, size = 4 },
	Vanish           = { colour = Color3.fromRGB(100, 100, 140),  label = "…",  duration = 0.4, size = 4 },
	Summon           = { colour = Color3.fromRGB(180, 140, 255),  label = "☩",  duration = 1.2, size = 8 },
	Rage             = { colour = Color3.fromRGB(255,  60,  60),  label = "⚡",  duration = 0.8, size = 6 },
	Haste            = { colour = Color3.fromRGB(255, 200, 100),  label = "≫",  duration = 0.5, size = 5 },
	Shout            = { colour = Color3.fromRGB(220, 200, 100),  label = "♫",  duration = 0.6, size = 7 },
	Breathe          = { colour = Color3.fromRGB(150, 200, 150),  label = "~",  duration = 0.5, size = 4 },
	Eat              = { colour = Color3.fromRGB(180, 120,  60),  label = "✦",  duration = 0.6, size = 4 },
	Stance           = { colour = Color3.fromRGB(180, 180, 220),  label = "△",  duration = 0.5, size = 5 },
	DeathGrip        = { colour = Color3.fromRGB(100,  40, 160),  label = "⚓",  duration = 0.7, size = 6 },
	BowShot          = { colour = Color3.fromRGB(200, 180, 100),  label = "↗",  duration = 0.4, size = 4 },
	Consecration     = { colour = Color3.fromRGB(255, 230, 100),  label = "⬡",  duration = 1.0, size = 8 },
	HammerSwing      = { colour = Color3.fromRGB(200, 180, 100),  label = "⚒",  duration = 0.4, size = 4 },
	ShadowHeal       = { colour = Color3.fromRGB(160, 100, 220),  label = "✚",  duration = 0.7, size = 5 },
	FingerOfDeath    = { colour = Color3.fromRGB(140,  60, 200),  label = "☠",  duration = 0.5, size = 5 },
	Armageddon       = { colour = Color3.fromRGB(255,  80,  40),  label = "☄",  duration = 2.5, size = 20 },

	-- RuneHeal (resource restore)
	RuneHeal         = { colour = Color3.fromRGB(100, 220, 180),  label = "♻",  duration = 0.6, size = 5 },
}

local function getProfile(animTag: string?): EffectProfile
	if animTag and EFFECT_PROFILES[animTag] then
		return EFFECT_PROFILES[animTag]
	end
	return EFFECT_PROFILES.Default
end

--------------------------------------------------------------------------------
-- VFX HELPERS
--------------------------------------------------------------------------------

--- Finds a character's HumanoidRootPart from a player name.
local function getRootFromName(name: string): BasePart?
	local p = Players:FindFirstChild(name) :: Player?
	if p and p.Character then
		return p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	end
	return nil
end

--- Creates a floating BillboardGui label over a part for `duration` seconds.
local function spawnBillboard(
	root    : BasePart,
	profile : EffectProfile,
	yOffset : number?
)
	local billboard = Instance.new("BillboardGui")
	billboard.Name            = "AbilityVFX"
	billboard.Adornee         = root
	billboard.Size            = UDim2.fromOffset(profile.size * 18, profile.size * 18)
	billboard.StudsOffset     = Vector3.new(0, (yOffset or 3) + math.random(0, 1), 0)
	billboard.AlwaysOnTop     = false
	billboard.MaxDistance     = 80
	billboard.ResetOnSpawn    = false
	billboard.Parent          = game.Workspace

	local lbl = Instance.new("TextLabel")
	lbl.Size               = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3         = profile.colour
	lbl.TextSize           = math.clamp(profile.size * 9, 20, 80)
	lbl.Font               = Enum.Font.GothamBold
	lbl.Text               = profile.label
	lbl.TextStrokeColor3   = Color3.new(0, 0, 0)
	lbl.TextStrokeTransparency = 0.5
	lbl.Parent             = billboard

	-- Fade-in
	lbl.TextTransparency = 0.8
	TweenService:Create(lbl, TweenInfo.new(0.15), { TextTransparency = 0 }):Play()

	-- Float up
	local startOffset = billboard.StudsOffset
	TweenService:Create(billboard, TweenInfo.new(profile.duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = startOffset + Vector3.new(0, profile.size * 0.5, 0)
	}):Play()

	-- Fade-out and destroy
	task.delay(profile.duration * 0.6, function()
		if not lbl.Parent then return end
		TweenService:Create(lbl, TweenInfo.new(profile.duration * 0.4), {
			TextTransparency = 1
		}):Play()
		task.delay(profile.duration * 0.4 + 0.05, function()
			billboard:Destroy()
		end)
	end)
end

--- Flash a brief coloured highlight on the caster's character (rim-light fake via SelectionBox).
local function spawnCasterFlash(root: BasePart, profile: EffectProfile)
	local selBox = Instance.new("SelectionBox")
	selBox.Adornee      = root
	selBox.Color3       = profile.colour
	selBox.LineThickness = 0.08
	selBox.SurfaceTransparency = 0.85
	selBox.SurfaceColor3 = profile.colour
	selBox.Parent       = game.Workspace

	task.delay(0.25, function()
		TweenService:Create(selBox, TweenInfo.new(0.2), {
			LineThickness = 0,
			SurfaceTransparency = 1
		}):Play()
		task.delay(0.22, function() selBox:Destroy() end)
	end)
end

--- AoE ring flash centred on caster.
local function spawnAoERing(root: BasePart, profile: EffectProfile, range: number?)
	local r = range or 10
	local part = Instance.new("Part")
	part.Name             = "AoERing"
	part.Shape            = Enum.PartType.Cylinder
	part.Anchored         = true
	part.CanCollide       = false
	part.CastShadow       = false
	part.Material         = Enum.Material.Neon
	part.Color            = profile.colour
	part.Transparency     = 0.6
	part.Size             = Vector3.new(0.15, r * 2, r * 2)
	part.CFrame           = CFrame.new(root.Position) * CFrame.Angles(0, 0, math.pi / 2)
	part.Parent           = game.Workspace

	TweenService:Create(part, TweenInfo.new(profile.duration * 0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size        = Vector3.new(0.05, r * 2.4, r * 2.4),
		Transparency = 0.95,
	}):Play()

	task.delay(profile.duration * 0.7, function()
		part:Destroy()
	end)
end

--- Beam from caster to target.
local function spawnBeam(casterRoot: BasePart, targetRoot: BasePart, profile: EffectProfile)
	local a0 = Instance.new("Attachment")
	a0.WorldPosition = casterRoot.Position + Vector3.new(0, 1, 0)
	a0.Parent = game.Workspace.Terrain

	local a1 = Instance.new("Attachment")
	a1.WorldPosition = targetRoot.Position + Vector3.new(0, 1, 0)
	a1.Parent = game.Workspace.Terrain

	local beam = Instance.new("Beam")
	beam.Attachment0  = a0
	beam.Attachment1  = a1
	beam.Color        = ColorSequence.new(profile.colour)
	beam.Width0       = 0.3
	beam.Width1       = 0.15
	beam.Transparency = NumberSequence.new(0.2)
	beam.LightEmission = 0.8
	beam.Parent       = game.Workspace.Terrain

	task.delay(profile.duration * 0.5, function()
		TweenService:Create(beam, TweenInfo.new(0.2), {}):Play()
		task.delay(0.22, function()
			beam:Destroy()
			a0:Destroy()
			a1:Destroy()
		end)
	end)
end

--------------------------------------------------------------------------------
-- MAIN HANDLER
--------------------------------------------------------------------------------

--- Called whenever any player casts an ability successfully.
local function handleCast(payload: any)
	if type(payload) ~= "table" then return end

	local casterName : string = payload.casterName or ""
	local abilityId  : string = payload.abilityId  or ""
	local targetName : string? = payload.targetName

	local ability  = AbilityConfig.GetAbility(abilityId)
	local animTag  = ability and ability.animationTag or nil
	local profile  = getProfile(animTag)

	-- Resolve character parts
	local casterRoot = getRootFromName(casterName)
	local targetRoot = targetName and getRootFromName(targetName) or nil

	if not casterRoot then return end  -- caster not in scene; skip

	-- 1. Caster flash (always)
	spawnCasterFlash(casterRoot, profile)

	-- 2. Billboard on caster
	spawnBillboard(casterRoot, profile, 3)

	-- 3. Targeted spell → beam + billboard on target
	if targetRoot and targetRoot ~= casterRoot then
		local effectType = ability and ability.effectType or ""
		if effectType == "Damage" or effectType == "DoT" or effectType == "Debuff" then
			spawnBeam(casterRoot, targetRoot, profile)
			-- Smaller indicator on target
			local hitProfile: EffectProfile = {
				colour   = profile.colour,
				label    = "✦",
				duration = profile.duration * 0.7,
				size     = math.max(2, profile.size - 1),
			}
			spawnBillboard(targetRoot, hitProfile, 4)
		elseif effectType == "Heal" or effectType == "HoT" or effectType == "Shield" then
			spawnBeam(casterRoot, targetRoot, {
				colour   = Color3.fromRGB(150, 255, 150),
				label    = profile.label,
				duration = profile.duration,
				size     = profile.size,
			})
			local healProfile: EffectProfile = {
				colour   = Color3.fromRGB(150, 255, 150),
				label    = "✚",
				duration = profile.duration * 0.8,
				size     = profile.size,
			}
			spawnBillboard(targetRoot, healProfile, 4)
		end
	end

	-- 4. AoE ring for area abilities
	if ability then
		local et = ability.effectType
		if et == "AoE" then
			spawnAoERing(casterRoot, profile, ability.range)
		end
	end

	-- 5. Armageddon: multi-wave billboard
	if abilityId == "OVERLORD_ARMAGEDDON" then
		for wave = 1, 5 do
			task.delay(wave * 0.4, function()
				if not casterRoot.Parent then return end
				spawnBillboard(casterRoot, {
					colour   = Color3.fromRGB(255, 80 + wave * 20, 40),
					label    = "☄",
					duration = 0.8,
					size     = 6 + wave,
				}, 2 + wave)
			end)
		end
	end
end

--------------------------------------------------------------------------------
-- WIRE UP REMOTE
--------------------------------------------------------------------------------

local castEvent = AbilityRemotes.GetEvent("AbilityCast")
castEvent.OnClientEvent:Connect(function(payload: any)
	-- Protect against bad server data
	local ok, err = pcall(handleCast, payload)
	if not ok then
		warn("[AbilityEffectsClient] Error in handleCast:", err)
	end
end)

print("[AbilityEffectsClient] VFX listener active.")
