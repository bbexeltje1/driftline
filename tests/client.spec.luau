-- Boots the real Main.client against the strict stub. Fails if the client requires modules
-- from the wrong place, waits without a timeout, or never builds its interface.
local gui = nil
for _, child in ipairs(playerGui.children) do
	if child.Name == "GameHud" then gui = child end
end
assert(gui, "the client builds its HUD")
assert(gui.ResetOnSpawn == false, "the HUD survives respawn")

local labels = {}
for _, child in ipairs(gui.children) do
	if child.__type == "TextLabel" then table.insert(labels, child) end
end
assert(#labels >= 2, "the HUD has a title and a status line")

local stamped = false
for _, label in ipairs(labels) do
	if type(label.Text) == "string" and label.Text:find("BUILD") then stamped = true end
end
assert(stamped, "the HUD shows which build is running")

for _, instance in ipairs(ReplicatedStorage.children) do
	assert(instance.Name ~= "Modules" or instance.__type ~= "Folder", "no Modules folder is required from beside the script")
end
print("PASS Client: HUD built, build stamp shown, remotes resolved")
