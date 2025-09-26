-- Player Data Manager using ProfileService
local ProfileService = require(game.ServerStorage.ServerPackages.ProfileService)
local Players = game:GetService("Players")

-- Data template for new players
local ProfileTemplate = {
	Balance = 0,
	Inventory = {},
	Stats = {
		ObjectsCollected = 0,
		TotalValue = 0,
		LastPlayed = os.time(),
	},
	Settings = {
		AutoSave = true,
	},
}

-- Function to sanitize data for DataStore compatibility
local function sanitizeData(data)
	if type(data) == "table" then
		local sanitized = {}
		for key, value in pairs(data) do
			-- Ensure keys are strings or numbers
			local sanitizedKey = tostring(key)

			-- Recursively sanitize values
			if type(value) == "table" then
				sanitized[sanitizedKey] = sanitizeData(value)
			elseif type(value) == "string" then
				-- Ensure string is valid UTF-8 and remove any problematic characters
				sanitized[sanitizedKey] = string.gsub(value, "[%z\1-\31\127-\255]", "")
			elseif type(value) == "number" then
				-- Ensure number is finite
				if value ~= value then -- NaN check
					sanitized[sanitizedKey] = 0
				elseif value == math.huge or value == -math.huge then
					sanitized[sanitizedKey] = 0
				else
					sanitized[sanitizedKey] = value
				end
			elseif type(value) == "boolean" then
				sanitized[sanitizedKey] = value
			else
				-- Convert other types to string safely
				sanitized[sanitizedKey] = tostring(value)
			end
		end
		return sanitized
	else
		return data
	end
end

-- ProfileService setup
local ProfileStore = ProfileService.GetProfileStore(
	"PlayerData", -- Store name
	ProfileTemplate
)

-- Active profiles storage
local Profiles = {}

-- Player data manager module
local PlayerDataManager = {}

-- Get player's profile data
function PlayerDataManager.GetProfile(player)
	return Profiles[player]
end

-- Get player's data (shortcut)
function PlayerDataManager.GetData(player)
	local profile = Profiles[player]
	return profile and profile.Data
end

-- Add balance to player
function PlayerDataManager.AddBalance(player, amount)
	local profile = Profiles[player]
	if profile then
		profile.Data.Balance = profile.Data.Balance + amount
		profile.Data.Stats.TotalValue = profile.Data.Stats.TotalValue + amount
		return profile.Data.Balance
	end
	return 0
end

-- Add item to inventory
function PlayerDataManager.AddToInventory(player, item)
	local profile = Profiles[player]
	if profile then
		-- Sanitize the item data for DataStore compatibility
		local sanitizedItem = {
			objectType = tostring(item.objectType or "Unknown"),
			objectId = tonumber(item.objectId) or 0,
			value = tonumber(item.value) or 0,
			-- Convert Vector3 position to a simple table
			position = item.position
					and {
						x = math.floor(item.position.X * 100) / 100, -- Round to 2 decimal places
						y = math.floor(item.position.Y * 100) / 100,
						z = math.floor(item.position.Z * 100) / 100,
					}
				or { x = 0, y = 0, z = 0 },
			timestamp = os.time(),
		}

		table.insert(profile.Data.Inventory, sanitizedItem)
		profile.Data.Stats.ObjectsCollected = profile.Data.Stats.ObjectsCollected + 1
		return true
	end
	return false
end

-- Update last played time
function PlayerDataManager.UpdateLastPlayed(player)
	local profile = Profiles[player]
	if profile then
		profile.Data.Stats.LastPlayed = os.time()
		-- Sanitize data before saving
		profile.Data = sanitizeData(profile.Data)
	end
end

-- Force sanitize all active profiles (call this if you encounter data issues)
function PlayerDataManager.SanitizeAllProfiles()
	for player, profile in pairs(Profiles) do
		if profile then
			profile.Data = sanitizeData(profile.Data)
			print(string.format("🧹 Sanitized data for %s", player.Name))
		end
	end
end

-- Player joined - load their profile
local function PlayerAdded(player)
	local profile = ProfileStore:LoadProfileAsync("Player_" .. player.UserId)

	if profile ~= nil then
		profile:AddUserId(player.UserId) -- GDPR compliance
		profile:Reconcile() -- Fill in missing template values

		-- Sanitize existing data to prevent DataStore errors
		profile.Data = sanitizeData(profile.Data)

		profile:ListenToRelease(function()
			Profiles[player] = nil
			-- Kick player if profile is released while they're still in game
			player:Kick("Data session ended - please rejoin")
		end)

		if player.Parent == Players then
			Profiles[player] = profile
			print(
				string.format(
					"✅ Loaded profile for %s (Balance: %d, Objects: %d)",
					player.Name,
					profile.Data.Balance,
					profile.Data.Stats.ObjectsCollected
				)
			)

			-- Update last played
			PlayerDataManager.UpdateLastPlayed(player)
		else
			-- Player left before profile loaded
			profile:Release()
		end
	else
		-- Profile couldn't be loaded - kick player
		player:Kick("Unable to load your data - please try again later")
	end
end

-- Player left - save and release their profile
local function PlayerRemoving(player)
	local profile = Profiles[player]
	if profile ~= nil then
		PlayerDataManager.UpdateLastPlayed(player)
		profile:Release()
		print(string.format("💾 Saved and released profile for %s", player.Name))
	end
end

-- Connect events
Players.PlayerAdded:Connect(PlayerAdded)
Players.PlayerRemoving:Connect(PlayerRemoving)

-- Handle players already in game (for testing)
for _, player in pairs(Players:GetPlayers()) do
	task.spawn(PlayerAdded, player)
end

-- Export the manager
_G.PlayerDataManager = PlayerDataManager
print("📊 PlayerDataManager initialized with ProfileService")
