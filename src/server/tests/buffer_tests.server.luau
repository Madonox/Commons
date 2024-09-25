-- Buffer / commons test:

local Commons = require(game:GetService("ReplicatedStorage"):WaitForChild("Commons"))

local Buffer = Commons.Buffer.Buffer

local my_buffer = Buffer.new({
    MakeBuffer = true;
    Template = {"Vector3int16","Vector2"};
})

my_buffer:Serialize({Vector3int16.new(1,5,3), Vector2.new(-1,1)})

print(my_buffer:Deserialize())