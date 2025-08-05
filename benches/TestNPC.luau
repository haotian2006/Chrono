local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Chrono = require(ReplicatedStorage.Packages.chrono.server.replicate)

local Models = {}

local USE_CHRONO = false
local NUM_MODELS = 1000

local function createModel()
    local model = Instance.new("Model",workspace)
    model.Name = "TestNPC"
    model.PrimaryPart = Instance.new("Part", model)
    if USE_CHRONO then
        Chrono.RegisterNPC(model)
    end
    table.insert(Models, model)
end

for i = 1, NUM_MODELS do
    createModel()
end

local function
