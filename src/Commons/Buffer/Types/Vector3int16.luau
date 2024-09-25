-- Madonox
-- 2024

-- Abstracts from Buffer (:Serialize is called as though it were the buffer)
local Vector3int16Type = {}

function Vector3int16Type:Serialize(value:Vector3int16)
    self:Write(2,"writei16",value.X)
	self:Write(2,"writei16",value.Y)
	self:Write(2,"writei16",value.Z)
end

function Vector3int16Type:Deserialize()
    return Vector3int16.new(
		self:Read(2,"readi16"),
		self:Read(2,"readi16"),
		self:Read(2,"readi16")
	)
end

return Vector3int16Type