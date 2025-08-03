local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.config)
local Snapshots = require(ReplicatedStorage.Shared.snapshots)
local Events = require(ReplicatedStorage.Events.client)
local InterpolationBuffer = require(script.Parent.interpolationBuffer)
local Networkables = require(ReplicatedStorage.Shared.makeNetworkable)
local RenderCache = require(script.Parent.renderCache)

local MAX_UNRELIABLE_BYTES = 900
local SNAPSHOT_SIZE = 19
local HEADER_SIZE = 2
local MAX_BATCH = (MAX_UNRELIABLE_BYTES - HEADER_SIZE) // SNAPSHOT_SIZE

local outgoingSnapshots = {} :: { { timestamp: number, cframe: { Position: Vector3, RotationY: number } } }

local ClientReplicateCFrame: RemoteEvent = ReplicatedStorage:WaitForChild("ClientReplicateCFrame") :: any
local ServerReplicateCFrame: RemoteEvent = ReplicatedStorage:WaitForChild("ServerReplicateCFrame") :: any

local idMap = {} :: {
	[number]: {
		snapshot: Snapshots.CircularSnapshot<CFrame>,
		character: Model?,
		lastCFrame: CFrame?,
		isNPC: boolean?,
		npcType: string?,
	},
}

local player = Players.LocalPlayer
local initializedPlayers = {} :: { [Player]: boolean }
local characters = {} :: { [Player]: Model }
local playerTickRates = {} :: { [number]: number }

local bufferTracker = InterpolationBuffer(Config.MIN_BUFFER, Config.MAX_BUFFER, 0.1)
RenderCache.Init({
	playerTickRates = playerTickRates,
	bufferTracker = bufferTracker,
})

local playerNetworkId = 300

local function PackF16(float: number): number
	if float > 65504 then
		return 0b0_11111_0000000000
	end
	if float < -65504 then
		return 0b1_11111_0000000000
	end
	if float ~= float then
		return 0b1_11111_0000000001
	end
	if float == 0 then
		return 0
	end

	local absolute = math.abs(float)
	local interval = math.ldexp(1, math.floor(math.log(absolute, 2)) - 10)
	local rounded = (absolute // interval) * interval
	local fraction, exponent = math.frexp(rounded)
	exponent += 14

	local mantissa = math.round(
		if exponent <= 0 then fraction * 0x400 / math.ldexp(1, math.abs(exponent)) else fraction * 0x800
	) % 0x400

	local result = mantissa + math.max(exponent, 0) * 0x400 + if float < 0 then 0x8000 else 0

	return result
end

local function UnpackSnapshotData(
	buff: buffer,
	offset: number
): { timestamp: number, cframe: { Position: Vector3, RotationY: number }, id: number }
	local value = {}
	value.timestamp = buffer.readf32(buff, offset + 0)

	local x = buffer.readf32(buff, offset + 4)
	local y = buffer.readf32(buff, offset + 8)
	local z = buffer.readf32(buff, offset + 12)
	value.cframe = {}
	value.cframe.Position = Vector3.new(x, y, z)

	local encoded = buffer.readu16(buff, offset + 16)
	local id = buffer.readu8(buff, offset + 18)
	local mantissaExponent = encoded % 0x8000
	value.id = id

	if mantissaExponent == 0b0_11111_0000000000 then
		value.cframe.RotationY = if encoded // 0x8000 == 1 then -math.huge else math.huge
	elseif mantissaExponent == 0b1_11111_0000000000 then
		value.cframe.RotationY = 0 / 0
	elseif mantissaExponent == 0b0_00000_0000000000 then
		value.cframe.RotationY = 0
	else
		local mantissa = mantissaExponent % 0x400
		local exponent = mantissaExponent // 0x400
		local fraction

		if exponent == 0 then
			fraction = mantissa / 0x400
		else
			fraction = mantissa / 0x800 + 0.5
		end

		local result = math.ldexp(fraction, exponent - 14)
		value.cframe.RotationY = if encoded // 0x8000 == 1 then -result else result
	end

	return value
end

local function PackSnapshotData(
	buff: buffer,
	offset: number,
	timestamp: number,
	cframe: { Position: Vector3, RotationY: number }
)
	buffer.writef32(buff, offset + 0, timestamp)

	buffer.writef32(buff, offset + 4, cframe.Position.X)
	buffer.writef32(buff, offset + 8, cframe.Position.Y)
	buffer.writef32(buff, offset + 12, cframe.Position.Z)

	buffer.writeu16(buff, offset + 16, PackF16(cframe.RotationY))
end

local function Flush()
	local count = math.min(#outgoingSnapshots, MAX_BATCH)
	if count == 0 then
		return false
	end

	local offset = 0
	local snapshotBuffer = buffer.create(count * SNAPSHOT_SIZE)
	for i = 1, count do
		local snapshot = outgoingSnapshots[#outgoingSnapshots]
		outgoingSnapshots[#outgoingSnapshots] = nil
		PackSnapshotData(snapshotBuffer, offset, snapshot.timestamp, snapshot.cframe)
		offset += SNAPSHOT_SIZE
	end

	ClientReplicateCFrame:FireServer(snapshotBuffer)
	Flush()

	return true
end

local function RegisterClientNPC(id: number, model: Model, npcType: string?)
	if not idMap[id] then
		warn("Tried to register NPC that hasn't been replicated yet")
		return
	end
	idMap[id].character = model
	if npcType then
		idMap[id].npcType = npcType
	end
end

local function PlayerAdded(player: Player, id: number)
	if initializedPlayers[player] then
		warn("Player already initialized", player)
		return
	end

	if player == Players.LocalPlayer then
		playerNetworkId = id
	end

	initializedPlayers[player] = true

	local registeredSnapshots = Snapshots(CFrame.identity.Lerp)

	local initialRenderTime = os.clock()

	local character = player.Character or player.CharacterAdded:Wait()
	local humanoidRootPart = character:WaitForChild("HumanoidRootPart") :: BasePart
	humanoidRootPart.Anchored = false
	characters[player] = character

	local initialCFrame = CFrame.identity

	if characters[player] and characters[player].PrimaryPart then
		initialCFrame = (characters[player] :: any).PrimaryPart.CFrame
	end

	registeredSnapshots:Push(initialRenderTime, initialCFrame)

	idMap[id] = {
		snapshot = registeredSnapshots,
		character = characters[player],
		lastCFrame = initialCFrame,
	}

	RenderCache.Add(id)

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
--local lastSentCFrame = CFrame.identity

Events.TickRateChanged.On(function(data)
	playerTickRates[data.id] = data.tickRate
end)

local function HandleReplicatedData(clientLastTicks, cframes)
	for id, serverTime in clientLastTicks do
		if not idMap[id] then
			local npcType = "DEFAULT" --will be overrided once replicated & configed on the client
			idMap[id] = {
				snapshot = Snapshots(CFrame.identity.Lerp),
				character = nil,
				lastCFrame = nil,
				isNPC = true,
				npcType = npcType,
			}
			RenderCache.Add(id, true, npcType)
		end

		if not idMap[id].isNPC then
			bufferTracker.RegisterPacket(id, serverTime, playerTickRates[id] or Config.TICK_RATE)
		end
	end

	RenderCache.OnSnapshotUpdate(clientLastTicks)

	for id, cframe in cframes do
		local entry = idMap[id]
		if not entry then
			continue
		elseif entry.isNPC and entry.npcType and not RenderCache.GetTargetRenderTime(id) then
			RenderCache.Add(id, true, entry.npcType)
		end

		--since CFrames are received in the networkable format, I have to decode it to be actual CFrames. It is nicely done because of the roblox CFrame.new overload for quaternions.
		--same applies on the server as well of course.
		entry.snapshot:Push(clientLastTicks[id], Networkables.DecodeYawCFrame(cframe))
	end
end

ServerReplicateCFrame.OnClientEvent:Connect(function(snapshotBuffer)
	local offset = 0
	local cframes = {}
	local timestamps = {}
	for i = 1, buffer.len(snapshotBuffer) // SNAPSHOT_SIZE do
		local snapshot = UnpackSnapshotData(snapshotBuffer, offset)
		offset += SNAPSHOT_SIZE

		local id = snapshot.id
		cframes[id] = snapshot.cframe
		timestamps[id] = snapshot.timestamp
	end
	HandleReplicatedData(timestamps, cframes)
end)

Events.ServerReplicateCFrame.On(function(serverData: { timestamps: { [number]: number }, cframes: { [number]: any } })
	HandleReplicatedData(serverData.timestamps, serverData.cframes)
end)

RunService.PreRender:Connect(function(deltaTime: number)
	RenderCache.Update(deltaTime)

	for id, data in idMap do
		if not data.character or data.character == player.Character then
			continue
		end

		local humanoidRootPart = data.character:FindFirstChild("HumanoidRootPart")
		if not humanoidRootPart or not humanoidRootPart:IsA("BasePart") then
			continue
		end

		local targetRenderTime = RenderCache.GetTargetRenderTime(id)
		local targetCFrame = data.snapshot:GetAt(targetRenderTime)

		if targetCFrame then
			data.lastCFrame = targetCFrame

			-- make sure it isn't welded to anything else (e.g. being carried)

			if humanoidRootPart.AssemblyRootPart == humanoidRootPart then
				humanoidRootPart.CFrame = targetCFrame
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

	local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart or not humanoidRootPart:IsA("BasePart") then
		return
	end

	local currentCFrame = humanoidRootPart.CFrame
	--TODO: don't send cframe when player doesn't move
	--local changed = vector.magnitude(lastSentCFrame.Position - currentCFrame.Position :: any) >= 0.1
	--or not lastSentCFrame.Rotation:FuzzyEq(currentCFrame.Rotation :: any, 0.1)

	--lastSentCFrame = currentCFrame

	-- CFrames need to be made networkable. I am currently sending them as position: Vector3, rotation: {x, y, z} (omitting w because it can be calculated by x,y,z)
	-- this allows for much nicer compression since I am using quaternions
	-- currently sends CFrame even if player did not move due to nature of dynamic interpolation buffer (may change in the future when I think of a method)
	-- local networkable = if changed then Networkables.MakeNetworkable(currentCFrame) else nil :: any
	local networkable = Networkables.MakeYawNetworkable(currentCFrame)
	table.insert(outgoingSnapshots, {
		timestamp = os.clock(),
		cframe = networkable,
	})

	Flush()
end)

return {
	idMap = idMap,
	playerTickRates = playerTickRates,
	BufferTracker = bufferTracker,

	RegisterClientNPC = RegisterClientNPC,
	GetAllNetworkIds = function()
		local ids = {}
		for id, _ in idMap do
			table.insert(ids, id)
		end
		return ids
	end,
}
