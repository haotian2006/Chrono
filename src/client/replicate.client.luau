local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.config)
local Snapshots = require(ReplicatedStorage.Shared.snapshots)
local Events = require(ReplicatedStorage.Events.client)

local RequestServerTime = ReplicatedStorage:WaitForChild("RequestServerTime")

local idMap = {} :: { [number]: { snapshot: Snapshots.SnapshotInstance, character: Model } }
local player = Players.LocalPlayer

local serverTimeOffset = 0

local function SynchronizeTime()
	local clientSendTime = time()
	local serverTime = RequestServerTime:InvokeServer()
	local clientReceiveTime = time()

	local rtt = clientReceiveTime - clientSendTime
	serverTimeOffset = serverTime + (rtt / 2) - clientReceiveTime
end

local function GetInterpolationBuffer()
	local ping = player:GetNetworkPing()
	return math.clamp(ping * 1.0, Config.MIN_BUFFER, Config.MAX_BUFFER)
end

Events.ServerReplicateCFrame.On(function(serverData)
	local cframes = serverData.cframes
	local snapshotTime = time() + serverTimeOffset

	for id, cframe in cframes do
		local entry = idMap[id]
		if not entry then
			continue
		end
		entry.snapshot:PushAt(snapshotTime, cframe :: any)
	end
end)

Events.InitializePlayer.On(function(serverData)
	local id = serverData.id
	local player = Players[serverData.player]

	local registeredSnapshots = Snapshots.RegisterPlayer(player)
	idMap[id] = { snapshot = registeredSnapshots, character = player.Character }
end)

local lastSent = time()
local lastSentCFrame = CFrame.new()

RunService.Heartbeat:Connect(function(deltaTime: number)
	local dynamicBuffer = GetInterpolationBuffer()
	local targetTime = time() + serverTimeOffset - dynamicBuffer

	for id, data in idMap do
		local targetCFrame = data.snapshot:GetAt(targetTime)
		if not targetCFrame then
			continue
		end

		local character = data.character
		if not character or not character.PrimaryPart then
			continue
		end

		local currentCFrame = character:GetPivot()
		local interpolatedCFrame = currentCFrame:Lerp(targetCFrame, deltaTime * Config.INTERPOLATION_SPEED)

		character:PivotTo(interpolatedCFrame)
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
		task.wait(10)
		SynchronizeTime()
	end
end)
