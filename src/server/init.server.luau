-- Buffer test:

local Buffer = require(game:GetService("ReplicatedStorage"):WaitForChild("Commons"):WaitForChild("Buffer"))

local b = Buffer.new({
    MakeBuffer = true;
    Template = {"CFrame","CFrame"};
})

b:Serialize({CFrame.new(0,5,0),CFrame.new(1,1,1)})

print(b:Deserialize())