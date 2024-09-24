-- Buffer / commons test:

local Commons = require(game:GetService("ReplicatedStorage"):WaitForChild("Commons"))

local Buffer = Commons.Buffer.Buffer

local myBuffer = Buffer.new({
    MakeBuffer =  true;
    Template = {"CFrame","CFrame"}
})

myBuffer:Serialize({CFrame.new(0,5,0),CFrame.identity})

print(myBuffer:Deserialize())

local Netty = Commons.Netty.Server