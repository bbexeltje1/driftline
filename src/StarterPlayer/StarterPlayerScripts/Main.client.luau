-- Client entry point. Build the interface FIRST, then talk to the server (template rule 3).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ScriptContext = game:GetService("ScriptContext")
local player = Players.LocalPlayer

-- Build stamp: proves in-game which commit is running.
local tagOk, tagModule = pcall(function()
	return require(ReplicatedStorage:WaitForChild("Shared", 10):WaitForChild("BuildTag", 10))
end)
local tag = if tagOk and type(tagModule) == "table" then tostring(tagModule.tag) else "dev"

local Config = require(ReplicatedStorage.Shared.Config)
-- Client modules come from ReplicatedStorage, never from beside this script (template rule 1).
local clientModules = ReplicatedStorage:WaitForChild("ClientModules", 10)
if not clientModules then
	error("ClientModules folder missing from ReplicatedStorage")
end
local Hud = require(clientModules:WaitForChild("Hud", 10))
local HudPresenter = require(clientModules:WaitForChild("HudPresenter", 10))
local InputMapper = require(clientModules:WaitForChild("InputMapper", 10))
local BoardController = require(clientModules:WaitForChild("BoardController", 10))
local AnimationController = require(clientModules:WaitForChild("AnimationController", 10))
local CameraController = require(clientModules:WaitForChild("CameraController", 10))
local BoardCatalog = require(ReplicatedStorage.Shared.BoardCatalog)
local Profile = require(ReplicatedStorage.Shared.Profile)

local playerGui = player:WaitForChild("PlayerGui", 10)
local hud = HudPresenter.build(playerGui, Config.displayName)

local status = Hud.label(hud.screen, "BUILD " .. tag, UDim2.fromOffset(240, 26), UDim2.fromOffset(16, 62))
status.BackgroundTransparency = 1
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextSize = 14

-- Errors become visible text, not just an Output line nobody reads.
ScriptContext.Error:Connect(function(message)
	status.Text = "ERROR: " .. tostring(message)
	status.TextColor3 = Color3.fromRGB(255, 130, 130)
end)
print("[driftline] client: HUD built (" .. tag .. ")")

-- Bounded waits only (template rule 3).
local remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
if not remotes then
	status.Text = "SERVER NOT READY — no Remotes folder. Check Output."
	return
end
print("[driftline] client: remotes found")

-- Session profile mirror (display + board stats). Server owns the real one.
local profile = Profile.new(player.UserId)
local input = InputMapper.new()
input:bind()
local controller = BoardController.new(player, remotes, Profile.boardStats(profile))
local animator = AnimationController.new(player)
local cameraCtl = CameraController.new(player)

local running = false
local function startRun()
	running = true
	controller:setRunning(true)
	hud:hideResults()
	remotes.StartRun:FireServer()
end

hud.startButton.MouseButton1Click:Connect(startRun)
hud.equipBoard.MouseButton1Click:Connect(function()
	local ok = remotes.EquipItem:InvokeServer("board", "Arcboard")
	if ok and ok.ok then
		Profile.equip(profile, "board", "Arcboard")
		controller.boardStats = Profile.boardStats(profile)
		animator:setBoardColor("Arcboard")
	end
end)
hud.equipCosmetic.MouseButton1Click:Connect(function()
	local ok = remotes.EquipItem:InvokeServer("cosmetic", "DuskStripe")
	if ok and ok.ok then
		Profile.equip(profile, "cosmetic", "DuskStripe")
		animator:setCosmetic("DuskStripe")
	end
end)
for itemId, button in pairs(hud.shopButtons) do
	button.MouseButton1Click:Connect(function()
		local result = remotes.UnlockItem:InvokeServer(itemId)
		if result and result.ok then
			Profile.unlock(profile, itemId)
			hud:setTokens(profile.tokens)
		end
	end)
end

remotes.RunUpdate.OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then
		return
	end
	if payload.state == "running" then
		running = true
		controller:setRunning(true)
	elseif payload.state == "finished" then
		running = false
		controller:setRunning(false)
	end
	if type(payload.elapsed) == "number" then
		hud:setTimer(payload.elapsed)
	end
	if type(payload.banked) == "number" and type(payload.pending) == "number" then
		hud:setScore(payload.banked, payload.pending)
	end
	if payload.nextGate ~= nil then
		hud:setGates(payload.nextGate)
	end
	if type(payload.tokens) == "number" then
		profile.tokens = payload.tokens
		hud:setTokens(payload.tokens)
	end
	if type(payload.landing) == "string" then
		hud:setLanding(string.upper(payload.landing))
	end
	if type(payload.trick) == "string" then
		hud:setLanding(payload.trick .. " +" .. tostring(payload.trickPoints or 0))
	end
end)

remotes.ProfileUpdate.OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then
		return
	end
	if type(payload.tokens) == "number" then
		profile.tokens = payload.tokens
		hud:setTokens(payload.tokens)
	end
	if type(payload.equippedBoard) == "string" then
		profile.equippedBoard = payload.equippedBoard
		controller.boardStats = Profile.boardStats(profile)
		animator:setBoardColor(payload.equippedBoard)
	end
	if payload.equippedCosmetic ~= nil then
		profile.equippedCosmetic = payload.equippedCosmetic
		animator:setCosmetic(payload.equippedCosmetic)
	end
end)

remotes.Results.OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" then
		return
	end
	running = false
	controller:setRunning(false)
	hud:showResults(payload.elapsed or 0, payload.banked or 0, payload.granted or 0)
	hud:setLanding("FINISHED")
end)

-- Main loop: input -> prediction -> animation -> camera -> HUD telemetry.
RunService.RenderStepped:Connect(function(dt: number)
	local intent = input:intent()
	if intent.startPressed or intent.retryPressed then
		startRun()
	end
	if running then
		controller:step(intent, dt)
	end
	animator:apply(controller.pose, intent.steer, controller.edge, controller.speed)
	cameraCtl:step(controller.heading, controller.speed, dt)
	hud:setSpeed(controller.speed)
end)

print("[driftline] client: ready")
