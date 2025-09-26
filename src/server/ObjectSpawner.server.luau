-- Object Spawner - Creates collectible objects around the baseplate
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- Object types and their properties
local ObjectTypes = {
	{
		name = "Coin",
		model = "rbxasset://models/Coin.rbxm", -- We'll create a simple part instead
		value = { min = 10, max = 50 },
		color = Color3.fromRGB(255, 215, 0), -- Gold
		size = Vector3.new(2, 0.5, 2),
		shape = Enum.PartType.Cylinder,
	},
	{
		name = "Gem",
		model = "rbxasset://models/Gem.rbxm",
		value = { min = 50, max = 150 },
		color = Color3.fromRGB(138, 43, 226), -- Purple
		size = Vector3.new(1.5, 2, 1.5),
		shape = Enum.PartType.Block,
	},
	{
		name = "Crystal",
		model = "rbxasset://models/Crystal.rbxm",
		value = { min = 100, max = 300 },
		color = Color3.fromRGB(0, 191, 255), -- Blue
		size = Vector3.new(2, 3, 2),
		shape = Enum.PartType.Block,
	},
}

-- World objects storage
local WorldObjects = {}
local ObjectFolder = workspace:FindFirstChild("CollectibleObjects")
if not ObjectFolder then
	ObjectFolder = Instance.new("Folder")
	ObjectFolder.Name = "CollectibleObjects"
	ObjectFolder.Parent = workspace
end

-- Object spawner module
local ObjectSpawner = {}

-- Create a collectible object
local function CreateObject(objectType, position, objectId)
	-- Create main part
	local part = Instance.new("Part")
	part.Name = objectType.name .. "_" .. objectId
	part.Size = objectType.size
	part.Shape = objectType.shape
	part.Material = Enum.Material.Neon
	part.Color = objectType.color
	part.Anchored = true
	part.CanCollide = false
	part.Position = position

	-- Add glow effect
	local pointLight = Instance.new("PointLight")
	pointLight.Color = objectType.color
	pointLight.Brightness = 2
	pointLight.Range = 10
	pointLight.Parent = part

	-- Add floating animation
	local floatTween = TweenService:Create(
		part,
		TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = position + Vector3.new(0, 1, 0) }
	)
	floatTween:Play()

	-- Add spinning animation
	local spinTween = TweenService:Create(
		part,
		TweenInfo.new(3, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
		{ Rotation = Vector3.new(0, 360, 0) }
	)
	spinTween:Play()

	-- Add collection detection
	local clickDetector = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = 10
	clickDetector.Parent = part

	-- Add GUI label
	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Size = UDim2.new(0, 100, 0, 50)
	billboardGui.StudsOffset = Vector3.new(0, 3, 0)
	billboardGui.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = objectType.name
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = billboardGui

	part.Parent = ObjectFolder

	return part, floatTween, spinTween
end

-- Spawn objects around the baseplate
function ObjectSpawner.SpawnObjects(count)
	count = count or 50

	-- Clear existing objects
	ObjectFolder:ClearAllChildren()
	table.clear(WorldObjects)

	local baseplate = workspace:FindFirstChild("Baseplate")
	local spawnArea = {
		minX = -100,
		maxX = 100,
		minZ = -100,
		maxZ = 100,
		y = 5,
	}

	if baseplate then
		local size = baseplate.Size
		local pos = baseplate.Position
		spawnArea = {
			minX = pos.X - size.X / 2 + 10,
			maxX = pos.X + size.X / 2 - 10,
			minZ = pos.Z - size.Z / 2 + 10,
			maxZ = pos.Z + size.Z / 2 - 10,
			y = pos.Y + size.Y / 2 + 3,
		}
	end

	for i = 1, count do
		-- Random object type
		local objectType = ObjectTypes[math.random(1, #ObjectTypes)]

		-- Random position
		local position = Vector3.new(
			math.random(spawnArea.minX, spawnArea.maxX),
			spawnArea.y,
			math.random(spawnArea.minZ, spawnArea.maxZ)
		)

		-- Random value within range
		local value = math.random(objectType.value.min, objectType.value.max)

		-- Create the object
		local part, floatTween, spinTween = CreateObject(objectType, position, i)

		-- Store object data
		WorldObjects[i] = {
			id = i,
			part = part,
			position = position,
			objectType = objectType,
			value = value,
			exists = true,
			floatTween = floatTween,
			spinTween = spinTween,
			spawnTime = tick(),
		}

		-- Handle click detection (for testing - will be replaced by distance-based collection)
		part.ClickDetector.MouseClick:Connect(function(player)
			print(string.format("Player %s clicked %s (ID: %d)", player.Name, objectType.name, i))
		end)
	end

	print(string.format("🎯 Spawned %d collectible objects around the baseplate", count))
	return WorldObjects
end

-- Get object by ID
function ObjectSpawner.GetObject(objectId)
	return WorldObjects[objectId]
end

-- Remove object (when collected)
function ObjectSpawner.RemoveObject(objectId)
	local obj = WorldObjects[objectId]
	if obj and obj.exists then
		obj.exists = false

		-- Stop animations
		if obj.floatTween then
			obj.floatTween:Cancel()
		end
		if obj.spinTween then
			obj.spinTween:Cancel()
		end

		-- Create collection effect
		if obj.part then
			local collectTween =
				TweenService:Create(obj.part, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Size = Vector3.new(0.1, 0.1, 0.1),
					Transparency = 1,
					Position = obj.part.Position + Vector3.new(0, 5, 0),
				})
			collectTween:Play()

			collectTween.Completed:Connect(function()
				obj.part:Destroy()
			end)
		end

		return true
	end
	return false
end

-- Get all objects
function ObjectSpawner.GetAllObjects()
	return WorldObjects
end

-- Respawn object after delay
function ObjectSpawner.RespawnObject(objectId, delay)
	delay = delay or 30 -- 30 seconds default

	task.wait(delay)

	local oldObj = WorldObjects[objectId]
	if oldObj then
		-- Create new object at same position
		local objectType = oldObj.objectType
		local position = oldObj.position
		local value = math.random(objectType.value.min, objectType.value.max)

		local part, floatTween, spinTween = CreateObject(objectType, position, objectId)

		-- Update object data
		WorldObjects[objectId] = {
			id = objectId,
			part = part,
			position = position,
			objectType = objectType,
			value = value,
			exists = true,
			floatTween = floatTween,
			spinTween = spinTween,
			spawnTime = tick(),
		}

		print(string.format("🔄 Respawned %s (ID: %d)", objectType.name, objectId))
	end
end

-- Export the spawner
_G.ObjectSpawner = ObjectSpawner

-- Auto-spawn objects on startup
ObjectSpawner.SpawnObjects(50)

print("🎮 ObjectSpawner initialized - 50 objects spawned around baseplate")
