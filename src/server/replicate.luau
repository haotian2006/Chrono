local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.config)
local Snapshots = require(ReplicatedStorage.Shared.snapshots)
local Grid = require(ReplicatedStorage.Shared.grid)
local Events = require(ReplicatedStorage.Events.server)
local config = require(ReplicatedStorage.Shared.config)

local playerIdMap = {} :: { [Player]: number }
local idMap = {} :: { [number]: {
	player: Player,
	snapshot: Snapshots.SnapshotInstance,
} }
local lastReplicatedTimes = {} :: { [number]: number }

local MAX_ID = 255
local IncrementalFactoryUID = 0

local function GetNextID(): number
	if IncrementalFactoryUID + 1 == MAX_ID then
		error("Max ID reached, please investigate.")
	end
	IncrementalFactoryUID += 1

	return IncrementalFactoryUID
end

local function OnCharacterAdded(player: Player, character: Model, id: number)
	if config.ENABLE_CUSTOM_CHARACTERS then
		character.Parent = workspace.CurrentCamera
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

Players.PlayerAdded:Connect(function(player)
	local id = GetNextID()
	playerIdMap[player] = id
	idMap[id] = {
		player = player,
		snapshot = Snapshots.RegisterPlayer(player),
	}
	lastReplicatedTimes[id] = 0

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
	end
end)

Events.ClientReplicateCFrame.On(function(player, cframe)
	local id = playerIdMap[player]
	local data = idMap[id]
	if not data then
		return
	end

	data.snapshot:PushAt(workspace:GetServerTimeNow(), cframe)
end)

local function GetTickInterval(character: Model): number
	local baseTick = Config.TICK_RATE
	if not character then
		return baseTick
	end

	local nearbyPlayers = Grid.GetNearbyEntities(character, Config.PROXIMITY, { "player" })

	if #nearbyPlayers > 1 then
		return baseTick
	else
		return baseTick * 2
	end
end

RunService.Heartbeat:Connect(function(deltaTime)
	local currentTime = workspace:GetServerTimeNow()
	Grid.UpdateGrid()

	local cframes = {}

	for id, data in idMap do
		local character = data.player.Character
		if not character then
			continue
		end
		local tickInterval = GetTickInterval(character)
		if currentTime - lastReplicatedTimes[id] < tickInterval then
			continue
		end
		lastReplicatedTimes[id] = currentTime

		local latestSnapshot = data.snapshot:GetLatest()
		if latestSnapshot then
			cframes[id] = latestSnapshot.cFrame
		else
			cframes[id] = character:GetPivot()
		end
	end

	if next(cframes) then
		Events.ServerReplicateCFrame.FireAll({
			cframes = cframes,
			timeStamp = workspace:GetServerTimeNow(),
		})
	end
end)

return nil
