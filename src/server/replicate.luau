local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.config)
local Snapshots = require(ReplicatedStorage.Shared.snapshots)
local Grid = require(ReplicatedStorage.Shared.grid)
local Events = require(ReplicatedStorage.Events.server)

local playerIdMap = {} :: { [Player]: number }
local idMap = {} :: { [number]: {
	player: Player,
	snapshot: Snapshots.SnapshotInstance,
} }
local lastReplicatedTimes = {} :: { [number]: number }

local MAX_ID = 255
local IncrementalFactoryUID = 0

local function GetNextID(): number
	--for reference, we are using u8s for now.
	if IncrementalFactoryUID + 1 == MAX_ID then
		error("Max ID reached, please investigate.")
	end
	IncrementalFactoryUID += 1

	return IncrementalFactoryUID
end

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

local function OnCharacterAdded(player: Player, character: Model, id: number)
	if Config.ENABLE_CUSTOM_CHARACTERS then
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart
		humanoidRootPart.Anchored = true
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

local function initExistingPlayers(player: Player)
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

local function PlayerAdded(player: Player)
	local id = GetNextID()
	playerIdMap[player] = id
	
	idMap[id] = {
		player = player,
		snapshot = Snapshots.RegisterPlayer(player),
	}
	lastReplicatedTimes[id] = 0

	initExistingPlayers(player)

	player.CharacterAdded:Connect(function(character)
		OnCharacterAdded(player, character, id)
	end)
	
	player.CharacterRemoving:Connect(OnCharacterRemoving)
end

local function PlayerRemoving(player: Player)
	local id = playerIdMap[player]

	if id then
		idMap[id] = nil
		lastReplicatedTimes[id] = nil
		playerIdMap[player] = nil
	end
end

Events.ClientReplicateCFrame.On(function(player, cframe)
	local id = playerIdMap[player]
	local data = idMap[id]
	if not data then
		return
	end

	data.snapshot:PushAt(workspace:GetServerTimeNow(), cframe)
end)

RunService.Heartbeat:Connect(function()
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

Players.PlayerAdded:Connect(PlayerAdded)
Players.PlayerRemoving:Connect(PlayerRemoving)

return nil
