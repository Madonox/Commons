-- Madonox
-- 2024

-- Abstracts from Buffer (:Serialize is called as though it were the buffer)
local Integer8 = {}

function Integer8:Serialize(value:number)
    self:Write(1,"writei8",value)
end

function Integer8:Deserialize()
    return self:Read(1,"readi8")
end

return Integer8