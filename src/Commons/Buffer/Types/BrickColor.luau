-- Madonox
-- 2024

-- Abstracts from Buffer (:Serialize is called as though it were the buffer)
local BrickColorType = {}

function BrickColorType:Serialize(value: BrickColor)
    self:Write(64,value.r * 255)
    self:Write(64, value.g * 255)
    self:Write(64, value.b * 255)
end

function BrickColorType:Deserialize()
    return BrickColor.new(
        self:Read(64,"readf64"),
        self:Read(64,"readf64"),
        self:Read(64,"readf64")
    )
end

return BrickColorType