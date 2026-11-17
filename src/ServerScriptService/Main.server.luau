-- Server entry point. Wiring only: modules hold behaviour.
print("[driftline] server: booting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local BoardCatalog = require(ReplicatedStorage.Shared.BoardCatalog)
local Profile = require(ReplicatedStorage.Shared.Profile)
local CourseService = require(script.Modules.CourseService)
local ProfileService = require(script.Modules.ProfileService)
local DriftRunService = require(script.Modules.RunService)

-- Remotes exist before anything heavy can fail (template rule 3).
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage
local function makeEvent(name: string): RemoteEvent
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = remotes
	return event
end
local function makeFunction(name: string): RemoteFunction
	local fn = Instance.new("RemoteFunction")
	fn.Name = name
	fn.Parent = remotes
	return fn
end
makeEvent("Ready")
makeEvent("StartRun")
makeEvent("TrickEvent")
makeEvent("LandEvent")
makeEvent("WipeoutEvent")
makeEvent("RunUpdate")
makeEvent("ProfileUpdate")
makeEvent("Results")
makeFunction("UnlockItem")
makeFunction("EquipItem")

local courseData = CourseService.load()
if courseData then
	print("[driftline] server: course loaded (2 gates, finish, hazards)")
else
	warn("[driftline] server: Workspace.Course missing — gates/finish disabled. Build the place with Rojo.")
end
DriftRunService.init(courseData, remotes)

local function pushProfile(player: Player)
	local profile = ProfileService.get(player.UserId)
	local owned: { string } = {}
	for id, has in pairs(profile.owned) do
		if has then
			table.insert(owned, id)
		end
	end
	remotes.ProfileUpdate:FireClient(player, {
		tokens = profile.tokens,
		owned = owned,
		equippedBoard = profile.equippedBoard,
		equippedCosmetic = profile.equippedCosmetic,
		sessionOnly = true,
	})
end

local function onPlayerAdded(player: Player)
	-- Studio runs use temporary data: never touch DataStore here (template rule 2).
	if RunService:IsStudio() then
		print("[driftline] studio run: temporary session progress, nothing to configure")
		player:SetAttribute("OfflineSave", true)
	end
	player:SetAttribute("JoinedAt", os.time())
	ProfileService.get(player.UserId)
	task.delay(1, function()
		pushProfile(player)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
Players.PlayerRemoving:Connect(function(player: Player)
	DriftRunService.clear(player)
	ProfileService.clear(player.UserId)
end)

remotes.StartRun.OnServerEvent:Connect(function(player: Player)
	DriftRunService.startRun(player)
end)
remotes.TrickEvent.OnServerEvent:Connect(function(player: Player, payload: any)
	DriftRunService.handleTrick(player, payload)
end)
remotes.LandEvent.OnServerEvent:Connect(function(player: Player, payload: any)
	DriftRunService.handleLanding(player, payload)
end)
remotes.WipeoutEvent.OnServerEvent:Connect(function(player: Player, payload: any)
	DriftRunService.handleWipeout(player, payload)
end)

remotes.UnlockItem.OnServerInvoke = function(player: Player, itemId: any): any
	local profile = ProfileService.get(player.UserId)
	local ok = Profile.unlock(profile, itemId)
	if ok then
		pushProfile(player)
	end
	return { ok = ok, tokens = profile.tokens, itemId = itemId }
end

remotes.EquipItem.OnServerInvoke = function(player: Player, slot: any, itemId: any): any
	local profile = ProfileService.get(player.UserId)
	local ok = Profile.equip(profile, slot, itemId)
	if ok then
		pushProfile(player)
	end
	return { ok = ok, equippedBoard = profile.equippedBoard, equippedCosmetic = profile.equippedCosmetic }
end

-- Server-observed gate/finish/hazard polling (bounded rate).
task.spawn(function()
	while true do
		task.wait(0.1)
		for _, player in ipairs(Players:GetPlayers()) do
			DriftRunService.poll(player)
		end
	end
end)

-- Expose catalogue size for diagnostics (no behaviour on instances).
print("[driftline] server: catalogue boards=" .. tostring(#BoardCatalog.Boards) .. " ready")
ReplicatedStorage:SetAttribute(Config.readyAttribute, true)
print("[driftline] server: ready")
