-- Madonox
-- 2024

local Buffer = require(script:WaitForChild("Buffer"))
local Netty = require(script:WaitForChild("Netty"))
local Pool = require(script:WaitForChild("Pool"))
local Observer = require(script:WaitForChild("Observer"))

type Commons = {
    Netty: Netty.Netty;
    Buffer: Buffer.BufferLibrary;
	Pool: Pool.Pool;
	Observer: Observer.Observer;
}

local Commons:Commons = {
    Netty = Netty;
    Buffer = Buffer;
	Pool = Pool;
	Observer = Observer;
}

table.freeze(Commons)

return Commons