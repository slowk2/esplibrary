--// Services
local players = game:GetService("Players")
local run_service = game:GetService("RunService")
local replicated_storage = game:GetService("ReplicatedStorage")
local user_input_service = game:GetService("UserInputService")
local camera = workspace.CurrentCamera
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera

-- Cache services
local LocalPlayer = Players.LocalPlayer
local LocalCharacter = LocalPlayer and LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local LocalHumanoidRootPart = LocalCharacter:WaitForChild("HumanoidRootPart")

--// Modules
local utility = require(replicated_storage.Modules.Utility)
local camera_controller = require(players.LocalPlayer.PlayerScripts.Controllers.CameraController)
local constants = require(replicated_storage.Modules.CONSTANTS)
local fighter_controller = require(players.LocalPlayer.PlayerScripts.Controllers.FighterController)
local mechanics_controller = require(players.LocalPlayer.PlayerScripts.Controllers.MechanicsController)

--// Variables
local aa_rotation = 0
local isSilentAimEnabled = false
local isCamlockEnabled = false
local isNoSpreadEnabled = false
local isAntiAimEnabled = false
local isThirdPersonEnabled = false
local hitchance = 100
local selectedBone = "Head"

--// Silent Aim Helper Functions
local get_players = function()
    local entities = {}
    for _, child in workspace:GetChildren() do
        if child:FindFirstChildOfClass("Humanoid") then
            table.insert(entities, child)
        elseif child.Name == "HurtEffect" then
            for _, hurt_player in child:GetChildren() do
                if hurt_player.ClassName ~= "Highlight" then
                    table.insert(entities, hurt_player)
                end
            end
        end
    end
    return entities
end

local get_closest_player = function()
    local closest, closest_distance = nil, math.huge
    local character = players.LocalPlayer.Character

    if not character then
        return
    end

    for _, player in get_players() do
        if player == players.LocalPlayer then continue end
        if not player:FindFirstChild("HumanoidRootPart") then continue end

        local position, on_screen = camera:WorldToViewportPoint(player.HumanoidRootPart.Position)
        if not on_screen then continue end

        local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
        local distance = (center - Vector2.new(position.X, position.Y)).Magnitude

        if distance < closest_distance then
            closest = player
            closest_distance = distance
        end
    end
    return closest
end



local ESP = {}
ESP.__index = ESP

function ESP.new()
    local self = setmetatable({}, ESP)
    self.espCache = {}
    self.toggles = { -- Inicializa os toggles com valores padrão (falso)
        Box = false,
        DistanceLabel = false,
        NameLabel = false,
        HealthBar = false,
        ArmorBar = false,
        ItemLabel = false,
        SkeletonLines = false
    }
    return self
end

function ESP:createDrawing(type, properties)
    local drawing = Drawing.new(type)
    for prop, val in pairs(properties) do
        drawing[prop] = val
    end
    return drawing
end

function ESP:createComponents()
    return {
        Box = self:createDrawing("Square", {
            Thickness = 1,
            Transparency = 1,
            Color = Color3.fromRGB(255, 255, 255),
            Filled = false
        }),
        
        DistanceLabel = self:createDrawing("Text", {
            Size = 18,
            Center = true,
            Outline = true,
            Color = Color3.fromRGB(255, 255, 255),
            OutlineColor = Color3.fromRGB(0, 0, 0)
        }),
        NameLabel = self:createDrawing("Text", {
            Size = 18,
            Center = true,
            Outline = true,
            Color = Color3.fromRGB(255, 255, 255),
            OutlineColor = Color3.fromRGB(0, 0, 0)
        }),
        HealthBar = {
            Outline = self:createDrawing("Square", {
                Thickness = 1,
                Transparency = 1,
                Color = Color3.fromRGB(0, 0, 0),
                Filled = false
            }),
            Health = self:createDrawing("Square", {
                Thickness = 1,
                Transparency = 1,
                Color = Color3.fromRGB(0, 255, 0),
                Filled = true
            }),
            HealthText = self:createDrawing("Text", {
                Size = 14,
                Center = true,
                Outline = true,
                Color = Color3.fromRGB(255, 255, 255),
                OutlineColor = Color3.fromRGB(0, 0, 0)
            })
        },
        ArmorBar = {
            Outline = self:createDrawing("Square", {
                Thickness = 1,
                Transparency = 1,
                Color = Color3.fromRGB(0, 0, 0),
                Filled = false
            }),
            Armor = self:createDrawing("Square", {
                Thickness = 1,
                Transparency = 1,
                Color = Color3.fromRGB(0, 0, 255),
                Filled = true
            }),
            ArmorText = self:createDrawing("Text", {
                Size = 14,
                Center = true,
                Outline = true,
                Color = Color3.fromRGB(255, 255, 255),
                OutlineColor = Color3.fromRGB(0, 0, 0)
            })
        },
        ItemLabel = self:createDrawing("Text", {
            Size = 18,
            Center = true,
            Outline = true,
            Color = Color3.fromRGB(255, 255, 255),
            OutlineColor = Color3.fromRGB(0, 0, 0)
        }),
        SkeletonLines = {}
    }
end

local bodyConnections = {
    R15 = {
        {"Head", "UpperTorso"},
        {"UpperTorso", "LowerTorso"},
        {"LowerTorso", "LeftUpperLeg"},
        {"LowerTorso", "RightUpperLeg"},
        {"LeftUpperLeg", "LeftLowerLeg"},
        {"LeftLowerLeg", "LeftFoot"},
        {"RightUpperLeg", "RightLowerLeg"},
        {"RightLowerLeg", "RightFoot"},
        {"UpperTorso", "LeftUpperArm"},
        {"UpperTorso", "RightUpperArm"},
        {"LeftUpperArm", "LeftLowerArm"},
        {"LeftLowerArm", "LeftHand"},
        {"RightUpperArm", "RightLowerArm"},
        {"RightLowerArm", "RightHand"}
    },
    R6 = {
        {"Head", "Torso"},
        {"Torso", "Left Arm"},
        {"Torso", "Right Arm"},
        {"Torso", "Left Leg"},
        {"Torso", "Right Leg"}
    }
}

function ESP:updateComponents(components, character, player)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChild("Humanoid")

    if hrp and humanoid then
        local distanceFromPlayer = (LocalHumanoidRootPart.Position - hrp.Position).magnitude

        -- Verifica se a distância é maior que 200
        if distanceFromPlayer > 200 then
            self:hideComponents(components)
            return
        end

        local hrpPosition, onScreen = Camera:WorldToViewportPoint(hrp.Position)

        if onScreen then
            local screenWidth, screenHeight = Camera.ViewportSize.X, Camera.ViewportSize.Y
            local factor = 1 / (hrpPosition.Z * math.tan(math.rad(Camera.FieldOfView * 0.5)) * 2) * 100
            local width, height = math.floor(screenHeight / 25 * factor), math.floor(screenWidth / 27 * factor)

            -- Atualizar caixa
            components.Box.Visible = self.toggles.Box
            if self.toggles.Box then
                components.Box.Size = Vector2.new(width, height)
                components.Box.Position = Vector2.new(hrpPosition.X - width / 2, hrpPosition.Y - height / 2)
            end

            -- Atualizar rótulo de distância
            components.DistanceLabel.Visible = self.toggles.DistanceLabel
            if self.toggles.DistanceLabel then
                components.DistanceLabel.Text = string.format("[%dM]", math.floor(distanceFromPlayer))
                components.DistanceLabel.Position = Vector2.new(hrpPosition.X, hrpPosition.Y + height / 2 + 15)
            end

            -- Atualizar rótulo de nome
            components.NameLabel.Visible = self.toggles.NameLabel
            if self.toggles.NameLabel then
                components.NameLabel.Text = string.format("[%s]", player.Name)
                components.NameLabel.Position = Vector2.new(hrpPosition.X, hrpPosition.Y - height / 2 - 15)
            end

            -- Atualizar barra de saúde
            local healthFraction = humanoid.Health / humanoid.MaxHealth
            components.HealthBar.Outline.Visible = self.toggles.HealthBar
            components.HealthBar.Health.Visible = self.toggles.HealthBar
            components.HealthBar.HealthText.Visible = self.toggles.HealthBar
            if self.toggles.HealthBar then
                components.HealthBar.Outline.Size = Vector2.new(5, height)
                components.HealthBar.Outline.Position = Vector2.new(hrpPosition.X - width / 2 - 5, hrpPosition.Y - height / 2)

                components.HealthBar.Health.Size = Vector2.new(3, height * healthFraction)
                components.HealthBar.Health.Position = Vector2.new(components.HealthBar.Outline.Position.X + 1, components.HealthBar.Outline.Position.Y + height * (1 - healthFraction))

                components.HealthBar.HealthText.Text = string.format("%d", math.floor(humanoid.Health))
                components.HealthBar.HealthText.Position = Vector2.new(components.HealthBar.Health.Position.X - 15, components.HealthBar.Health.Position.Y - 1)
            end

            -- Atualizar barra de armadura
            local armorFraction = character:FindFirstChild("Armor") and character.Armor.Value / character.Armor.MaxValue or 0
            components.ArmorBar.Outline.Visible = self.toggles.ArmorBar
            components.ArmorBar.Armor.Visible = self.toggles.ArmorBar
            components.ArmorBar.ArmorText.Visible = self.toggles.ArmorBar
            if self.toggles.ArmorBar then
                components.ArmorBar.Outline.Size = Vector2.new(5, height)
                components.ArmorBar.Outline.Position = Vector2.new(hrpPosition.X + width / 2 + 2, hrpPosition.Y - height / 2)

                components.ArmorBar.Armor.Size = Vector2.new(3, height * armorFraction)
                components.ArmorBar.Armor.Position = Vector2.new(components.ArmorBar.Outline.Position.X + 1, components.ArmorBar.Outline.Position.Y + height * (1 - armorFraction))

                components.ArmorBar.ArmorText.Text = string.format("%d", math.floor(character:FindFirstChild("Armor") and character.Armor.Value or 0))
                components.ArmorBar.ArmorText.Position = Vector2.new(components.ArmorBar.Armor.Position.X + 10, components.ArmorBar.Armor.Position.Y - 10)
            end

            -- Atualizar rótulo do item
            components.ItemLabel.Visible = self.toggles.ItemLabel
            if self.toggles.ItemLabel then
                local backpack = player.Backpack
                local tool = backpack:FindFirstChildOfClass("Tool") or character:FindFirstChildOfClass("Tool")
                components.ItemLabel.Text = tool and string.format("[Holding: %s]", tool.Name) or "[Holding: No tool]"
                components.ItemLabel.Position = Vector2.new(hrpPosition.X, hrpPosition.Y + height / 2 + 35)
            end

            -- Atualizar esqueleto
            if self.toggles.SkeletonLines then
                local connections = bodyConnections[humanoid.RigType.Name] or {}
                for _, connection in ipairs(connections) do
                    local partA = character:FindFirstChild(connection[1])
                    local partB = character:FindFirstChild(connection[2])
                    if partA and partB then
                        local line = components.SkeletonLines[connection[1] .. "-" .. connection[2]] or self:createDrawing("Line", {Thickness = 1, Color = Color3.fromRGB(255, 255, 255)})
                        local posA, onScreenA = Camera:WorldToViewportPoint(partA.Position)
                        local posB, onScreenB = Camera:WorldToViewportPoint(partB.Position)
                        line.From = Vector2.new(posA.X, posA.Y)
                        line.To = Vector2.new(posB.X, posB.Y)
                        line.Visible = onScreenA and onScreenB
                        components.SkeletonLines[connection[1] .. "-" .. connection[2]] = line
                    end
                end
            else
                for _, line in pairs(components.SkeletonLines) do
                    line.Visible = false
                end
            end
        else
            self:hideComponents(components)
        end
    end
end


function ESP:hideComponents(components)
    components.Box.Visible = false
    components.DistanceLabel.Visible = false
    components.NameLabel.Visible = false
    components.HealthBar.Outline.Visible = false
    components.HealthBar.Health.Visible = false
    components.HealthBar.HealthText.Visible = false
    components.ArmorBar.Outline.Visible = false
    components.ArmorBar.Armor.Visible = false
    components.ArmorBar.ArmorText.Visible = false
    components.ItemLabel.Visible = false
    for _, line in pairs(components.SkeletonLines) do
        line.Visible = false
    end
end

function ESP:removeEsp(player)
    local components = self.espCache[player]
    if components then
        components.Box:Remove()
        components.DistanceLabel:Remove()
        components.NameLabel:Remove()
        components.HealthBar.Outline:Remove()
        components.HealthBar.Health:Remove()
        components.HealthBar.HealthText:Remove()
        components.ArmorBar.Outline:Remove()
        components.ArmorBar.Armor:Remove()
        components.ArmorBar.ArmorText:Remove()
        components.ItemLabel:Remove()
        for _, line in pairs(components.SkeletonLines) do
            line:Remove()
        end
        self.espCache[player] = nil
    end
end

local espInstance = ESP.new()

-- ESP Toggles
local espSection = misc:Section({Name = "ESP Features", Size = 330})
espSection:Toggle({Name = "ESP Box", Flag = "ESPBox", Callback = function(value)
    espInstance.toggles.Box = value
end})

espSection:Toggle({Name = "ESP Distance Label", Flag = "ESPDistanceLabel", Callback = function(value)
    espInstance.toggles.DistanceLabel = value
end})

espSection:Toggle({Name = "ESP Name Label", Flag = "ESPNameLabel", Callback = function(value)
    espInstance.toggles.NameLabel = value
end})

espSection:Toggle({Name = "ESP Health Bar", Flag = "ESPHealthBar", Callback = function(value)
    espInstance.toggles.HealthBar = value
end})

espSection:Toggle({Name = "ESP Armor Bar", Flag = "ESPArmorBar", Callback = function(value)
    espInstance.toggles.ArmorBar = value
end})

espSection:Toggle({Name = "ESP Item Label", Flag = "ESPItemLabel", Callback = function(value)
    espInstance.toggles.ItemLabel = value
end})

espSection:Toggle({Name = "ESP Skeleton Lines", Flag = "ESPSkeletonLines", Callback = function(value)
    espInstance.toggles.SkeletonLines = value
end})

run_service.RenderStepped:Connect(function()
    for _, player in ipairs(players:GetPlayers()) do
        if player ~= players.LocalPlayer then
            local character = player.Character
            if character then
                if not espInstance.espCache[player] then
                    espInstance.espCache[player] = espInstance:createComponents()
                end
                espInstance:updateComponents(espInstance.espCache[player], character, player)
            else
                if espInstance.espCache[player] then
                    espInstance:hideComponents(espInstance.espCache[player])
                end
            end
        end
    end
end)

players.PlayerRemoving:Connect(function(player)
    espInstance:removeEsp(player)
end)
