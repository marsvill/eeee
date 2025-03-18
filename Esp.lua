if getgenv().Esp then return getgenv().Esp end

local Esp = {
    Objects = {},
    Enabled = false,
    Settings = {
        TeamCheck = false,
        Boxes = false,
        BoxesColor = Color3.fromRGB(255, 255, 255),
        HealthBar = false,
        Tracers = false,
        Font = Drawing.Fonts.UI,
        TracersColor = Color3.fromRGB(255, 255, 255),
        Names = false,
        NamesColor = Color3.fromRGB(255, 255, 255),
        TextSize = 11,
        TeamColor = false,
        TracerOrigin = "Bottom", -- "Bottom", "Mouse", "Top"
        TracerTransparency = 1,
        BoxesTransparency = 1,
        NamesTransparency = 1,
    },
}
getgenv().Esp = Esp
local Camera = workspace.CurrentCamera
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")

local Color3fromRGB = Color3.fromRGB

local function CreateDrawing(type, properties)
    local obj = Drawing.new(type)
    for prop, value in pairs(properties) do
        obj[prop] = value
    end
    return obj
end

local function roundVec2(vec2)
    return Vector2.new(math.round(vec2.X), math.round(vec2.Y))
end

function Esp:CreateObject(player)
    local objects = {
        Box = CreateDrawing("Square", {
            Thickness = 1,
            Filled = false,
            Transparency = 1,
            Color = self.Settings.BoxesColor,
            Visible = false
        }),
        BoxOutline = CreateDrawing("Square", {
            Thickness = 3,
            Filled = false,
            Transparency = self.Settings.BoxesTransparency,
            Color = Color3.new(0, 0, 0),
            Visible = false,
            ZIndex = 0
        }),
        Tracer = CreateDrawing("Line", {
            Thickness = 1,
            Transparency = self.Settings.TracerTransparency,
            Color = self.Settings.TracersColor,
            Visible = false,
            ZIndex = 1
        }),
        TracerOutline = CreateDrawing("Line", {
            Thickness = 3,
            Transparency = self.Settings.TracerTransparency,
            Color = Color3.new(0, 0, 0),
            Visible = false,
            ZIndex = 0
        }),
        Name = CreateDrawing("Text", {
            Text = player.Name,
            Center = true,
            Outline = true,
            Font = self.Settings.Font,
            Size = self.Settings.TextSize,
            Transparency = self.Settings.NamesTransparency,
            Color = self.Settings.NamesColor,
            Visible = false
            
        }),
        HealthBar = CreateDrawing("Line", {
            Color = Color3.new(0.5, 0.1, 0.1),
            Thickness = 1,
            Visible = false,
            ZIndex = 3
        }),
        HealthBarO = CreateDrawing("Line", {
            Color = Color3.new(0, 0, 0),
            Thickness = 3,
            Visible = false,
            ZIndex = 2
        }),
        HealthFill = CreateDrawing("Line", {
            Color = Color3.new(0, 1, 0),
            Thickness = 1,
            Visible = false,
            ZIndex = 4
        })
    }

    self.Objects[player] = objects
    return objects
end

function Esp:RemoveObject(player)
    local objects = self.Objects[player]
    if objects then
        for _, obj in pairs(objects) do
            obj:Remove()
        end
        self.Objects[player] = nil
    end
end

function Esp:UpdateObject(player)
    local objects = self.Objects[player]
    if not objects then
        objects = self:CreateObject(player)
    end
    
    -- Update transparencies
    objects.Box.Transparency = self.Settings.BoxesTransparency
    objects.BoxOutline.Transparency = self.Settings.BoxesTransparency
    objects.Tracer.Transparency = self.Settings.TracerTransparency
    objects.TracerOutline.Transparency = self.Settings.TracerTransparency
    objects.Name.Transparency = self.Settings.NamesTransparency

    -- Reset visibility
    for _, obj in pairs(objects) do
        obj.Visible = false
    end

    if not self.Enabled then return end

    local character = player.Character
    if not character then return end

    local humanoid = character:FindFirstChild("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    if not (humanoid and root) then return end

    -- Team check
    if self.Settings.TeamCheck and player.Team == LocalPlayer.Team then return end

    -- Whitelist/Enemy mode check
    if getgenv().WhitelistConfig.Enabled then
        if getgenv().WhitelistConfig.EnemyMode then
            if not getgenv().WhitelistConfig.Players[player] then return end
        else
            if getgenv().WhitelistConfig.Players[player] then return end
        end
    end

    local rootPos = root.Position
    local pos2d, onScreen = Camera:WorldToViewportPoint(rootPos)
    if not onScreen then return end

    local boxSize = Vector2.new(3500, 4500)
    local pos = Vector2.new(pos2d.X, pos2d.Y)
    local depth = pos2d.Z

    local fovOffset = Camera.FieldOfView / 70
    local resOffset = 1080 / Camera.ViewportSize.Y
    local depth = pos2d.Z * fovOffset * resOffset

    local size = roundVec2(boxSize / depth)

    
    local zindexOffset = 1e6 - depth 

    -- Update box
    local BoxesColor = self.Settings.BoxesColor
    local NamesColor = self.Settings.NamesColor
    local TracersColor = self.Settings.TracersColor
    
    if self.Settings.TeamColor then
        BoxesColor = player.TeamColor and player.TeamColor.Color or BoxesColor
        NamesColor = player.TeamColor and player.TeamColor.Color or NamesColor
        TracersColor = player.TeamColor and player.TeamColor.Color or TracersColor
    else
        BoxesColor = self.Settings.BoxesColor
        NamesColor = self.Settings.NamesColor
        TracersColor = self.Settings.TracersColor
        
    end

    -- Update box
    if self.Settings.Boxes then
        objects.Box.Size = size
        objects.Box.Position = pos - (size / 2)
        objects.Box.Visible = true
        objects.Box.Color = BoxesColor 
        objects.Box.ZIndex = zindexOffset - depth
        
        objects.BoxOutline.Size = size
        objects.BoxOutline.Position = objects.Box.Position
        objects.BoxOutline.Visible = true
        objects.BoxOutline.Color = Color3.new(0, 0, 0)  
    end

    if self.Settings.Names then
        local namePos = pos - Vector2.new(0, size.Y/2 + objects.Name.TextBounds.Y)
        objects.Name.Position = namePos
        objects.Name.Size = math.max(1000/depth, self.Settings.TextSize)
        objects.Name.Text = player.DisplayName or player.Name 
        objects.Name.Transparency = self.Settings.NamesTransparency
        objects.Name.Font = self.Settings.Font -- Update the font
        objects.Name.Visible = true
        objects.Name.Color = NamesColor
    end
    -- Update tracer
    if self.Settings.Tracers then
        local tracerStart
        if self.Settings.TracerOrigin == "Bottom" then
            tracerStart = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
        elseif self.Settings.TracerOrigin == "Mouse" then
            tracerStart = UserInputService:GetMouseLocation()
        elseif self.Settings.TracerOrigin == "Top" then
            tracerStart = Vector2.new(Camera.ViewportSize.X / 2, 0)
        end

        objects.Tracer.From = tracerStart
        objects.Tracer.To = Vector2.new(pos2d.X, pos2d.Y)
        objects.Tracer.Visible = true
        objects.Tracer.Color = TracersColor

        objects.TracerOutline.From = tracerStart
        objects.TracerOutline.To = Vector2.new(pos2d.X, pos2d.Y)
        
        objects.TracerOutline.Visible = true
    end
    if self.Settings.HealthBar then
        local healthPercent = humanoid.Health / humanoid.MaxHealth
        local barPos = pos + Vector2.new(-(size.X / 2 + 4), size.Y / 2)

        objects.HealthBar.From = barPos
        objects.HealthBar.To = barPos - Vector2.new(0, size.Y)
        objects.HealthBar.Visible = true

        objects.HealthBarO.From = objects.HealthBar.From
        objects.HealthBarO.To = objects.HealthBar.To
        objects.HealthBarO.Visible = true

        objects.HealthFill.From = barPos
        objects.HealthFill.To = barPos - Vector2.new(0, size.Y * healthPercent)
        objects.HealthFill.Visible = true
    end
end

function Esp:Toggle(enabled)
    self.Settings.Enabled = enabled
    if not enabled then
        for _, objects in pairs(self.Objects) do
            for _, obj in pairs(objects) do
                obj.Visible = false
            end
        end
    end
end

-- Setup player connections
Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then
        Esp:CreateObject(player)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    Esp:RemoveObject(player)
end)

-- Initialize existing players
for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        Esp:CreateObject(player)
    end
end

-- Update loop
game:GetService("RunService").RenderStepped:Connect(function()
    for player, _ in pairs(Esp.Objects) do
        Esp:UpdateObject(player)
    end
end)
return Esp
