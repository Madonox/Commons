-- Madonox
-- 2024

local Buffer = require(script:WaitForChild("Buffer"))
local Netty = require(script:WaitForChild("Netty"))
local Thread = require(script:WaitForChild("Thread"))
local Observer = require(script:WaitForChild("Observer"))

type Commons = {
    Netty: Netty.Netty;
    Buffer: Buffer.BufferLibrary;
	Thread: Thread.Thread;
	Observer: Observer.Observer;
}

local Commons:Commons = {
    Netty = Netty;
    Buffer = Buffer;
	Pool = Thread;
	Observer = Observer;
}

table.freeze(Commons)

return Commons