local Hitmarker = {}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Variables
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local hitmarkers = {}

function Hitmarker.new(position, damage)
    local hitmarker = Drawing.new("Text")
    hitmarker.Text = tostring(math.floor(damage))
    hitmarker.Size = 24
    hitmarker.Center = true
    hitmarker.Outline = true
    hitmarker.OutlineColor = Color3.new(0, 0, 0)
    hitmarker.Color = Color3.new(1, 0, 0)
    hitmarker.Font = Drawing.Fonts.Monospace

    local worldPosition = position
    local startTime = tick()

    table.insert(hitmarkers, {
        marker = hitmarker,
        worldPos = worldPosition,
        created = startTime
    })
end

-- Update hitmarker positions
RunService.RenderStepped:Connect(function()
    for i = #hitmarkers, 1, -1 do
        local data = hitmarkers[i]
        local timePassed = tick() - data.created
        
        if timePassed > 1 then
            data.marker:Remove()
            table.remove(hitmarkers, i)
        else
            local screenPos, visible = Camera:WorldToViewportPoint(data.worldPos)
            if visible then
                data.marker.Position = Vector2.new(
                    screenPos.X,
                    screenPos.Y - 40 * timePassed -- Make it float up
                )
                data.marker.Transparency = 1 - timePassed -- Fade out
                data.marker.Visible = true
            else
                data.marker.Visible = false
            end
        end
    end
end)

return Hitmarker
