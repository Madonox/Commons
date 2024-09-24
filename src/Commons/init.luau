-- Madonox
-- 2024

local Buffer = require(script:WaitForChild("Buffer"))
local Netty = require(script:WaitForChild("Netty"))

type Commons = {
    Netty: Netty.Netty;
    Buffer: Buffer.BufferModule;
}

local Commons:Commons = {
    Netty = Netty;
    Buffer = Buffer;
}

table.freeze(Commons)

return Commons