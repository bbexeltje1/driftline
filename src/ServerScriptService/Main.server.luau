-- Server entry point. Keep it to wiring: modules hold behaviour.
print("[game] server: booting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)

-- Remotes exist before anything heavy can fail: a client that waits on them must never be
-- left waiting because of an unrelated server error later in this file.
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage
local ready = Instance.new("RemoteEvent")
ready.Name = "Ready"
ready.Parent = remotes

local function onPlayerAdded(player)
	-- Studio runs use temporary data: never touch DataStore here, or an unpublished place
	-- throws "You must publish this place to the web" at load time and kills the server.
	if RunService:IsStudio() then
		print("[game] studio run: temporary progress, nothing to configure")
		player:SetAttribute("OfflineSave", true)
	end
	player:SetAttribute("JoinedAt", os.time())
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

ReplicatedStorage:SetAttribute(Config.readyAttribute, true)
print("[game] server: ready")
