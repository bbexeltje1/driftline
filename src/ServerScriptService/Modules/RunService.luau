--!strict
-- Authoritative per-player run state: start, ordered gates, finish-once,
-- wipeout penalty, checkpoint recovery, trick bank/bail. The server derives
-- score from validated intents (MovementValidator + TrickScorer), never from
-- client-submitted totals. Session-only; no DataStore here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage.Shared.Config)
local RunRules = require(ReplicatedStorage.Shared.RunRules)
local TrickScorer = require(ReplicatedStorage.Shared.TrickScorer)
local MovementValidator = require(script.Parent.MovementValidator)
local ProfileService = require(script.Parent.ProfileService)
local RewardService = require(script.Parent.RewardService)

local RunService = {}

export type PlayerRun = {
	player: Player,
	run: any,
	scorer: any,
	seenIds: { [string]: boolean },
	startedAt: number,
	state: string, -- ready | running | finished
	lastGateCheck: number,
}

local runs: { [number]: PlayerRun } = {}
local courseData: any = nil
local remotes: any = nil

function RunService.init(course: any, remoteFolder: any)
	courseData = course
	remotes = remoteFolder
end

local function getRun(player: Player): PlayerRun?
	return runs[player.UserId]
end

local function hasEventId(payload: any): boolean
	return type(payload) == "table" and type(payload.eventId) == "string" and #payload.eventId > 0
end

local function elapsedOf(entry: PlayerRun): number
	if entry.state ~= "running" then
		return 0
	end
	local base = os.clock() - entry.startedAt
	return RunRules.elapsedWithPenalty(base, entry.run.penalty)
end

local function pushUpdate(entry: PlayerRun, extra: any?)
	if not remotes then
		return
	end
	local profile = ProfileService.get(entry.player.UserId)
	local payload: any = {
		state = entry.state,
		elapsed = elapsedOf(entry),
		banked = entry.scorer.banked,
		pending = TrickScorer.computePending(entry.scorer),
		gatesPassed = entry.run.gatesPassed,
		nextGate = RunRules.nextGate(entry.run),
		tokens = profile.tokens,
		penalty = entry.run.penalty,
	}
	if entry.pendingRespawn then
		payload.respawnAt = entry.pendingRespawn
		entry.pendingRespawn = nil
	end
	if extra then
		for key, value in pairs(extra) do
			payload[key] = value
		end
	end
	remotes.RunUpdate:FireClient(entry.player, payload)
end

-- CFrame.Angles(0, pi, 0): the rider looks along +Z, the course direction.
local RIDER_FACING = CFrame.Angles(0, math.pi, 0)

local function teleportTo(entry: PlayerRun, cframe: CFrame)
	local character = entry.player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		local hrp = root :: BasePart
		-- Keep the course position, but always face down the course (+Z).
		hrp.CFrame = CFrame.new(cframe.Position + Vector3.new(0, 3, 0)) * RIDER_FACING
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
		entry.pendingRespawn = hrp.CFrame
	end
end

function RunService.startRun(player: Player): boolean
	ProfileService.get(player.UserId) -- ensure session profile exists
	local runId = HttpService:GenerateGUID(false)
	local entry: PlayerRun = {
		player = player,
		run = RunRules.newRun(runId),
		scorer = TrickScorer.new(),
		seenIds = {},
		startedAt = os.clock(),
		state = "running",
		lastGateCheck = 0,
	}
	runs[player.UserId] = entry
	if courseData then
		teleportTo(entry, courseData.startCFrame)
	end
	pushUpdate(entry, { runId = runId })
	return true
end

function RunService.handleTrick(player: Player, payload: any): boolean
	local entry = getRun(player)
	if not entry or entry.state ~= "running" then
		return false
	end
	if not MovementValidator.validateGrab(payload, entry.seenIds) then
		return false
	end
	entry.seenIds[payload.eventId] = true
	local awarded = TrickScorer.addGrab(entry.scorer, payload.trickId)
	if awarded == nil then
		return false
	end
	pushUpdate(entry, { trick = payload.trickId, trickPoints = awarded })
	return true
end

function RunService.handleLanding(player: Player, payload: any): string?
	local entry = getRun(player)
	if not entry or entry.state ~= "running" then
		return nil
	end
	local quality = MovementValidator.validateLanding(payload, entry.seenIds)
	if not quality then
		return nil
	end
	entry.seenIds[payload.eventId] = true
	-- Spin tier is evaluated from validated yaw at landing.
	TrickScorer.addSpin(entry.scorer, payload.yawDeg or 0)
	local banked = TrickScorer.land(entry.scorer, quality)
	if quality == "bail" then
		RunRules.applyWipeoutPenalty(entry.run)
		if courseData then
			teleportTo(entry, courseData.checkpointCFrame)
		end
	end
	pushUpdate(entry, { landing = quality, bankedNow = banked })
	return quality
end

function RunService.handleWipeout(player: Player, payload: any): boolean
	local entry = getRun(player)
	if not entry or entry.state ~= "running" then
		return false
	end
	if not hasEventId(payload) then
		return false
	end
	if entry.seenIds[payload.eventId] then
		return false
	end
	entry.seenIds[payload.eventId] = true
	TrickScorer.bail(entry.scorer)
	RunRules.applyWipeoutPenalty(entry.run)
	if courseData then
		teleportTo(entry, courseData.checkpointCFrame)
	end
	pushUpdate(entry, { landing = "bail", wipedOut = true })
	return true
end

-- Gate/finish polling from server-observed character position.
function RunService.poll(player: Player)
	local entry = getRun(player)
	if not entry or entry.state ~= "running" or not courseData then
		return
	end
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local position = (root :: BasePart).Position

	-- Fell off the course: same consequence as a wipeout, reset to checkpoint.
	if position.Y < Config.run.fallHeight then
		TrickScorer.bail(entry.scorer)
		RunRules.applyWipeoutPenalty(entry.run)
		teleportTo(entry, courseData.checkpointCFrame)
		pushUpdate(entry, { landing = "bail", wipedOut = true })
		return
	end

	-- Hazard proximity -> wipeout (server-observed, not client-claimed).
	for _, hazardPos in ipairs(courseData.hazardPositions) do
		if (position - hazardPos).Magnitude < 6 then
			TrickScorer.bail(entry.scorer)
			RunRules.applyWipeoutPenalty(entry.run)
			teleportTo(entry, courseData.checkpointCFrame)
			pushUpdate(entry, { landing = "bail", wipedOut = true })
			return
		end
	end

	local nextGate = RunRules.nextGate(entry.run)
	if nextGate and courseData.gates[nextGate] then
		local gatePos = (courseData.gates[nextGate] :: CFrame).Position
		if (position - gatePos).Magnitude <= Config.run.gateRadius then
			RunRules.passGate(entry.run, nextGate)
			pushUpdate(entry, { gatePassed = nextGate })
		end
	end

	if RunRules.canFinish(entry.run) then
		local finishPos = (courseData.finishCFrame :: CFrame).Position
		if (position - finishPos).Magnitude <= Config.run.finishRadius then
			entry.state = "finished"
			entry.run.finished = true
			local profile = ProfileService.get(player.UserId)
			local elapsed = elapsedOf(entry)
			local granted = RewardService.grantForFinish(profile, entry.run.runId, entry.scorer.banked, elapsed)
			pushUpdate(entry, { finished = true, elapsed = elapsed, granted = granted })
			if remotes then
				remotes.Results:FireClient(player, {
					runId = entry.run.runId,
					elapsed = elapsed,
					banked = entry.scorer.banked,
					granted = granted,
					tokens = profile.tokens,
				})
			end
		end
	end
end

function RunService.clear(player: Player)
	runs[player.UserId] = nil
end

function RunService.getState(player: Player): string
	local entry = getRun(player)
	return if entry then entry.state else "ready"
end

return RunService
