-- With no Remotes folder the client must not hang: the HUD still appears and says why.
local gui = nil
for _, child in ipairs(playerGui.children) do if child.Name == "GameHud" then gui = child end end
assert(gui, "the HUD is built even when the server never sends its remotes")

local explained = false
for _, child in ipairs(gui.children) do
	if child.__type == "TextLabel" and type(child.Text) == "string" and child.Text:find("SERVER NOT READY") then
		explained = true
	end
end
assert(explained, "the client explains that the server bridge is missing")
print("PASS Client: HUD renders and reports a missing server")
