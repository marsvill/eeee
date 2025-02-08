if LOADPX ~= true or HASHPX ~= "0092foz62c3ty5rtgfedwgh54324243243243234324324234234utrfunz2exvc32e3ur75ez9x6" then
	return print("Use an offical loadsting")
end

local AimVisualizer = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local visualObjects = {} -- Will store {marker, beam, attachment1, attachment2} for each player

-- Improved hit detection function
local function isAimingAtPlayer(fromPos, aimPos, ignoreChar)
    local toTarget = (aimPos - fromPos)
    local distance = toTarget.Magnitude
    
    if distance < 0.1 then return false end
    
    local direction = toTarget.Unit
    local ray = Ray.new(fromPos, direction * math.min(distance * 1.1, 1000))
    
    -- Create ignore list with all visual markers
    local ignoreList = {ignoreChar}
    for _, visuals in pairs(visualObjects) do
        table.insert(ignoreList, visuals.marker)
    end
    
    -- Do multiple raycasts with increasing size
    for _, raySize in ipairs({0.1, 0.5, 1}) do
        local hit, hitPos = workspace:FindPartOnRayWithIgnoreList(ray, ignoreList, false, true)
        
        if hit then
            -- Check if hit part belongs to a player
            local hitModel = hit:FindFirstAncestorOfClass("Model")
            if hitModel then
                local hitPlayer = Players:GetPlayerFromCharacter(hitModel)
                if hitPlayer and hitModel ~= ignoreChar then
                    -- Check if hit point is close enough to aim position
                    local hitDistance = (hitPos - aimPos).Magnitude
                    if hitDistance < 5 then  -- 5 studs tolerance
                        return true
                    end
                end
            end
        end
    end
    
    return false
end

local function updateVisualsColor(visuals, isAiming)
    local targetColor = isAiming and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
    visuals.marker.Color = targetColor
    visuals.beam.Color = ColorSequence.new(targetColor)
end

local function createVisuals(player)
    -- Create marker
    local marker = Instance.new("Part")
    marker.Size = Vector3.new(0.5, 0.5, 0.5)
    marker.Anchored = true
    marker.CanCollide = false
    marker.Material = Enum.Material.Neon
    marker.Color = Color3.fromRGB(255, 0, 0)
    marker.Transparency = 1
    
    -- Create attachments for beam
    local att1 = Instance.new("Attachment")
    local att2 = Instance.new("Attachment")
    att2.Parent = marker
    
    -- Create beam
    local beam = Instance.new("Beam")
    beam.Color = ColorSequence.new(marker.Color)
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
        att2 = att2
    }
end

function AimVisualizer:Start()
    -- Create visuals for existing players
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character and not visualObjects[player] then
            visualObjects[player] = createVisuals(player)
        end
    end

    -- Handle new/leaving players
    Players.PlayerAdded:Connect(function(player)
        visualObjects[player] = createVisuals(player)
    end)

    Players.PlayerRemoving:Connect(function(player)
        if visualObjects[player] then
            visualObjects[player].marker:Destroy()
            visualObjects[player].beam:Destroy()
            visualObjects[player] = nil
        end
    end)

    -- Use PreRender for fastest possible updates
    RunService.PreRender:Connect(function()
        for player, visuals in pairs(visualObjects) do
            local character = player.Character
            if not character then 
                visuals.marker.Transparency = 1
                visuals.beam.Enabled = false
                continue 
            end

            local backpack = player:FindFirstChild("Backpack")
            if not backpack then 
                visuals.marker.Transparency = 1
                visuals.beam.Enabled = false
                continue 
            end

            local rightHand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
            if not rightHand then 
                visuals.marker.Transparency = 1
                visuals.beam.Enabled = false
                continue 
            end

            -- Check equipped tool once
            local equippedTool = character:FindFirstChildOfClass("Tool")
            if not equippedTool then
                visuals.marker.Transparency = 1
                visuals.beam.Enabled = false
                continue
            end

            local aimPos = backpack:GetAttribute("AimPosition")
            if not aimPos or typeof(aimPos) ~= "Vector3" then
                visuals.marker.Transparency = 1
                visuals.beam.Enabled = false
                continue
            end

            -- Update position directly
            visuals.marker.Position = aimPos
            visuals.marker.Transparency = 0
            visuals.att1.Parent = rightHand
            visuals.beam.Enabled = true

            -- Check if aiming at player with improved detection
            local isAiming = isAimingAtPlayer(rightHand.Position, aimPos, character)
            updateVisualsColor(visuals, isAiming)
        end
    end)
end

function AimVisualizer:Stop()
    -- Disconnect all connections
    for _, connection in pairs(getconnections(RunService.PreRender)) do
        if connection.Function and debug.info(connection.Function, "s"):find("AimVisualizer") then
            connection:Disconnect()
        end
    end
    
    -- Clean up visuals
    for _, visuals in pairs(visualObjects) do
        visuals.marker:Destroy()
        visuals.beam:Destroy()
    end
    table.clear(visualObjects)
end

AimVisualizer:Start()
