--!strict
-- Physics-driven board (client). The rider is an unanchored HumanoidRootPart driven by:
--   * a ground probe + spring support along the ground normal (RideDynamics.supportAccel),
--   * a VectorForce carrying drive, drag, grip and Roblox-gravity correction,
--   * an AlignOrientation that keeps the board flush with the slope.
-- Landings are judged from the real impact. The server validates trick/landing claims
-- and never trusts client score; it also resets the rider to the checkpoint on a wipeout.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Physics = require(ReplicatedStorage.Shared.Physics)
local RideDynamics = require(ReplicatedStorage.Shared.RideDynamics)
local Landing = require(ReplicatedStorage.Shared.Landing)

local BoardController = {}

local NO_INTENT = { steer = 0, edge = 0, tuck = false, brake = false, popPressed = false, grab = nil }

local function newEventId(): string
	return tostring(os.clock()) .. "-" .. tostring(math.random(1, 999999))
end

local function forwardOf(heading: number): Vector3
	return Vector3.new(-math.sin(heading), 0, -math.cos(heading))
end

function BoardController.new(player: Player, remotes: any, boardStats: any): any
	local self: any = {
		player = player,
		remotes = remotes,
		boardStats = boardStats,
		speed = 0,
		heading = math.pi, -- course runs +Z; CFrame yaw pi faces +Z
		slip = 0,
		edge = 0,
		grounded = false,
		airTime = 0,
		spin = 0,
		velocity = Vector3.zero,
		lastPopAt = -10,
		launchUntil = 0,
		groundNormal = Vector3.yAxis,
		pose = "idle",
		running = false,
		rig = nil,
	}

	function self:setRunning(value: boolean)
		self.running = value
		if value then
			self.spin = 0
			self.airTime = 0
		end
	end

	-- Creates the physics rig once per character: a force, an orientation and an attachment.
	function self:ensureRig(hrp: BasePart): any
		if self.rig and self.rig.hrp == hrp then
			return self.rig
		end
		local attachment = Instance.new("Attachment")
		attachment.Name = "DriftAttach"
		attachment.Parent = hrp
		local force = Instance.new("VectorForce")
		force.Attachment0 = attachment
		force.RelativeTo = Enum.ActuatorRelativeTo.World
		force.ApplyAtCenterOfMass = true
		force.Parent = hrp
		local align = Instance.new("AlignOrientation")
		align.Attachment0 = attachment
		align.Mode = Enum.OrientationAlignmentMode.OneAttachment
		align.Responsiveness = 30
		align.MaxTorque = 100000
		align.Parent = hrp
		hrp.Anchored = false
		self.rig = { hrp = hrp, force = force, align = align }
		return self.rig
	end

	-- Server teleports (start, checkpoint, retry) send the new CFrame; snap to it.
	function self:resetTo(cframe: CFrame)
		self.speed = 0
		self.spin = 0
		self.airTime = 0
		self.velocity = Vector3.zero
		self.launchUntil = 0
		local look = cframe.LookVector
		-- forward = (-sin h, 0, -cos h): recover h from the look vector.
		self.heading = math.atan2(-look.X, -look.Z)
		self.grounded = false
		local character = self.player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local hrp = root :: BasePart
			hrp.CFrame = cframe
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.AssemblyAngularVelocity = Vector3.zero
		end
	end

	function self:step(rawIntent: any, dt: number)
		local character = self.player.Character
		if not character then
			return
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		local hrp = root :: BasePart
		-- Drive inputs only count during a run; before Enter the rider just stands on the pad.
		local intent = if self.running then rawIntent else NO_INTENT
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = 0
			humanoid.PlatformStand = true
		end
		local rig = self:ensureRig(hrp)
		dt = math.min(dt, Config.physics.maxDelta)

		local mass = math.max(hrp.AssemblyMass, 1)
		local velocity = hrp.AssemblyLinearVelocity
		local position = hrp.Position
		local now = os.clock()

		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		local origin = position + Vector3.new(0, 4, 0)
		local hit = Workspace:Raycast(origin, Vector3.new(0, -(Config.ride.probeLength + 4), 0), params)
		local normal = if hit then hit.Normal else Vector3.yAxis
		local dy = if hit then position.Y - hit.Position.Y else math.huge
		local nearGround = hit ~= nil and dy <= Config.ride.restLength + 1.5
		local launchHeld = now < self.launchUntil
		local wasGrounded = self.grounded
		local gravityFix = RideDynamics.gravityCorrection(Workspace.Gravity)
		local heading = self.heading
		local forward = forwardOf(heading)

		if nearGround and not launchHeld then
			self.groundNormal = normal
			local closing = -velocity:Dot(normal)
			local compression = Config.ride.restLength - dy
			local support = RideDynamics.supportAccel(compression, closing)

			-- Slope frame: forward and lateral in the ground plane.
			local tangentFwd = forward - normal * forward:Dot(normal)
			if tangentFwd.Magnitude < 0.01 then
				tangentFwd = forward
			else
				tangentFwd = tangentFwd.Unit
			end
			local speed = velocity:Dot(tangentFwd)
			local lateral = velocity - tangentFwd * speed - normal * velocity:Dot(normal)
			local forwardSpeed = math.max(speed, 0)

			-- Landing: the first grounded frame after air ends the air phase.
			if not wasGrounded then
				local airAtLanding = self.airTime
				if airAtLanding >= Config.ride.landingMinAir and self.remotes and self.running then
					local alignDeg = math.abs(math.deg(self.spin)) % 360
					if alignDeg > 180 then
						alignDeg = 360 - alignDeg
					end
					local yawDeg = math.deg(self.spin)
					local impact = math.max(closing, 0)
					local quality = Landing.classify(impact, alignDeg, yawDeg)
					self.pose = if quality == "clean" then "land-clean" elseif quality == "sketchy" then "land-sketchy" else "crash"
					self.remotes.LandEvent:FireServer({
						eventId = newEventId(),
						airTime = airAtLanding,
						yawDeg = yawDeg,
						impact = impact,
						alignDeg = alignDeg,
					})
					if quality == "bail" or quality == "sketchy" then
						local factor = if quality == "bail" then 0.3 else 0.7
						hrp.AssemblyLinearVelocity = Vector3.new(velocity.X * factor, velocity.Y, velocity.Z * factor)
					end
				end
				self.spin = 0
				self.airTime = 0
			end

			-- Steering (ground), then forces for this step.
			self.heading = RideDynamics.steerHeading(heading, intent.steer, intent.edge, forwardSpeed, self.boardStats, dt)
			local driveA = RideDynamics.driveAccel(forwardSpeed, intent.tuck, intent.brake, self.boardStats)
			local dragA = RideDynamics.dragAccel(forwardSpeed, intent.tuck)
			local gripA = -lateral * RideDynamics.gripRate(self.boardStats, intent.edge)
			local accel = normal * support + tangentFwd * (driveA + dragA) + gripA + Vector3.new(0, gravityFix, 0)
			rig.force.Force = accel * mass
			rig.align.CFrame = CFrame.lookAt(position, position + tangentFwd, normal)

			self.grounded = true
			self.speed = forwardSpeed
			self.edge = intent.edge
			self.velocity = velocity
			self.pose = if intent.tuck then "tuck" elseif intent.edge ~= 0 or math.abs(intent.steer) > 0 then "carve" else "ride"

			if intent.popPressed then
				local pop = Physics.popVelocity(self.lastPopAt, now)
				if pop then
					self.lastPopAt = now
					self.launchUntil = now + Config.ride.launchHold
					hrp.AssemblyLinearVelocity = velocity + Vector3.new(0, pop, 0)
					rig.force.Force = Vector3.new(0, gravityFix * mass, 0)
					self.grounded = false
					self.pose = "takeoff"
				end
			end
		else
			-- Airborne: only world gravity (corrected) acts; air steer nudges heading.
			self.grounded = false
			self.airTime += dt
			local air = Physics.stepAir({ heading = self.heading, spin = self.spin }, { steer = intent.steer }, dt)
			self.heading = air.heading
			self.spin = air.spin
			rig.force.Force = Vector3.new(0, gravityFix * mass, 0)
			rig.align.CFrame = CFrame.lookAt(position, position + forwardOf(self.heading), Vector3.yAxis)
			self.speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
			self.velocity = velocity
			self.pose = "air"
			if intent.grab and self.remotes and self.running then
				self.pose = if intent.grab == "Meteor" then "meteor" else "sail"
				self.remotes.TrickEvent:FireServer({
					eventId = newEventId(),
					trickId = intent.grab,
					airTime = self.airTime,
					speed = self.speed,
				})
			end
		end
	end

	return self
end

return BoardController
