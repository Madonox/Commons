-- Madonox
-- 2025

-- Abstracts from Buffer (:Serialize is called as though it were the buffer)
local CFrameType = {}

function CFrameType:Serialize(value: CFrame): ()
	local components: { number } = table.create(12)
	local x, y, z, r01, r02, r03, r11, r12, r13, r21, r22, r23 = value:GetComponents()

	components[1] = x
	components[2] = y
	components[3] = z
	components[4] = r01
	components[5] = r02
	components[6] = r03
	components[7] = r11
	components[8] = r12
	components[9] = r13
	components[10] = r21
	components[11] = r22
	components[12] = r23

	for _, component in ipairs(components) do
		self:Write(8, "writef64", component)
	end
end

function CFrameType:Deserialize(): CFrame
	local components: { number } = table.create(12)
	for i = 1, 12 do
		components[i] = self:Read(8, "readf64")
	end

	return CFrame.new(
		components[1], components[2], components[3],
		components[4], components[5], components[6],
		components[7], components[8], components[9],
		components[10], components[11], components[12]
	)
end

return CFrameType
