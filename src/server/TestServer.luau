local Net = require(script.Parent:WaitForChild("server.blink"))

-- This is required so Blink actually creates the RemoteEvents
Net.Start()

Net.HelloEvent.On(function(player, message)
	print("From client:", player.Name, message)
	Net.WelcomeBack.FireClient(player, "Welcome back, " .. player.Name .. "!")
end)
