export type Networkable = {
	Diff: (
		newCFrame: CFrame,
		tolerance: number
	) -> {
		Position: Vector3,
		Rotation: { x: number, y: number, z: number },
	},
	Apply: (deltaData: {
		Position: Vector3,
		Rotation: { x: number, y: number, z: number },
	}) -> CFrame,
}

return {
	MakeNetworkable = function(initialCFrame: CFrame): Networkable
		local current = initialCFrame

		local function Diff(newCFrame: CFrame, tolerance: number)
			local deltaCFrame = current:ToObjectSpace(newCFrame)

			local position = deltaCFrame.Position

			local axis, angle = deltaCFrame:ToAxisAngle()

			local halfAngle = angle * 0.5
			local sinHalf = math.sin(halfAngle)

			local x = axis.X * sinHalf
			local y = axis.Y * sinHalf
			local z = axis.Z * sinHalf

			current = newCFrame

			return {
				Position = position,
				Rotation = { x = x, y = y, z = z },
			}
		end

		local function Apply(deltaData: {
			Position: Vector3,
			Rotation: { x: number, y: number, z: number },
		}): CFrame
			local position = deltaData.Position
			local rotation = deltaData.Rotation

			local x, y, z = rotation.x, rotation.y, rotation.z
			local wSquared = 1 - x * x - y * y - z * z
			local w = if wSquared > 0 then math.sqrt(wSquared) else 0

			local deltaCFrame = CFrame.new(position.X, position.Y, position.Z, x, y, z, w)

			current = current * deltaCFrame

			return current
		end

		return {
			Diff = Diff,
			Apply = Apply,
		}
	end,
	NetworkableCFrameTable = function(cframes)
		local results = {}
		for index, cframe in cframes do
			local position = cframe.Position
			local axis, angle = cframe:ToAxisAngle()

			local halfAngle = angle * 0.5
			local sinHalf = math.sin(halfAngle)
			local x = axis.X * sinHalf
			local y = axis.Y * sinHalf
			local z = axis.Z * sinHalf

			results[index] = {
				Position = position,
				Rotation = { x = x, y = y, z = z },
			}
		end
		return results
	end,
	DecodeCFrame = function(data: { Position: Vector3, Rotation: { x: number, y: number, z: number } }): CFrame
		local position = data.Position
		local rotation = data.Rotation

		local x, y, z = rotation.x, rotation.y, rotation.z
		local wSquared = 1 - x * x - y * y - z * z
		local w = if wSquared > 0 then math.sqrt(wSquared) else 0

		return CFrame.new(position.X, position.Y, position.Z, x, y, z, w)
	end,
}
