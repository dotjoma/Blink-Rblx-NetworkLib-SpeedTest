-- Initialize Blink networking by requiring the server module
local Blink = require(game.ServerStorage.Server["server.blink"])

-- Set up event handlers
Blink.HelloEvent.On(function(player, message)
	print("From client:", player.Name, message)
	Blink.WelcomeBack.Fire(player, "Welcome back, " .. player.Name .. "!")
end)
