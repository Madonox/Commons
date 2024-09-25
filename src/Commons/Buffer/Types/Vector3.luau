-- Madonox
-- 2024

-- Abstracts from Buffer (:Serialize is called as though it were the buffer)
local Vector3Type = {}

function Vector3Type:Serialize(value:Vector3)
    self:Write(8,"writef64",value.X)
	self:Write(8,"writef64",value.Y)
	self:Write(8,"writef64",value.Z)
end

function Vector3Type:Deserialize()
    return Vector3.new(
		self:Read(8,"readf64"),
		self:Read(8,"readf64"),
		self:Read(8,"readf64")
	)
end

return Vector3Type