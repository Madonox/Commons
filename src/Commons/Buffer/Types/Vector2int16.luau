-- Madonox
-- 2024

-- Abstracts from Buffer (:Serialize is called as though it were the buffer)
local Vector2int16Type = {}

function Vector2int16Type:Serialize(value:Vector2int16)
    self:Write(2,"writei16",value.X)
	self:Write(2,"writei16",value.Y)
end

function Vector2int16Type:Deserialize()
    return Vector2int16.new(
		self:Read(2,"readi16"),
		self:Read(8,"readi16")
	)
end

return Vector2int16Type