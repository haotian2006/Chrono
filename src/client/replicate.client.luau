local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.config)
local Snapshots = require(ReplicatedStorage.Shared.snapshots)
local Events = require(ReplicatedStorage.Events.client)
local config = require(ReplicatedStorage.Shared.config)
local InterpolationBuffer = require(script.Parent.interpolationBuffer)
local ClientRig = require(ReplicatedStorage.Shared.rigs.createCharacter)

local idMap = {} :: {
	[number]: {
		snapshot: Snapshots.SnapshotInstance,
		character: Model,
		lastCFrame: CFrame?,
	},
}

local player = Players.LocalPlayer

local lerp = (math :: any).lerp

local playerRenderTimes = {} :: { [number]: number }

local bufferTracker = InterpolationBuffer(Config.TICK_RATE, Config.MIN_BUFFER, Config.MAX_BUFFER, 0.1)

Events.ServerReplicateCFrame.On(function(serverData)
	bufferTracker.RegisterPacket(serverData.timeStamp)

	local cframes = serverData.cframes
	local snapshotTime = workspace:GetServerTimeNow()

	for id, cframe in cframes do
		local entry = idMap[id]
		if not entry then
			continue
		end
		entry.snapshot:PushAt(snapshotTime, cframe)
	end
end)

Events.InitializePlayer.On(function(serverData)
	local id = serverData.id
	local playerInstance = Players[serverData.player]

	local registeredSnapshots = Snapshots.RegisterPlayer(playerInstance)

	local initialRenderTime = workspace:GetServerTimeNow() - bufferTracker.GetBuffer()

	if config.ENABLE_CUSTOM_CHARACTERS then
		if player == playerInstance then
			playerInstance.Character = ClientRig(playerInstance).Model
			workspace.CurrentCamera.CameraSubject = playerInstance.Character
		else
			playerInstance.Character = ClientRig(playerInstance).Model
		end
	end

	local initialCFrame = CFrame.new()
	if playerInstance.Character and playerInstance.Character.PrimaryPart then
		initialCFrame = playerInstance.Character.PrimaryPart:GetPivot()
	end

	registeredSnapshots:PushAt(initialRenderTime, initialCFrame)

	idMap[id] = {
		snapshot = registeredSnapshots,
		character = playerInstance.Character,
		lastCFrame = initialCFrame,
	}
	playerRenderTimes[id] = initialRenderTime
end)

local lastSent = time()
local lastSentCFrame = CFrame.new()

RunService.RenderStepped:Connect(function(deltaTime: number)
	local globalServerTime = workspace:GetServerTimeNow()
	local targetRenderTime = globalServerTime - bufferTracker.GetBuffer()

	local renderTimeLerpFactor = math.clamp(deltaTime * Config.RENDER_LERP_FACTOR, 0, 1)

	for id, data in idMap do
		if not data.character or not data.character.PrimaryPart or data.character == player.Character then
			continue
		end

		local currentRenderTime = playerRenderTimes[id] or targetRenderTime
		local newRenderTime = lerp(currentRenderTime, targetRenderTime, renderTimeLerpFactor)
		playerRenderTimes[id] = newRenderTime

		local targetCFrame = data.snapshot:GetAt(newRenderTime)
		if targetCFrame then
			if not data.lastCFrame then
				data.lastCFrame = targetCFrame
			else
				local smoothFactor = math.clamp(deltaTime * Config.SMOOTHING_CONSTANT, 0, 1)
				data.lastCFrame = data.lastCFrame:Lerp(targetCFrame, smoothFactor)
			end
			data.character:PivotTo(data.lastCFrame :: any)
		end
	end
end)

RunService.Heartbeat:Connect(function()
	if time() - lastSent < Config.TICK_RATE then
		return
	end
	lastSent = time()

	if player.Character and player.Character.PrimaryPart then
		local currentCFrame = player.Character.PrimaryPart:GetPivot()

		if lastSentCFrame:FuzzyEq(currentCFrame, 0.1) then
			return
		end

		lastSentCFrame = currentCFrame
		Events.ClientReplicateCFrame.Fire(currentCFrame)
	end
end)
