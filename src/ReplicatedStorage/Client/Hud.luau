-- Client-only view helpers. Lives in ReplicatedStorage so both the LocalScript and tests can
-- reach it: Rojo does NOT copy ModuleScripts into StarterPlayerScripts as files, so anything
-- required at runtime must come from ReplicatedStorage.
local Hud = {}

function Hud.label(parent, text, size, position)
	local instance = Instance.new("TextLabel")
	instance.Size = size
	instance.Position = position
	instance.BackgroundColor3 = Color3.fromRGB(41, 45, 76)
	instance.TextColor3 = Color3.new(1, 1, 1)
	instance.Text = text
	instance.Font = Enum.Font.GothamBold
	instance.TextScaled = true
	instance.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = instance
	return instance
end

function Hud.build(playerGui, titleText)
	local screen = Instance.new("ScreenGui")
	screen.Name = "GameHud"
	screen.ResetOnSpawn = false
	screen.Parent = playerGui
	local title = Hud.label(screen, titleText, UDim2.fromOffset(280, 40), UDim2.fromOffset(16, 16))
	title.TextColor3 = Color3.fromRGB(255, 224, 109)
	return screen
end

return Hud
