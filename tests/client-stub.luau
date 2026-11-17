-- A deliberately strict stand-in for a Roblox client. It exists to catch the two bugs that
-- cost real playtests: requiring modules from beside the script, and untimed WaitForChild.
-- Reads of unknown properties raise. Methods on instances only exist if defined here.
local function signal()
	local s = { listeners = {} }
	function s:Connect(fn) table.insert(self.listeners, fn); return { Disconnect = function() end } end
	function s:Fire(...) for _, fn in ipairs(self.listeners) do fn(...) end end
	return s
end

local Vector3 = { new = function(x, y, z) return { X = x or 0, Y = y or 0, Z = z or 0 } end }
Vector3.zero = Vector3.new(0, 0, 0)
Vector3.yAxis = Vector3.new(0, 1, 0)
local Vector2 = { new = function(x, y) return { X = x or 0, Y = y or 0 } end }
local function colour(r, g, b) return { r = r or 0, g = g or 0, b = b or 0 } end
local Color3 = { new = colour, fromRGB = colour }
local UDim = { new = function(s, o) return { Scale = s, Offset = o } end }
local UDim2 = {
	new = function(sx, ox, sy, oy) return { X = { Scale = sx, Offset = ox }, Y = { Scale = sy, Offset = oy } } end,
}
UDim2.fromOffset = function(x, y) return UDim2.new(0, x, 0, y) end
UDim2.fromScale = function(x, y) return UDim2.new(x, 0, y, 0) end
local Enum = setmetatable({}, {
	__index = function(t, family)
		local members = setmetatable({}, { __index = function(m, key) local v = { Name = key }; rawset(m, key, v); return v end })
		rawset(t, family, members)
		return members
	end,
})

local GUI = { Frame = true, TextLabel = true, TextButton = true, ScreenGui = true, ViewportFrame = true }

local created = {}
local task = {}
task.wait = function() if coroutine.isyieldable() then coroutine.yield() end return 0 end
task.spawn = function(fn) fn() end
task.delay = function(_, fn) task.spawn(fn) end
task.defer = task.spawn
task.cancel = function() end

local function newInstance(className)
	-- Real instances always have a name; defaulting to "" stops the strict reader from
	-- tripping over unnamed objects created by view code.
	local object = { __type = className, Name = "", children = {}, attributes = {} }
	function object:GetChildren() return self.children end
	function object:GetDescendants() return self.children end
	function object:IsA(name) if self.__type == name then return true end; return name == "GuiObject" and GUI[self.__type] == true end
	function object:FindFirstChild(name)
		for _, child in ipairs(self.children) do if child.Name == name then return child end end
		return nil
	end
	function object:WaitForChild(name, timeout)
		local found = self:FindFirstChild(name)
		if found then return found end
		-- Studio raises "Infinite yield possible" on an untimed wait that never resolves.
		if not timeout then error("Infinite yield possible on '" .. tostring(self.Name) .. ":WaitForChild(\"" .. name .. "\")'") end
		return nil
	end
	function object:Destroy() self.__destroyed = true end
	function object:GetAttribute(name) return self.attributes[name] end
	function object:SetAttribute(name, value) self.attributes[name] = value end
	function object:GetAttributeChangedSignal() return signal() end
	function object:GetPropertyChangedSignal() return signal() end
	function object:IsDescendantOf() return false end
	function object:FindFirstAncestorOfClass() return nil end
	table.insert(created, object)
	return setmetatable(object, {
		__index = function(t, key)
			local child = rawget(t, "children")
			if child then for _, c in ipairs(child) do if c.Name == key then return c end end end
			error("stub: '" .. tostring(rawget(t, "Name")) .. "' has no property or child '" .. tostring(key) .. "'", 2)
		end,
		__newindex = function(t, key, value)
			-- Instances cannot carry functions as fields; assigning one is a real Studio error.
			if type(value) == "function" then
				error("stub: cannot assign a function to '" .. tostring(rawget(t, "Name")) .. "." .. tostring(key) .. "'")
			end
			if key == "Parent" and value and value.children then table.insert(value.children, t) end
			rawset(t, key, value)
		end,
	})
end

local Instance = { new = newInstance }
local function service(name) local s = newInstance(name); s.Name = name; return s end

local ReplicatedStorage = service("ReplicatedStorage")
local Shared = service("Folder"); Shared.Name = "Shared"; Shared.Parent = ReplicatedStorage
local tagModule = service("ModuleScript"); tagModule.Name = "BuildTag"; tagModule.Parent = Shared
local configModule = service("ModuleScript"); configModule.Name = "Config"; configModule.Parent = Shared
local physicsModule = service("ModuleScript"); physicsModule.Name = "Physics"; physicsModule.Parent = Shared
local landingModule = service("ModuleScript"); landingModule.Name = "Landing"; landingModule.Parent = Shared
local trickCatalogModule = service("ModuleScript"); trickCatalogModule.Name = "TrickCatalog"; trickCatalogModule.Parent = Shared
local trickScorerModule = service("ModuleScript"); trickScorerModule.Name = "TrickScorer"; trickScorerModule.Parent = Shared
local boardCatalogModule = service("ModuleScript"); boardCatalogModule.Name = "BoardCatalog"; boardCatalogModule.Parent = Shared
local runRulesModule = service("ModuleScript"); runRulesModule.Name = "RunRules"; runRulesModule.Parent = Shared
local networkContractsModule = service("ModuleScript"); networkContractsModule.Name = "NetworkContracts"; networkContractsModule.Parent = Shared
local profileModule = service("ModuleScript"); profileModule.Name = "Profile"; profileModule.Parent = Shared
local ClientModules = service("Folder"); ClientModules.Name = "ClientModules"; ClientModules.Parent = ReplicatedStorage
local hudModule = service("ModuleScript"); hudModule.Name = "Hud"; hudModule.Parent = ClientModules
local hudPresenterModule = service("ModuleScript"); hudPresenterModule.Name = "HudPresenter"; hudPresenterModule.Parent = ClientModules
local inputMapperModule = service("ModuleScript"); inputMapperModule.Name = "InputMapper"; inputMapperModule.Parent = ClientModules
local boardControllerModule = service("ModuleScript"); boardControllerModule.Name = "BoardController"; boardControllerModule.Parent = ClientModules
local animationControllerModule = service("ModuleScript"); animationControllerModule.Name = "AnimationController"; animationControllerModule.Parent = ClientModules
local cameraControllerModule = service("ModuleScript"); cameraControllerModule.Name = "CameraController"; cameraControllerModule.Parent = ClientModules

local player = service("Player"); player.Name = "Player"; player.UserId = 1
local playerGui = service("PlayerGui"); playerGui.Name = "PlayerGui"; playerGui.Parent = player
local Players = { LocalPlayer = player }
local userInput = service("UserInputService")
userInput.InputBegan = signal(); userInput.InputEnded = signal()
userInput.TouchEnabled = false
local scriptContext = service("ScriptContext"); scriptContext.Error = signal()
local httpService = service("HttpService")
local runService = service("RunService"); runService.RenderStepped = signal()
local readyEvent = signal()
local Remotes = service("Folder"); Remotes.Name = "Remotes"; Remotes.Parent = ReplicatedStorage
local function makeRemote(name, className)
	local remote = service(className or "RemoteEvent"); remote.Name = name; remote.Parent = Remotes
	remote.OnClientEvent = signal()
	remote.OnServerEvent = signal()
	rawset(remote, "FireServer", function() end)
	rawset(remote, "FireClient", function() end)
	rawset(remote, "InvokeServer", function() return { ok = false } end)
	return remote
end
local readyRemote = makeRemote("Ready")
makeRemote("StartRun")
makeRemote("TrickEvent")
makeRemote("LandEvent")
makeRemote("WipeoutEvent")
makeRemote("RunUpdate")
makeRemote("ProfileUpdate")
makeRemote("Results")
makeRemote("UnlockItem", "RemoteFunction")
makeRemote("EquipItem", "RemoteFunction")
HARNESS_DROP_REMOTES = function()
	for index, child in ipairs(ReplicatedStorage.children) do
		if child.Name == "Remotes" then table.remove(ReplicatedStorage.children, index) break end
	end
end

-- `script` is the LocalScript itself; its Parent is the PlayerScripts container, which does
-- NOT contain the client modules. Modelling that is what catches the wrong require path.
local playerScripts = service("Folder"); playerScripts.Name = "PlayerScripts"; playerScripts.Parent = player
local script = service("LocalScript"); script.Name = "Main"; script.Parent = playerScripts

-- TextButtons need a click signal (HudPresenter/Main.client connect at boot).
local originalNewInstance = newInstance
newInstance = function(className)
	local createdInstance = originalNewInstance(className)
	if className == "TextButton" then
		createdInstance.MouseButton1Click = signal()
	end
	return createdInstance
end
Instance.new = newInstance

local workspace = service("Workspace")
local fakeCamera = { CFrame = { Position = Vector3.new(0, 10, 0) }, CameraType = nil }
rawset(workspace, "CurrentCamera", fakeCamera)

local serviceCache = {}
local game = { GetService = function(_, name)
	if name == "Players" then return Players end
	if name == "ReplicatedStorage" then return ReplicatedStorage end
	if name == "UserInputService" then return userInput end
	if name == "ScriptContext" then return scriptContext end
	if name == "RunService" then return runService end
	if name == "HttpService" then return httpService end
	if name == "Workspace" then return workspace end
	if serviceCache[name] then return serviceCache[name] end
	local createdService = service(name)
	serviceCache[name] = createdService
	return createdService
end }
