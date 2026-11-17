--!strict
-- PC keyboard -> intent table. M1 guarantees keyboard only (controller/touch M4).
-- Context-aware: A/D steer on ground, spin in air; J/K grabs in air only.
local UserInputService = game:GetService("UserInputService")

local InputMapper = {}

export type Intent = {
	steer: number, -- -1..1
	tuck: boolean,
	brake: boolean,
	edge: number, -- -1..1
	popPressed: boolean,
	grab: string?, -- "Meteor" | "Sail" | nil (edge-triggered)
	startPressed: boolean,
	retryPressed: boolean,
}

function InputMapper.new(): any
	local self: any = {
		keysDown = {},
		popQueued = false,
		grabQueued = nil,
		startQueued = false,
		retryQueued = false,
	}
	function self:bind()
		UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
			if processed then
				return
			end
			local code = input.KeyCode
			self.keysDown[code] = true
			if code == Enum.KeyCode.Space then
				self.popQueued = true
			elseif code == Enum.KeyCode.J then
				self.grabQueued = "Meteor"
			elseif code == Enum.KeyCode.K then
				self.grabQueued = "Sail"
			elseif code == Enum.KeyCode.Return or code == Enum.KeyCode.KeypadEnter then
				self.startQueued = true
			elseif code == Enum.KeyCode.R then
				self.retryQueued = true
			end
		end)
		UserInputService.InputEnded:Connect(function(input: InputObject)
			self.keysDown[input.KeyCode] = false
		end)
	end
	function self:intent(): Intent
		local down = self.keysDown
		local steer = 0
		if down[Enum.KeyCode.A] then
			steer -= 1
		end
		if down[Enum.KeyCode.D] then
			steer += 1
		end
		local edge = 0
		if down[Enum.KeyCode.Q] then
			edge -= 1
		end
		if down[Enum.KeyCode.E] then
			edge += 1
		end
		local intent: Intent = {
			steer = steer,
			tuck = down[Enum.KeyCode.W] == true,
			brake = down[Enum.KeyCode.S] == true,
			edge = edge,
			popPressed = self.popQueued,
			grab = self.grabQueued,
			startPressed = self.startQueued,
			retryPressed = self.retryQueued,
		}
		self.popQueued = false
		self.grabQueued = nil
		self.startQueued = false
		self.retryQueued = false
		return intent
	end
	return self
end

return InputMapper
