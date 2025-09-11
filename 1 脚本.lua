local FluentSource = game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua")
local Fluent = loadstring(FluentSource)()

if not Fluent or type(Fluent) ~= "table" then
    warn("错误：无法加载 Fluent UI 库或它不是表格。请检查 HttpService 和网络连接。")
    return
end

local Window = Fluent:CreateWindow({
    Title = "Ink Game",
    SubTitle = "by VILTRUMITE MARK",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true, -- 亚克力效果
    Theme = "Dark", -- 主题
    MinimizeKey = Enum.KeyCode.LeftControl -- 最小化按键
})

local Tab_Misc = Window:AddTab({ Title = "杂项", Icon = "wrench" }) -- 杂项标签

do
    local RunService = game:GetService("RunService")
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local noclipEnabled = false

    Tab_Misc:AddToggle("NoclipToggle", {
        Title = "穿墙模式",
        Default = false,
        Callback = function(value)
            noclipEnabled = value
        end
    })

    RunService.Stepped:Connect(function()
        if noclipEnabled then
            local character = LocalPlayer.Character
            if character then
                for _, part in pairs(character:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
                    end
                end
            end
        end
    end)
end

Tab_Misc:AddButton({
    Title = "传送到新游戏",
    Callback = function()
        local pos = Vector3.new(194.58, 54.48, -8.76)
        local player = game.Players.LocalPlayer
        local char = player.Character or player.CharacterAdded:Wait()
        local hrp = char:WaitForChild("HumanoidRootPart")
        hrp.CFrame = CFrame.new(pos)
    end
})

-- 自定义移动速度切换 + 滑块 (已改进以避免重置)
do
    local Players = game:GetService("Players")
    local UserInputService = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    local LocalPlayer = Players.LocalPlayer
    local currentSpeed = 50
    local defaultSpeed = 16
    local sprintSpeed = 100
    local speedEnabled = false
    local isSprinting = false

    local function updateWalkSpeed()
        local character = LocalPlayer.Character
        if character then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                if speedEnabled then
                    if isSprinting then
                        humanoid.WalkSpeed = sprintSpeed
                    else
                        humanoid.WalkSpeed = currentSpeed
                    end
                else
                    humanoid.WalkSpeed = defaultSpeed
                end
            end
        end
    end

    Tab_Misc:AddSlider("CustomWalkSpeedSlider", {
        Title = "启用时的速度",
        Description = "选择启用加速模式时的速度",
        Default = currentSpeed,
        Min = 16,
        Max = 200,
        Rounding = 0,
        Callback = function(value)
            currentSpeed = value
        end
    })

    Tab_Misc:AddToggle("ToggleCustomSpeed", {
        Title = "启用加速模式",
        Default = false,
        Callback = function(value)
            speedEnabled = value
            if not speedEnabled then
                local character = LocalPlayer.Character
                if character then
                    local humanoid = character:FindFirstChildOfClass("Humanoid")
                    if humanoid then
                        humanoid.WalkSpeed = defaultSpeed
                    end
                end
            end
        end
    })

    Tab_Misc:AddSlider("SprintSpeedSlider", {
        Title = "冲刺速度",
        Description = "选择按住 Shift 时的速度（如果启用了加速模式）",
        Default = sprintSpeed,
        Min = 50,
        Max = 300,
        Rounding = 0,
        Callback = function(value)
            sprintSpeed = value
        end
    })

    UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
        if input.KeyCode == Enum.KeyCode.LeftShift and not gameProcessedEvent then
            isSprinting = true
        end
    end)

    UserInputService.InputEnded:Connect(function(input, gameProcessedEvent)
        if input.KeyCode == Enum.KeyCode.LeftShift and not gameProcessedEvent then
            isSprinting = false
        end
    end)

    RunService.Heartbeat:Connect(function()
        if speedEnabled then
            updateWalkSpeed()
        end
    end)

    LocalPlayer.CharacterAdded:Connect(function(character)
        local humanoid = character:WaitForChild("Humanoid")
        updateWalkSpeed()
        humanoid.Died:Connect(function() end)
    end)

    if LocalPlayer.Character then
        updateWalkSpeed()
    end
end

do
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local currentJump = 100
    local defaultJump = 50
    local jumpEnabled = false

    Tab_Misc:AddSlider("CustomJumpPowerSlider", {
        Title = "启用时的跳跃高度",
        Description = "选择启用高跳时的跳跃高度",
        Default = currentJump,
        Min = 50,
        Max = 200,
        Rounding = 0,
        Callback = function(value)
            currentJump = value
            if jumpEnabled then
                local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    humanoid.JumpPower = currentJump
                end
            end
        end
    })

    Tab_Misc:AddToggle("ToggleJumpPower", {
        Title = "启用高跳",
        Default = false,
        Callback = function(value)
            jumpEnabled = value
            local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid.JumpPower = value and currentJump or defaultJump
            end
        end
    })
end

local Tab_Kill = Window:AddTab({ Title = "击杀玩家", Icon = "target" }) -- 击杀玩家标签

do -- 此代码块包含自动跟随和自动点击
    local TweenSpeed = 0.01

    local Players = game:GetService("Players")
    local TweenService = game:GetService("TweenService")
    local LocalPlayer = Players.LocalPlayer
    local autoFollowEnabled = false
    local currentFollowTask = nil

    local function getChar()
        return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    end

    local function getRandomPlayer()
        local others = {}
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                table.insert(others, p)
            end
        end
        if #others == 0 then return nil end
        return others[math.random(1, #others)]
    end

    local function followTarget(target)
        local myChar = getChar()
        local myHRP = myChar:WaitForChild("HumanoidRootPart")
        local targetHRP = target.Character:WaitForChild("HumanoidRootPart")

        while autoFollowEnabled and target and target.Character and targetHRP.Parent and myHRP.Parent do
            local goal = {CFrame = targetHRP.CFrame * CFrame.new(0, 0, 0)}
            local tweenInfo = TweenInfo.new(TweenSpeed, Enum.EasingStyle.Linear)
            local tween = TweenService:Create(myHRP, tweenInfo, goal)
            tween:Play()
            tween.Completed:Wait()
        end
    end

    Tab_Kill:AddToggle("AutoFollowToggle", {
        Title = "自动跟随随机玩家", -- 移除了“紧贴”字样
        Default = false,
        Callback = function(value)
            autoFollowEnabled = value
            if value then
                currentFollowTask = task.spawn(function()
                    local target = getRandomPlayer()
                    if target then
                        print("正在跟随:", target.Name)
                        followTarget(target)
                    else
                        warn("未找到其他玩家可跟随。")
                        autoFollowEnabled = false
                    end
                end)
            else
                print("已停止跟随。")
            end
        end
    })

    -- 🔥 自动点击 (已移至此) 🔥
    local RunService = game:GetService("RunService") -- 确保此代码块中 RunService 可用
    local autoClickEnabled = false
    local clickDelay = 0.1
    local clickTask = nil

    local function performAutoClick()
        local character = LocalPlayer.Character
        if character then
            local equippedTool = character:FindFirstChildOfClass("Tool")
            if equippedTool then
                equippedTool:Activate()
            end
        end
    end

    Tab_Kill:AddToggle("AutoClickToggle", {
        Title = "启用自动点击 (工具)",
        Description = "自动激活手中持有的工具。",
        Default = false,
        Callback = function(value)
            autoClickEnabled = value
            if autoClickEnabled then
                clickTask = task.spawn(function()
                    while autoClickEnabled do
                        performAutoClick()
                        task.wait(clickDelay)
                    end
                end)
            else
                if clickTask then
                    task.cancel(clickTask)
                    clickTask = nil
                end
            end
        end
    })

    Tab_Kill:AddSlider("ClickDelaySlider", {
        Title = "自动点击延迟",
        Description = "两次激活之间的等待时间（秒）。",
        Default = clickDelay,
        Min = 0.01,
        Max = 1,
        Rounding = 2,
        Callback = function(value)
            clickDelay = value
        end
    })

    LocalPlayer.CharacterAdded:Connect(function(character)
        if autoClickEnabled and clickTask then
            task.cancel(clickTask)
            clickTask = task.spawn(function()
                while autoClickEnabled do
                    performAutoClick()
                    task.wait(clickDelay)
                end
            end)
        end
    end)
end

-- 绿灯红灯标签
local Tab_GreenRed = Window:AddTab({ Title = "绿灯红灯", Icon = "circle" })

Tab_GreenRed:AddButton({
    Title = "传送到终点",
    Callback = function()
        local player = game.Players.LocalPlayer
        local character = player.Character or player.CharacterAdded:Wait()

        local hrp = character:WaitForChild("HumanoidRootPart")

        local targetPosition = Vector3.new(-45.65, 1089.92, 127.10)

        hrp.CFrame = CFrame.new(targetPosition)
    end
})

-- 灯光熄灭标签
local Tab_LightOut = Window:AddTab({ Title = "灯光熄灭", Icon = "moon" })

Tab_LightOut:AddButton({
    Title = "传送到安全位置",
    Callback = function()
        local player = game.Players.LocalPlayer
        local character = player.Character or player.CharacterAdded:Wait()
        local hrp = character:WaitForChild("HumanoidRootPart")

        local targetPosition = Vector3.new(199.07, 144.55, -66.46)

        hrp.CFrame = CFrame.new(targetPosition)
    end
})