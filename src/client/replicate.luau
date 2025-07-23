local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.config)
local Snapshots = require(ReplicatedStorage.Shared.snapshots)
local Events = require(ReplicatedStorage.Events.client)
local InterpolationBuffer = require(script.Parent.interpolationBuffer)
local Networkables = require(ReplicatedStorage.Shared.makeNetworkable)
local RenderCache = require(script.Parent.renderCache)

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

Events.TickRateChanged.On(function(data)
	playerTickRates[data.id] = data.tickRate
end)

Events.ServerReplicateCFrame.On(function(serverData: { timestamps: { [number]: number }, cframes: { [number]: any } })
	local clientLastTicks = serverData.timestamps
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

	local cframes = serverData.cframes

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
end)

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
	Events.ClientReplicateCFrame.Fire({
		timestamp = os.clock(),
		cframe = networkable,
	})
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
