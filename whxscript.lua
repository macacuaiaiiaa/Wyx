local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local sunfishEnabled = false
local checkingMove = false
local lastFEN = nil
local lastMove = nil
local sunfish = nil

-- Carregar Sunfish
local function loadSunfish()
    local success, mod = pcall(function()
        return require(player:WaitForChild("PlayerScripts"):WaitForChild("AI"):WaitForChild("Sunfish"))
    end)
    if success and mod then
        print("[WHXScript] Sunfish carregado.")
        return mod
    else
        warn("[WHXScript] Erro ao carregar Sunfish.")
        return nil
    end
end

local function getFEN()
    local success, result = pcall(function()
        local tableSet = ReplicatedStorage:WaitForChild("InternalClientEvents"):WaitForChild("GetActiveTableset")
        local board = tableSet:Invoke()
        return board:WaitForChild("FEN").Value
    end)
    if success and type(result) == "string" then
        return result
    else
        return nil
    end
end

local function getBestMove(fen)
    if not sunfish then return nil end
    local success, move = pcall(function()
        return sunfish:GetBestMove(fen, 2000)
    end)
    if success and type(move) == "string" and #move >= 4 then
        local from = move:sub(1, 2)
        local to = move:sub(3, 4)
        return from, to
    else
        return nil
    end
end

local board = playerGui:WaitForChild("2DBoard"):WaitForChild("GodFrame"):WaitForChild("Board")

-- === Criar GUI da seta (linha via imagem + ponta) ===
local arrowGui = playerGui:FindFirstChild("WHXScript_ArrowGui")
if not arrowGui then
    arrowGui = Instance.new("ScreenGui")
    arrowGui.Name = "WHXScript_ArrowGui"
    arrowGui.ResetOnSpawn = false
    arrowGui.Parent = playerGui
end

-- Linha da seta (ImageLabel com textura)
local arrowLine = arrowGui:FindFirstChild("WHX_ArrowLine")
if not arrowLine then
    arrowLine = Instance.new("ImageLabel")
    arrowLine.Name = "WHX_ArrowLine"
    arrowLine.BackgroundTransparency = 1
    arrowLine.Image = "rbxassetid://3926305904" -- linha fina e suave
    arrowLine.Size = UDim2.new(0, 0, 0, 6)
    arrowLine.AnchorPoint = Vector2.new(0, 0.5)
    arrowLine.ImageColor3 = Color3.fromRGB(0, 255, 0)
    arrowLine.Parent = arrowGui
end

-- Ponta da seta (imagem)
local pointer = arrowGui:FindFirstChild("WHX_ArrowPointer")
if not pointer then
    pointer = Instance.new("ImageLabel")
    pointer.Name = "WHX_ArrowPointer"
    pointer.Image = "rbxassetid://3926307971" -- seta limpa
    pointer.BackgroundTransparency = 1
    pointer.Size = UDim2.new(0, 24, 0, 24)
    pointer.AnchorPoint = Vector2.new(0.5, 0.5)
    pointer.ImageColor3 = Color3.fromRGB(0, 255, 0)
    pointer.Parent = arrowGui
end

arrowLine.Visible = false
pointer.Visible = false

local function updateArrow(fromSquare, toSquare)
    if not fromSquare or not toSquare then
        arrowLine.Visible = false
        pointer.Visible = false
        return
    end

    local fromFrame = board:FindFirstChild(fromSquare:lower())
    local toFrame = board:FindFirstChild(toSquare:lower())
    if not fromFrame or not toFrame then
        arrowLine.Visible = false
        pointer.Visible = false
        return
    end

    local fromPos = fromFrame.AbsolutePosition + fromFrame.AbsoluteSize / 2
    local toPos = toFrame.AbsolutePosition + toFrame.AbsoluteSize / 2
    local direction = toPos - fromPos
    local distance = direction.Magnitude

    local lineLength = math.max(0, distance - 18) -- espaço para ponta da seta

    local angle = math.deg(math.atan2(direction.Y, direction.X))

    arrowLine.Visible = true
    pointer.Visible = true

    arrowLine.Position = UDim2.new(0, fromPos.X, 0, fromPos.Y)
    arrowLine.Size = UDim2.new(0, lineLength, 0, 6)
    arrowLine.Rotation = angle
    arrowLine.ImageColor3 = Color3.fromRGB(0, 255, 0)

    pointer.Position = UDim2.new(0, toPos.X, 0, toPos.Y)
    pointer.Rotation = angle
    pointer.ImageColor3 = Color3.fromRGB(0, 255, 0)
end

local function clearArrow()
    arrowLine.Visible = false
    pointer.Visible = false
end

-- === GUI Principal WHXScript ===
local screenGui = playerGui:FindFirstChild("WHXScript_GUI")
if not screenGui then
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "WHXScript_GUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui
end

local window = screenGui:FindFirstChild("Window")
if not window then
    window = Instance.new("Frame")
    window.Name = "Window"
    window.Size = UDim2.new(0, 280, 0, 130)
    window.Position = UDim2.new(0, 50, 0, 50)
    window.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
    window.BorderSizePixel = 0
    window.AnchorPoint = Vector2.new(0, 0)
    window.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = window

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 28)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBlack
    title.Text = "WHXScript - Auto Chess"
    title.TextColor3 = Color3.fromRGB(0, 255, 0)
    title.TextStrokeColor3 = Color3.fromRGB(0, 100, 0)
    title.TextStrokeTransparency = 0
    title.TextSize = 24
    title.Parent = window

    local btnClose = Instance.new("TextButton")
    btnClose.Name = "CloseButton"
    btnClose.Size = UDim2.new(0, 28, 0, 28)
    btnClose.Position = UDim2.new(1, -34, 0, 2)
    btnClose.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    btnClose.BorderSizePixel = 0
    btnClose.Font = Enum.Font.GothamBlack
    btnClose.Text = "×"
    btnClose.TextColor3 = Color3.fromRGB(0, 255, 0)
    btnClose.TextStrokeColor3 = Color3.fromRGB(0, 100, 0)
    btnClose.TextStrokeTransparency = 0
    btnClose.TextSize = 28
    btnClose.Parent = window

    local container = Instance.new("Frame")
    container.Name = "Container"
    container.Size = UDim2.new(1, -16, 1, -40)
    container.Position = UDim2.new(0, 8, 0, 32)
    container.BackgroundTransparency = 1
    container.Parent = window

    local btnToggleSunfish = Instance.new("TextButton")
    btnToggleSunfish.Name = "BtnToggleSunfish"
    btnToggleSunfish.Size = UDim2.new(1, 0, 0, 40)
    btnToggleSunfish.Position = UDim2.new(0, 0, 0, 0)
    btnToggleSunfish.BackgroundColor3 = Color3.fromRGB(0, 120, 0)
    btnToggleSunfish.BorderSizePixel = 0
    btnToggleSunfish.Font = Enum.Font.GothamBlack
    btnToggleSunfish.Text = "Ativar Sunfish"
    btnToggleSunfish.TextColor3 = Color3.fromRGB(180, 255, 180)
    btnToggleSunfish.TextStrokeColor3 = Color3.fromRGB(0, 100, 0)
    btnToggleSunfish.TextStrokeTransparency = 0
    btnToggleSunfish.TextSize = 22
    btnToggleSunfish.Parent = container

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "StatusLabel"
    statusLabel.Size = UDim2.new(1, 0, 0, 24)
    statusLabel.Position = UDim2.new(0, 0, 0, 48)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.GothamBlack
    statusLabel.Text = "Status: Desativado"
    statusLabel.TextColor3 = Color3.fromRGB(120, 255, 120)
    statusLabel.TextStrokeColor3 = Color3.fromRGB(0, 100, 0)
    statusLabel.TextStrokeTransparency = 0
    statusLabel.TextSize = 16
    statusLabel.TextWrapped = true
    statusLabel.Parent = container

    btnToggleSunfish.MouseButton1Click:Connect(function()
        sunfishEnabled = not sunfishEnabled
        if sunfishEnabled then
            btnToggleSunfish.BackgroundColor3 = Color3.fromRGB(0, 160, 0)
            btnToggleSunfish.Text = "Desativar Sunfish"
            if not sunfish then sunfish = loadSunfish() end
            print("[WHXScript] Sunfish ativado.")
            statusLabel.Text = "Status: Sunfish ativado, sugerindo movimentos..."
            statusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
        else
            btnToggleSunfish.BackgroundColor3 = Color3.fromRGB(100, 0, 0)
            btnToggleSunfish.Text = "Ativar Sunfish"
            clearArrow()
            print("[WHXScript] Sunfish desativado.")
            statusLabel.Text = "Status: Desativado"
            statusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
        end
    end)

    btnClose.MouseButton1Click:Connect(function()
        window.Visible = false
        miniBar.Visible = true
    end)
end

-- === Barra minimizada arrastável ===
local miniBar = screenGui:FindFirstChild("MiniBar")
if not miniBar then
    miniBar = Instance.new("TextButton")
    miniBar.Name = "MiniBar"
    miniBar.Size = UDim2.new(0, 50, 0, 28)
    miniBar.Position = UDim2.new(0, 20, 0, 20)
    miniBar.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    miniBar.BorderSizePixel = 0
    miniBar.Text = "WHX"
    miniBar.TextColor3 = Color3.fromRGB(0, 255, 0)
    miniBar.Font = Enum.Font.GothamBlack
    miniBar.TextSize = 20
    miniBar.Visible = true
    miniBar.Parent = screenGui

    local miniCorner = Instance.new("UICorner")
    miniCorner.CornerRadius = UDim.new(0, 8)
    miniCorner.Parent = miniBar

    -- Arrastar miniBar
    local draggingMini = false
    local dragStartMini = nil
    local startPosMini = nil

    miniBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingMini = true
            dragStartMini = input.Position
            startPosMini = miniBar.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    draggingMini = false
                end
            end)
        end
    end)

    miniBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and draggingMini then
            local delta = input.Position - dragStartMini
            local newX = math.clamp(startPosMini.X.Offset + delta.X, 0, workspace.CurrentCamera.ViewportSize.X - miniBar.AbsoluteSize.X)
            local newY = math.clamp(startPosMini.Y.Offset + delta.Y, 0, workspace.CurrentCamera.ViewportSize.Y - miniBar.AbsoluteSize.Y)
            miniBar.Position = UDim2.new(0, newX, 0, newY)
        end
    end)

    miniBar.MouseButton1Click:Connect(function()
        miniBar.Visible = false
        window.Visible = true
    end)
end

-- Tornar janela principal arrastável
local draggingWindow = false
local dragStartWindow = nil
local startPosWindow = nil

window.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        draggingWindow = true
        dragStartWindow = input.Position
        startPosWindow = window.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                draggingWindow = false
            end
        end)
    end
end)

window.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement and draggingWindow then
        local delta = input.Position - dragStartWindow
        local newX = math.clamp(startPosWindow.X.Offset + delta.X, 0, workspace.CurrentCamera.ViewportSize.X - window.AbsoluteSize.X)
        local newY = math.clamp(startPosWindow.Y.Offset + delta.Y, 0, workspace.CurrentCamera.ViewportSize.Y - window.AbsoluteSize.Y)
        window.Position = UDim2.new(0, newX, 0, newY)
    end
end)

window.Visible = false
miniBar.Visible = true

-- Loop principal da sugestão
RunService.RenderStepped:Connect(function()
    if not sunfishEnabled then return end
    if checkingMove then return end
    checkingMove = true

    local fenAtual = getFEN()
    if fenAtual and fenAtual ~= lastFEN then
        lastFEN = fenAtual
        local from, to = getBestMove(fenAtual)
        if from and to then
            local currentMove = from .. to
            if currentMove ~= lastMove then
                print("[WHXScript] Sugestão: " .. from .. " → " .. to)
                updateArrow(from, to)
                lastMove = currentMove
            end
        else
            if lastMove then
                clearArrow()
                lastMove = nil
            end
        end
    end

    checkingMove = false
end)
