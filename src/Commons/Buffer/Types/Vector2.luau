-- Madonox
-- 2024

-- Abstracts from Buffer (:Serialize is called as though it were the buffer)
local Vector2Type = {}

function Vector2Type:Serialize(value:Vector2)
    self:Write(8,"writef64",value.X)
	self:Write(8,"writef64",value.Y)
end

function Vector2Type:Deserialize()
    return Vector2.new(
		self:Read(8,"readf64"),
		self:Read(8,"readf64")
	)
end

return Vector2Type