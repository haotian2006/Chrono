local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RequestServerTime = Instance.new("RemoteFunction")
RequestServerTime.Name = "RequestServerTime"
RequestServerTime.Parent = ReplicatedStorage

RequestServerTime.OnServerInvoke = function()
	return time()
end
