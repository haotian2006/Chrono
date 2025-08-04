---
title: Interpolation Buffer
outline: deep
---

# Interpolation Buffer

An interpolation buffer is a time period for holding onto snapshots.  

When using unreliables and sending cframes rapidly, there is bound to be packet loss, or delayed packets.  

Interpolation delays gives you the time needed to reorder packets, receive packets and deal with packet loss.  

::: warning Roblox Default
Roblox has an interpolation delay **floor of 200ms**, but this is a heavy overkill when you are playing in low latency without packet loss.
:::

I will be showing how to create your own **"dynamic" interpolation buffer**.

---

## How It Works

To implement a dynamic interpolation buffer, you would need to **"predict"** when a packet gets dropped or received in an incorrect order.  

This may sound complicated at first, but it is actually very simple due to the fact that you can easily have an **"estimated arrival" prediction**.  

Estimated arrivals should be based on 2 things:

1. **Replication frequency**  
2. **Latency**

---

### Replication Frequency
Your replication frequency is the general tick rate you want to send your CFrames.  
::: tip Recommended Frequency
I recommend having a frequency of **20–40Hz** for the best results.
:::

---

### Latency

Your latency should be calculated as the **recent average** of the time differences (offsets) between when packets are sent and when they arrive.  
This gives you an **expectation** of how long packets usually take to reach you.


---

### Detecting Packet Drops

Using the average latency, you can detect if a packet has likely been dropped **if it doesn't arrive within the expected time window**.  


::: tip Delayed Packets
Suppose a packet does eventually arrive, but **in the next replication frame**, along with the packet that was originally scheduled for that frame.  

In that case, you can **assume that the late packet is the one you dropped**.  

You can confirm this by checking if **the gap between the delayed packet and the expected one is smaller than your average latency**.
:::

---

## Example Implementation

Below is an example of the implementation in **chrono**: 

```lua
local RenderCache = require(script.Parent.renderCache)

return function(minBuffer: number, maxBuffer: number, alpha: number)
	--average latency will be the average RTT between the client & server
	local playerLatencies = {} :: { [number]: { averageLatency: number, deviation: number, lastLatency: number? } }
	local fix = 0.2
	local recovery = 0.5

	local function RegisterPacket(networkId: number, serverTime: number, tickRate: number)
		local clientNow = RenderCache.GetEstimatedServerTime(networkId)
		local latency = clientNow - serverTime
		if latency > 1 then
			playerLatencies[networkId] = nil
			RenderCache.Remove(networkId)
			RenderCache.Add(networkId)

			warn(`{networkId} latency too high, cleared cache to repredict in case of error:! {latency}`)
		end
		if not playerLatencies[networkId] then
			--using the difference between current and last latency, i could smooth out the deviation (the variation in latency, which correlates to packet loss)
			--this is using statistics https://en.wikipedia.org/wiki/Moving_average
			playerLatencies[networkId] = { averageLatency = latency, deviation = 0, lastLatency = latency }
			return
		end

		local data = playerLatencies[networkId]
		if data.lastLatency then
			local delta = math.abs(latency - data.lastLatency)
			data.deviation = data.deviation * (1 - fix) + delta * fix
		end

		data.averageLatency = data.averageLatency * (1 - alpha) + latency * alpha
		data.lastLatency = latency
	end

	local function GetBuffer(networkId: number, tickRate: number)
		--calculate the interpolation buffer that accounts for expected latency, possible deviations and recovery from delays
		--the buffer will be per player
		local data = playerLatencies[networkId]
		if not data then
			return minBuffer
		end

		local recoveryMargin = tickRate * recovery
		local rawBuffer = data.averageLatency + data.deviation + recoveryMargin

		local buffer = if rawBuffer < minBuffer then minBuffer + (minBuffer - rawBuffer) * 0.2 else rawBuffer
		if buffer > maxBuffer then
			warn(`Interpolation buffer exceeded max! Was {buffer}, clamped to {maxBuffer}`)
			buffer = maxBuffer
		end

		return buffer
	end

	return {
		RegisterPacket = RegisterPacket,
		GetBuffer = GetBuffer,
		PlayerLatencies = playerLatencies,
	}
end
