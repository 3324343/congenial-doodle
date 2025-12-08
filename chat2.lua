--========================================================--
--   FE Chat Bot Controller (Exploit) + Auto Walk + AI    --
--========================================================--

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LP = Players.LocalPlayer

--========================================================--
-- SETTINGS
--========================================================--
local Settings = {
    Prefix = "!",             -- <==== ganti prefix disini
    Ping = true,
    AutoRespond = true,
    AutoWalk = true,
    API_Key = "YOUR_API_KEY_HERE"
}

--========================================================--
-- CHAT SENDER
--========================================================--
local function sendChat(msg)
    game:GetService("ReplicatedStorage")
        .DefaultChatSystemChatEvents.SayMessageRequest:FireServer(msg, "All")
end

--========================================================--
-- GEMINI API REQUEST
--========================================================--
local function sendToGemini(prompt)
    local url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=" .. Settings.API_Key
    
    local data = {
        contents = {{
            parts = {{
                text = prompt
            }}
        }}
    }

    local response = request({
        Url = url,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json"
        },
        Body = game:GetService("HttpService"):JSONEncode(data)
    })

    if response and response.Body then
        local json = game:GetService("HttpService"):JSONDecode(response.Body)
        if json and json.candidates and json.candidates[1] then
            return json.candidates[1].content.parts[1].text
        end
    end

    return nil
end

--========================================================--
-- AUTO RESPONSE AI
--========================================================--
local function processAutoResponse(player, message)
    if not Settings.AutoRespond then return end
    if player == LP then return end

    local prompt = "Player said: "..player.Name.." : "..message.."\nGive a short natural response."

    task.spawn(function()
        local ai = sendToGemini(prompt)
        if ai then
            sendChat(ai)
        end
    end)
end

--========================================================--
-- PING COMMAND
--========================================================--
local function handlePing(player, message)
    if message:lower() == Settings.Prefix.."ping" then
        local ms = math.random(40, 120)
        sendChat("Pong! ("..ms.."ms)")
    end
end

--========================================================--
-- FIND PLAYER
--========================================================--
local function findPlayer(name)
    name = name:lower()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower():sub(1, #name) == name then
            return p
        end
    end
end

--========================================================--
-- AUTO WALK TO PLAYER (SMOOTH)
--========================================================--
local walking = false

local function autoWalkToPlayer(name)
    local target = findPlayer(name)
    if not target or not target.Character then
        sendChat("Player not found.")
        return
    end

    walking = true

    sendChat("Walking to "..target.Name.."...")

    while walking and target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") do
        local char = LP.Character
        if char and char:FindFirstChild("Humanoid") and char:FindFirstChild("HumanoidRootPart") then
            local hrp = char.HumanoidRootPart
            local targetPos = target.Character.HumanoidRootPart.Position

            -- smooth move
            hrp.CFrame = hrp.CFrame:Lerp(CFrame.new(targetPos), 0.1)
        end

        RunService.Heartbeat:Wait()
    end
end

local function stopWalk()
    walking = false
end

--========================================================--
-- COMMAND HANDLER
--========================================================--
local function handleCommand(player, message)
    if not message:lower():sub(1, #Settings.Prefix) == Settings.Prefix then return end

    local args = message:split(" ")
    local cmd = args[1]:sub(#Settings.Prefix + 1):lower()

    if cmd == "ping" then
        handlePing(player, message)

    elseif cmd == "walkto" and args[2] then
        autoWalkToPlayer(args[2])

    elseif cmd == "stopwalk" then
        stopWalk()
        sendChat("Stopped walking.")

    end
end

--========================================================--
-- MESSAGE LISTENER
--========================================================--
local function onMessage(player, message)
    handleCommand(player, message)   -- commands (prefix)
    processAutoResponse(player, message) -- AI auto chat
end

--========================================================--
-- HOOK CHAT EVENT
--========================================================--
for _, p in ipairs(Players:GetPlayers()) do
    p.Chatted:Connect(function(msg)
        onMessage(p, msg)
    end)
end

Players.PlayerAdded:Connect(function(p)
    p.Chatted:Connect(function(msg)
        onMessage(p, msg)
    end)
end)

print("Chat Bot Loaded | Prefix:", Settings.Prefix)
