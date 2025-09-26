-- Real Object Collection Client with Distance Detection
local Blink = require(game.ReplicatedStorage.Client["client.blink"])
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- UI Elements
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CollectionUI"
screenGui.Parent = player:WaitForChild("PlayerGui")

-- Stats display
local statsFrame = Instance.new("Frame")
statsFrame.Size = UDim2.new(0, 300, 0, 120)
statsFrame.Position = UDim2.new(0, 10, 0, 10)
statsFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
statsFrame.BackgroundTransparency = 0.3
statsFrame.BorderSizePixel = 0
statsFrame.Parent = screenGui

local statsTitle = Instance.new("TextLabel")
statsTitle.Size = UDim2.new(1, 0, 0, 30)
statsTitle.Position = UDim2.new(0, 0, 0, 0)
statsTitle.BackgroundTransparency = 1
statsTitle.Text = "📊 Collection Stats"
statsTitle.TextColor3 = Color3.new(1, 1, 1)
statsTitle.TextScaled = true
statsTitle.Font = Enum.Font.GothamBold
statsTitle.Parent = statsFrame

local balanceLabel = Instance.new("TextLabel")
balanceLabel.Size = UDim2.new(1, 0, 0, 30)
balanceLabel.Position = UDim2.new(0, 0, 0, 30)
balanceLabel.BackgroundTransparency = 1
balanceLabel.Text = "💰 Balance: 0"
balanceLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
balanceLabel.TextScaled = true
balanceLabel.Font = Enum.Font.Gotham
balanceLabel.Parent = statsFrame

local objectsLabel = Instance.new("TextLabel")
objectsLabel.Size = UDim2.new(1, 0, 0, 30)
objectsLabel.Position = UDim2.new(0, 0, 0, 60)
objectsLabel.BackgroundTransparency = 1
objectsLabel.Text = "🎯 Objects: 0"
objectsLabel.TextColor3 = Color3.fromRGB(138, 43, 226)
objectsLabel.TextScaled = true
objectsLabel.Font = Enum.Font.Gotham
objectsLabel.Parent = statsFrame

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, 0, 0, 30)
statusLabel.Position = UDim2.new(0, 0, 0, 90)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "🔍 Walk near objects to collect"
statusLabel.TextColor3 = Color3.new(0.8, 0.8, 0.8)
statusLabel.TextScaled = true
statusLabel.Font = Enum.Font.Gotham
statusLabel.Parent = statsFrame

-- Collection prompt
local promptFrame = Instance.new("Frame")
promptFrame.Size = UDim2.new(0, 200, 0, 60)
promptFrame.Position = UDim2.new(0.5, -100, 0.8, 0)
promptFrame.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
promptFrame.BackgroundTransparency = 0.2
promptFrame.BorderSizePixel = 0
promptFrame.Visible = false
promptFrame.Parent = screenGui

local promptLabel = Instance.new("TextLabel")
promptLabel.Size = UDim2.new(1, 0, 1, 0)
promptLabel.BackgroundTransparency = 1
promptLabel.Text = "Press E to collect"
promptLabel.TextColor3 = Color3.new(1, 1, 1)
promptLabel.TextScaled = true
promptLabel.Font = Enum.Font.GothamBold
promptLabel.Parent = promptFrame

-- Statistics tracking
local Stats = {
	balance = 0,
	totalObjects = 0,
	totalRequests = 0,
	successfulCollections = 0,
	failedCollections = 0,
	totalResponseTime = 0,
	minResponseTime = math.huge,
	maxResponseTime = 0,
}

-- Nearby objects detection
local nearbyObjects = {}
local currentTarget = nil
local DETECTION_DISTANCE = 8

-- Handle collection responses
Blink.ObjectCollected.On(function(data)
	local response = HttpService:JSONDecode(data)

	Stats.totalRequests = Stats.totalRequests + 1
	Stats.totalResponseTime = Stats.totalResponseTime + response.processingTime
	Stats.minResponseTime = math.min(Stats.minResponseTime, response.processingTime)
	Stats.maxResponseTime = math.max(Stats.maxResponseTime, response.processingTime)

	if response.success then
		Stats.successfulCollections = Stats.successfulCollections + 1
		Stats.balance = response.newBalance
		Stats.totalObjects = response.totalObjects or Stats.totalObjects + 1

		-- Update UI
		balanceLabel.Text = string.format("💰 Balance: %d", Stats.balance)
		objectsLabel.Text = string.format("🎯 Objects: %d", Stats.totalObjects)
		statusLabel.Text =
			string.format("✅ Collected %s! (+%d)", response.objectType or "Object", response.value or 0)

		-- Flash effect
		local flashTween = TweenService:Create(
			balanceLabel,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true),
			{ TextColor3 = Color3.new(1, 1, 1) }
		)
		flashTween:Play()

		print(
			string.format(
				"✅ Collected %s! Balance: %d (%.3fms)",
				response.objectType or "Object",
				response.newBalance,
				response.processingTime * 1000
			)
		)
	else
		Stats.failedCollections = Stats.failedCollections + 1
		statusLabel.Text = string.format("❌ %s", response.error)

		print(string.format("❌ Collection failed: %s (%.3fms)", response.error, response.processingTime * 1000))
	end

	-- Hide prompt after collection attempt
	promptFrame.Visible = false
	currentTarget = nil
end)

-- Function to collect object
local function collectObject(objectId)
	if objectId then
		Blink.RequestCollectObject.Fire(tostring(objectId))
		statusLabel.Text = "⏳ Collecting..."
	end
end

-- Detect nearby objects
local function updateNearbyObjects()
	if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
		return
	end

	local playerPosition = player.Character.HumanoidRootPart.Position
	local objectsFolder = workspace:FindFirstChild("CollectibleObjects")

	if not objectsFolder then
		return
	end

	-- Clear previous nearby objects
	table.clear(nearbyObjects)
	currentTarget = nil
	promptFrame.Visible = false

	-- Find closest collectible object
	local closestObject = nil
	local closestDistance = math.huge

	for _, obj in pairs(objectsFolder:GetChildren()) do
		if obj:IsA("Part") and obj.Position then
			local distance = (playerPosition - obj.Position).Magnitude

			if distance <= DETECTION_DISTANCE then
				-- Extract object ID from name
				local objectId = tonumber(obj.Name:match("_(%d+)$"))
				if objectId then
					nearbyObjects[objectId] = {
						part = obj,
						distance = distance,
					}

					if distance < closestDistance then
						closestDistance = distance
						closestObject = {
							id = objectId,
							part = obj,
							distance = distance,
						}
					end
				end
			end
		end
	end

	-- Update prompt for closest object
	if closestObject then
		currentTarget = closestObject.id
		promptFrame.Visible = true
		promptLabel.Text = string.format(
			"Press E to collect %s\n(%.1f studs away)",
			closestObject.part.Name:match("^(.-)_") or "Object",
			closestObject.distance
		)
	else
		promptFrame.Visible = false
		statusLabel.Text = "🔍 Walk near objects to collect"
	end
end

-- Input handling
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.E then
		if currentTarget then
			collectObject(currentTarget)
		end
	elseif input.KeyCode == Enum.KeyCode.R then
		-- Print stats
		print("📊 Collection Statistics:")
		print(string.format("   Balance: %d", Stats.balance))
		print(string.format("   Objects Collected: %d", Stats.totalObjects))
		print(
			string.format(
				"   Success Rate: %.1f%%",
				Stats.totalRequests > 0 and (Stats.successfulCollections / Stats.totalRequests) * 100 or 0
			)
		)
		if Stats.totalRequests > 0 then
			print(string.format("   Avg Response Time: %.3fms", (Stats.totalResponseTime / Stats.totalRequests) * 1000))
		end
	end
end)

-- Update nearby objects detection
RunService.Heartbeat:Connect(updateNearbyObjects)

print("🎮 Real Object Collection Client loaded!")
print("Controls:")
print("   E - Collect nearby object")
print("   R - Print statistics")
print("   Walk near glowing objects to see collection prompt")
