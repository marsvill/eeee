local AimVisualizer = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Cache commonly used values
local workspace = workspace
local huge = math.huge
local min = math.min

-- Precompute colors
local RED_COLOR = Color3.fromRGB(255, 0, 0)
local GREEN_COLOR = Color3.fromRGB(0, 255, 0)
local RED_BEAM = ColorSequence.new(RED_COLOR)
local GREEN_BEAM = ColorSequence.new(GREEN_COLOR)

local visualObjects = {} -- Will store {marker, beam, attachment1, attachment2} for each player
local cachedParts = {} -- Cache character parts and tools

-- Improved hit detection function with caching
local function isAimingAtPlayer(fromPos, aimPos, ignoreChar)
    local toTarget = (aimPos - fromPos)
    local distance = toTarget.Magnitude
    
    if distance < 0.1 then return false end
    
    local direction = toTarget.Unit
    local ray = Ray.new(fromPos, direction * min(distance * 1.1, 1000))
    
    -- Use cached ignore list
    local ignoreList = cachedParts[ignoreChar] or {ignoreChar}
    
    -- Single optimized raycast
    local hit, hitPos = workspace:FindPartOnRayWithIgnoreList(ray, ignoreList, false, true)
    
    if hit then
        local hitModel = hit:FindFirstAncestorOfClass("Model")
        if hitModel and hitModel ~= ignoreChar then
            local hitPlayer = Players:GetPlayerFromCharacter(hitModel)
            if hitPlayer and (hitPos - aimPos).Magnitude < 4 then
                return true
            end
        end
    end
    
    return false
end

local function updateVisualsColor(visuals, isAiming)
    if isAiming then
        visuals.marker.Color = GREEN_COLOR
        visuals.beam.Color = GREEN_BEAM
    else
        visuals.marker.Color = RED_COLOR
        visuals.beam.Color = RED_BEAM
    end
end

local function createVisuals(player)
    local marker = Instance.new("Part")
    marker.Size = Vector3.new(0.5, 0.5, 0.5)
    marker.Anchored = true
    marker.CanCollide = false
    marker.Material = Enum.Material.Neon
    marker.Color = RED_COLOR
    marker.Transparency = 1
    
    local att1 = Instance.new("Attachment")
    local att2 = Instance.new("Attachment")
    att2.Parent = marker
    
    local beam = Instance.new("Beam")
    beam.Color = RED_BEAM
    beam.Width0 = 0.2
    beam.Width1 = 0.2
    beam.FaceCamera = true
    beam.Attachment0 = att1
    beam.Attachment1 = att2
    beam.Enabled = false
    
    marker.Parent = workspace
    beam.Parent = workspace
    
    return {
        marker = marker,
        beam = beam,
        att1 = att1,
        att2 = att2,
        lastAimPos = Vector3.new(0, 0, 0),
        lastColor = false
    }
end

-- Cache character parts for a player
local function cacheCharacterParts(player, character)
    local parts = {character}
    for _, visual in pairs(visualObjects) do
        table.insert(parts, visual.marker)
    end
    cachedParts[character] = parts
end

function AimVisualizer:Start()
    -- Create visuals for existing players
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character and not visualObjects[player] then
            visualObjects[player] = createVisuals(player)
            cacheCharacterParts(player, player.Character)
        end
    end

    -- Handle new/leaving players
    Players.PlayerAdded:Connect(function(player)
        visualObjects[player] = createVisuals(player)
        if player.Character then
            cacheCharacterParts(player, player.Character)
        end
        player.CharacterAdded:Connect(function(char)
            cacheCharacterParts(player, char)
        end)
    end)

    Players.PlayerRemoving:Connect(function(player)
        if visualObjects[player] then
            visualObjects[player].marker:Destroy()
            visualObjects[player].beam:Destroy()
            visualObjects[player] = nil
        end
        cachedParts[player.Character] = nil
    end)

    -- Use Heartbeat for fastest updates
    RunService.Heartbeat:Connect(function()
        for player, visuals in pairs(visualObjects) do
            local character = player.Character
            if not character then 
                if visuals.beam.Enabled then
                    visuals.marker.Transparency = 1
                    visuals.beam.Enabled = false
                end
                continue 
            end

            local backpack = player:FindFirstChild("Backpack")
            if not backpack then 
                if visuals.beam.Enabled then
                    visuals.marker.Transparency = 1
                    visuals.beam.Enabled = false
                end
                continue 
            end

            local rightHand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
            if not rightHand then 
                if visuals.beam.Enabled then
                    visuals.marker.Transparency = 1
                    visuals.beam.Enabled = false
                end
                continue 
            end

            -- Check equipped tool with caching
            local equippedTool = character:FindFirstChildOfClass("Tool")
            if not equippedTool then
                if visuals.beam.Enabled then
                    visuals.marker.Transparency = 1
                    visuals.beam.Enabled = false
                end
                continue
            end

            local aimPos = backpack:GetAttribute("AimPosition")
            if not aimPos or typeof(aimPos) ~= "Vector3" then
                if visuals.beam.Enabled then
                    visuals.marker.Transparency = 1
                    visuals.beam.Enabled = false
                end
                continue
            end

            -- Only update if position changed significantly
            if (visuals.lastAimPos - aimPos).Magnitude > 0.01 then
                visuals.marker.Position = aimPos
                visuals.lastAimPos = aimPos
            end

            -- Update visibility if needed
            if visuals.marker.Transparency ~= 0 then
                visuals.marker.Transparency = 0
            end
            if visuals.att1.Parent ~= rightHand then
                visuals.att1.Parent = rightHand
            end
            if not visuals.beam.Enabled then
                visuals.beam.Enabled = true
            end

            -- Check if aiming at player with improved detection
            local isAiming = isAimingAtPlayer(rightHand.Position, aimPos, character)
            if isAiming ~= visuals.lastColor then
                updateVisualsColor(visuals, isAiming)
                visuals.lastColor = isAiming
            end
        end
    end)
end

function AimVisualizer:Stop()
    -- Disconnect all connections
    for _, connection in pairs(getconnections(RunService.Heartbeat)) do
        if connection.Function and debug.info(connection.Function, "s"):find("AimVisualizer") then
            connection:Disconnect()
        end
    end
    
    -- Clean up visuals and caches
    for _, visuals in pairs(visualObjects) do
        visuals.marker:Destroy()
        visuals.beam:Destroy()
    end
    table.clear(visualObjects)
    table.clear(cachedParts)
end

AimVisualizer:Start()
