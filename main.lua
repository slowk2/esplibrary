--// Services
local players = game:GetService("Players")
local run_service = game:GetService("RunService")
local replicated_storage = game:GetService("ReplicatedStorage")
local user_input_service = game:GetService("UserInputService")
local camera = workspace.CurrentCamera

-- Cache services
local LocalPlayer = players.LocalPlayer
local LocalCharacter = LocalPlayer and LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local LocalHumanoidRootPart = LocalCharacter:WaitForChild("HumanoidRootPart")

-- ESP Library
local ESP = {}
ESP.__index = ESP

function ESP.new()
    local self = setmetatable({}, ESP)
    self.espCache = {}
    self.toggles = {
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

-- Define body connections
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

        if distanceFromPlayer > 200 then
            self:hideComponents(components)
            return
        end

        local hrpPosition, onScreen = camera:WorldToViewportPoint(hrp.Position)

        if onScreen then
            local screenWidth, screenHeight = camera.ViewportSize.X, camera.ViewportSize.Y
            local factor = 1 / (hrpPosition.Z * math.tan(math.rad(camera.FieldOfView * 0.5)) * 2) * 100
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
        else
            self:hideComponents(components)
        end
    else
        self:hideComponents(components)
    end
end

function ESP:hideComponents(components)
    for _, component in pairs(components) do
        if type(component) == "table" then
            for _, innerComponent in pairs(component) do
                innerComponent.Visible = false
            end
        else
            component.Visible = false
        end
    end
end

function ESP:initialize()
    local espComponents = self:createComponents()
    local function onCharacterAdded(character)
        character:WaitForChild("Humanoid").Died:Connect(function()
            for _, component in pairs(espComponents) do
                if type(component) == "table" then
                    for _, innerComponent in pairs(component) do
                        innerComponent:Remove()
                    end
                else
                    component:Remove()
                end
            end
        end)
        
        run_service.RenderStepped:Connect(function()
            self:updateComponents(espComponents, character, players:GetPlayerFromCharacter(character))
        end)
    end

    LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
    if LocalPlayer.Character then
        onCharacterAdded(LocalPlayer.Character)
    end
end

return ESP
