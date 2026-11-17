--!strict
-- Minimal M1 HUD + results + shop. Built before any remote wait (template rule 3).
-- Server values (RunUpdate/ProfileUpdate/Results) are display-only; the server
-- remains authoritative for score/tokens/gates.
local Hud = require(script.Parent.Hud)
local BoardCatalog = require(script.Parent.Parent.Shared.BoardCatalog)

local HudPresenter = {}

function HudPresenter.build(playerGui: PlayerGui, titleText: string): any
	local screen = Hud.build(playerGui, titleText)
	local refs: any = { screen = screen }

	refs.speed = Hud.label(screen, "Speed 0", UDim2.fromOffset(220, 36), UDim2.fromOffset(16, 120))
	refs.timer = Hud.label(screen, "Time 0.0", UDim2.fromOffset(220, 36), UDim2.fromOffset(16, 162))
	refs.score = Hud.label(screen, "Score 0  Pending 0", UDim2.fromOffset(300, 36), UDim2.fromOffset(16, 204))
	refs.gates = Hud.label(screen, "Gates: next 1", UDim2.fromOffset(300, 36), UDim2.fromOffset(16, 246))
	refs.landing = Hud.label(screen, "", UDim2.fromOffset(300, 36), UDim2.fromOffset(16, 288))
	refs.tokens = Hud.label(screen, "Tokens 0 (SESSION ONLY)", UDim2.fromOffset(300, 36), UDim2.fromOffset(16, 330))
	refs.legend = Hud.label(
		screen,
		"W tuck  S brake  A/D steer  Q/E edge  Space pop  J/K grab  Enter start  R retry",
		UDim2.fromOffset(560, 36),
		UDim2.fromOffset(16, 372)
	)
	refs.legend.TextSize = 13
	refs.legend.AnchorPoint = Vector2.new(0, 1)
	refs.legend.Position = UDim2.new(0, 16, 1, -16)

	refs.startButton = Hud.button(screen, "START RUN (Enter)", UDim2.fromOffset(240, 48), UDim2.fromOffset(16, 420))
	refs.results = Hud.label(screen, "", UDim2.fromOffset(420, 90), UDim2.fromOffset(16, 480))
	refs.results.AnchorPoint = Vector2.new(0.5, 0.5)
	refs.results.Position = UDim2.new(0.5, 0, 0.4, 0)
	refs.results.Visible = false

	-- Shop: one button per unlockable item (server validates funds/ownership).
	refs.shopButtons = {}
	local y = 580
	for _, item in pairs(BoardCatalog.Boards) do
		if item.cost > 0 then
			local button = Hud.button(screen, "Unlock " .. item.name .. " (" .. tostring(item.cost) .. ")", UDim2.fromOffset(300, 40), UDim2.fromOffset(16, y))
			button:SetAttribute("ItemId", item.id)
			refs.shopButtons[item.id] = button
			y += 46
		end
	end
	for _, item in pairs(BoardCatalog.Cosmetics) do
		local button = Hud.button(screen, "Unlock " .. item.name .. " (" .. tostring(item.cost) .. ")", UDim2.fromOffset(300, 40), UDim2.fromOffset(16, y))
		button:SetAttribute("ItemId", item.id)
		refs.shopButtons[item.id] = button
		y += 46
	end
	refs.equipBoard = Hud.button(screen, "Equip Arcboard", UDim2.fromOffset(300, 40), UDim2.fromOffset(16, y))
	y += 46
	refs.equipCosmetic = Hud.button(screen, "Equip Dusk Stripe", UDim2.fromOffset(300, 40), UDim2.fromOffset(16, y))

	function refs:setSpeed(value: number)
		self.speed.Text = "Speed " .. tostring(math.floor(value))
	end
	function refs:setTimer(value: number)
		self.timer.Text = "Time " .. string.format("%.1f", value)
	end
	function refs:setScore(banked: number, pending: number)
		self.score.Text = "Score " .. tostring(banked) .. "  Pending " .. tostring(pending)
	end
	function refs:setGates(nextGate: number?)
		self.gates.Text = if nextGate then "Gates: next " .. tostring(nextGate) else "Gates: all passed — FINISH!"
	end
	function refs:setLanding(text: string)
		self.landing.Text = text
		if text == "CLEAN" then
			self.landing.TextColor3 = Color3.fromRGB(120, 255, 160)
		elseif text == "SKETCHY" then
			self.landing.TextColor3 = Color3.fromRGB(255, 224, 109)
		elseif text == "BAIL" then
			self.landing.TextColor3 = Color3.fromRGB(255, 130, 130)
		end
	end
	function refs:setTokens(value: number)
		self.tokens.Text = "Tokens " .. tostring(value) .. " (SESSION ONLY)"
	end
	function refs:showResults(elapsed: number, banked: number, granted: number)
		self.results.Visible = true
		self.results.Text = "FINISH  Time " .. string.format("%.1f", elapsed) .. "  Score " .. tostring(banked) .. "  + " .. tostring(granted) .. " tokens"
	end
	function refs:hideResults()
		self.results.Visible = false
	end
	return refs
end

return HudPresenter
