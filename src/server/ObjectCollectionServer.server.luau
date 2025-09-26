-- Real Object Collection Server with Distance Validation and ProfileService
local Blink = require(game.ServerStorage.Server["server.blink"])
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

-- Wait for other systems to initialize
repeat
	task.wait()
until _G.PlayerDataManager and _G.ObjectSpawner
local PlayerDataManager = _G.PlayerDataManager
local ObjectSpawner = _G.ObjectSpawner

print("🔗 ObjectCollectionServer connected to PlayerDataManager and ObjectSpawner")

-- Collection settings
local COLLECTION_DISTANCE = 8 -- studs
local COLLECTION_COOLDOWN = 0.5 -- seconds between collections per player
local RESPAWN_DELAY = 30 -- seconds before object respawns

-- Player cooldowns
local PlayerCooldowns = {}

-- Validate object collection with real distance checking
local function validateObjectCollection(player, objectId)
	local startTime = tick()

	-- Check if player has valid profile
	local playerData = PlayerDataManager.GetData(player)
	if not playerData then
		return false, "Player data not loaded", tick() - startTime
	end

	-- Check collection cooldown
	local lastCollection = PlayerCooldowns[player]
	if lastCollection and tick() - lastCollection < COLLECTION_COOLDOWN then
		return false, "Collection cooldown active", tick() - startTime
	end

	-- Get object from spawner
	local object = ObjectSpawner.GetObject(objectId)
	if not object then
		return false, "Object does not exist", tick() - startTime
	end

	if not object.exists then
		return false, "Object already collected", tick() - startTime
	end

	-- Get player's character and position
	local character = player.Character
	if not character then
		return false, "Character not found", tick() - startTime
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		return false, "HumanoidRootPart not found", tick() - startTime
	end

	-- Calculate distance between player and object
	local playerPosition = humanoidRootPart.Position
	local objectPosition = object.position
	local distance = (playerPosition - objectPosition).Magnitude

	-- Check if player is close enough
	if distance > COLLECTION_DISTANCE then
		return false,
			string.format("Too far away (%.1f studs, max %.1f)", distance, COLLECTION_DISTANCE),
			tick() - startTime
	end

	-- Check line of sight (optional - prevents collecting through walls)
	local raycast = workspace:Raycast(playerPosition, objectPosition - playerPosition)
	if raycast and raycast.Instance ~= object.part then
		-- There's something blocking the path, but we'll allow it for now
		-- In a real game, you might want to prevent this
	end

	return true, "Valid collection", tick() - startTime
end

-- Handle object collection requests
Blink.RequestCollectObject.On(function(player, data)
	local requestStartTime = tick()

	-- Parse the request
	local objectId = tonumber(data)
	if not objectId then
		Blink.ObjectCollected.Fire(
			player,
			HttpService:JSONEncode({
				success = false,
				objectId = 0,
				newBalance = 0,
				error = "Invalid object ID",
				processingTime = tick() - requestStartTime,
			})
		)
		return
	end

	-- Validate the collection
	local isValid, reason, validationTime = validateObjectCollection(player, objectId)

	if isValid then
		-- Get object data
		local object = ObjectSpawner.GetObject(objectId)
		local playerData = PlayerDataManager.GetData(player)

		-- Process the collection
		local newBalance = PlayerDataManager.AddBalance(player, object.value)
		PlayerDataManager.AddToInventory(player, {
			objectType = object.objectType.name,
			objectId = objectId,
			value = object.value,
			position = object.position,
		})

		-- Remove object from world
		ObjectSpawner.RemoveObject(objectId)

		-- Set cooldown
		PlayerCooldowns[player] = tick()

		-- Schedule respawn
		task.spawn(function()
			ObjectSpawner.RespawnObject(objectId, RESPAWN_DELAY)
		end)

		-- Send success response
		Blink.ObjectCollected.Fire(
			player,
			HttpService:JSONEncode({
				success = true,
				objectId = objectId,
				objectType = object.objectType.name,
				value = object.value,
				newBalance = newBalance,
				totalObjects = playerData.Stats.ObjectsCollected,
				processingTime = tick() - requestStartTime,
				validationTime = validationTime,
			})
		)

		print(
			string.format(
				"✅ %s collected %s (ID: %d, Value: %d) - Balance: %d (%.3fms)",
				player.Name,
				object.objectType.name,
				objectId,
				object.value,
				newBalance,
				(tick() - requestStartTime) * 1000
			)
		)
	else
		-- Get current balance for error response
		local playerData = PlayerDataManager.GetData(player)
		local currentBalance = playerData and playerData.Balance or 0

		-- Send failure response
		Blink.ObjectCollected.Fire(
			player,
			HttpService:JSONEncode({
				success = false,
				objectId = objectId,
				newBalance = currentBalance,
				error = reason,
				processingTime = tick() - requestStartTime,
				validationTime = validationTime,
			})
		)

		print(
			string.format(
				"❌ %s failed to collect object %d: %s (%.3fms)",
				player.Name,
				objectId,
				reason,
				(tick() - requestStartTime) * 1000
			)
		)
	end
end)

-- Clean up cooldowns when player leaves
Players.PlayerRemoving:Connect(function(player)
	PlayerCooldowns[player] = nil
end)

print("🎯 Real Object Collection Server initialized!")
print("   📏 Collection Distance:", COLLECTION_DISTANCE, "studs")
print("   ⏱️ Collection Cooldown:", COLLECTION_COOLDOWN, "seconds")
print("   🔄 Respawn Delay:", RESPAWN_DELAY, "seconds")
