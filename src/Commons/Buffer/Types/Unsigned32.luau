-- Madonox
-- 2024

-- Abstracts from Buffer (:Serialize is called as though it were the buffer)
local Unsigned32 = {}

function Unsigned32:Serialize(value:number)
    self:Write(4,"writeu32",value)
end

function Unsigned32:Deserialize()
    return self:Read(4,"readu32")
end

return Unsigned32