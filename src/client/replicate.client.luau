local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.config)
local Snapshots = require(ReplicatedStorage.Shared.snapshots)
local Events = require(ReplicatedStorage.Events.client)
local InterpolationBuffer = require(script.Parent.interpolationBuffer)
local ClientRig = require(ReplicatedStorage.Shared.rigs.createCharacter)
local MakeNetworkable = require(ReplicatedStorage.Shared.makeNetworkable)

local idMap = {} :: {
	[number]: {
		snapshot: Snapshots.SnapshotInstance,
		character: Model,
		lastCFrame: CFrame?,
	},
}

local localPlayer = Players.LocalPlayer

local lerp = (math :: any).lerp
local playerRenderTimes = {} :: { [number]: number }
local initializedPlayers = {} :: { [Player]: boolean }
local characters = {} :: { [Player]: Model }

local bufferTracker = InterpolationBuffer(Config.TICK_RATE, Config.MIN_BUFFER, Config.MAX_BUFFER, 0.1)

local networkedCFrame = nil

local function playerAdded(player: Player, id: number)
	if initializedPlayers[player] then
		warn("Player already initialized", player)
		return
	end

	initializedPlayers[player] = true

	local registeredSnapshots = Snapshots.RegisterPlayer(player)

	local initialRenderTime = workspace:GetServerTimeNow() - bufferTracker.GetBuffer()

	--custom characters will be - server rig parented to camera (not physically simulated) and a client rig, that is physically simulated
	if Config.ENABLE_CUSTOM_CHARACTERS then
		characters[player] = ClientRig(player).Model
		
		if player == localPlayer then
			(workspace.CurrentCamera :: any).CameraSubject = characters[player]
		end
	end

	local initialCFrame = CFrame.new()
	if characters[player] and characters[player].PrimaryPart then
		initialCFrame = characters[player].PrimaryPart:GetPivot()
	end

	registeredSnapshots:PushAt(initialRenderTime, initialCFrame)

	idMap[id] = {
		snapshot = registeredSnapshots,
		character = characters[player],
		lastCFrame = initialCFrame,
	}
	playerRenderTimes[id] = initialRenderTime

	local character = characters[player]

	if not character then
		warn("idk man", player)
		return
	end
	
	local humanoid = character:WaitForChild("Humanoid")

	humanoid.Died:Connect(function()
		initializedPlayers[player] = nil
	end)
end

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

Events.InitializePlayer.On(function(data)
	local playerInstance = Players[data.player]

	if playerInstance then
		playerAdded(playerInstance, data.id)
	end
end)

Events.InitializeExistingPlayers.On(function(data)
	for _, playerData in data do
		local playerInstance = Players[playerData.player]

		if playerInstance then
			playerAdded(playerInstance, playerData.id)
		end
	end
end)

local lastSent = time()
local lastSentCFrame = CFrame.new()

RunService.RenderStepped:Connect(function(deltaTime: number)
	--GetServerTimeNow() is really nice, because it accounts for the RTT and can serve as the game world's timestamp.
	--The target render time is what we will be aiming for - by retrieving the dynamic interpolation buffer and subtracting it, we can pretty accurately reflect the actual state at the world timestamp.
	local globalServerTime = workspace:GetServerTimeNow()
	--GetBuffer returns the interpolation buffer, which is the length of the buffer + your latency. The latency is the remote latency, but the buffer time itself accounts for the varying latency, packet loss, delayed packets - and smooths it out.
	--snapshot timestamps are attached by the server, and the interpolation actually needs to start it from where the client receives it
	--tldr, GetBuffer will by minimum return GetServerTimeNow() - latency in a perfect world scenario
	--in a game with network variations, the formula becomes GetServerTimeNow() - (latency + deviationMargin + recoveryMargin)
	local targetRenderTime = globalServerTime - bufferTracker.GetBuffer()

	local renderTimeLerpFactor = math.clamp(deltaTime * Config.RENDER_LERP_FACTOR, 0, 1)

	for id, data in idMap do
		if not data.character or not data.character.PrimaryPart or data.character == characters[localPlayer] then
			continue
		end

		--get the entity snapshot at the new render time - a smoothly interpolated value between the current and target render time.
		--warning: having a too high lerp factor may increase the "interpolation buffer" - experiment with lower values / directly setting the render time.
		--snapshots library internalls holds historical data to interpolate smoothly and avoid jitter.
		--further logic is an implementation detail.
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

	if characters[localPlayer] and characters[localPlayer].PrimaryPart then
		local currentCFrame = characters[localPlayer].PrimaryPart:GetPivot()
		--if player did not move, don't network the change.
		local delta = networkedCFrame.Diff(currentCFrame, 0.1)

		if delta == CFrame.new() or vector.magnitude(delta.Position :: any) < 0.1 then
			return
		end

		lastSentCFrame = currentCFrame
		Events.ClientReplicateCFrame.Fire(currentCFrame)
	end
end)
