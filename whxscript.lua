--[[
    WHXScript - Auto Chess Engine
    Versão melhorada com melhor organização e performance
    Autor: WHX
]]

-- ===== SERVIÇOS E CONFIGURAÇÕES =====
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

-- Configurações principais
local CONFIG = {
    STOCKFISH_API_URL = "https://v0-gpt-5-development-eight.vercel.app/api/move",
    STOCKFISH_DEPTH = 12,
    UPDATE_INTERVAL = 0.5, -- segundos entre verificações
    ARROW_COLORS = {
        NORMAL = Color3.fromRGB(150, 0, 0),
        HOVER = Color3.fromRGB(200, 50, 50),
        ACTIVE = Color3.fromRGB(255, 100, 100)
    },
    GUI_COLORS = {
        BACKGROUND = Color3.fromRGB(25, 0, 30),
        ACCENT = Color3.fromRGB(160, 32, 240),
        SUCCESS = Color3.fromRGB(0, 255, 0),
        ERROR = Color3.fromRGB(255, 40, 40),
        TEXT = Color3.fromRGB(255, 255, 255)
    }
}

-- ===== VARIÁVEIS GLOBAIS =====
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Estado do script
local ScriptState = {
    enabled = false,
    checking = false,
    lastFEN = nil,
    lastMove = nil,
    lastUpdateTime = 0,
    errorCount = 0,
    maxErrors = 5
}

-- ===== UTILITÁRIOS =====
local Utils = {}

function Utils.clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

function Utils.lerp(a, b, t)
    return a + (b - a) * t
end

function Utils.createTween(object, info, properties)
    local tween = TweenService:Create(object, info, properties)
    tween:Play()
    return tween
end

function Utils.safeCall(func, errorMessage)
    local success, result = pcall(func)
    if not success then
        warn("[WHXScript] " .. (errorMessage or "Erro desconhecido") .. ": " .. tostring(result))
        ScriptState.errorCount = ScriptState.errorCount + 1
        return nil
    end
    return result
end

-- ===== MÓDULO DE XADREZ =====
local ChessEngine = {}

function ChessEngine.getFEN()
    return Utils.safeCall(function()
        local tableSet = ReplicatedStorage:WaitForChild("InternalClientEvents"):WaitForChild("GetActiveTableset")
        local board = tableSet:Invoke()
        local fen = board:WaitForChild("FEN").Value
        
        if type(fen) ~= "string" or #fen < 10 then
            error("FEN inválido recebido")
        end
        
        return fen
    end, "Erro ao obter FEN")
end

function ChessEngine.getBestMove(fen)
    if not fen or #fen < 10 then
        return nil
    end
    
    return Utils.safeCall(function()
        -- Tentativa 1: Usar proxy CORS para contornar limitações do Roblox
        local proxyUrl = "https://api.allorigins.win/raw?url=" .. HttpService:UrlEncode(CONFIG.STOCKFISH_API_URL)
        
        -- Tentar primeiro com proxy CORS
        local success1, response1 = pcall(function()
            local requestBody = HttpService:JSONEncode({
                fen = fen,
                depth = CONFIG.STOCKFISH_DEPTH
            })
            
            return HttpService:PostAsync(
                proxyUrl,
                requestBody,
                Enum.HttpContentType.ApplicationJson,
                false,
                {
                    ["Content-Type"] = "application/json",
                    ["Access-Control-Allow-Origin"] = "*"
                }
            )
        end)
        
        if success1 then
            local data = HttpService:JSONDecode(response1)
            if data and data.bestmove and #data.bestmove >= 4 then
                local move = data.bestmove
                local fromSquare = move:sub(1, 2)
                local toSquare = move:sub(3, 4)
                
                if fromSquare:match("^[a-h][1-8]$") and toSquare:match("^[a-h][1-8]$") then
                    return {
                        from = fromSquare,
                        to = toSquare,
                        move = move,
                        evaluation = data.evaluation or 0
                    }
                end
            end
        end
        
        -- Tentativa 2: Usar método GET com parâmetros na URL
        local success2, response2 = pcall(function()
            local getUrl = CONFIG.STOCKFISH_API_URL .. "?fen=" .. HttpService:UrlEncode(fen) .. "&depth=" .. CONFIG.STOCKFISH_DEPTH
            return HttpService:GetAsync(getUrl, false, {
                ["Accept"] = "application/json",
                ["User-Agent"] = "RobloxStudio"
            })
        end)
        
        if success2 then
            local data = HttpService:JSONDecode(response2)
            if data and data.bestmove and #data.bestmove >= 4 then
                local move = data.bestmove
                local fromSquare = move:sub(1, 2)
                local toSquare = move:sub(3, 4)
                
                if fromSquare:match("^[a-h][1-8]$") and toSquare:match("^[a-h][1-8]$") then
                    return {
                        from = fromSquare,
                        to = toSquare,
                        move = move,
                        evaluation = data.evaluation or 0
                    }
                end
            end
        end
        
        -- Tentativa 3: Usar proxy alternativo
        local altProxyUrl = "https://cors-anywhere.herokuapp.com/" .. CONFIG.STOCKFISH_API_URL
        local success3, response3 = pcall(function()
            local requestBody = HttpService:JSONEncode({
                fen = fen,
                depth = CONFIG.STOCKFISH_DEPTH
            })
            
            return HttpService:PostAsync(
                altProxyUrl,
                requestBody,
                Enum.HttpContentType.ApplicationJson,
                false,
                {
                    ["Content-Type"] = "application/json",
                    ["X-Requested-With"] = "XMLHttpRequest"
                }
            )
        end)
        
        if success3 then
            local data = HttpService:JSONDecode(response3)
            if data and data.bestmove and #data.bestmove >= 4 then
                local move = data.bestmove
                local fromSquare = move:sub(1, 2)
                local toSquare = move:sub(3, 4)
                
                if fromSquare:match("^[a-h][1-8]$") and toSquare:match("^[a-h][1-8]$") then
                    return {
                        from = fromSquare,
                        to = toSquare,
                        move = move,
                        evaluation = data.evaluation or 0
                    }
                end
            end
        end
        
        error("Todas as tentativas de requisição falharam")
    end, "Erro na API Stockfish")
end

-- ===== MÓDULO DE INTERFACE =====
local GUI = {}

function GUI.init()
    GUI.createArrowSystem()
    GUI.createMainWindow()
    GUI.createMiniBar()
    GUI.setupEventHandlers()
end

function GUI.createArrowSystem()
    local arrowGui = playerGui:FindFirstChild("WHXScript_ArrowGui")
    if arrowGui then arrowGui:Destroy() end
    
    arrowGui = Instance.new("ScreenGui")
    arrowGui.Name = "WHXScript_ArrowGui"
    arrowGui.ResetOnSpawn = false
    arrowGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    arrowGui.Parent = playerGui
    
    -- Linha da seta
    local arrowLine = Instance.new("ImageLabel")
    arrowLine.Name = "ArrowLine"
    arrowLine.BackgroundTransparency = 1
    arrowLine.Image = "rbxassetid://3926305904"
    arrowLine.Size = UDim2.new(0, 0, 0, 10)
    arrowLine.AnchorPoint = Vector2.new(0, 0.5)
    arrowLine.ImageColor3 = CONFIG.ARROW_COLORS.NORMAL
    arrowLine.ZIndex = 10
    arrowLine.Visible = false
    arrowLine.Parent = arrowGui
    
    -- Ponta da seta
    local arrowPointer = Instance.new("ImageLabel")
    arrowPointer.Name = "ArrowPointer"
    arrowPointer.Image = "rbxassetid://3926307971"
    arrowPointer.BackgroundTransparency = 1
    arrowPointer.Size = UDim2.new(0, 30, 0, 30)
    arrowPointer.AnchorPoint = Vector2.new(0.5, 0.5)
    arrowPointer.ImageColor3 = CONFIG.ARROW_COLORS.NORMAL
    arrowPointer.ZIndex = 11
    arrowPointer.Visible = false
    arrowPointer.Parent = arrowGui
    
    GUI.arrowLine = arrowLine
    GUI.arrowPointer = arrowPointer
end

function GUI.updateArrow(moveData)
    if not moveData or not GUI.arrowLine or not GUI.arrowPointer then
        GUI.clearArrow()
        return
    end
    
    local board = playerGui:WaitForChild("2DBoard"):WaitForChild("GodFrame"):WaitForChild("Board")
    local fromFrame = board:FindFirstChild(moveData.from:lower())
    local toFrame = board:FindFirstChild(moveData.to:lower())
    
    if not fromFrame or not toFrame then
        GUI.clearArrow()
        return
    end
    
    local fromPos = fromFrame.AbsolutePosition + fromFrame.AbsoluteSize / 2
    local toPos = toFrame.AbsolutePosition + toFrame.AbsoluteSize / 2
    local direction = toPos - fromPos
    local distance = direction.Magnitude
    local lineLength = math.max(0, distance - 30)
    local angle = math.deg(math.atan2(direction.Y, direction.X))
    
    -- Animar aparição da seta
    GUI.arrowLine.Visible = true
    GUI.arrowPointer.Visible = true
    
    GUI.arrowLine.Position = UDim2.new(0, fromPos.X, 0, fromPos.Y)
    GUI.arrowLine.Size = UDim2.new(0, lineLength, 0, 10)
    GUI.arrowLine.Rotation = angle
    
    GUI.arrowPointer.Position = UDim2.new(0, toPos.X, 0, toPos.Y)
    GUI.arrowPointer.Rotation = angle
    
    -- Efeito de pulsação
    Utils.createTween(GUI.arrowLine, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
        ImageTransparency = 0.3
    })
    
    Utils.createTween(GUI.arrowPointer, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
        ImageTransparency = 0.3
    })
end

function GUI.clearArrow()
    if GUI.arrowLine then GUI.arrowLine.Visible = false end
    if GUI.arrowPointer then GUI.arrowPointer.Visible = false end
end

function GUI.createMainWindow()
    local screenGui = playerGui:FindFirstChild("WHXScript_GUI")
    if screenGui then screenGui:Destroy() end
    
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "WHXScript_GUI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = playerGui
    
    -- Janela principal
    local window = Instance.new("Frame")
    window.Name = "MainWindow"
    window.Size = UDim2.new(0, 320, 0, 180)
    window.Position = UDim2.new(0.5, -160, 0.5, -90)
    window.BackgroundColor3 = CONFIG.GUI_COLORS.BACKGROUND
    window.BorderSizePixel = 0
    window.Visible = false
    window.Parent = screenGui
    
    -- Cantos arredondados
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = window
    
    -- Sombra
    local shadow = Instance.new("ImageLabel")
    shadow.Name = "Shadow"
    shadow.Size = UDim2.new(1, 20, 1, 20)
    shadow.Position = UDim2.new(0, -10, 0, -10)
    shadow.BackgroundTransparency = 1
    shadow.Image = "rbxassetid://1316045217"
    shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    shadow.ImageTransparency = 0.5
    shadow.ZIndex = 0
    shadow.Parent = window
    
    -- Título
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -40, 0, 40)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.Text = "WHXScript - Auto Chess Engine"
    title.TextColor3 = CONFIG.GUI_COLORS.ACCENT
    title.TextSize = 18
    title.TextXAlignment = Enum.TextXAlignment.Center
    title.Parent = window
    
    -- Botão fechar
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseButton"
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -35, 0, 5)
    closeBtn.BackgroundColor3 = Color3.fromRGB(60, 0, 60)
    closeBtn.BorderSizePixel = 0
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Text = "×"
    closeBtn.TextColor3 = CONFIG.GUI_COLORS.ERROR
    closeBtn.TextSize = 20
    closeBtn.Parent = window
    
    local closeBtnCorner = Instance.new("UICorner")
    closeBtnCorner.CornerRadius = UDim.new(0, 6)
    closeBtnCorner.Parent = closeBtn
    
    -- Container principal
    local container = Instance.new("Frame")
    container.Name = "Container"
    container.Size = UDim2.new(1, -20, 1, -50)
    container.Position = UDim2.new(0, 10, 0, 40)
    container.BackgroundTransparency = 1
    container.Parent = window
    
    -- Botão toggle
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Name = "ToggleButton"
    toggleBtn.Size = UDim2.new(1, 0, 0, 45)
    toggleBtn.Position = UDim2.new(0, 0, 0, 0)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(120, 0, 40)
    toggleBtn.BorderSizePixel = 0
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.Text = "🚀 Ativar Stockfish Engine"
    toggleBtn.TextColor3 = CONFIG.GUI_COLORS.TEXT
    toggleBtn.TextSize = 16
    toggleBtn.Parent = container
    
    local toggleBtnCorner = Instance.new("UICorner")
    toggleBtnCorner.CornerRadius = UDim.new(0, 8)
    toggleBtnCorner.Parent = toggleBtn
    
    -- Status label
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "StatusLabel"
    statusLabel.Size = UDim2.new(1, 0, 0, 30)
    statusLabel.Position = UDim2.new(0, 0, 0, 55)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.Text = "Status: Engine desativado"
    statusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    statusLabel.TextSize = 14
    statusLabel.TextWrapped = true
    statusLabel.Parent = container
    
    -- Info label
    local infoLabel = Instance.new("TextLabel")
    infoLabel.Name = "InfoLabel"
    infoLabel.Size = UDim2.new(1, 0, 0, 40)
    infoLabel.Position = UDim2.new(0, 0, 0, 85)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.Text = "Depth: " .. CONFIG.STOCKFISH_DEPTH .. " | Erros: 0/" .. ScriptState.maxErrors
    infoLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    infoLabel.TextSize = 12
    infoLabel.TextWrapped = true
    infoLabel.Parent = container
    
    GUI.window = window
    GUI.toggleBtn = toggleBtn
    GUI.statusLabel = statusLabel
    GUI.infoLabel = infoLabel
    GUI.closeBtn = closeBtn
end

function GUI.createMiniBar()
    local miniBar = Instance.new("TextButton")
    miniBar.Name = "MiniBar"
    miniBar.Size = UDim2.new(0, 80, 0, 35)
    miniBar.Position = UDim2.new(0, 20, 0, 20)
    miniBar.BackgroundColor3 = CONFIG.GUI_COLORS.BACKGROUND
    miniBar.BorderSizePixel = 0
    miniBar.Text = "WHX ♛"
    miniBar.TextColor3 = CONFIG.GUI_COLORS.ACCENT
    miniBar.Font = Enum.Font.GothamBold
    miniBar.TextSize = 16
    miniBar.Visible = true
    miniBar.Parent = playerGui:FindFirstChild("WHXScript_GUI")
    
    local miniCorner = Instance.new("UICorner")
    miniCorner.CornerRadius = UDim.new(0, 8)
    miniCorner.Parent = miniBar
    
    GUI.miniBar = miniBar
end

function GUI.setupEventHandlers()
    -- Toggle button
    GUI.toggleBtn.MouseButton1Click:Connect(function()
        ScriptState.enabled = not ScriptState.enabled
        GUI.updateToggleButton()
        
        if not ScriptState.enabled then
            GUI.clearArrow()
        end
    end)
    
    -- Close button
    GUI.closeBtn.MouseButton1Click:Connect(function()
        GUI.window.Visible = false
        GUI.miniBar.Visible = true
    end)
    
    -- Mini bar click
    GUI.miniBar.MouseButton1Click:Connect(function()
        GUI.miniBar.Visible = false
        GUI.window.Visible = true
    end)
    
    -- Hover effects
    GUI.toggleBtn.MouseEnter:Connect(function()
        Utils.createTween(GUI.toggleBtn, TweenInfo.new(0.2), {
            BackgroundColor3 = ScriptState.enabled and Color3.fromRGB(0, 120, 0) or Color3.fromRGB(180, 0, 60)
        })
    end)
    
    GUI.toggleBtn.MouseLeave:Connect(function()
        Utils.createTween(GUI.toggleBtn, TweenInfo.new(0.2), {
            BackgroundColor3 = ScriptState.enabled and Color3.fromRGB(0, 90, 0) or Color3.fromRGB(120, 0, 40)
        })
    end)
end

function GUI.updateToggleButton()
    if ScriptState.enabled then
        GUI.toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 90, 0)
        GUI.toggleBtn.Text = "⏹️ Desativar Stockfish Engine"
        GUI.toggleBtn.TextColor3 = CONFIG.GUI_COLORS.SUCCESS
        GUI.statusLabel.Text = "Status: Engine ativo, analisando posições..."
        GUI.statusLabel.TextColor3 = CONFIG.GUI_COLORS.SUCCESS
    else
        GUI.toggleBtn.BackgroundColor3 = Color3.fromRGB(120, 0, 40)
        GUI.toggleBtn.Text = "🚀 Ativar Stockfish Engine"
        GUI.toggleBtn.TextColor3 = CONFIG.GUI_COLORS.TEXT
        GUI.statusLabel.Text = "Status: Engine desativado"
        GUI.statusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    end
end

function GUI.updateInfo()
    if GUI.infoLabel then
        GUI.infoLabel.Text = string.format("Depth: %d | Erros: %d/%d | FPS: %.1f", 
            CONFIG.STOCKFISH_DEPTH, 
            ScriptState.errorCount, 
            ScriptState.maxErrors,
            1/RunService.Heartbeat:Wait()
        )
    end
end

-- ===== MÓDULO PRINCIPAL =====
local Main = {}

function Main.init()
    print("[WHXScript] Inicializando Auto Chess Engine...")
    
    GUI.init()
    Main.setupMainLoop()
    
    print("[WHXScript] Engine inicializado com sucesso!")
end

function Main.setupMainLoop()
    RunService.Heartbeat:Connect(function()
        local currentTime = tick()
        
        -- Atualizar info da GUI
        GUI.updateInfo()
        
        -- Verificar se deve parar por muitos erros
        if ScriptState.errorCount >= ScriptState.maxErrors then
            if ScriptState.enabled then
                ScriptState.enabled = false
                GUI.updateToggleButton()
                GUI.statusLabel.Text = "Status: Desativado por muitos erros"
                GUI.statusLabel.TextColor3 = CONFIG.GUI_COLORS.ERROR
            end
            return
        end
        
        -- Executar lógica principal apenas se ativo e no intervalo correto
        if ScriptState.enabled and not ScriptState.checking and 
           (currentTime - ScriptState.lastUpdateTime) >= CONFIG.UPDATE_INTERVAL then
            
            Main.processChessPosition()
            ScriptState.lastUpdateTime = currentTime
        end
    end)
end

function Main.processChessPosition()
    ScriptState.checking = true
    
    local fen = ChessEngine.getFEN()
    
    if not fen then
        GUI.clearArrow()
        ScriptState.checking = false
        return
    end
    
    -- Só processar se a posição mudou
    if fen ~= ScriptState.lastFEN then
        ScriptState.lastFEN = fen
        
        local moveData = ChessEngine.getBestMove(fen)
        
        if moveData then
            ScriptState.lastMove = moveData
            GUI.updateArrow(moveData)
            
            -- Reset error count on success
            if ScriptState.errorCount > 0 then
                ScriptState.errorCount = math.max(0, ScriptState.errorCount - 1)
            end
        else
            GUI.clearArrow()
        end
    end
    
    ScriptState.checking = false
end

-- ===== INICIALIZAÇÃO =====
Main.init()

-- ===== CLEANUP =====
game.Players.PlayerRemoving:Connect(function(plr)
    if plr == player then
        GUI.clearArrow()
    end
end)
