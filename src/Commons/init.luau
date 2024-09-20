-- Madonox
-- 2024

export type CommonModuleOptions = {
    Name: any;
}

local Netty = require(script:WaitForChild("Netty"))
local Buffer = require(script:WaitForChild("Buffer"))

type Commons = {
    Netty: Netty.Netty;
    Buffer: Buffer.BufferModule;
}

local Commons:Commons = {
    Netty = Netty;
    Buffer = Buffer;
}

-- Assign proxies

local function AssignProxy(module)
    module.Proxy = Commons
    local proxyEvent = module.proxyEvent
    if proxyEvent then
        proxyEvent()
    end
end

table.freeze(Commons)
AssignProxy(Netty)
AssignProxy(Buffer)

return Commons