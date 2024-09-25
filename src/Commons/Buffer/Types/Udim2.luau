-- Madonox
-- 2024

-- Abstracts from Buffer (:Serialize is called as though it were the buffer)
local Udim2Type = {}

function Udim2Type:Serialize(value:UDim2)
	local x,y = value.X,value.Y
    self:Write(8,"writef64",x.Scale)
	self:Write(8,"writef64",x.Offset)
	self:Write(8,"writef64",y.Scale)
	self:Write(8,"writef64",y.Offset)
end

function Udim2Type:Deserialize()
    return UDim2.new(
		self:Read(8,"readf64"),
		self:Read(8,"readf64"),
		self:Read(8,"readf64"),
		self:Read(8,"readf64")
	)
end

return Udim2Type