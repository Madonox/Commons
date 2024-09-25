-- Madonox
-- 2024

-- Abstracts from Buffer (:Serialize is called as though it were the buffer)
local UdimType = {}

function UdimType:Serialize(value:UDim)
    self:Write(8,"writef64",value.Scale)
	self:Write(8,"writef64",value.Offset)
end

function UdimType:Deserialize()
    return UDim.new(
		self:Read(8,"readf64"),
		self:Read(8,"readf64")
	)
end

return UdimType