local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

local Config = require(ReplicatedStorage.Shared.config)
local Snapshots = require(ReplicatedStorage.Shared.snapshots)
local Grid = require(ReplicatedStorage.Shared.grid)
local Events = require(ReplicatedStorage.Events.server)
--local Rig = require(ReplicatedStorage.Shared.rigs.createCharacter)

local Networkables = require(ReplicatedStorage.Shared.makeNetworkable)

local ClientReplicateCFrame = Instance.new("RemoteEvent")
ClientReplicateCFrame.Name = "ClientReplicateCFrame"
ClientReplicateCFrame.Parent = ReplicatedStorage

local ServerReplicateCFrame = Instance.new("RemoteEvent")
ServerReplicateCFrame.Name = "ServerReplicateCFrame"
ServerReplicateCFrame.Parent = ReplicatedStorage

local idStack = {} :: { number }
local playerIdMap = {} :: { [Player]: number }
local idMap = {} :: {
	[number]: {
		player: Player?,
		snapshot: Snapshots.CircularSnapshot<CFrame>,
		clientLastTick: number?,
		serverOwned: boolean?,
		npcType: string?,
	},
}

local lastReplicatedTimes = {} :: { [number]: number }
local playerTickRates = {} :: { [number]: number }
local replicators = {} :: { [number]: Model }

local MAX_ID = 255
local IncrementalFactoryUID = 0

local function UnpackSnapshotData(
	buff: buffer,
	offset: number
): { timestamp: number, cframe: { Position: Vector3, RotationY: number } }
	local value = {}
	value.timestamp = buffer.readf32(buff, offset + 0)

	local x = buffer.readf32(buff, offset + 4)
	local y = buffer.readf32(buff, offset + 8)
	local z = buffer.readf32(buff, offset + 12)
	value.cframe = {}
	value.cframe.Position = Vector3.new(x, y, z)

	local encoded = buffer.readu16(buff, offset + 16)
	local mantissaExponent = encoded % 0x8000

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

local function GetNextID(): number
	local reusedID = table.remove(idStack)
	if reusedID then
		return reusedID
	end

	if IncrementalFactoryUID + 1 == MAX_ID then
		error("Max ID reached, please investigate.")
	end
	IncrementalFactoryUID += 1

	return IncrementalFactoryUID
end

local function ReturnID(id: number)
	table.insert(idStack, id)
end

local function GetNPCConfig(npcType: string?): any
	npcType = npcType or "DEFAULT"
	return Config.NPC_TYPES[npcType] or Config.NPC_TYPES.DEFAULT
end

local function OnCharacterAdded(player: Player, character: Model, id: number)
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart

	if Config.DISABLE_DEFAULT_REPLICATION then
		if humanoidRootPart then
			humanoidRootPart.Anchored = true
		end
	end

	if Config.DISABLE_DEFAULT_REPLICATION then
		local clone: Model = StarterPlayer.StarterCharacter:Clone()
		clone.Parent = workspace.CurrentCamera

		replicators[id] = clone
	end

	Grid.AddEntity(character, "player")
	Events.InitializePlayer.FireAll({
		id = id,
		player = player.Name,
	})
end

local function OnCharacterRemoving(character: Model)
	Grid.RemoveEntity(character)
end

local function InitExistingPlayers(player: Player)
	local playerData = {}

	for existingPlayer, _ in playerIdMap do
		if existingPlayer == player then
			continue
		end

		table.insert(playerData, {
			id = playerIdMap[existingPlayer],
			player = existingPlayer.Name,
		})
	end

	if #playerData == 0 then
		warn("No existing players found to initialize for player", player)
		return
	end

	Events.InitializeExistingPlayers.Fire(player, playerData)
end

Players.PlayerAdded:Connect(function(player: Player)
	local id = GetNextID()
	playerIdMap[player] = id
	idMap[id] = {
		player = player,
		snapshot = Snapshots(CFrame.identity.Lerp),
		clientLastTick = nil,
		--clientLastTick:
		--players: last tick received from that client
		--NPCs: last tick generated on the server (acts as serverLastTick)

		serverOwned = false,
		npcType = nil,
	}
	lastReplicatedTimes[id] = 0

	InitExistingPlayers(player)

	player.CharacterAdded:Connect(function(character)
		OnCharacterAdded(player, character, id)
	end)
	player.CharacterRemoving:Connect(OnCharacterRemoving)
end)

Players.PlayerRemoving:Connect(function(player)
	local id = playerIdMap[player]
	if id then
		idMap[id] = nil
		lastReplicatedTimes[id] = nil
		playerIdMap[player] = nil

		ReturnID(id)
	end
end)

ClientReplicateCFrame.OnServerEvent:Connect(function(player: Player, snapshotBuffer: buffer, count: number)
	local id = playerIdMap[player]
	if not id then
		return
	end

	local data = idMap[id]
	if not data or not data.snapshot then
		return
	end

	local SNAPSHOT_SIZE = 18
	if buffer.len(snapshotBuffer) < count * SNAPSHOT_SIZE then
		warn("invalid format")
		return
	end

	local offset = 0

	for i = 1, count do
		local snapshot = UnpackSnapshotData(snapshotBuffer, offset)
		print(snapshot)
		offset += SNAPSHOT_SIZE

		local cframe = CFrame.new(snapshot.cframe.Position) * CFrame.Angles(0, snapshot.cframe.RotationY, 0)

		data.clientLastTick = snapshot.timestamp
		data.snapshot:Push(snapshot.timestamp, cframe)
	end
end)

local function UpdateTick(id: number, tickRate: number)
	Events.TickRateChanged.FireAll({
		id = id,
		tickRate = tickRate,
	})
end

local function GetTickInterval(character: Model?, id: number): number
	local data = idMap[id]
	if data and data.serverOwned then
		return GetNPCConfig(data.npcType).TICK_RATE
	end

	local baseTick = Config.TICK_RATE
	if not character then
		return baseTick
	end

	local nearbyPlayers = Grid.GetNearbyEntities(character, Config.PROXIMITY, { "player" })
	local newTickRate = if #nearbyPlayers > 1 then baseTick else baseTick * 2

	if newTickRate ~= playerTickRates[id] then
		playerTickRates[id] = newTickRate
		UpdateTick(id, newTickRate)
	end

	return newTickRate
end

RunService.PostSimulation:Connect(function(deltaTime)
	Grid.UpdateGrid()

	local cframes = {}
	local lastTicks = {}

	for id, data in idMap do
		local character = data.player and data.player.Character or nil
		local isNPC = data.serverOwned == true

		if
			not isNPC
			and (not character or not character:FindFirstChild("HumanoidRootPart") or not data.clientLastTick)
		then
			continue
		end

		local tickInterval = GetTickInterval(character, id)

		local now = os.clock()
		local lastReplicated = lastReplicatedTimes[id]

		if now - lastReplicated < tickInterval then
			continue
		end
		lastReplicatedTimes[id] = now

		local latestSnapshot = data.snapshot:GetLatest()
		if latestSnapshot then
			cframes[id] = latestSnapshot.value
		elseif character and character:FindFirstChild("HumanoidRootPart") then
			cframes[id] = ((character :: any).HumanoidRootPart :: any).CFrame
		end

		lastTicks[id] = data.clientLastTick or now --players: client tick, NPCs: server tick aka now
	end

	Events.ServerReplicateCFrame.FireAll({
		--using helper function that converts an entire table of CFrames to networkable form
		cframes = Networkables.NetworkableYawCFrameTable(cframes),
		timestamps = lastTicks,
	})

	if not Config.DISABLE_DEFAULT_REPLICATION then
		return
	end

	--Since we disabled roblox replication, we won't be able to easily do collision detections on the server
	--This module has each player be represented as a dummy parented to the camera (will not replicate)
	--and i simply bulkmoveto them to the latest character CFrame
	local staged = {}
	local targets = {}
	for id, clone in replicators do
		local data = idMap[id]
		local humanoidRootPart = clone:FindFirstChild("HumanoidRootPart") :: BasePart?
		if data and data.snapshot and humanoidRootPart then
			local latestSnapshot = data.snapshot:GetLatest()

			if latestSnapshot then
				table.insert(staged, humanoidRootPart)
				table.insert(targets, latestSnapshot.value)
			end
		end
	end

	if #staged > 0 then
		workspace:BulkMoveTo(staged, targets)
	end
end)

--Exposes a function for other scripts to get the most up to date CFrame of a player or npc
--for my personal usecase, I am using it to bypass the physics buffer for hitbox calculation

--Since npc visuals is decoupled from the logic, the npc is never moved on the server
--PushNPCTransform doesnt move the rig, it updates the snapshots and fires the clients to interpolate the rig
--if someone wants the rig to actually move, they can just cframe the rig themselves, but that will be double replicated
local function GetLatestCFrame(target: Player | number): CFrame?
	local id: number?

	if typeof(target) == "Instance" and target:IsA("Player") then
		id = playerIdMap[target]
	elseif typeof(target) == "number" then
		id = target
	else
		return nil
	end

	if not id then
		return nil
	end

	local data = idMap[id]
	if not data then
		return nil
	end

	local latestSnapshot = data.snapshot:GetLatest()
	if latestSnapshot then
		return latestSnapshot.value
	end

	return nil
end

local function RegisterNPC(model: Model?, npcType: string?): number
	local id = GetNextID()

	local npcConfig = GetNPCConfig(npcType)

	idMap[id] = {
		player = nil,
		snapshot = Snapshots(CFrame.identity.Lerp),
		clientLastTick = os.clock(),
		serverOwned = true,
		npcType = npcType or "DEFAULT",
	}
	lastReplicatedTimes[id] = 0

	playerTickRates[id] = npcConfig.TICK_RATE
	UpdateTick(id, playerTickRates[id])

	if model then
		model:SetAttribute("NPC_ID", id)
		Grid.AddEntity(model, "npc")
	end

	return id
end

local function PushNPCTransform(id: number, cframe: CFrame)
	local data = idMap[id]
	if data and data.serverOwned then
		local now = os.clock()
		data.snapshot:Push(now, cframe)
		data.clientLastTick = now
	end
end

return {
	GetLatestCFrame = GetLatestCFrame,
	RegisterNPC = RegisterNPC,
	PushNPCTransform = PushNPCTransform,
}
