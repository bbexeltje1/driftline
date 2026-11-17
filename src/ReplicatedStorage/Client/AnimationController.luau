--!strict
-- Procedural original poses: board lean/tilt follows steer/edge/speed/state.
-- Priority: crash > landing > trick > air > carve > tuck > ride > idle.
-- The board is player equipment (created at runtime); course geometry is not.
local BoardCatalog = require(script.Parent.Parent.Shared.BoardCatalog)

local AnimationController = {}

function AnimationController.new(player: Player): any
	local self: any = { player = player, board = nil, boardColor = nil }
	function self:ensureBoard()
		local character = self.player.Character
		if not character then
			return nil
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then
			return nil
		end
		if self.board and self.board.Parent then
			return self.board
		end
		local board = Instance.new("Part")
		board.Name = "DriftBoard"
		board.Size = Vector3.new(2.2, 0.25, 4.2)
		board.Anchored = true -- placed by CFrame each frame; no physics
		board.CanCollide = false
		board.CanQuery = false
		board.Color = Color3.fromRGB(232, 236, 240)
		board.Material = Enum.Material.SmoothPlastic
		board.Parent = character
		self.board = board
		return board
	end
	function self:setCosmetic(cosmeticId: string?)
		local board = self:ensureBoard()
		if not board then
			return
		end
		if cosmeticId and BoardCatalog.isCosmetic(cosmeticId) then
			local item = BoardCatalog.getItem(cosmeticId)
			local c = item.color
			board.Color = Color3.fromRGB(c[1], c[2], c[3])
		end
	end
	function self:setBoardColor(boardId: string?)
		local board = self:ensureBoard()
		if not board then
			return
		end
		local item = BoardCatalog.getBoard(boardId)
		if item then
			local c = item.color
			board.Color = Color3.fromRGB(c[1], c[2], c[3])
		end
	end
	-- pose: idle|ride|tuck|carve|takeoff|air|meteor|sail|land-clean|land-sketchy|crash
	function self:apply(pose: string, steer: number, edge: number, speed: number)
		local board = self:ensureBoard()
		if not board then
			return
		end
		local character = self.player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		local hrp = root :: BasePart
		local roll = steer * 0.45 + edge * 0.35
		local pitch = 0
		if pose == "tuck" then
			pitch = 0.35
		elseif pose == "takeoff" then
			pitch = -0.3
		elseif pose == "meteor" then
			pitch = -0.9
			roll = 0.2
		elseif pose == "sail" then
			roll = 1.1
		elseif pose == "crash" then
			roll = 1.4
			pitch = 0.6
		elseif pose == "land-sketchy" then
			roll = 0.7
		end
		-- Visual-only board: anchored, placed from HRP each frame. The rider HRP is
		-- never rotated here (BoardController owns HRP CFrame; per-frame rotation compounds).
		board.CFrame = hrp.CFrame * CFrame.new(0, -2.6, 0) * CFrame.Angles(pitch, 0, roll)
	end
	return self
end

return AnimationController
