local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.config)
local Snapshots = require(ReplicatedStorage.Shared.snapshots)
local Events = require(ReplicatedStorage.Events.client)
local InterpolationBuffer = require(script.Parent.interpolationBuffer)
local ClientRig = require(ReplicatedStorage.Shared.rigs.createCharacter)
local Networkables = require(ReplicatedStorage.Shared.makeNetworkable)

local idMap = {} :: {
	[number]: {
		snapshot: Snapshots.SnapshotInstance,
		character: Model,
		lastCFrame: CFrame?,
	},
}

local player = Players.LocalPlayer
local initializedPlayers = {} :: { [Player]: boolean }
local characters = {} :: { [Player]: Model }
local playerTickRates = {} :: { [number]: number }

local bufferTracker = InterpolationBuffer(Config.MIN_BUFFER, Config.MAX_BUFFER, 0.1)

local networkedCFrame = nil
local playerNetworkId = 300

Events.TickRateChanged.On(function(data)
	playerTickRates[data.id] = data.tickRate
end)

Events.ServerReplicateCFrame.On(function(serverData)
	local clientLastTicks = serverData.timeStamps
	for id, serverTime in clientLastTicks do
		bufferTracker.RegisterPacket(id, serverTime)
	end

	local CFrames = serverData.CFrames
	local snapshotTime = os.clock()

	for id, CFrame in CFrames do
		local entry = idMap[id]
		if not entry then
			continue
		end

		--since CFrames are received in the networkable format, I have to decode it to be actual CFrames. It is nicely done because of the roblox CFrame.new overload for quaternions.
		--same applies on the server as well of course.
		entry.snapshot:PushAt(snapshotTime, Networkables.DecodeCFrame(CFrame))
	end
end)

local function PlayerAdded(player: Player, id: number)
	if initializedPlayers[player] then
		warn("Player already initialized", player)
		return
	end

	if player == Players.LocalPlayer then
		playerNetworkId = id
	end

	initializedPlayers[player] = true

	local registeredSnapshots = Snapshots.RegisterPlayer(player)

	local initialRenderTime = os.clock() - bufferTracker.GetBuffer(id, playerTickRates[id] or Config.TICK_RATE)

	--custom characters will be - server rig parented to camera (not physically simulated) and a client rig, that is physically simulated
	--if not, we just unanchor on the client (since it might be anchored on the server)
	if Config.ENABLE_CUSTOM_CHARACTERS then
		characters[player] = ClientRig(player).Model

		if player == Players.LocalPlayer then
			player.Character = characters[player];
			(workspace.CurrentCamera :: any).CameraSubject = characters[player]
		end
	else
		local character = player.Character or player.CharacterAdded:Wait()
		local humanoidRootPart = character:WaitForChild("HumanoidRootPart") :: BasePart
		humanoidRootPart.Anchored = false
		characters[player] = character
	end

	local initialCFrame = CFrame.new(0, 4, 0)

	if characters[player] and characters[player].PrimaryPart then
		initialCFrame = (characters[player] :: any).PrimaryPart.CFrame
	end

	registeredSnapshots:PushAt(initialRenderTime, initialCFrame)

	idMap[id] = {
		snapshot = registeredSnapshots,
		character = characters[player],
		lastCFrame = initialCFrame,
	}
	networkedCFrame = Networkables.MakeNetworkable(initialCFrame)

	local character = characters[player]

	if not character then
		return
	end

	local humanoid = character:WaitForChild("Humanoid") :: Humanoid

	humanoid.Died:Connect(function()
		initializedPlayers[player] = nil
	end)
end

Events.InitializePlayer.On(function(data)
	local playerInstance = Players[data.player]

	if playerInstance then
		PlayerAdded(playerInstance, data.id)
	end
end)

Events.InitializeExistingPlayers.On(function(data)
	for _, playerData in data do
		local playerInstance = Players[playerData.player]

		if playerInstance then
			PlayerAdded(playerInstance, playerData.id)
		end
	end
end)

local lastSent = os.clock()
local lastSentCFrame = CFrame.new()

RunService.PreRender:Connect(function(deltaTime: number)
	--The target render time is what we will be aiming for - by retrieving the dynamic interpolation buffer and subtracting it, we can pretty accurately reflect the actual state at the world timestamp.
	local globalServerTime = os.clock()

	for id, data in idMap do
		if not data.character or data.character == player.Character then
			continue
		end

		local HRP = data.character:FindFirstChild("HumanoidRootPart")
		if not HRP or not HRP:IsA("BasePart") then
			continue
		end

		--GetBuffer returns the interpolation buffer, which is the length of the buffer + your latency. The latency is the remote latency, but the buffer time itself accounts for the varying latency, packet loss, delayed packets - and smooths it out.
		--snapshot timestamps are attached by the server, and the interpolation actually needs to start it from where the client receives it
		--tldr, GetBuffer will by minimum return time - latency in a perfect world scenario
		--in a game with network variations, the formula becomes time - (latency + deviationMargin + recoveryMargin)

		local targetRenderTime = globalServerTime - bufferTracker.GetBuffer(id, playerTickRates[id] or Config.TICK_RATE)

		local targetCFrame = data.snapshot:GetAt(targetRenderTime)
		if targetCFrame then
			data.lastCFrame = targetCFrame

			-- make sure it isn't welded to anything else (e.g. being carried)
			if HRP.AssemblyRootPart == HRP then
				HRP.CFrame = data.lastCFrame :: CFrame
			end
		end
	end
end)

RunService.PostSimulation:Connect(function()
	if os.clock() - lastSent < (playerTickRates[playerNetworkId] or Config.TICK_RATE) then
		return
	end
	lastSent = os.clock()

	if not player.Character then
		return
	end

	local HRP = player.Character:FindFirstChild("HumanoidRootPart")
	if not HRP or not HRP:IsA("BasePart") then
		return
	end

	local currentCFrame = HRP.CFrame
	-- local changed = vector.magnitude(lastSentCFrame.Position - currentCFrame.Position :: any) >= 0.1
	-- 	or not lastSentCFrame.Rotation:FuzzyEq(currentCFrame.Rotation :: any, 0.1)

	lastSentCFrame = currentCFrame

	-- CFrames need to be made networkable. I am currently sending them as position: Vector3, rotation: {x, y, z} (omitting w because it can be calculated by x,y,z)
	-- this allows for much nicer compression since I am using quaternions
	-- currently sends CFrame even if player did not move due to nature of dynamic interpolation buffer (may change in the future when I think of a method)
	local networkable = Networkables.MakeNetworkable(currentCFrame)
	Events.ClientReplicateCFrame.Fire({
		timeStamp = os.clock(),
		CFrame = networkable,
	})
end)
