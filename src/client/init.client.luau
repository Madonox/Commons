local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Commons = require(ReplicatedStorage:WaitForChild("Commons"))
print(Commons)
local NettyClient = Commons.Netty.Client
print(NettyClient)
NettyClient.Start()

NettyClient.RegisterEvent({
    Name = "Test";
    Arguments = {
        {
            Id = "CFrame";
            Type = NettyClient.DataTypes.Data;
        };
        {
            Id = "My_Variable";
            Type = NettyClient.DataTypes.Instance;
        }
    }
},function(value_1:CFrame,My_Variable:string)
    
end)