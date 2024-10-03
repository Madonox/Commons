-- Basic Roblox test

local Remote = Instance.new("RemoteEvent")
Remote.Name = "MyRemote"
Remote.Parent = game:GetService("ReplicatedStorage")

task.spawn(function()
	while task.wait(1) do
		for i = 1,200 do
			Remote:FireAllClients(1)
		end
	end
end)