--!strict
-- Reads the versioned Studio/Rojo course artifact (Workspace.Course).
-- Geometry is authored in default.project.json and built into the place;
-- this service only reads positions. It never creates course geometry.
local Workspace = game:GetService("Workspace")

local CourseService = {}

export type CourseData = {
	startCFrame: CFrame,
	checkpointCFrame: CFrame,
	gates: { CFrame },
	finishCFrame: CFrame,
	hazardPositions: { Vector3 },
}

local function findCourse(): Instance?
	return Workspace:FindFirstChild("Course")
end

function CourseService.load(): CourseData?
	local course = findCourse()
	if not course then
		return nil
	end
	local startPad = course:FindFirstChild("StartPad")
	local checkpoint = course:FindFirstChild("Checkpoint")
	local finishPad = course:FindFirstChild("FinishPad")
	local gatesFolder = course:FindFirstChild("Gates")
	if not startPad or not finishPad or not gatesFolder then
		return nil
	end
	local gates: { CFrame } = {}
	for index = 1, 2 do
		local gate = gatesFolder:FindFirstChild("Gate" .. index)
		if not gate then
			return nil
		end
		table.insert(gates, (gate :: BasePart).CFrame)
	end
	local hazards: { Vector3 } = {}
	local hazardsFolder = course:FindFirstChild("Hazards")
	if hazardsFolder then
		for _, hazard in ipairs(hazardsFolder:GetChildren()) do
			if hazard:IsA("BasePart") then
				table.insert(hazards, (hazard :: BasePart).Position)
			end
		end
	end
	local checkpointCFrame = if checkpoint then (checkpoint :: BasePart).CFrame else (startPad :: BasePart).CFrame
	return {
		startCFrame = (startPad :: BasePart).CFrame,
		checkpointCFrame = checkpointCFrame,
		gates = gates,
		finishCFrame = (finishPad :: BasePart).CFrame,
		hazardPositions = hazards,
	}
end

return CourseService
