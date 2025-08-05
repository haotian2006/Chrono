local RunService = game:GetService("RunService")

local function LoadFolder(folder: Folder)
	for _, moduleScript in folder:GetDescendants() do
		if moduleScript:IsA("ModuleScript") then
			local yielded = true
			local success, message

			task.spawn(function()
				success, message = pcall(require, moduleScript)

				yielded = false
			end)

			if not success then
				error(`{moduleScript:GetFullName()}: {message}`)
			end

			if yielded then
				warn("Yielded while requiring" .. moduleScript:GetFullName())
			end
		end
	end
end

local Chrono = {}

function Chrono.Start()
	LoadFolder(if RunService:IsServer() then script.server else script.client)
end

return Chrono
