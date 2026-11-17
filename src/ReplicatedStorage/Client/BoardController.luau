--!strict
-- Client prediction: drives HumanoidRootPart with shared Physics rules.
-- Grounded via downward raycast; airborne ballistic. Sends trick/landing
-- intents with unique event IDs; the server validates and banks.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Physics = require(ReplicatedStorage.Shared.Physics)
local Landing = require(ReplicatedStorage.Shared.Landing)
local BoardCatalog = require(ReplicatedStorage.Shared.BoardCatalog)

local BoardController = {}

local function newEventId(): string
	return tostring(os.clock()) .. "-" .. tostring(math.random(1, 999999))
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
		groundNormal = Vector3.yAxis,
		pose = "idle",
		running = false,
	}
	function self:setRunning(value: boolean)
		self.running = value
		if value then
			self.speed = 0
			self.spin = 0
			self.airTime = 0
		end
	end
	-- Server teleports (start, checkpoint, retry) send the new CFrame; snap to it.
	function self:resetTo(cframe: CFrame)
		self.speed = 0
		self.spin = 0
		self.airTime = 0
		self.velocity = Vector3.zero
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
		end
	end
	function self:step(intent: any, dt: number)
		local character = self.player.Character
		if not character then
			return
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		local hrp = root :: BasePart
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = 0 -- custom controller owns motion
			humanoid.PlatformStand = true
		end
		hrp.Anchored = true -- kinematic controller: CFrame owns motion, no physics fight
		dt = math.min(dt, Config.physics.maxDelta)

		-- Ground probe.
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		local origin = hrp.Position + Vector3.new(0, 4, 0)
		local hit = Workspace:Raycast(origin, Vector3.new(0, -12, 0), params)
		local wasGrounded = self.grounded
		if hit then
			self.groundNormal = hit.Normal
		end
		local support = hit ~= nil and (origin.Y - hit.Position.Y) < 9
		-- Hysteresis: a fast-falling rider stays airborne until close, so the
		-- landing branch (classification + LandEvent) always runs once.
		local canGround = support and (wasGrounded or self.velocity.Y > -8)

		if canGround then
			-- Grounded: slope pitch along heading.
			local forward = Vector3.new(-math.sin(self.heading), 0, -math.cos(self.heading))
			local tangent = forward - self.groundNormal * forward:Dot(self.groundNormal)
			local pitch = 0
			if tangent.Magnitude > 0.01 then
				pitch = math.asin(math.clamp(-tangent.Unit.Y, -1, 1))
			end
			local next = Physics.stepGrounded(
				{ speed = self.speed, heading = self.heading, slip = self.slip, edge = self.edge },
				{ steer = intent.steer, tuck = intent.tuck, brake = intent.brake, edge = intent.edge },
				pitch,
				dt,
				self.boardStats
			)
			self.speed = next.speed
			self.heading = next.heading
			self.slip = next.slip
			self.edge = next.edge
			self.grounded = true
			self.airTime = 0
			self.spin = 0
			-- Pop.
			if intent.popPressed then
				local pop = Physics.popVelocity(self.lastPopAt, os.clock())
				if pop then
					self.lastPopAt = os.clock()
					self.velocity = forward * self.speed + Vector3.new(0, pop, 0)
					self.grounded = false
					self.pose = "takeoff"
				end
			end
			if self.grounded then
				local groundPos = hit.Position + Vector3.new(0, 3, 0)
				local move = forward * self.speed * dt
				local target = groundPos + move
				-- Keep HRP on the surface (snap), heading-aligned.
				local yawCFrame = CFrame.new(target) * CFrame.Angles(0, self.heading, 0)
				hrp.CFrame = yawCFrame
				hrp.AssemblyLinearVelocity = forward * self.speed
				self.velocity = forward * self.speed
				self.pose = if intent.tuck then "tuck" elseif intent.edge ~= 0 then "carve" elseif math.abs(intent.steer) > 0 then "carve" else "ride"
			end
		else
			-- Airborne: ballistic + weak yaw.
			self.grounded = false
			self.airTime += dt
			local air = Physics.stepAir({ heading = self.heading, spin = self.spin }, { steer = intent.steer }, dt)
			self.heading = air.heading
			self.spin = air.spin
			self.velocity += Vector3.new(0, -Config.physics.gravity * dt, 0)
			local forward = Vector3.new(-math.sin(self.heading), 0, -math.cos(self.heading))
			-- Preserve horizontal momentum; steer nudges heading only.
			local horizontal = Vector3.new(self.velocity.X, 0, self.velocity.Z)
			if horizontal.Magnitude < 0.1 then
				horizontal = forward * self.speed
			end
			self.velocity = Vector3.new(horizontal.X, self.velocity.Y, horizontal.Z)
			hrp.CFrame = CFrame.new(hrp.Position + self.velocity * dt) * CFrame.Angles(0, self.heading, 0)
			hrp.AssemblyLinearVelocity = self.velocity
			self.pose = "air"
			-- Grab intent (J/K) while airborne.
			if intent.grab and self.remotes and self.running then
				self.pose = if intent.grab == "Meteor" then "meteor" else "sail"
				self.remotes.TrickEvent:FireServer({
					eventId = newEventId(),
					trickId = intent.grab,
					airTime = self.airTime,
					speed = self.speed,
				})
			end
			-- Landing.
			if hit and self.velocity.Y < 0 and (origin.Y - hit.Position.Y) < 6 then
				local impact = math.abs(self.velocity.Y)
				local alignDeg = math.abs(math.deg(self.spin)) % 360
				if alignDeg > 180 then
					alignDeg = 360 - alignDeg
				end
				local yawDeg = math.deg(self.spin)
				local quality = Landing.classify(impact, alignDeg, yawDeg)
				self.grounded = true
				self.pose = if quality == "clean" then "land-clean" elseif quality == "sketchy" then "land-sketchy" else "crash"
				if self.remotes and self.running then
					self.remotes.LandEvent:FireServer({
						eventId = newEventId(),
						airTime = self.airTime,
						yawDeg = yawDeg,
						impact = impact,
						alignDeg = alignDeg,
					})
				end
				if quality == "bail" then
					self.speed *= 0.3
				elseif quality == "sketchy" then
					self.speed *= 0.7
				end
				self.velocity = Vector3.zero
				self.airTime = 0
				self.spin = 0
			end
		end
		if wasGrounded and not self.grounded and self.pose == "ride" then
			self.pose = "takeoff"
		end
	end
	return self
end

return BoardController
