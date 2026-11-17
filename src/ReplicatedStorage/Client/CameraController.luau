--!strict
-- Follow camera: behind heading, speed-aware distance/lookahead, damped.
-- No auto-roll. Scriptable camera owned by the client.
local Workspace = game:GetService("Workspace")

local CameraController = {}

function CameraController.new(player: Player): any
	local self: any = { player = player, camera = Workspace.CurrentCamera }
	function self:step(heading: number, speed: number, dt: number)
		local character = self.player.Character
		if not character then
			return
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		local camera = self.camera or Workspace.CurrentCamera
		if not camera then
			return
		end
		self.camera = camera
		camera.CameraType = Enum.CameraType.Scriptable
		local hrp = root :: BasePart
		local forward = Vector3.new(-math.sin(heading), 0, -math.cos(heading))
		local distance = 14 + math.clamp(speed * 0.12, 0, 10)
		local height = 7 + math.clamp(speed * 0.05, 0, 4)
		local desiredPos = hrp.Position - forward * distance + Vector3.new(0, height, 0)
		local lookAt = hrp.Position + forward * (6 + speed * 0.15) + Vector3.new(0, 1, 0)
		local alpha = math.clamp(dt * 6, 0, 1)
		local currentPos = camera.CFrame.Position
		local nextPos = currentPos:Lerp(desiredPos, alpha)
		camera.CFrame = CFrame.lookAt(nextPos, lookAt)
	end
	return self
end

return CameraController
