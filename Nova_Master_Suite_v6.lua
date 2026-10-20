--[[
 NOVA MASTER SUITE v6.0 | FLING + GUARD + COUNTER
 Original combined implementation based on the NOVA FLING v5 and NOVA GUARD v2
 scripts in this project. Visual theme: RED / BLACK / GOLD + glass.

 USO: Para pruebas en entornos permitidos/tu propia experiencia Roblox.
 CLIENT: LocalScript (StarterPlayerScripts); un cliente no puede obligar al
 servidor a aplicar impulsos a carros/jugadores ajenos.
 SERVER: NOVA_Counter.server.lua se instala aparte SOLO en tu propio juego.
 La fuerza ORIGINAL de FLING v5 se conserva sin aumentar los numeros.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
assert(LocalPlayer, "NOVA MASTER SUITE necesita ejecutarse en un cliente de Roblox")

local ENV = (type(getgenv) == "function" and getgenv()) or _G
for _, key in ipairs({"NovaMasterSuiteV6", "NovaFlingV5", "NovaGuardMasterV2", "NovaGuardMasterV1"}) do
    local old = ENV[key]
    if type(old) == "table" and type(old.Destroy) == "function" then
        pcall(old.Destroy)
    end
end

local PRESETS = {
    ORIGINAL = { speed = 9e7, spin = 9e8, foot = 2.00, seat = 2.40, car = 3.15 },
    NORMAL  = { speed = 650, spin = 340, foot = 0.85, seat = 1.15, car = 1.55 },
    FUERTE  = { speed = 1350, spin = 760, foot = 1.05, seat = 1.55, car = 2.10 },
    ULTRA   = { speed = 2600, spin = 1300, foot = 1.25, seat = 1.90, car = 2.65 },
    TEORICO = { speed = 4700, spin = 2450, foot = 1.80, seat = 2.70, car = 3.85 },
}
local CONFIG = {
    leadMax = 0.13, maxLeadStuds = 15, betweenTargets = 0.10,
    betweenRounds = 0.30, maxTargetDistance = 20000, maxAssemblyBox = 155,
    maxConnectedParts = 250, updateTargetEvery = 0.18, recoveryFrames = 7,
}
local GUARD_CONFIG = {
    scanInterval = 0.11, attributionRadius = 24, dangerRadius = 13,
    maxSafeAge = 3, recoveryCooldown = 1.55, snapshotInterval = 0.3,
    modes = {
        SAFE = { selfSpeed = 175, selfSpin = 95, otherSpeed = 150, otherSpin = 105 },
        SMART = { selfSpeed = 105, selfSpin = 65, otherSpeed = 115, otherSpin = 75 },
        SENSITIVE = { selfSpeed = 75, selfSpin = 45, otherSpeed = 85, otherSpin = 55 },
    },
}

local State = {
    active = false, busy = false, destroyed = false, generation = 0,
    selected = {}, level = "ORIGINAL", connections = {}, rows = {},
    page = "FLING", minimized = false, hidden = false,
    guard = {
        enabled = true, recover = true, visual = true, mode = "SMART",
        attempts = 0, recoveries = 0, records = {}, marks = {}, tags = {},
        lastAttacker = nil, safeCFrame = nil, safeAt = 0,
        lastSnapshot = 0, lastRecovery = -1e6,
        lastVelocity = Vector3.zero, suppressUntil = 0,
    },
    counterEnabled = false,
}
ENV.NovaMasterSuiteV6 = State

local function track(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(State.connections, connection)
    return connection
end
local function create(className, props, parent)
    local instance = Instance.new(className)
    for key, value in pairs(props or {}) do instance[key] = value end
    instance.Parent = parent
    return instance
end
local function rounded(gui, radius)
    create("UICorner", {CornerRadius = UDim.new(0, radius or 10)}, gui)
    return gui
end
local function outlined(gui, color, alpha, width)
    create("UIStroke", {Color = color, Transparency = alpha or 0,
        Thickness = width or 1.1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, gui)
    return gui
end
local function gradient(gui, a, b, rotation)
    create("UIGradient", {Color = ColorSequence.new(a, b), Rotation = rotation or 0}, gui)
end
local C = {
    bg = Color3.fromRGB(9, 8, 11), glass = Color3.fromRGB(24, 17, 21),
    light = Color3.fromRGB(47, 27, 31), deepRed = Color3.fromRGB(85, 13, 19),
    red = Color3.fromRGB(221, 44, 55), redBright = Color3.fromRGB(255, 82, 94),
    gold = Color3.fromRGB(218, 173, 83), goldLight = Color3.fromRGB(254, 222, 149),
    ink = Color3.fromRGB(16, 14, 17), white = Color3.fromRGB(250, 242, 229),
    muted = Color3.fromRGB(180, 166, 153), green = Color3.fromRGB(111, 226, 150),
}

local screen = create("ScreenGui", {
    Name = "NOVA_MASTER_SUITE_v6", ResetOnSpawn = false,
    IgnoreGuiInset = true, DisplayOrder = 210, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, LocalPlayer:WaitForChild("PlayerGui"))
State.gui = screen
local FULL_W, FULL_H, MINI_W, MINI_H = 360, 446, 215, 48
local main = rounded(create("Frame", {
    Name = "MasterWindow", Size = UDim2.fromOffset(FULL_W, FULL_H),
    Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = C.bg, BackgroundTransparency = 0.07,
    BorderSizePixel = 0, Active = true, ClipsDescendants = true,
}, screen), 15)
outlined(main, C.gold, 0.08, 1.7)
gradient(main, C.glass, C.bg, 90)

local gloss = rounded(create("Frame", {
    BackgroundColor3 = C.white, BackgroundTransparency = 0.955,
    BorderSizePixel = 0, Position = UDim2.fromOffset(7, 7),
    Size = UDim2.new(1, -14, 0, 67), ZIndex = 1,
}, main), 13)
gradient(gloss, Color3.fromRGB(255, 225, 220), C.ink, 90)

local header = rounded(create("Frame", {
    Name = "Header", Size = UDim2.new(1, 0, 0, 49),
    BackgroundColor3 = C.deepRed, BorderSizePixel = 0, Active = true,
}, main), 14)
gradient(header, Color3.fromRGB(120, 19, 27), Color3.fromRGB(34, 12, 17), 0)
create("Frame", {
    Position = UDim2.new(0, 0, 1, -2), Size = UDim2.new(1, 0, 0, 2),
    BackgroundColor3 = C.gold, BorderSizePixel = 0,
}, header)
local brand = create("TextLabel", {
    Text = "NOVA  /  MASTER", Font = Enum.Font.GothamBlack, TextSize = 16,
    TextColor3 = C.white, TextXAlignment = Enum.TextXAlignment.Left,
    BackgroundTransparency = 1, Position = UDim2.fromOffset(13, 5),
    Size = UDim2.new(1, -108, 0, 22), ZIndex = 2,
}, header)
local subtitle = create("TextLabel", {
    Text = "FLING   •   GUARD   •   COUNTER    /    VI", Font = Enum.Font.GothamBold,
    TextSize = 9, TextColor3 = C.goldLight,
    TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
    Position = UDim2.fromOffset(14, 28), Size = UDim2.new(1, -100, 0, 13), ZIndex = 2,
}, header)
local function button(parent, text, pos, size, bg, textSize)
    local btn = rounded(create("TextButton", {
        Text = text, Position = pos, Size = size, BackgroundColor3 = bg or C.light,
        BorderSizePixel = 0, AutoButtonColor = true,
        TextColor3 = C.white, Font = Enum.Font.GothamBold,
        TextSize = textSize or 11, ZIndex = 4,
    }, parent), 8)
    outlined(btn, C.gold, 0.48, 0.85)
    return btn
end
local grip = create("TextButton", {
    Name = "Mover", Text = "", BackgroundTransparency = 1,
    Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, -87, 1, -2),
    Active = true, AutoButtonColor = false, ZIndex = 3,
}, header)
local miniButton = button(header, "–", UDim2.new(1, -79, 0, 9), UDim2.fromOffset(32, 30), C.ink, 18)
local closeButton = button(header, "×", UDim2.new(1, -42, 0, 9), UDim2.fromOffset(32, 30), C.deepRed, 18)

local tabs = create("Frame", {
    BackgroundTransparency = 1, Position = UDim2.fromOffset(11, 59),
    Size = UDim2.new(1, -22, 0, 34),
}, main)
local tabFling = button(tabs, "⚡ FLING", UDim2.fromOffset(0, 0), UDim2.new(1/3, -4, 1, 0), C.deepRed, 11)
local tabGuard = button(tabs, "◆ GUARD", UDim2.new(1/3, 2, 0, 0), UDim2.new(1/3, -4, 1, 0), C.ink, 11)
local tabCounter = button(tabs, "✦ COUNTER", UDim2.new(2/3, 4, 0, 0), UDim2.new(1/3, -4, 1, 0), C.ink, 10)

local function newPage(name)
    return create("Frame", {
        Name = name, Position = UDim2.fromOffset(11, 102),
        Size = UDim2.new(1, -22, 1, -150), BackgroundTransparency = 1,
        Visible = false,
    }, main)
end
local flingPage = newPage("Fling")
local guardPage = newPage("Guard")
local counterPage = newPage("Counter")
flingPage.Visible = true

local function textLabel(parent, value, pos, size, fontSize, color, bold, align)
    return create("TextLabel", {
        BackgroundTransparency = 1, Text = value, Position = pos, Size = size,
        TextColor3 = color or C.muted, Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextSize = fontSize or 11, TextXAlignment = align or Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, parent)
end
local function glassFrame(parent, pos, size)
    local frame = rounded(create("Frame", {
        BackgroundColor3 = C.glass, BackgroundTransparency = 0.17,
        BorderSizePixel = 0, Position = pos, Size = size,
    }, parent), 10)
    outlined(frame, C.gold, 0.55, 1)
    return frame
end

-- Bottom line stays visible on every page.
local statusBar = glassFrame(main, UDim2.new(0, 11, 1, -38), UDim2.new(1, -22, 0, 29))
local statusText = textLabel(statusBar, "SISTEMA LISTO", UDim2.fromOffset(10, 0), UDim2.new(1, -88, 1, 0), 10, C.muted, true)
local statusChip = rounded(create("TextLabel", {
    Position = UDim2.new(1, -70, 0, 5), Size = UDim2.fromOffset(60, 19),
    Text = "READY", TextSize = 9, Font = Enum.Font.GothamBlack,
    TextColor3 = C.goldLight, BackgroundColor3 = C.deepRed, BorderSizePixel = 0,
}, statusBar), 6)
local function countSelected()
    local count = 0
    for _, value in pairs(State.selected) do if value then count += 1 end end
    return count
end
local function setStatus(message)
    if State.destroyed then return end
    statusChip.Text = State.active and "LIVE" or State.busy and "WAIT" or "READY"
    statusChip.TextColor3 = State.active and C.green or C.goldLight
    statusText.Text = message or ((State.active and "FLING ACTIVO" or "LISTO") .. "  ·  " .. countSelected() .. " objetivos")
end

-- FLING controls + live player list.
textLabel(flingPage, "OBJETIVOS", UDim2.fromOffset(2, 0), UDim2.fromOffset(180, 22), 12, C.goldLight, true)
local search = rounded(create("TextBox", {
    Position = UDim2.fromOffset(0, 25), Size = UDim2.new(1, 0, 0, 32),
    BackgroundColor3 = C.glass, BorderSizePixel = 0,
    PlaceholderText = "Buscar usuario o nombre...", PlaceholderColor3 = C.muted,
    Text = "", ClearTextOnFocus = false,
    TextSize = 12, TextColor3 = C.white, Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
}, flingPage), 9)
outlined(search, C.gold, 0.55)
create("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 8)}, search)
local playerList = rounded(create("ScrollingFrame", {
    Position = UDim2.fromOffset(0, 64), Size = UDim2.new(1, 0, 0, 124),
    BorderSizePixel = 0, BackgroundColor3 = C.ink,
    CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 4,
    ScrollBarImageColor3 = C.gold,
}, flingPage), 10)
create("UIPadding", {PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6),
    PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5)}, playerList)
create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4)}, playerList)
local chooseAll = button(flingPage, "◎ TODOS", UDim2.fromOffset(0, 194), UDim2.new(0.5, -4, 0, 29), C.light)
local chooseNone = button(flingPage, "○ NINGUNO", UDim2.new(0.5, 4, 0, 194), UDim2.new(0.5, -4, 0, 29), C.light)
local power = button(flingPage, "POTENCIA  ◆ ORIGINAL", UDim2.fromOffset(0, 230), UDim2.new(1, 0, 0, 30), C.deepRed)
local flingStart = button(flingPage, "▶  ACTIVAR", UDim2.fromOffset(0, 267), UDim2.new(0.5, -4, 0, 35), C.deepRed)
local flingStop = button(flingPage, "■  DETENER", UDim2.new(0.5, 4, 0, 267), UDim2.new(0.5, -4, 0, 35), C.ink)

-- GUARD controls.
textLabel(guardPage, "DEFENSA INTELIGENTE", UDim2.fromOffset(2, 0), UDim2.new(1, 0, 0, 22), 12, C.goldLight, true)
local guardInfo = glassFrame(guardPage, UDim2.fromOffset(0, 27), UDim2.new(1, 0, 0, 70))
local guardMessage = textLabel(guardInfo, "● PROTECCIÓN ACTIVA", UDim2.fromOffset(12, 7), UDim2.new(1, -24, 0, 23), 13, C.green, true)
local guardThreat = textLabel(guardInfo, "Amenaza: ninguna", UDim2.fromOffset(12, 32), UDim2.new(1, -24, 0, 24), 11, C.muted)
local guardToggle = button(guardPage, "GUARD: ON", UDim2.fromOffset(0, 106), UDim2.new(0.5, -4, 0, 36), C.deepRed)
local recoverToggle = button(guardPage, "RECOVER: ON", UDim2.new(0.5, 4, 0, 106), UDim2.new(0.5, -4, 0, 36), C.deepRed)
local modeToggle = button(guardPage, "MODO: SMART", UDim2.fromOffset(0, 149), UDim2.new(0.5, -4, 0, 36), C.light)
local espToggle = button(guardPage, "ESP: ON", UDim2.new(0.5, 4, 0, 149), UDim2.new(0.5, -4, 0, 36), C.light)
local guardStats = glassFrame(guardPage, UDim2.fromOffset(0, 194), UDim2.new(1, 0, 0, 46))
local guardStatsLabel = textLabel(guardStats, "Amenazas 0  •  Recuperaciones 0", UDim2.fromOffset(12, 4), UDim2.new(1, -24, 1, -8), 11, C.goldLight, true)
local panicButton = button(guardPage, "⟲  RECUPERAR", UDim2.fromOffset(0, 248), UDim2.new(0.5, -4, 0, 38), C.deepRed)
local clearButton = button(guardPage, "LIMPIAR ALERTAS", UDim2.new(0.5, 4, 0, 248), UDim2.new(0.5, -4, 0, 38), C.ink)

-- COUNTER: integrated control, server-authoritative, only in your own experience.
textLabel(counterPage, "COUNTER / REVENGE CORE", UDim2.fromOffset(2, 0), UDim2.new(1, 0, 0, 22), 12, C.goldLight, true)
local counterInfo = glassFrame(counterPage, UDim2.fromOffset(0, 29), UDim2.new(1, 0, 0, 100))
local counterStatus = textLabel(counterInfo, "Servidor: no detectado", UDim2.fromOffset(11, 8), UDim2.new(1, -22, 0, 22), 12, C.goldLight, true)
local counterHint = textLabel(counterInfo, "Solo para experiencias que controlas.", UDim2.fromOffset(11, 33), UDim2.new(1, -22, 0, 30), 11, C.muted)
local counterDetail = textLabel(counterInfo, "Requiere NOVA_Counter.server.lua", UDim2.fromOffset(11, 70), UDim2.new(1, -22, 0, 20), 10, C.muted)
local counterToggle = button(counterPage, "COUNTER: NO DISPONIBLE", UDim2.fromOffset(0, 140), UDim2.new(1, 0, 0, 40), C.ink)
local counterSteps = glassFrame(counterPage, UDim2.fromOffset(0, 192), UDim2.new(1, 0, 0, 100))
textLabel(counterSteps, "1  Detecta aproximaciones rápidas", UDim2.fromOffset(12, 7), UDim2.new(1, -24, 0, 24), 11, C.white)
textLabel(counterSteps, "2  Reproduce el efecto del golpe", UDim2.fromOffset(12, 34), UDim2.new(1, -24, 0, 24), 11, C.white)
textLabel(counterSteps, "3  Impulsa desde el servidor", UDim2.fromOffset(12, 62), UDim2.new(1, -24, 0, 24), 11, C.white)

local function choosePage(page)
    State.page = page
    flingPage.Visible = page == "FLING"
    guardPage.Visible = page == "GUARD"
    counterPage.Visible = page == "COUNTER"
    tabFling.BackgroundColor3 = page == "FLING" and C.deepRed or C.ink
    tabGuard.BackgroundColor3 = page == "GUARD" and C.deepRed or C.ink
    tabCounter.BackgroundColor3 = page == "COUNTER" and C.deepRed or C.ink
end
track(tabFling.MouseButton1Click, function() choosePage("FLING") end)
track(tabGuard.MouseButton1Click, function() choosePage("GUARD") end)
track(tabCounter.MouseButton1Click, function() choosePage("COUNTER") end)

local function refreshList()
    if State.destroyed then return end
    for _, connection in ipairs(State.rows) do connection:Disconnect() end
    table.clear(State.rows)
    for _, child in ipairs(playerList:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    local filter = search.Text:lower()
    local players = Players:GetPlayers()
    table.sort(players, function(a, b) return a.Name:lower() < b.Name:lower() end)
    local order = 0
    for _, player in ipairs(players) do
        if player ~= LocalPlayer and (filter == "" or player.Name:lower():find(filter, 1, true)
            or player.DisplayName:lower():find(filter, 1, true)) then
            order += 1
            local chosen = State.selected[player.UserId] == true
            local row = button(playerList,
                (chosen and "  [✓]  " or "  [ ]  ") .. player.DisplayName .. "  @" .. player.Name,
                UDim2.new(), UDim2.new(1, -3, 0, 28), chosen and C.deepRed or C.light)
            row.LayoutOrder = order
            row.TextXAlignment = Enum.TextXAlignment.Left
            row.TextTruncate = Enum.TextTruncate.AtEnd
            table.insert(State.rows, row.MouseButton1Click:Connect(function()
                State.selected[player.UserId] = not State.selected[player.UserId] or nil
                refreshList()
                setStatus()
            end))
        end
    end
end

-- FLING engine preserved from NOVA FLING v5, including ORIGINAL values.
local function findSeat(humanoid, root, character)
    local direct = humanoid.SeatPart
    if direct and direct:IsA("BasePart") then return direct end
    if not humanoid.Sit then return nil end
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { character }
    params.MaxParts = 95
    local ok, near = pcall(function()
        return workspace:GetPartBoundsInRadius(root.Position, 17, params)
    end)
    if not ok then return nil end
    for _, part in ipairs(near) do
        if part:IsA("Seat") or part:IsA("VehicleSeat") then
            if part.Occupant == humanoid then return part end
            local weld = part:FindFirstChild("SeatWeld")
            if weld and weld:IsA("Weld") and (
                (weld.Part0 and weld.Part0:IsDescendantOf(character))
                or (weld.Part1 and weld.Part1:IsDescendantOf(character))
            ) then return part end
        end
    end
    return nil
end

local function findVehicleModel(seat)
    if not seat then return nil end
    local candidate = seat.Parent
    while candidate and candidate ~= workspace do
        if candidate:IsA("Model") and candidate:FindFirstChildWhichIsA("VehicleSeat", true) then
            return candidate
        end
        candidate = candidate.Parent
    end
    return nil
end

-- Componentes unidos por joints: mas significativo que la caja de un Model con
-- accesorios, scripts, piezas ancladas o plataformas ajenas al carro.
local boundsCache = setmetatable({}, { __mode = "k" })
local function getConnectedBounds(seat, ignoredCharacter)
    if not seat then return nil end
    local assembly = seat.AssemblyRootPart or seat
    -- Algunos asientos hacen del HRP del ocupante el AssemblyRootPart;
    -- no queremos construir un hitbox alrededor del personaje en ese caso.
    if assembly:IsDescendantOf(ignoredCharacter) then assembly = seat end
    if not assembly or assembly.Anchored then return nil end
    local cached = boundsCache[seat]
    if cached and cached.root == assembly and os.clock() - cached.at < 1.15 then
        return cached.bounds
    end
    local parts = { assembly }
    local ok, connected = pcall(function() return assembly:GetConnectedParts(true) end)
    if ok then
        for i, part in ipairs(connected) do
            if i > CONFIG.maxConnectedParts then break end
            if part:IsA("BasePart") and part ~= assembly and not part:IsDescendantOf(ignoredCharacter) then
                table.insert(parts, part)
            end
        end
    end
    local reference = assembly.CFrame
    local minX, minY, minZ = math.huge, math.huge, math.huge
    local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
    local eligible = 0
    for _, part in ipairs(parts) do
        if part.Parent and not part:IsDescendantOf(ignoredCharacter) then
            eligible += 1
            -- Eight corners of each bounding part expressed in the assembly frame.
            local half = part.Size * 0.5
            for _, sx in ipairs({-1, 1}) do
                for _, sy in ipairs({-1, 1}) do
                    for _, sz in ipairs({-1, 1}) do
                        local point = reference:PointToObjectSpace(part.CFrame:PointToWorldSpace(
                            Vector3.new(sx * half.X, sy * half.Y, sz * half.Z)))
                        minX, maxX = math.min(minX, point.X), math.max(maxX, point.X)
                        minY, maxY = math.min(minY, point.Y), math.max(maxY, point.Y)
                        minZ, maxZ = math.min(minZ, point.Z), math.max(maxZ, point.Z)
                    end
                end
            end
        end
    end
    if eligible == 0 then return nil end
    local size = Vector3.new(maxX-minX, maxY-minY, maxZ-minZ)
    if size.Magnitude > CONFIG.maxAssemblyBox then return nil end
    local bounds = {
        root = assembly,
        localCenter = Vector3.new((maxX+minX)/2, (maxY+minY)/2, (maxZ+minZ)/2),
        half = size * 0.5,
    }
    boundsCache[seat] = { root = assembly, bounds = bounds, at = os.clock() }
    return bounds
end

local function resolveTarget(player)
    if player == LocalPlayer or player.Parent ~= Players then return nil end
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and (character:FindFirstChild("HumanoidRootPart") or (humanoid and humanoid.RootPart))
    if not (humanoid and root and root:IsA("BasePart") and humanoid.Health > 0) then return nil end
    local seat = findSeat(humanoid, root, character)
    local vehicle = findVehicleModel(seat)
    local isCar = seat and (seat:IsA("VehicleSeat") or vehicle ~= nil)
    local mode = isCar and "CARRO" or seat and "ASIENTO" or humanoid.Sit and "SENTADO" or "A PIE"
    local bounds = seat and getConnectedBounds(seat, character) or nil
    local focus = bounds and bounds.root or seat or root
    return {
        player = player, character = character, humanoid = humanoid,
        root = root, seat = seat, vehicle = vehicle,
        focus = focus, mode = mode, bounds = bounds,
    }
end

local function getSelf()
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not (humanoid and root and humanoid.Health > 0 and not root.Anchored) then return nil end
    local assemblyRoot = root.AssemblyRootPart
    if assemblyRoot and assemblyRoot.Anchored then return nil end
    return character, humanoid, root
end

local function restore(character, humanoid, root, pivot, oldPlatformStand, oldAutoRotate)
    if not (character and character.Parent and humanoid and humanoid.Parent and root and root.Parent) then return end
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    for _ = 1, CONFIG.recoveryFrames do
        if not (character.Parent and root.Parent) then break end
        character:PivotTo(pivot * CFrame.new(0, 0.7, 0))
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        RunService.Heartbeat:Wait()
    end
    humanoid.PlatformStand = oldPlatformStand
    humanoid.AutoRotate = oldAutoRotate
    if not oldPlatformStand and humanoid.Health > 0 then
        humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
end

-- Recorrido de contacto alrededor del ensamblaje: laterales, morro, cola,
-- diagonales y alternancia de altura. La caja gira junto a la pieza de origen.
local function contactPoint(target, step, lead)
    local phase = step * 0.51
    local bounds = target.bounds
    if bounds and bounds.root and bounds.root.Parent and not bounds.root.Anchored then
        local frame = bounds.root.CFrame
        local half = bounds.half
        local ox = math.max(1.0, half.X)
        local oz = math.max(1.0, half.Z)
        local oy = math.max(0.6, math.min(2.5, half.Y * 0.35))
        local choice = (step - 1) % 12
        local x, z
        if choice == 0 then x, z = ox + 0.30, 0
        elseif choice == 1 then x, z = -(ox + 0.30), 0
        elseif choice == 2 then x, z = 0, oz + 0.30
        elseif choice == 3 then x, z = 0, -(oz + 0.30)
        elseif choice == 4 then x, z = ox * 0.85, oz * 0.85
        elseif choice == 5 then x, z = -ox * 0.85, oz * 0.85
        elseif choice == 6 then x, z = ox * 0.85, -oz * 0.85
        elseif choice == 7 then x, z = -ox * 0.85, -oz * 0.85
        elseif choice == 8 then x, z = ox + 0.12, oz * 0.4
        elseif choice == 9 then x, z = -(ox + 0.12), -oz * 0.4
        elseif choice == 10 then x, z = ox * 0.4, oz + 0.12
        else x, z = -ox * 0.4, -(oz + 0.12) end
        local y = (choice % 3 == 0 and -oy) or (choice % 3 == 1 and oy) or 0
        local localOffset = bounds.localCenter + Vector3.new(x, y, z)
        local origin = frame:PointToWorldSpace(localOffset) + lead
        local center = frame:PointToWorldSpace(bounds.localCenter) + lead
        return origin, center, phase
    end
    local focus = target.focus
    local center = focus.Position + lead
    local radius = target.mode == "A PIE" and 1.2 or target.mode == "CARRO" and 3.2 or 1.75
    local y = ((step % 4) < 2) and 1.2 or -0.8
    local angle = step * 1.36
    local origin = center + Vector3.new(math.cos(angle) * radius, y, math.sin(angle) * radius)
    return origin, center, phase
end

local function attempt(targetPlayer, generation)
    local character, humanoid, root = getSelf()
    local target = resolveTarget(targetPlayer)
    if not character or not target then return end
    if humanoid.Sit then setStatus("Levántate de tu asiento antes de iniciar") return end
    local startPivot = character:GetPivot()
    local oldPlatformStand, oldAutoRotate = humanoid.PlatformStand, humanoid.AutoRotate
    local level = State.level -- Freeze settings throughout one attempt.
    local preset = PRESETS[level]
    local holdVelocity
    if level == "ORIGINAL" then
        -- K1LAS1K's original force magnitudes: 9e7 / 9e8, with a 9e9 BodyVelocity.
        -- These are LOCAL simulation writes, not a bypass of server ownership.
        holdVelocity = Instance.new("BodyVelocity")
        holdVelocity.Name = "NovaOriginalForce"
        holdVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        holdVelocity.Velocity = Vector3.zero
        holdVelocity.Parent = root
    end
    local seconds = (target.mode == "CARRO") and preset.car
        or ((target.mode == "ASIENTO" or target.mode == "SENTADO") and preset.seat or preset.foot)
    local started = os.clock()
    local ok, err = xpcall(function()
        humanoid.PlatformStand = true
        humanoid.AutoRotate = false
        local step = 0
        local lastResolve = os.clock()
        while State.active and State.generation == generation and os.clock() - started <= seconds do
            if targetPlayer.Character ~= target.character or target.humanoid.Health <= 0 then break end
            if not (root.Parent and target.focus.Parent and humanoid.Health > 0) then break end
            if (target.focus.Position - startPivot.Position).Magnitude > CONFIG.maxTargetDistance then break end
            -- Re-clasifica cada pocas decimas, por si se baja, cambia de asiento o carro.
            if os.clock() - lastResolve >= CONFIG.updateTargetEvery then
                local updated = resolveTarget(targetPlayer)
                if not updated or updated.character ~= target.character then break end
                target = updated
                lastResolve = os.clock()
            end
            local anchorRoot = target.focus.AssemblyRootPart
            if target.focus.Anchored or (anchorRoot and anchorRoot.Anchored) then
                setStatus("OBJETIVO ANCLADO: fisica no desplazable")
                break
            end
            step += 1
            local velocity = target.focus.AssemblyLinearVelocity
            local elapsed = os.clock() - started
            local predicted = math.clamp(0.018 + velocity.Magnitude / 4200, 0.014, CONFIG.leadMax)
            local lead = velocity * predicted
            if lead.Magnitude > CONFIG.maxLeadStuds then lead = lead.Unit * CONFIG.maxLeadStuds end
            local origin, center, angle = contactPoint(target, step, lead)
            if origin.Y < workspace.FallenPartsDestroyHeight + 12 then break end
            character:PivotTo(CFrame.new(origin) * CFrame.Angles(angle, angle * 0.65, angle * 0.35))
            local direction = center - origin
            if direction.Magnitude < 0.05 then direction = Vector3.yAxis end
            -- Alternar impulso entrante/saliente en pasos cortos para ensayar
            -- contactos con partes de distintas formas y tamaños.
            local sign = (step % 6 == 0) and -1 or 1
            local fraction = (level == "TEORICO" and elapsed < 0.3) and 0.85 or 1.0
            if level == "ORIGINAL" then
                -- Exact original linear XYZ (90M, 900M, 90M) and angular XYZ (900M).
                root.AssemblyLinearVelocity = Vector3.new(9e7, 9e8, 9e7)
                root.AssemblyAngularVelocity = Vector3.new(9e8, 9e8, 9e8)
            else
                root.AssemblyLinearVelocity = direction.Unit * (sign * preset.speed * fraction)
                root.AssemblyAngularVelocity = Vector3.new(preset.spin, preset.spin * 0.65, preset.spin)
            end
            RunService.Heartbeat:Wait()
        end
    end, function(message) return tostring(message) end)
    if holdVelocity then holdVelocity:Destroy() end
    local recovered, recoveryError = pcall(restore, character, humanoid, root, startPivot, oldPlatformStand, oldAutoRotate)
    if not ok then warn("[NOVA MASTER SUITE v6] " .. tostring(err)) end
    if not recovered then warn("[NOVA MASTER SUITE v6 restore] " .. tostring(recoveryError)) end
end

local function run(generation)
    while State.active and State.generation == generation do
        local targets = {}
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and State.selected[player.UserId] then
                table.insert(targets, player)
            end
        end
        if #targets == 0 then break end
        for _, player in ipairs(targets) do
            if not State.active or State.generation ~= generation then break end
            local target = resolveTarget(player)
            if target then
                setStatus("OBJETIVO: @" .. player.Name .. "  •  " .. target.mode .. "  •  " .. State.level)
                attempt(player, generation)
            end
            task.wait(CONFIG.betweenTargets)
        end
        task.wait(CONFIG.betweenRounds)
    end
end

local function stopFling()
    State.active = false
    State.generation += 1
    setStatus(State.busy and "DETENIENDO / RECUPERANDO..." or nil)
end

-- GUI actions for FLING.
local function beginFling()
    if State.busy then setStatus("RECUPERANDO: espera a terminar") return end
    if countSelected() == 0 then setStatus("SELECCIONA UN OBJETIVO") return end
    local character, humanoid = getSelf()
    if not character then setStatus("PERSONAJE NO DISPONIBLE") return end
    if humanoid.Sit then setStatus("LEVÁNTATE DEL ASIENTO") return end
    State.active, State.busy = true, true
    State.guard.suppressUntil = math.huge -- Guard must not fight the fling worker.
    State.generation += 1
    local generation = State.generation
    task.spawn(function()
        local ok, err = xpcall(function() run(generation) end, function(e) return tostring(e) end)
        State.active, State.busy = false, false
        State.guard.suppressUntil = os.clock() + 2.0
        State.guard.lastVelocity = Vector3.zero
        if not ok then warn("[NOVA MASTER SUITE Worker] " .. tostring(err)) end
        setStatus()
    end)
    setStatus("FLING ACTIVADO  ·  ORIGINAL: " .. tostring(State.level == "ORIGINAL"))
end
track(flingStart.MouseButton1Click, beginFling)
track(flingStop.MouseButton1Click, stopFling)
track(power.MouseButton1Click, function()
    local levels = {"ORIGINAL", "NORMAL", "FUERTE", "ULTRA", "TEORICO"}
    local index = table.find(levels, State.level) or 1
    State.level = levels[(index % #levels) + 1]
    power.Text = "POTENCIA  ◆ " .. State.level
end)
track(chooseAll.MouseButton1Click, function()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then State.selected[player.UserId] = true end
    end
    refreshList()
    setStatus()
end)
track(chooseNone.MouseButton1Click, function()
    table.clear(State.selected)
    refreshList()
    setStatus()
end)
track(search:GetPropertyChangedSignal("Text"), refreshList)
track(Players.PlayerAdded, refreshList)
track(LocalPlayer.CharacterRemoving, function()
    stopFling()
    local g = State.guard
    g.safeCFrame = nil; g.safeAt = 0; g.lastVelocity = Vector3.zero
end)
track(LocalPlayer.CharacterAdded, function()
    local g = State.guard
    g.safeCFrame = nil; g.safeAt = 0; g.lastVelocity = Vector3.zero
end)

-- Unified GUARD monitor. Avoid conflicting with FLING's teleport / high velocities.
local g = State.guard
local function guardSelf()
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
        return root, humanoid
    end
end
local function otherRoot(player)
    if player == LocalPlayer then return end
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
        return root, humanoid
    end
end
local function clearMark(player)
    if g.marks[player] then g.marks[player]:Destroy(); g.marks[player] = nil end
    if g.tags[player] then g.tags[player]:Destroy(); g.tags[player] = nil end
end
local function mark(player)
    if not g.visual then return end
    local char = player.Character
    local root = otherRoot(player)
    if not char or not root then return end
    if not g.marks[player] or g.marks[player].Adornee ~= char then
        clearMark(player)
        g.marks[player] = create("Highlight", {
            Adornee = char, Name = "NOVA_MASTER_ALERT", DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
            FillColor = C.red, FillTransparency = 0.77,
            OutlineColor = C.goldLight, OutlineTransparency = 0.06,
        }, screen)
    end
    if not g.tags[player] then
        local tag = create("BillboardGui", {
            Adornee = root, AlwaysOnTop = true, Size = UDim2.fromOffset(145, 27),
            StudsOffsetWorldSpace = Vector3.new(0, 3.3, 0),
        }, screen)
        create("TextLabel", {
            Name = "Counter", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
            Font = Enum.Font.GothamBlack, TextSize = 11, TextColor3 = C.goldLight,
            TextStrokeTransparency = 0.28, Text = "",
        }, tag)
        g.tags[player] = tag
    end
    local record = g.records[player.UserId]
    local label = g.tags[player]:FindFirstChild("Counter")
    if label then label.Text = "⚠ AMENAZA ×" .. tostring(record and record.count or 1) end
end
local function renderGuard()
    guardMessage.Text = g.enabled and "● PROTECCIÓN ACTIVA" or "● PROTECCIÓN PAUSADA"
    guardMessage.TextColor3 = g.enabled and C.green or C.redBright
    guardToggle.Text = g.enabled and "GUARD: ON" or "GUARD: OFF"
    recoverToggle.Text = g.recover and "RECOVER: ON" or "RECOVER: OFF"
    modeToggle.Text = "MODO: " .. g.mode
    espToggle.Text = g.visual and "ESP: ON" or "ESP: OFF"
    guardToggle.BackgroundColor3 = g.enabled and C.deepRed or C.ink
    recoverToggle.BackgroundColor3 = g.recover and C.deepRed or C.ink
    espToggle.BackgroundColor3 = g.visual and C.deepRed or C.ink
    guardStatsLabel.Text = string.format("Amenazas %d   •   Recuperaciones %d", g.attempts, g.recoveries)
end
local function registerThreat(player)
    local now = os.clock()
    local uid = player.UserId
    local record = g.records[uid] or {count = 0, last = -math.huge}
    if now - record.last < 0.95 then return end
    record.last = now; record.count += 1
    g.records[uid] = record; g.attempts += 1; g.lastAttacker = player
    guardThreat.Text = "Amenaza: @" .. player.Name .. "  ×" .. record.count
    mark(player)
    renderGuard()
end
local function findThreat(root, cfg)
    local chosen, best = nil, -math.huge
    for _, player in ipairs(Players:GetPlayers()) do
        local oroot, ohum = otherRoot(player)
        if oroot then
            local delta = root.Position - oroot.Position
            local distance = delta.Magnitude
            if distance > 0.1 and distance < GUARD_CONFIG.attributionRadius then
                local velocity = oroot.AssemblyLinearVelocity
                local speed = velocity.Magnitude
                local spin = oroot.AssemblyAngularVelocity.Magnitude
                local approaching = speed > 0.01 and velocity.Unit:Dot(delta.Unit) or 0
                local suspicious = speed >= cfg.otherSpeed or spin >= cfg.otherSpin
                if ohum.Sit then suspicious = suspicious and spin > cfg.otherSpin * 1.8 end
                if suspicious and (distance < GUARD_CONFIG.dangerRadius or approaching > 0.35) then
                    local score = math.min(500, speed) * 0.012 + spin * 0.05 + approaching * 2 - distance * 0.09
                    if score > best then best = score; chosen = player end
                end
            end
        end
    end
    return chosen
end
local function saveSafe(root, humanoid, now, speed, spin)
    if humanoid.Sit or humanoid.SeatPart or humanoid.FloorMaterial == Enum.Material.Air then return end
    if speed > 27 or spin > 20 then return end
    if now - g.lastSnapshot < GUARD_CONFIG.snapshotInterval then return end
    g.lastSnapshot = now; g.safeCFrame = root.CFrame; g.safeAt = now
end
local function tryRecover(root, humanoid, now)
    if State.busy or State.active or now < g.suppressUntil then return false end
    if humanoid.Sit or humanoid.SeatPart then return false end
    if now - g.lastRecovery < GUARD_CONFIG.recoveryCooldown then return false end
    if not g.safeCFrame or now - g.safeAt > GUARD_CONFIG.maxSafeAge then return false end
    g.lastRecovery = now
    local ok = pcall(function()
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
        root.CFrame = g.safeCFrame + Vector3.new(0, 2, 0)
    end)
    if ok then g.recoveries += 1; renderGuard() end
    return ok
end
local scanAccum = 0
track(RunService.Heartbeat, function(dt)
    if State.destroyed or not g.enabled or State.busy or State.active or os.clock() < g.suppressUntil then return end
    scanAccum += math.min(dt, 0.2)
    if scanAccum < GUARD_CONFIG.scanInterval then return end
    scanAccum = 0
    local root, humanoid = guardSelf()
    if not root then return end
    local now = os.clock()
    local cfg = GUARD_CONFIG.modes[g.mode]
    local vel = root.AssemblyLinearVelocity
    local speed = vel.Magnitude
    local spin = root.AssemblyAngularVelocity.Magnitude
    local deltaV = (vel - g.lastVelocity).Magnitude
    g.lastVelocity = vel
    local threat = findThreat(root, cfg)
    if threat then registerThreat(threat) end
    local flung = speed >= cfg.selfSpeed or spin >= cfg.selfSpin
    local spike = deltaV >= cfg.selfSpeed * 0.9 and speed >= cfg.selfSpeed * 0.65
    if flung or spike then
        if g.recover and tryRecover(root, humanoid, now) then
            setStatus("GUARD  ·  RECUPERACIÓN EJECUTADA")
        end
    else
        saveSafe(root, humanoid, now, speed, spin)
    end
end)
track(guardToggle.MouseButton1Click, function()
    g.enabled = not g.enabled
    g.lastVelocity = Vector3.zero
    renderGuard()
end)
track(recoverToggle.MouseButton1Click, function()
    g.recover = not g.recover
    renderGuard()
end)
track(modeToggle.MouseButton1Click, function()
    local modes = {"SAFE", "SMART", "SENSITIVE"}
    g.mode = modes[((table.find(modes, g.mode) or 2) % #modes) + 1]
    renderGuard()
end)
track(espToggle.MouseButton1Click, function()
    g.visual = not g.visual
    if not g.visual then
        for player in pairs(g.marks) do clearMark(player) end
    else
        for _, player in ipairs(Players:GetPlayers()) do
            if g.records[player.UserId] then mark(player) end
        end
    end
    renderGuard()
end)
track(panicButton.MouseButton1Click, function()
    local root, hum = guardSelf()
    local now = os.clock()
    if root and hum and tryRecover(root, hum, now) then
        setStatus("PANIC  ·  RECUPERADO")
    else
        setStatus("PANIC  ·  SIN PUNTO SEGURO DISPONIBLE")
    end
end)
track(clearButton.MouseButton1Click, function()
    for player in pairs(g.marks) do clearMark(player) end
    for player in pairs(g.tags) do clearMark(player) end
    g.records = {}; g.attempts = 0; g.recoveries = 0; g.lastAttacker = nil
    guardThreat.Text = "Amenaza: ninguna"
    renderGuard()
end)

-- Counter only operates when an optional, server-owned companion exists.
local counterFolder, toggleRemote, statusRemote
local boundStatusRemote = nil
local function updateCounterUI()
    local available = toggleRemote and toggleRemote:IsA("RemoteEvent")
    counterToggle.Text = available and (State.counterEnabled and "COUNTER: ON" or "COUNTER: OFF") or "COUNTER: NO DISPONIBLE"
    counterStatus.Text = available and "Servidor: módulo detectado" or "Servidor: no detectado"
    counterHint.Text = available and "Servidor valida distancia y velocidad." or "Solo funciona en tu propio juego."
    counterToggle.BackgroundColor3 = available and (State.counterEnabled and C.deepRed or C.light) or C.ink
end
local function bindStatus(event)
    if not event or not event:IsA("RemoteEvent") or event == boundStatusRemote then return end
    boundStatusRemote = event
    track(event.OnClientEvent, function(message)
        if State.destroyed or event ~= statusRemote then return end
        if message == "ON" or message == "OFF" then
            State.counterEnabled = (message == "ON")
            updateCounterUI()
        elseif message == "TRIGGERED" then
            setStatus("COUNTER  ·  CONTRAATAQUE ACTIVADO")
        end
    end)
end
local function findCounterModules()
    local folder = ReplicatedStorage:FindFirstChild("NOVA_Counter")
    counterFolder = folder
    toggleRemote = folder and folder:FindFirstChild("Toggle")
    statusRemote = folder and folder:FindFirstChild("Status")
    bindStatus(statusRemote)
    updateCounterUI()
end
track(ReplicatedStorage.ChildAdded, function(child)
    if child.Name == "NOVA_Counter" then findCounterModules() end
end)
track(ReplicatedStorage.ChildRemoved, function(child)
    if child == counterFolder then
        State.counterEnabled = false
        findCounterModules()
    end
end)
local folderEvents = nil
local function watchCounterFolder()
    if folderEvents then
        for _, conn in ipairs(folderEvents) do conn:Disconnect() end
    end
    folderEvents = {}
    local folder = ReplicatedStorage:FindFirstChild("NOVA_Counter")
    if folder then
        table.insert(folderEvents, track(folder.ChildAdded, findCounterModules))
        table.insert(folderEvents, track(folder.ChildRemoved, findCounterModules))
    end
    findCounterModules()
end
track(ReplicatedStorage.ChildAdded, function(child)
    if child.Name == "NOVA_Counter" then watchCounterFolder() end
end)
watchCounterFolder()
track(counterToggle.MouseButton1Click, function()
    if not toggleRemote or not toggleRemote:IsA("RemoteEvent") then
        setStatus("COUNTER NECESITA SERVIDOR PROPIO")
        return
    end
    -- Server acknowledges the state; do not claim it worked until then.
    toggleRemote:FireServer(not State.counterEnabled)
    counterHint.Text = "Esperando confirmación del servidor..."
end)
track(Players.PlayerRemoving, function(player)
    State.selected[player.UserId] = nil
    clearMark(player)
    g.records[player.UserId] = nil
    if g.lastAttacker == player then g.lastAttacker = nil end
    task.defer(function()
        if not State.destroyed then refreshList(); setStatus() end
    end)
end)

-- UI movement: mouse/touch anywhere inside the header grip, to all screen edges.
local function viewport()
    local camera = workspace.CurrentCamera
    return camera and camera.ViewportSize or Vector2.new(800, 600)
end
local uiScale = create("UIScale", {Scale = 1}, main)
local function fitScale()
    local vp = viewport()
    local w = State.minimized and MINI_W or FULL_W
    local h = State.minimized and MINI_H or FULL_H
    uiScale.Scale = math.min(1, (vp.X - 12) / w, (vp.Y - 12) / h)
end
local function clampPanel(center)
    local vp = viewport()
    local half = main.AbsoluteSize * 0.5
    local loX, hiX = half.X, vp.X - half.X
    local loY, hiY = half.Y, vp.Y - half.Y
    return Vector2.new(
        math.clamp(center.X, loX, math.max(loX, hiX)),
        math.clamp(center.Y, loY, math.max(loY, hiY)))
end
local function moveTo(center)
    local p = clampPanel(center)
    main.Position = UDim2.fromOffset(p.X, p.Y)
end
local function setMinimized(value)
    local center = main.AbsolutePosition + main.AbsoluteSize * 0.5
    State.minimized = value
    tabs.Visible = not value
    flingPage.Visible = not value and State.page == "FLING"
    guardPage.Visible = not value and State.page == "GUARD"
    counterPage.Visible = not value and State.page == "COUNTER"
    statusBar.Visible = not value
    main.Size = value and UDim2.fromOffset(MINI_W, MINI_H) or UDim2.fromOffset(FULL_W, FULL_H)
    brand.Text = value and "NOVA MASTER" or "NOVA  /  MASTER"
    brand.Position = value and UDim2.fromOffset(12, 13) or UDim2.fromOffset(13, 5)
    subtitle.Visible = not value
    miniButton.Text = value and "+" or "–"
    fitScale()
    task.defer(function()
        if not State.destroyed then moveTo(center) end
    end)
end
track(miniButton.MouseButton1Click, function() setMinimized(not State.minimized) end)

local dragging, pointer, dragStart, centerStart = false, nil, nil, nil
track(grip.InputBegan, function(input)
    if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    dragging = true; pointer = input
    dragStart = Vector2.new(input.Position.X, input.Position.Y)
    centerStart = main.AbsolutePosition + main.AbsoluteSize * 0.5
end)
track(UIS.InputChanged, function(input)
    if not dragging or not pointer then return end
    if pointer.UserInputType == Enum.UserInputType.Touch then
        if input ~= pointer then return end
    elseif input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
    local at = Vector2.new(input.Position.X, input.Position.Y)
    moveTo(centerStart + (at - dragStart))
end)
track(UIS.InputEnded, function(input)
    if not pointer then return end
    if input == pointer or (pointer.UserInputType == Enum.UserInputType.MouseButton1
        and input.UserInputType == Enum.UserInputType.MouseButton1) then
        dragging = false; pointer = nil
    end
end)
track(UIS.InputBegan, function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.RightShift then
        State.hidden = not State.hidden
        main.Visible = not State.hidden
    end
end)
local lastViewport = viewport()
track(RunService.Heartbeat, function()
    if State.destroyed then return end
    local now = viewport()
    if now ~= lastViewport then
        lastViewport = now
        fitScale()
        moveTo(main.AbsolutePosition + main.AbsoluteSize * 0.5)
    end
end)

-- Close destroys this combined suite; for compact background mode use minimize.
local function destroy()
    if State.destroyed then return end
    State.destroyed = true
    State.active = false
    State.generation += 1
    if toggleRemote and State.counterEnabled then
        pcall(function() toggleRemote:FireServer(false) end)
    end
    for _, connection in ipairs(State.rows) do pcall(function() connection:Disconnect() end) end
    for _, connection in ipairs(State.connections) do pcall(function() connection:Disconnect() end) end
    for player in pairs(g.marks) do clearMark(player) end
    for player in pairs(g.tags) do clearMark(player) end
    if screen then screen:Destroy() end
    if ENV.NovaMasterSuiteV6 == State then ENV.NovaMasterSuiteV6 = nil end
end
State.Destroy = destroy
track(closeButton.MouseButton1Click, destroy)

renderGuard()
findCounterModules()
refreshList()
choosePage("FLING")
setStatus()
fitScale()
