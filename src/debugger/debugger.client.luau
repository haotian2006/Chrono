local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Iris = require(ReplicatedStorage.Iris.Iris)
local Replication = require(script.Parent.Parent.Client.replicate)
local Config = require(ReplicatedStorage.Shared.config)

local GetAllNetworkIds = Replication.GetAllNetworkIds
local BufferTracker = Replication.BufferTracker

local playerTickRates = Replication.playerTickRates
local idMap = Replication.idMap

local searchText = Iris.State("") :: typeof(Iris.State(""))
local networkIds = GetAllNetworkIds()

Iris.Init()

Iris:Connect(function()
	if Iris.Window({ "Replication Debug" }) then
		if Iris.Button({ "🔄 Refresh" }).clicked then
			networkIds = GetAllNetworkIds()
		end

		Iris.InputText({ "Search ID" }, { text = searchText })
		Iris.Separator()

		for _, id in networkIds do
			if not tostring(id):find(searchText:get()) then
				continue
			end

			if Iris.Tree({ `Player ID: {id}` }).state.isUncollapsed.value then
				local tickRate = playerTickRates[id] or Config.TICK_RATE
				local bufferTime = BufferTracker.GetBuffer(id, tickRate)
				local latencyInfo = BufferTracker.PlayerLatencies[id]

				Iris.Separator()

				if latencyInfo then
					local latencyLabel = if latencyInfo.averageLatency > 0.2 then "🔴" else "🟢"
					local deviationLabel = if latencyInfo.deviation > 0.05 then "🔴" else "🟢"

					Iris.Text({ `{latencyLabel} Latency: {latencyInfo.averageLatency}` })
					Iris.Text({ `{deviationLabel} Deviation: {latencyInfo.deviation}` })
					Iris.Text({ `Buffer Time: {bufferTime}` })
					Iris.Text({ `Tick Rate: {tickRate}` })
				else
					Iris.Text({ "No latency/deviation data, please investigate!" })
				end

				Iris.Separator()

				local entry = idMap[id]
				local snapshots = entry and entry.snapshot.cache
				if snapshots and #snapshots > 0 then
					for i = 1, #snapshots do
						local snap = snapshots[i]
						if Iris.Tree({ `📝 Snapshot {i}` }).state.isUncollapsed.value then
							Iris.Text({ `Timestamp: {snap.timeStamp}` })
							Iris.Text({ `Position: {snap.CFrame.Position}` })
							Iris.End()
						else
							Iris.End()
						end
					end
				else
					Iris.Text({ "No snapshots available." })
				end
			end

			Iris.End()
		end

		Iris.End()
	end
end)
