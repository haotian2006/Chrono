local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.config)
local Snapshots = require(ReplicatedStorage.Shared.snapshots)
local Events = require(ReplicatedStorage.Events.client)

local RequestServerTime = ReplicatedStorage:WaitForChild("RequestServerTime")

local idMap = {} :: {
	[number]: {
		snapshot: Snapshots.SnapshotInstance,
		character: Model,
		lastCFrame: CFrame?,
	},
}

local player = Players.LocalPlayer

local serverTimeOffset = 0

local lerp = (math :: any).lerp

local playerRenderTimes = {} :: { [number]: number }

local function SynchronizeTime()
	local clientSendTime = time()
	local serverTime = RequestServerTime:InvokeServer()
	local clientReceiveTime = time()

	local rtt = clientReceiveTime - clientSendTime
	serverTimeOffset = serverTime + (rtt / 2) - clientReceiveTime
end

local function GetInterpolationBuffer(): number
	local ping = player:GetNetworkPing()
	return math.clamp(ping * Config.PING_MULTIPLIER, Config.MIN_BUFFER, Config.MAX_BUFFER)
end

Events.ServerReplicateCFrame.On(function(serverData)
	local cframes = serverData.cframes
	local snapshotTime = time() + serverTimeOffset

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

	local initialRenderTime = time() + serverTimeOffset - GetInterpolationBuffer()

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
	local globalServerTime = time() + serverTimeOffset
	local targetRenderTime = globalServerTime - GetInterpolationBuffer()

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

SynchronizeTime()

task.spawn(function()
	while true do
		task.wait(Config.TIME_SYNC_INTERVAL)
		SynchronizeTime()
	end
end)
