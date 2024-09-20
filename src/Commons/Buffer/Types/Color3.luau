-- Madonox
-- 2024

-- Abstracts from Buffer (:Serialize is called as though it were the buffer)
local Color3Type = {}

function Color3Type:Serialize(value:Color3)
    self:Write(8,"writef64",value.R * 255)
    self:Write(8,"writef64", value.G * 255)
    self:Write(8,"writef64", value.B * 255)
end

function Color3Type:Deserialize()
    return Color3.fromRGB()(
        self:Read(8,"readf64"),
        self:Read(8,"readf64"),
        self:Read(8,"readf64")
    )
end

return Color3Type