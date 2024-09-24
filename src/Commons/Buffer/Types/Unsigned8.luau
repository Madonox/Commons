-- Madonox
-- 2024

-- Abstracts from Buffer (:Serialize is called as though it were the buffer)
local Unsigned8 = {}

function Unsigned8:Serialize(value:number)
    self:Write(1,"writeu8",value)
end

function Unsigned8:Deserialize()
    return self:Read(1,"readu8")
end

return Unsigned8