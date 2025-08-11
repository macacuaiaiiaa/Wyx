local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local sunfishEnabled = false
local checkingMove = false
local lastFEN = nil
local lastMove = nil

local STOCKFISH_API_URL = "https://v0-gpt-5-development-eight.vercel.app/api/move"

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

local function getBestMoveStockfish(fen)
    local success, response = pcall(function()
        local body = HttpService:JSONEncode({
            fen = fen,
            depth = 12 -- ajustar se necessário para performance
        })
        local res = HttpService:PostAsync(STOCKFISH_API_URL, body, Enum.HttpContentType.ApplicationJson)
        return HttpService:JSONDecode(res)
    end)

    if success and response and response.bestmove then
        local move = response.bestmove
        if #move >= 4 then
            local from = move:sub(1, 2)
            local to = move:sub(3, 4)
            return from, to
        end
    else
        warn("[WHXScript] Erro na API Stockfish ou resposta inválida")
    end

    return nil
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

local arrowLine = arrowGui:FindFirstChild("WHX_ArrowLine")
if not arrowLine then
    arrowLine = Instance.new("ImageLabel")
    arrowLine.Name = "WHX_ArrowLine"
    arrowLine.BackgroundTransparency = 1
    arrowLine.Image = "rbxassetid://3926305904" -- linha fina e suave
    arrowLine.Size = UDim2.new(0, 0, 0, 8) -- linha mais grossa
    arrowLine.AnchorPoint = Vector2.new(0, 0.5)
    arrowLine.ImageColor3 = Color3.fromRGB(150, 0, 0) -- vermelho sangue escuro
    arrowLine.Parent = arrowGui
end

local pointer = arrowGui:FindFirstChild("WHX_ArrowPointer")
if not pointer then
    pointer = Instance.new("ImageLabel")
    pointer.Name = "WHX_ArrowPointer"
    pointer.Image = "rbxassetid://3926307971" -- seta limpa
    pointer.BackgroundTransparency = 1
    pointer.Size = UDim2.new(0, 28, 0, 28)
    pointer.AnchorPoint = Vector2.new(0.5, 0.5)
    pointer.ImageColor3 = Color3.fromRGB(150, 0, 0) -- vermelho sangue escuro
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

    local lineLength = math.max(0, distance - 28) -- espaço para a ponta da seta

    local angle = math.deg(math.atan2(direction.Y, direction.X))

    arrowLine.Visible = true
    pointer.Visible = true

    arrowLine.Position = UDim2.new(0, fromPos.X, 0, fromPos.Y)
    arrowLine.Size = UDim2.new(0, lineLength, 0, 8)
    arrowLine.Rotation = angle
    arrowLine.ImageColor3 = Color3.fromRGB(150, 0, 0)

    pointer.Position = UDim2.new(0, toPos.X, 0, toPos.Y)
    pointer.Rotation = angle
    pointer.ImageColor3 = Color3.fromRGB(150, 0, 0)
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
    window.BackgroundColor3 = Color3.fromRGB(25, 0, 30) -- fundo roxo escuro gótico
    window.BorderSizePixel = 0
    window.AnchorPoint = Vector2.new(0, 0)
    window.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = window

    local shadow = Instance.new("ImageLabel")
    shadow.Name = "Shadow"
    shadow.Size = UDim2.new(1, 14, 1, 14)
    shadow.Position = UDim2.new(0, -7, 0, -7)
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxassetid://1316045217"
    shadow.ImageColor3 = Color3.fromRGB(45, 0, 55)
    shadow.ZIndex = 0
    shadow.Parent = window

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 28)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBlack
    title.Text = "WHXScript - Auto Chess"
    title.TextColor3 = Color3.fromRGB(160, 32, 240)
    title.TextSize = 20
    title.Parent = window

    local btnClose = Instance.new("TextButton")
    btnClose.Name = "CloseButton"
    btnClose.Size = UDim2.new(0, 28, 0, 28)
    btnClose.Position = UDim2.new(1, -34, 0, 2)
    btnClose.BackgroundColor3 = Color3.fromRGB(60, 0, 60)
    btnClose.BorderSizePixel = 0
    btnClose.Font = Enum.Font.GothamBlack
    btnClose.Text = "×"
    btnClose.TextColor3 = Color3.fromRGB(255, 40, 40)
    btnClose.TextSize = 26
    btnClose.Parent = window

    btnClose.MouseEnter:Connect(function()
        btnClose.BackgroundColor3 = Color3.fromRGB(100, 0, 0)
        btnClose.TextColor3 = Color3.fromRGB(255, 80, 80)
    end)
    btnClose.MouseLeave:Connect(function()
        btnClose.BackgroundColor3 = Color3.fromRGB(60, 0, 60)
        btnClose.TextColor3 = Color3.fromRGB(255, 40, 40)
    end)

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
    btnToggleSunfish.BackgroundColor3 = Color3.fromRGB(120, 0, 40)
    btnToggleSunfish.BorderSizePixel = 0
    btnToggleSunfish.Font = Enum.Font.GothamBold
    btnToggleSunfish.Text = "Ativar Stockfish"
    btnToggleSunfish.TextColor3 = Color3.fromRGB(255, 80, 80)
    btnToggleSunfish.TextSize = 20
    btnToggleSunfish.Parent = container

    btnToggleSunfish.MouseEnter:Connect(function()
        btnToggleSunfish.BackgroundColor3 = Color3.fromRGB(180, 0, 60)
        btnToggleSunfish.TextColor3 = Color3.fromRGB(255, 120, 120)
    end)
    btnToggleSunfish.MouseLeave:Connect(function()
        if sunfishEnabled then
            btnToggleSunfish.BackgroundColor3 = Color3.fromRGB(0, 90, 0)
            btnToggleSunfish.TextColor3 = Color3.fromRGB(0, 255, 0)
        else
            btnToggleSunfish.BackgroundColor3 = Color3.fromRGB(120, 0, 40)
            btnToggleSunfish.TextColor3 = Color3.fromRGB(255, 80, 80)
        end
    end)

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "StatusLabel"
    statusLabel.Size = UDim2.new(1, 0, 0, 24)
    statusLabel.Position = UDim2.new(0, 0, 0, 48)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.Text = "Status: Desativado"
    statusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    statusLabel.TextSize = 16
    statusLabel.TextWrapped = true
    statusLabel.Parent = container

    -- Guardar referências para usar fora
    window.BtnToggleSunfish = btnToggleSunfish
    window.StatusLabel = statusLabel
end

-- Barra minimizada arrastável com estilo gótico
local miniBar = screenGui:FindFirstChild("MiniBar")
if not miniBar then
    miniBar = Instance.new("TextButton")
    miniBar.Name = "MiniBar"
    miniBar.Size = UDim2.new(0, 60, 0, 32)
    miniBar.Position = UDim2.new(0, 20, 0, 20)
    miniBar.BackgroundColor3 = Color3.fromRGB(15, 0, 15)
    miniBar.BorderSizePixel = 0
    miniBar.Text = "WHX"
    miniBar.TextColor3 = Color3.fromRGB(255, 50, 50)
    miniBar.Font = Enum.Font.GothamBold
    miniBar.TextSize = 20
    miniBar.Visible = true
    miniBar.Parent = screenGui

    local miniCorner = Instance.new("UICorner")
    miniCorner.CornerRadius = UDim.new(0, 10)
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

-- Botão toggle Stockfish
window.BtnToggleSunfish.MouseButton1Click:Connect(function()
    sunfishEnabled = not sunfishEnabled
    if sunfishEnabled then
        window.BtnToggleSunfish.BackgroundColor3 = Color3.fromRGB(0, 90, 0)
        window.BtnToggleSunfish.Text = "Desativar Stockfish"
        window.BtnToggleSunfish.TextColor3 = Color3.fromRGB(0, 255, 0)
        window.StatusLabel.Text = "Status: Stockfish ativado, sugerindo movimentos..."
window.StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
    else
        window.BtnToggleSunfish.BackgroundColor3 = Color3.fromRGB(120, 0, 40)
        window.BtnToggleSunfish.Text = "Ativar Stockfish"
        window.BtnToggleSunfish.TextColor3 = Color3.fromRGB(255, 80, 80)
        window.StatusLabel.Text = "Status: Desativado"
        window.StatusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
        clearArrow()
    end
end)

-- Botão fechar janela principal
window.CloseButton.MouseButton1Click:Connect(function()
    window.Visible = false
    miniBar.Visible = true
end)

-- Loop para checar e sugerir movimentos quando ativo
RunService.Heartbeat:Connect(function()
    if sunfishEnabled and not checkingMove then
        checkingMove = true
        local fen = getFEN()
        if fen and fen ~= lastFEN then
            lastFEN = fen
            local fromSquare, toSquare = getBestMoveStockfish(fen)
            if fromSquare and toSquare then
                lastMove = {from = fromSquare, to = toSquare}
                updateArrow(fromSquare, toSquare)
            else
                clearArrow()
            end
        elseif not fen then
            clearArrow()
        end
        checkingMove = false
    end
end)
