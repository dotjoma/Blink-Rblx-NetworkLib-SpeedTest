local Net = require(game.ReplicatedStorage.Client["client.blink"])

-- Listen for server replies
Net.WelcomeBack.On(function(msg)
	print("Server says:", msg)
end)

-- Fire an event to the server
Net.HelloEvent.Fire("Hello from the client!")
