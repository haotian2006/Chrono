return function(tickRate: number, minBuffer: number, maxBuffer: number, alpha: number)
	local averageLatency = 0
	local deviation = 0
	local lastLatency = nil

	local fix = 0.1
	local recovery = 0.5

	local function RegisterPacket(serverTime: number)
		local clientNow = workspace:GetServerTimeNow()
		local latency = clientNow - serverTime

		if lastLatency then
			local delta = math.abs(latency - lastLatency)
			deviation = deviation * (1 - fix) + delta * fix
		end

		averageLatency = averageLatency * (1 - alpha) + latency * alpha
		lastLatency = latency
	end

	local function GetBuffer()
		local deviationMargin = deviation * 2
		local recoveryMargin = tickRate * recovery
		local buffer = averageLatency + deviationMargin + recoveryMargin
		return math.clamp(buffer, minBuffer, maxBuffer)
	end

	return {
		RegisterPacket = RegisterPacket,
		GetBuffer = GetBuffer,
	}
end
