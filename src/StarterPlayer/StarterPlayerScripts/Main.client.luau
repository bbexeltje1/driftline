-- Client entry point. Build the interface FIRST, then talk to the server: a client that
-- waits on a remote before drawing anything shows the player an empty screen and no reason.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ScriptContext = game:GetService("ScriptContext")
local player = Players.LocalPlayer

-- Build stamp: proves in-game which commit is running.
local tagOk, tagModule = pcall(function()
	return require(ReplicatedStorage:WaitForChild("Shared", 10):WaitForChild("BuildTag", 10))
end)
local tag = if tagOk and type(tagModule) == "table" then tostring(tagModule.tag) else "dev"

local Config = require(ReplicatedStorage.Shared.Config)
-- Client modules come from ReplicatedStorage, never from beside this script: Rojo does not
-- replicate ModuleScripts into PlayerScripts as files, and script.Parent is the PlayerScripts
-- container at runtime. Requiring from there fails with "Infinite yield possible".
local Hud = require(ReplicatedStorage:WaitForChild("ClientModules", 10):WaitForChild("Hud"))

local playerGui = player:WaitForChild("PlayerGui")
local screen = Hud.build(playerGui, Config.displayName)

local status = Hud.label(screen, "BUILD " .. tag, UDim2.fromOffset(240, 26), UDim2.fromOffset(16, 62))
status.BackgroundTransparency = 1
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextSize = 14

-- Errors become visible text, not just an Output line nobody reads.
ScriptContext.Error:Connect(function(message)
	status.Text = "ERROR: " .. tostring(message)
	status.TextColor3 = Color3.fromRGB(255, 130, 130)
end)
print("[game] client: HUD built (" .. tag .. ")")

-- Bounded waits only: an untimed WaitForChild on something that never arrives freezes the
-- client with no explanation ("Infinite yield possible").
local remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
if not remotes then
	status.Text = "SERVER NOT READY — no Remotes folder. Check Output."
	return
end
print("[game] client: ready")
