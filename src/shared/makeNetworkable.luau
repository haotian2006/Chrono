export type Networkable = {
	Diff: (newCFrame: CFrame, tolerance: number) -> CFrame,
	Apply: (deltaCFrame: CFrame) -> CFrame,
}

return function(initialCFrame: CFrame): Networkable
	local current = initialCFrame

	local function Diff(newCFrame: CFrame, tolerance: number): CFrame
		local deltaCFrame = current:ToObjectSpace(newCFrame)
		local px, py, pz, r00, r01, r02, r10, r11, r12, r20, r21, r22 = deltaCFrame:GetComponents()

		current = newCFrame

		return CFrame.fromMatrix(
			--further compression to zero things by tolerance in the future.
			vector.create(px, py, pz) :: any,
			vector.create(r00, r01, r02) :: any,
			vector.create(r10, r11, r12) :: any,
			vector.create(r20, r21, r22) :: any
		)
	end

	local function Apply(deltaCFrame: CFrame): CFrame
		current = current * deltaCFrame
		return current
	end

	return {
		Diff = Diff,
		Apply = Apply,
	}
end
