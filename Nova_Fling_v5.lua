--[[
    NOVA FLING v5.0 | Compact Draggable Edition
    Mismo enfoque de v4; modo ORIGINAL recupera los valores de velocidad y rotacion
    de K1LAS1K/Ultimate-Fling-GUI sin cambiar el resto del algoritmo adaptativo.
    Prueba en una experiencia privada con participantes que acepten.

    IMPORTANTE: Un LocalScript no puede obligar al servidor a mover vehiculos
    ni personajes que pertenecen a otra simulacion de red. No hay bypass magico.

    Funciones:
      - Objetivos por UserId + busqueda + seleccion total
      - Detecta Humanoid.SeatPart, Occupant, SeatWeld y VehicleSeat
      - Modo AUTO: a pie / asiento / vehiculo
      - Colisiones de aproximacion alrededor de carroceria y asientos
      - 5 potencias (NORMAL / FUERTE / ULTRA / TEORICO / ORIGINAL)
      - Aims at connected physical assembly of a seat/vehicle
      - Re-resolves seats and player transitions while active
      - Dynamic movement prediction, adaptive orbit, and bounded contact passes
      - Worker unico cancelable, reinicio seguro, restauracion acotada
      - GUI NOVA compacta, barra flotante al minimizar, arrastre PC/tactil
      - Sin alterar FallenPartsDestroyHeight ni camara
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then error("NOVA FLING requiere un cliente Roblox") end

local PRESETS = {
    ORIGINAL = { speed = 9e7, spin = 9e8, foot = 2.00, seat = 2.40, car = 3.15 },
    NORMAL  = { speed =  650, spin =  340, foot = 0.85, seat = 1.15, car = 1.55 },
    FUERTE  = { speed = 1350, spin =  760, foot = 1.05, seat = 1.55, car = 2.10 },
    ULTRA   = { speed = 2600, spin = 1300, foot = 1.25, seat = 1.90, car = 2.65 },
    TEORICO = { speed = 4700, spin = 2450, foot = 1.80, seat = 2.70, car = 3.85 },
}
local CONFIG = {
    leadMax = 0.13,
    maxLeadStuds = 15,
    betweenTargets = 0.10,
    betweenRounds = 0.30,
    maxTargetDistance = 20000,
    maxAssemblyBox = 155,
    maxConnectedParts = 250,
    updateTargetEvery = 0.18,
    recoveryFrames = 7,
}

local ENV = (type(getgenv) == "function" and getgenv()) or _G
for _, oldKey in ipairs({"NovaFlingV5", "UltraFlingOPv4"}) do
    local old = ENV[oldKey]
    if type(old) == "table" and type(old.Destroy) == "function" then
        pcall(old.Destroy)
    end
end

local State = {
    active = false,
    busy = false,
    destroyed = false,
    generation = 0,
    selected = {}, -- [UserId] = true
    level = "ORIGINAL",
    connections = {},
    rows = {},
    dragConnection = nil,
    gui = nil,
}
ENV.NovaFlingV5 = State

local function track(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(State.connections, connection)
    return connection
end

local function create(className, properties, parent)
    local instance = Instance.new(className)
    for name, value in pairs(properties or {}) do
        instance[name] = value
    end
    instance.Parent = parent
    return instance
end

-- NOVA UI / Neon Aurora. 306x390 expanded, 212x46 minimized.
local COLORS = {
    bg = Color3.fromRGB(15, 16, 28),
    panel = Color3.fromRGB(26, 29, 47),
    row = Color3.fromRGB(35, 39, 62),
    chosen = Color3.fromRGB(39, 64, 80),
    accent = Color3.fromRGB(0, 218, 206),
    violet = Color3.fromRGB(113, 77, 246),
    red = Color3.fromRGB(234, 79, 109),
    blue = Color3.fromRGB(49, 59, 101),
    text = Color3.fromRGB(245, 248, 255),
    subtext = Color3.fromRGB(151, 164, 194),
}
local EXPANDED_W, EXPANDED_H = 306, 390
local MINI_W, MINI_H = 212, 46

local function round(guiObject, radius)
    create("UICorner", { CornerRadius = UDim.new(0, radius or 8) }, guiObject)
    return guiObject
end
local function colorBlend(guiObject, colorA, colorB, rotation)
    create("UIGradient", {
        Rotation = rotation or 0,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, colorA),
            ColorSequenceKeypoint.new(1, colorB),
        }),
    }, guiObject)
end

local uiParent = CoreGui
if type(gethui) == "function" then
    local ok, result = pcall(gethui)
    if ok and result then uiParent = result end
end
local screen = create("ScreenGui", {
    Name = "NovaFlingV5", ResetOnSpawn = false, IgnoreGuiInset = false,
    DisplayOrder = 120,
}, nil)
local parented = pcall(function() screen.Parent = uiParent end)
if not parented then screen.Parent = LocalPlayer:WaitForChild("PlayerGui") end
State.gui = screen

local main = round(create("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(EXPANDED_W, EXPANDED_H),
    BackgroundColor3 = COLORS.bg, BorderSizePixel = 0,
    ClipsDescendants = true, Active = true,
}, screen), 13)
create("UIStroke", { Color = COLORS.violet, Thickness = 1.3, Transparency = 0.18 }, main)

local header = round(create("Frame", {
    Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 46),
    BackgroundColor3 = COLORS.panel, BorderSizePixel = 0, Active = true,
}, main), 12)
colorBlend(header, Color3.fromRGB(42, 36, 83), Color3.fromRGB(18, 38, 58), 0)
create("Frame", {
    Position = UDim2.new(0, 0, 1, -2), Size = UDim2.new(1, 0, 0, 2),
    BackgroundColor3 = COLORS.accent, BorderSizePixel = 0,
}, header)

local brand = create("TextLabel", {
    Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -100, 0, 21),
    BackgroundTransparency = 1, Text = "NOVA // FLING",
    Font = Enum.Font.GothamBlack, TextSize = 15, TextTruncate = Enum.TextTruncate.AtEnd,
    TextColor3 = COLORS.text, TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 2,
}, header)
local subtitle = create("TextLabel", {
    Position = UDim2.fromOffset(13, 27), Size = UDim2.new(1, -104, 0, 12),
    BackgroundTransparency = 1, Text = "ORIGINAL CORE   •   V5",
    Font = Enum.Font.GothamBold, TextSize = 9,
    TextColor3 = COLORS.accent, TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 2,
}, header)
local function makeButton(parent, name, caption, position, size, color)
    return round(create("TextButton", {
        Name = name, Text = caption, Position = position, Size = size,
        BorderSizePixel = 0, BackgroundColor3 = color, AutoButtonColor = true,
        TextColor3 = COLORS.text, Font = Enum.Font.GothamBold, TextSize = 12,
        ZIndex = 4,
    }, parent), 7)
end

-- This is the ONLY drag surface: close/minimize remain clickable on touch.
local dragZone = create("TextButton", {
    Name = "DragBar", Position = UDim2.fromOffset(0, 0),
    Size = UDim2.new(1, -84, 1, -2),
    BackgroundTransparency = 1, Text = "", Active = true,
    AutoButtonColor = false, ZIndex = 3,
}, header)
local minimize = makeButton(header, "Minimize", "–", UDim2.new(1, -77, 0, 8), UDim2.fromOffset(31, 29), COLORS.blue)
local close = makeButton(header, "Close", "×", UDim2.new(1, -40, 0, 8), UDim2.fromOffset(31, 29), COLORS.red)

local body = create("Frame", {
    Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 1, -46),
    BackgroundTransparency = 1,
}, main)
local status = create("TextLabel", {
    Position = UDim2.fromOffset(12, 3), Size = UDim2.new(1, -90, 0, 24),
    BackgroundTransparency = 1, Text = "Selecciona tus objetivos",
    TextColor3 = COLORS.subtext, TextTruncate = Enum.TextTruncate.AtEnd,
    TextXAlignment = Enum.TextXAlignment.Left, TextSize = 11,
    Font = Enum.Font.GothamMedium,
}, body)
local stateChip = round(create("TextLabel", {
    Position = UDim2.new(1, -78, 0, 7), Size = UDim2.fromOffset(66, 19),
    BackgroundColor3 = COLORS.blue, TextColor3 = COLORS.accent,
    Text = "READY", Font = Enum.Font.GothamBold, TextSize = 10,
}, body), 6)
local search = round(create("TextBox", {
    Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -24, 0, 30),
    BackgroundColor3 = COLORS.panel, TextColor3 = COLORS.text,
    PlaceholderColor3 = COLORS.subtext, PlaceholderText = "  Buscar @usuario o nombre...",
    Text = "", ClearTextOnFocus = false, TextSize = 12,
    Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
}, body), 8)
create("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7) }, search)

local list = round(create("ScrollingFrame", {
    Position = UDim2.fromOffset(12, 69), Size = UDim2.new(1, -24, 0, 135),
    BackgroundColor3 = COLORS.panel, BorderSizePixel = 0,
    CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollBarThickness = 4, ScrollingDirection = Enum.ScrollingDirection.Y,
}, body), 8)
create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, list)
create("UIPadding", {
    PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5),
    PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5),
}, list)

local chooseAll = makeButton(body, "SelectAll", "◎ TODOS", UDim2.fromOffset(12, 211), UDim2.new(0.5, -16, 0, 29), COLORS.blue)
local chooseNone = makeButton(body, "SelectNone", "○ NINGUNO", UDim2.new(0.5, 4, 0, 211), UDim2.new(0.5, -16, 0, 29), COLORS.blue)
local power = makeButton(body, "Power", "✦ POTENCIA: ORIGINAL", UDim2.fromOffset(12, 247), UDim2.new(1, -24, 0, 30), COLORS.violet)
local start = makeButton(body, "Start", "▶ ACTIVAR", UDim2.fromOffset(12, 284), UDim2.new(0.5, -16, 0, 36), Color3.fromRGB(0, 135, 128))
local stop = makeButton(body, "Stop", "■ DETENER", UDim2.new(0.5, 4, 0, 284), UDim2.new(0.5, -16, 0, 36), COLORS.red)
create("TextLabel", {
    Position = UDim2.fromOffset(12, 326), Size = UDim2.new(1, -24, 0, 12),
    BackgroundTransparency = 1,
    Text = "✧ ARRASTRA ARRIBA  •  – MINIMIZAR  •  ⇧ TOGGLE",
    Font = Enum.Font.Gotham, TextSize = 9,
    TextColor3 = COLORS.subtext, TextXAlignment = Enum.TextXAlignment.Center,
}, body)

local function selectedCount()
    local count = 0
    for _, selected in pairs(State.selected) do
        if selected then count += 1 end
    end
    return count
end

local function setStatus(message)
    if State.destroyed then return end
    stateChip.Text = State.active and "LIVE" or State.busy and "WAIT" or "READY"
    stateChip.TextColor3 = State.active and COLORS.text or COLORS.accent
    stateChip.BackgroundColor3 = State.active and COLORS.violet or COLORS.blue
    if message then
        status.Text = message
    else
        status.Text = (State.active and "ACTIVO" or State.busy and "RECUPERANDO" or "LISTO")
            .. "  •  " .. tostring(selectedCount()) .. " seleccionado(s)"
    end
end

local refreshList
refreshList = function()
    if State.destroyed then return end
    for _, connection in ipairs(State.rows) do connection:Disconnect() end
    table.clear(State.rows)
    for _, child in ipairs(list:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    local filter = search.Text:lower()
    local players = Players:GetPlayers()
    table.sort(players, function(a, b) return a.Name:lower() < b.Name:lower() end)
    local layoutOrder = 0
    for _, player in ipairs(players) do
        if player ~= LocalPlayer and (
            filter == "" or player.Name:lower():find(filter, 1, true)
            or player.DisplayName:lower():find(filter, 1, true)
        ) then
            layoutOrder += 1
            local selected = State.selected[player.UserId] == true
            local entry = makeButton(list, "User_" .. player.UserId,
                (selected and "  [✓]  " or "  [ ]  ") .. player.DisplayName .. "  @" .. player.Name,
                UDim2.new(), UDim2.new(1, -2, 0, 28), selected and COLORS.chosen or COLORS.row)
            entry.LayoutOrder = layoutOrder
            entry.TextXAlignment = Enum.TextXAlignment.Left
            entry.TextSize = 12
            entry.TextTruncate = Enum.TextTruncate.AtEnd
            table.insert(State.rows, entry.MouseButton1Click:Connect(function()
                if State.selected[player.UserId] then
                    State.selected[player.UserId] = nil
                else
                    State.selected[player.UserId] = true
                end
                refreshList()
                setStatus()
            end))
        end
    end
end

-- Resolucion de asiento tolerante a replicacion incompleta, pasajeros y cambios de asiento.
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
    if not ok then warn("[NOVA FLING v5] " .. tostring(err)) end
    if not recovered then warn("[NOVA FLING v5 restore] " .. tostring(recoveryError)) end
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

local function destroy()
    if State.destroyed then return end
    stopFling()
    State.destroyed = true
    for _, connection in ipairs(State.rows) do pcall(function() connection:Disconnect() end) end
    for _, connection in ipairs(State.connections) do pcall(function() connection:Disconnect() end) end
    if State.dragConnection then State.dragConnection:Disconnect() end
    table.clear(State.rows)
    table.clear(State.connections)
    screen:Destroy()
    if ENV.NovaFlingV5 == State then ENV.NovaFlingV5 = nil end
end
State.Destroy = destroy

track(start.MouseButton1Click, function()
    if State.busy then setStatus("Espera a que termine la recuperación") return end
    if selectedCount() == 0 then setStatus("Selecciona al menos un jugador") return end
    local character, humanoid = getSelf()
    if not character then setStatus("Tu personaje aún no está listo") return end
    if humanoid.Sit then setStatus("Levántate primero de tu asiento") return end
    State.active, State.busy = true, true
    State.generation += 1
    local generation = State.generation
    task.spawn(function()
        local ok, message = xpcall(function() run(generation) end, function(e) return tostring(e) end)
        State.active, State.busy = false, false
        if not ok then warn("[NOVA FLING v5] Worker: " .. tostring(message)) end
        setStatus()
    end)
end)
track(stop.MouseButton1Click, stopFling)
track(close.MouseButton1Click, destroy)
track(power.MouseButton1Click, function()
    State.level = State.level == "ORIGINAL" and "NORMAL"
        or State.level == "NORMAL" and "FUERTE"
        or State.level == "FUERTE" and "ULTRA"
        or State.level == "ULTRA" and "TEORICO" or "ORIGINAL"
    power.Text = "✦ POTENCIA: " .. State.level
end)
track(chooseAll.MouseButton1Click, function()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then State.selected[player.UserId] = true end
    end
    refreshList(); setStatus()
end)
track(chooseNone.MouseButton1Click, function()
    table.clear(State.selected)
    refreshList(); setStatus()
end)
track(search:GetPropertyChangedSignal("Text"), refreshList)
track(Players.PlayerAdded, refreshList)
track(Players.PlayerRemoving, function(player)
    State.selected[player.UserId] = nil
    task.defer(function() refreshList(); setStatus() end)
end)
track(LocalPlayer.CharacterRemoving, stopFling)

-- Minimize into a compact draggable chip. Never destroy the running worker.
local collapsed = false
local function viewport()
    local camera = workspace.CurrentCamera
    if camera then return camera.ViewportSize end
    return Vector2.new(800, 600)
end
local function clampCenter(center)
    local view = viewport()
    local half = main.AbsoluteSize * 0.5
    -- Keep the title bar always reachable (including small mobile viewports).
    local minX, maxX = half.X + 5, view.X - half.X - 5
    local minY, maxY = half.Y + 5, view.Y - half.Y - 5
    if minX > maxX then minX, maxX = view.X * 0.5, view.X * 0.5 end
    if minY > maxY then minY, maxY = view.Y * 0.5, view.Y * 0.5 end
    local x = math.clamp(center.X, minX, maxX)
    local y = math.clamp(center.Y, minY, maxY)
    return Vector2.new(x, y)
end
local function setCenter(center)
    local p = clampCenter(center)
    main.Position = UDim2.fromOffset(p.X, p.Y)
end
track(minimize.MouseButton1Click, function()
    collapsed = not collapsed
    body.Visible = not collapsed
    main.Size = collapsed and UDim2.fromOffset(MINI_W, MINI_H) or UDim2.fromOffset(EXPANDED_W, EXPANDED_H)
    brand.Position = collapsed and UDim2.fromOffset(12, 12) or UDim2.fromOffset(12, 6)
    subtitle.Visible = not collapsed
    minimize.Text = collapsed and "+" or "–"
    -- Defer one render step so AbsoluteSize reflects the new size.
    task.defer(function()
        if not State.destroyed then
            local view = viewport()
            local absolute = main.AbsolutePosition + main.AbsoluteSize * 0.5
            setCenter(Vector2.new(math.clamp(absolute.X, 0, view.X), math.clamp(absolute.Y, 0, view.Y)))
        end
    end)
end)
track(UserInputService.InputBegan, function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.RightShift then main.Visible = not main.Visible end
end)

-- Real drag: only the header grip moves the panel, never the actions/list.
-- Touch drag uses the originating touch InputObject; mouse uses MouseMovement.
local dragging = false
local pointer, dragOrigin, panelOrigin = nil, nil, nil
track(dragZone.InputBegan, function(input)
    local typeId = input.UserInputType
    if typeId ~= Enum.UserInputType.Touch and typeId ~= Enum.UserInputType.MouseButton1 then return end
    dragging = true
    pointer = input
    dragOrigin = Vector2.new(input.Position.X, input.Position.Y)
    panelOrigin = main.AbsolutePosition + main.AbsoluteSize * 0.5
end)
track(UserInputService.InputChanged, function(input)
    if not dragging or not pointer then return end
    if pointer.UserInputType == Enum.UserInputType.Touch then
        if input ~= pointer then return end
    elseif input.UserInputType ~= Enum.UserInputType.MouseMovement then
        return
    end
    local current = Vector2.new(input.Position.X, input.Position.Y)
    setCenter(panelOrigin + (current - dragOrigin))
end)
track(UserInputService.InputEnded, function(input)
    if not pointer then return end
    if input == pointer or (pointer.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1) then
        dragging = false
        pointer = nil
    end
end)
track(screen:GetPropertyChangedSignal("AbsoluteSize"), function()
    if not State.destroyed and main.Visible then
        local absolute = main.AbsolutePosition + main.AbsoluteSize * 0.5
        setCenter(absolute)
    end
end)

refreshList()
setStatus()
