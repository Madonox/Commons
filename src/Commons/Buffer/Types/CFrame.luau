-- Madonox
-- 2024

-- Abstracts from Buffer (:Serialize is called as though it were the buffer)
local CFrameType = {}

function CFrameType:Serialize(value:CFrame)
    local x,y,z,r01,r02,r03,r11,r12,r13,r21,r22,r23 = value:GetComponents()
    self:Write(8,"writef64",x)
    self:Write(8,"writef64",y)
    self:Write(8,"writef64",z)
    self:Write(8,"writef64",r01)
    self:Write(8,"writef64",r02)
    self:Write(8,"writef64",r03)
    self:Write(8,"writef64",r11)
    self:Write(8,"writef64",r12)
    self:Write(8,"writef64",r13)
    self:Write(8,"writef64",r21)
    self:Write(8,"writef64",r22)
    self:Write(8,"writef64",r23)
end

function CFrameType:Deserialize()
    return CFrame.new(
        self:Read(8,"readf64"),
        self:Read(8,"readf64"),
        self:Read(8,"readf64"),
        self:Read(8,"readf64"),
        self:Read(8,"readf64"),
        self:Read(8,"readf64"),
        self:Read(8,"readf64"),
        self:Read(8,"readf64"),
        self:Read(8,"readf64"),
        self:Read(8,"readf64"),
        self:Read(8,"readf64"),
        self:Read(8,"readf64")
    )
end

return CFrameType