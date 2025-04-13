--!nonstrict
--solely here for the structuring of this open source repository
--do not use this in an actual game, thats skidding - loaders like this are bad practice
local ServerScriptService = game:GetService("ServerScriptService")

for _, moduleScript in ServerScriptService.Services:GetDescendants() do
	if moduleScript:IsA("ModuleScript") then
		local yielded = true
		local success
		local message

		task.spawn(function()
			success, message = pcall(function()
				require(moduleScript)
			end)

			yielded = false
		end)

		if success == false then
			error(`{moduleScript:GetFullName()}: {message}`)
		end

		if yielded then
			warn("Yielded while requiring" .. moduleScript:GetFullName())
		end
	end
end

print("Server loaded.")
