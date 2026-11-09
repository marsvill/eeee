-- https://www.roblox.com/games/71315343/
-- Auto Zenkai Boost, Auto Farm Every Stat, Auto Reconnect, Auto Re-exec, Anti-AFK, Safe Farm, Auto Transform, Dragon Ball Finder

local Flags = Flags or {
    Type = 'Auto', -- Auto, Agility, Attack, Defense, Ki 
    ZenkaiBoost = true,
    SafeFarm = true,
    OptimalWorld = true,
    Transform = true,
    DragonBallFinder = false,
}

if not game:IsLoaded() then game.Loaded:Wait() task.wait(1) end

local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local TeleportService = game:GetService('TeleportService')
local GuiService = game:GetService('GuiService')
local Client = Players.LocalPlayer or Players.PlayerAdded:Wait()
local PlayerGui = Client:WaitForChild('PlayerGui')
local Network = require(ReplicatedStorage:WaitForChild('Modules'):WaitForChild('Library'):WaitForChild('Network'))
local StatUtils = require(ReplicatedStorage:WaitForChild('Modules'):WaitForChild('Shared'):WaitForChild('StatUtils'))
local Constants = require(ReplicatedStorage:WaitForChild('Constants'))

-- Captured ByteNet payloads, indexed by the place they were supplied for.
local KiBlastPayloads = {
    [71315343] = buffer.fromstring(string.char(14, 114, 105, 142, 68, 244, 34, 244, 67, 224, 171, 11, 197, 0, 3, 0, 0, 0, 162, 202, 141, 68, 21, 112, 244, 67, 79, 233, 11, 197, 49, 30, 49, 55, 197, 86, 50, 191, 220, 244, 226, 54)),
    [1357512648] = buffer.fromstring(string.char(13, 91, 72, 162, 68, 0, 212, 45, 192, 224, 108, 203, 196, 0, 3, 0, 0, 0, 157, 150, 139, 68, 24, 147, 196, 62, 174, 79, 224, 196, 218, 15, 73, 192, 246, 145, 80, 191, 218, 15, 73, 192)),
    [1362482151] = buffer.fromstring(string.char(14, 62, 151, 174, 68, 106, 1, 173, 66, 49, 148, 211, 193, 0, 1, 0, 0, 0, 193, 142, 170, 68, 34, 115, 179, 66, 62, 25, 37, 194, 182, 15, 73, 64, 243, 95, 2, 180, 219, 15, 73, 192)),
    [3336119605] = buffer.fromstring(string.char(9, 65, 192, 142, 69, 90, 127, 243, 69, 135, 112, 6, 198, 0, 1, 0, 0, 0, 0, 0, 192, 191, 0, 65, 28, 70, 0, 0, 0, 192, 0, 0, 0, 128, 0, 0, 0, 0, 0, 0, 0, 128)),
}
local KiBlastPayload = KiBlastPayloads[game.PlaceId]
local KiBlastWarningShown = false

local HiddenFlags, Connections = {
    WorldData = {
        ['Time Chamber'] = {
            PlaceId = 1362482151,
            Agility = 2,
            Attack = 2,
            Defense = 2,
            Ki = 2,
        },
        ['Gravity Chamber'] = {
            PlaceId = 3371469539,
            Agility = 6,
            Attack = 3,
            Defense = 0.5,
            Ki = 0.5,
        },
        ['Hell'] = {
            PlaceId = 15669378828,
            Agility = 0.5,
            Attack = 0.5,
            Defense = 4,
            Ki = 1.5,
        },
        ['Beerus Planet'] = {
            PlaceId = 3336119605,
            Agility = 0.5,
            Attack = 0.5,
            Defense = 3,
            Ki = 3,
        },
        ['Earth'] = {
            PlaceId = 71315343,
            Agility = 1,
            Attack = 1,
            Defense = 1,
            Ki = 1,
        }
    }
}, {}

shared.afy = not shared.afy
print('[afy]', shared.afy)

local GetRoot; do
    GetRoot = function(Character) return Character and Character:FindFirstChild('HumanoidRootPart') end

    GetEnergyPercent = function()
        local Character = Client.Character
        local State = Character and Character:FindFirstChild('State')
        
        if State then
            local Energy = State:FindFirstChild('Energy')
            local MaxEnergy = State:FindFirstChild('MaxEnergy')

            if Energy and MaxEnergy then
                return (Energy.Value / MaxEnergy.Value) * 100
            end
        end
    end

    GetStatInfo = function()
        local Stats = Client:FindFirstChild('Stats')

        if Stats then
            return Stats.Agility, Stats.Attack, Stats.Defense, Stats.Ki
        end
    end

    GetTransformInfo = function()
        local Character = Client.Character
        if not Character then return end

        local Stats = Client:FindFirstChild('Stats')
        local State = Character:FindFirstChild('State')

        if Stats and State then
            return Stats.SelectedMode.Value, State.ActiveMode.Value
        end
    end

    Transform = function()
        local EquippedMode, EnabledMode = GetTransformInfo()

        if EquippedMode and EquippedMode ~= '' and (not EnabledMode or EnabledMode == '') then
            Network:InvokeServer("Transform", "Quick")
            return true
        end
    end

    GetBestTraining = function()
        local Required = StatUtils:GetRequiredZenkaiStats(GetZenkai() + 1)
        
        for Index, Stat in { GetStatInfo() } do
            if Stat.Value < (Required or StatUtils.MaxStats) then return Stat.Name end
        end
    end

    GetZenkai = function()
        local Stats = Client:FindFirstChild('Stats')

        if Stats then
            return Stats.ZenkaiBoost.Value
        end
    end

    Charge = function(Bool)
        if Bool then
            Network:InvokeServer("ChargeEnergy", true)
        else
            Network:FireServer("ChargeEnergy", false)
        end
    end

    GetOptimalWorld = function(TrainingStat)
        local Zenkai = GetZenkai() or 0
        local Agility, Attack, Defense, Ki = GetStatInfo()
        local TimeChamberThreshold = 1_250_000
        local CanTimeChamber = Agility.Value >= TimeChamberThreshold and Attack.Value >= TimeChamberThreshold and Defense.Value >= TimeChamberThreshold and Ki.Value >= TimeChamberThreshold
        local Candidates = {}

        if CanTimeChamber then
            table.insert(Candidates, {
                Name = "Time Chamber",
                Multi = HiddenFlags.WorldData["Time Chamber"][TrainingStat] or 1
            })
        end

        if Zenkai >= 6 then
            table.insert(Candidates, {
                Name = "Gravity Chamber",
                Multi = HiddenFlags.WorldData["Gravity Chamber"][TrainingStat] or 1
            })
        end

        if Zenkai >= 3 then
            table.insert(Candidates, {
                Name = "Hell",
                Multi = HiddenFlags.WorldData["Hell"][TrainingStat] or 1
            })
        end

        if Zenkai >= 5 then
            table.insert(Candidates, {
                Name = "Beerus Planet",
                Multi = HiddenFlags.WorldData["Beerus Planet"][TrainingStat] or 1
            })
        end

        table.insert(Candidates, { Name = "Earth", Multi = 1 })

        local BestWorld = Candidates[1]
        for Index, World in ipairs(Candidates) do
            if World.Multi > BestWorld.Multi then
                BestWorld = World
            end
        end

        return BestWorld.Name
    end

    GetDragonBallData = function()
        local Stats = Client:FindFirstChild('Stats')
        local DragonBalls = Stats and Stats:FindFirstChild('DragonBalls')
        if not DragonBalls then return end

        local DragonBallsString = DragonBalls.Value
        local DragonBalls, IsFull = {}, true

        for Index, BallData in DragonBallsString:split(';') do
            local Ball = BallData:split('=')
            local BallNumber = Ball and tonumber(Ball[1])
            if not BallNumber then continue end
            DragonBalls[BallNumber] = true
        end

        for Number = 1, 7 do
            if not DragonBalls[Number] then
                IsFull = false
            end
        end

        return DragonBalls, IsFull
    end

    GetDragonBall = function(DragonBalls)
        for Index, Model in workspace.Map:GetChildren() do
            local SpawnPos = Model:GetAttribute('SpawnPos')
            local BallNumber = Model:GetAttribute('BallNum')

            if SpawnPos and BallNumber then
                if DragonBalls[BallNumber] then continue end

                return Model
            end
        end
    end

    DragonBallFinder = function()
        local EarthId = HiddenFlags.WorldData.Earth.PlaceId
        if game.PlaceId ~= EarthId then TeleportService:Teleport(EarthId) task.wait(5) end

        local Character = Client.Character
        local Root = GetRoot(Character)
        if not Root then return end

        local DragonBalls, IsFull, BallFound = GetDragonBallData()
        if IsFull then return end

        local DragonBall = GetDragonBall(DragonBalls)

        if DragonBall then
            HiddenFlags.DataStoreDelay = true
            BallFound = true
            Root.CFrame = DragonBall:GetPivot() + vector.create(0, -5, 0)

            if not HiddenFlags.ProximityPrompt then
                HiddenFlags.ProximityPrompt = true

                task.delay(0.5, function()
                    local Prox = DragonBall:FindFirstChild('ProximityPrompt', true)

                    if Prox then
                        fireproximityprompt(Prox)
                    end

                    task.wait(0.5)
                    HiddenFlags.ProximityPrompt = false
                end)
            end
        end

        if not BallFound then
            if HiddenFlags.DataStoreDelay then task.wait(1) end
            loadstring(game:HttpGet('https://raw.githubusercontent.com/Cesare0328/my-scripts/refs/heads/main/CachedServerhop.lua'))()
        end
    end
end

for Index, Connection in getconnections(Client.Idled) do
    Connection:Disconnect()
end

table.insert(Connections, Client.OnTeleport:Connect(function()
    local SerializedFlags = 'getgenv().Flags = {'
    for Setting, Value in Flags do
        local IsString = typeof(Value) == 'string'
        SerializedFlags..=(`%s={IsString and `'%s'` or `%s`},`):format(tostring(Setting), tostring(Value))
    end
    SerializedFlags..='}\n'

    queue_on_teleport(SerializedFlags..[[
        if afy then return end getgenv().afy = true
        loadstring(game:HttpGet('https://raw.githubusercontent.com/marsvill/eeee/refs/heads/main/db.lua'))()
    ]])
end))

table.insert(Connections, TeleportService.TeleportInitFailed:Connect(function()
    task.wait(5)
    TeleportService:Teleport(game.PlaceId)
end))

table.insert(Connections, GuiService.ErrorMessageChanged:Connect(function()
    task.wait(2)
    TeleportService:Teleport(game.PlaceId)
end))

while shared.afy and task.wait() do
    local Character = Client.Character
    local Root = GetRoot(Character)
    if not Root then continue end

    if not HiddenFlags.OriginalCFrame then HiddenFlags.OriginalCFrame = Root.CFrame end

    if Flags.SafeFarm then
        Root.CFrame = CFrame.new(0, 10000, 0)
    end

    local DragonBalls, IsDragonBallFull = GetDragonBallData()

    if Flags.DragonBallFinder then
        if not IsDragonBallFull then
            DragonBallFinder()
            continue
        end
    end

    if Flags.Transform then
        if Transform() then continue end
    end

    local BestTraining = GetBestTraining()

    if Flags.ZenkaiBoost and not BestTraining then
        local Zenkai = GetZenkai()
        
        if Zenkai < Constants.Training.MaxZenkai then
            if Zenkai < Constants.Training.DragonBallZenkaiLimit then
                local CanZenkaiBoost = StatUtils:CanPlayerZenkai(Client)

                if CanZenkaiBoost then
                    Network:InvokeServer("RequestZenkaiBoost")
                end
            elseif IsDragonBallFull then
                local EarthId = HiddenFlags.WorldData.Earth.PlaceId
                
                if game.PlaceId == EarthId then
                    local CenterPedestial = workspace.Map.Pedestal.Center
                    local Tick = tick()

                    while Root and tick() - Tick < 0.5 and task.wait() do 
                        Root.CFrame = CenterPedestial.CFrame + vector.create(0, -5, 0)
                    end

                    fireproximityprompt(CenterPedestial.Attachment.ProximityPrompt)
                    Network:FireServer('SelectWish', 'ZenkaiBoost')
                else
                    TeleportService:Teleport(EarthId) 
                    task.wait(5) 
                end
            end

            task.wait(2)
            continue
        end
    end

    local BestTraining = Flags.Type == 'Auto' and BestTraining or Flags.Type
    local EnergyPercent = GetEnergyPercent()
    local OptimalWorld = GetOptimalWorld(BestTraining)
    local World = HiddenFlags.WorldData[OptimalWorld]
    local WorldId = World and World.PlaceId

    if Flags.OptimalWorld and WorldId ~= game.PlaceId then
        TeleportService:Teleport(WorldId)
        task.wait(5)
        continue
    end

    if BestTraining == "Agility" or BestTraining == "Attack" then
        Network:FireServer("FastFlight", true)
        Network:FireServer("Combat")
        continue
    end

    if EnergyPercent < 20 then
        HiddenFlags.ShouldCharge = true
    end

    if EnergyPercent > 90 then
        HiddenFlags.ShouldCharge = false
    end

    if HiddenFlags.ShouldCharge then Charge(true) continue end

    local Charging = Character:WaitForChild('State'):WaitForChild('Charging')
    if Charging and Charging.Value then Charge(false) continue end

    if BestTraining == "Defense" then
        Network:FireServer("DefenseTrain") -- , {["Autododge"] = false}
    end

    if BestTraining == "Ki" then
        local Remote = ReplicatedStorage:FindFirstChild('ByteNetReliable')
        if KiBlastPayload and Remote and Remote:IsA('RemoteEvent') then
            Remote:FireServer(KiBlastPayload)
        elseif not KiBlastWarningShown then
            KiBlastWarningShown = true
            warn('[afy] Ki training unavailable: missing payload or ByteNetReliable remote for PlaceId ' .. tostring(game.PlaceId))
        end
    end
end

for Index, Connection in Connections do
    Connection:Disconnect()
end
