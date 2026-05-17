--!strict
-- NPCService.server.lua — Phase 3
-- Wires ProximityPrompts on NPC models in Workspace to quest accept/turn-in flows.
--
-- Setup in Studio:
--   1. Create a Model named "NPC_QuestGiver" (or any name).
--   2. Add a StringValue attribute "QuestIds" = "quest_001_first_steps,quest_002_mistleaf_aid"
--      (comma-separated questIds this NPC offers).
--   3. Add a ProximityPrompt named "TalkPrompt" inside the PrimaryPart.
--      ActionText = "Поговорить", ObjectText = NPC display name.
--
-- Phase 3 fix: fires QuestRemotes.NPCDialogOpen with full payload:
--   { npcName, offers: [{questId, name, description}], turnedIn: [questId] }

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedRemotes = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes")
local QuestRemotes  = require(SharedRemotes:WaitForChild("QuestRemotes"))
local QuestsConfig  = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("QuestsConfig"))

-- ── config ────────────────────────────────────────────────────────────────

local NPC_TALK_RANGE  = 10
local NPC_FOLDER_NAME = "NPCs"

-- ── lazy-loaded QuestService ──────────────────────────────────────────────

local _questService: any = nil
local function getQuestService(): any
	if _questService then return _questService end
	local ss = game:GetService("ServerScriptService")
	local ok, svc = pcall(function()
		return require(ss:WaitForChild("Server"):WaitForChild("Services"):WaitForChild("QuestService"))
	end)
	if ok then _questService = svc end
	return _questService
end

-- ── helpers ───────────────────────────────────────────────────────────────

local function parseQuestIds(raw: string): { string }
	local ids: { string } = {}
	for id in raw:gmatch("[^,]+") do
		table.insert(ids, id:match("^%s*(.-)%s*$"))
	end
	return ids
end

local function wireNPC(model: Model)
	local primaryPart = model.PrimaryPart
	if not primaryPart then
		warn("[NPCService] Model", model.Name, "has no PrimaryPart; skipping.")
		return
	end

	local prompt = primaryPart:FindFirstChild("TalkPrompt") :: ProximityPrompt?
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name                  = "TalkPrompt"
		prompt.ActionText            = "Поговорить"
		prompt.ObjectText            = model.Name
		prompt.MaxActivationDistance = NPC_TALK_RANGE
		prompt.HoldDuration          = 0
		prompt.RequiresLineOfSight   = false
		prompt.Parent                = primaryPart
	end

	local rawQuestIds: string = model:GetAttribute("QuestIds") or ""
	local npcQuestIds = parseQuestIds(rawQuestIds)

	prompt.Triggered:Connect(function(player: Player)
		local qs = getQuestService()
		if not qs then
			warn("[NPCService] QuestService not ready yet.")
			return
		end

		local offers: { { questId: string, name: string, description: string } } = {}
		local turnedIn: { string } = {}

		for _, questId in ipairs(npcQuestIds) do
			if qs.CanTurnIn and qs.CanTurnIn(player, questId) then
				-- Auto-execute turn-in on the server; UI just shows confirmation
				local ok, reason = pcall(qs.TurnInQuest, player, questId)
				if ok then
					table.insert(turnedIn, questId)
				else
					warn("[NPCService] TurnInQuest failed for", questId, reason)
				end
			elseif qs.CanAccept and qs.CanAccept(player, questId) then
				local def = QuestsConfig.Quests[questId]
				if def then
					table.insert(offers, {
						questId     = questId,
						name        = def.name,
						description = def.description,
					})
				end
			end
		end

		if #offers > 0 or #turnedIn > 0 then
			QuestRemotes.GetEvent("NPCDialogOpen"):FireClient(player, {
				npcName  = model.Name,
				offers   = offers,
				turnedIn = turnedIn,
			})
		end
	end)

	print(string.format("[NPCService] Wired NPC '%s' with %d quest(s).", model.Name, #npcQuestIds))
end

-- ── boot: scan Workspace for NPC models ───────────────────────────────────

task.wait(1)  -- yield so Workspace finishes loading and Boot finishes Init

local npcFolder  = workspace:FindFirstChild(NPC_FOLDER_NAME)
local searchRoot: Instance = npcFolder or workspace

for _, child in ipairs(searchRoot:GetChildren()) do
	if child:IsA("Model") and child:GetAttribute("QuestIds") then
		wireNPC(child :: Model)
	end
end

searchRoot.ChildAdded:Connect(function(child: Instance)
	if child:IsA("Model") and child:GetAttribute("QuestIds") then
		wireNPC(child :: Model)
	end
end)

print("[NPCService] Ready.")
