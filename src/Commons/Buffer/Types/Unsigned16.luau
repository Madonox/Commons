-- Madonox
-- 2024

-- Abstracts from Buffer (:Serialize is called as though it were the buffer)
local Unsigned16 = {}

function Unsigned16:Serialize(value:number)
    self:Write(2,"writeu16",value)
end

function Unsigned16:Deserialize()
    return self:Read(2,"readu16")
end

return Unsigned16