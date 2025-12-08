--//==================================================\\--
--||   UNXHub Gemini AI + Ping + Teleport Command    ||--
--||          FIXED CHAT TELEPORT (WORKING)          ||--
--\\==================================================//--

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")

local MODEL_ID = "gemini-2.5-flash"
local FILE = "APIKey_Executor_Mode.gem"

_G.GeminiKey = isfile(FILE) and readfile(FILE) or nil
_G.GeminiBusy = false

--------------------------------------------------------
-- FIND PLAYER BY NAME
--------------------------------------------------------
local function FindPlayer(name)
    name = name:lower()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower():sub(1, #name) == name 
        or p.DisplayName:lower():sub(1, #name) == name then
            return p
        end
    end
end

--------------------------------------------------------
-- TELEPORT
--------------------------------------------------------
local function TeleportToPlayer(targetName)
    local lp = Players.LocalPlayer
    local target = FindPlayer(targetName)

    if not target or not target.Character then
        SendChat("❌ Player tidak ditemukan: " .. targetName)
        return
    end

    local myHRP = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    local theirHRP = target.Character:FindFirstChild("HumanoidRootPart")

    if myHRP and theirHRP then
        myHRP.CFrame = theirHRP.CFrame + Vector3.new(0, 3, 0)
        SendChat("✅ Teleported to " .. target.Name)
    end
end

--------------------------------------------------------
-- SEND CHAT
--------------------------------------------------------
function SendChat(msg)
    if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
        local ch = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
        if ch then ch:SendAsync(msg) end
        return
    end
    local chatEvent = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
    if chatEvent then
        chatEvent.SayMessageRequest:FireServer(msg, "All")
    end
end

--------------------------------------------------------
-- GEMINI API
--------------------------------------------------------
local function AskAI(prompt)
    if not _G.GeminiKey then
        return "No API Key Found. Save your key to " .. FILE
    end
    if _G.GeminiBusy then
        return "Wait, I'm thinking..."
    end

    _G.GeminiBusy = true
    local res = request({
        Url = "https://generativelanguage.googleapis.com/v1beta/models/"..MODEL_ID..":generateContent?key=".._G.GeminiKey,
        Method = "POST",
        Headers = {["Content-Type"] = "application/json"},
        Body = HttpService:JSONEncode({
            contents = {{
                parts = {{ text = prompt }}
            }}
        })
    })
    _G.GeminiBusy = false

    if not res or not res.Body then return "API Error." end
    local j = HttpService:JSONDecode(res.Body)
    return j.candidates and j.candidates[1].content.parts[1].text or "No Response."
end

--------------------------------------------------------
-- CHAT HANDLER
--------------------------------------------------------
local function Handle(sender, message)
    local msg = message:lower()

    -----------------------------
    -- PING
    -----------------------------
    if msg == ".ping" then
        local ms = math.random(40, 80)
        SendChat("🏓 Pong! " .. ms .. "ms")
        return
    end

    -----------------------------
    -- TELEPORT
    -- Format:  tp <nama>
    -----------------------------
    if msg:sub(1,3) == ".tp" then
        local target = msg:sub(4)
        TeleportToPlayer(target)
        return
    end

    -----------------------------
    -- MANUAL AI
    -----------------------------
    if msg:sub(1,3) == "!ai" then
        local q = message:sub(3)
        SendChat(AskAI(q))
        return
    end

    -----------------------------
    -- AUTO AI REPLY
    -----------------------------
    if msg:find(Players.LocalPlayer.Name:lower()) then
        SendChat(AskAI(message))
    end
end

--------------------------------------------------------
-- LISTEN CHAT
--------------------------------------------------------
if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
    TextChatService.MessageReceived:Connect(function(packet)
        local plr = Players:GetPlayerByUserId(packet.TextSource.UserId)
        if plr then Handle(plr, packet.Text) end
    end)
else
    Players.PlayerChatted:Connect(function(plr, msg)
        Handle(plr, msg)
    end)
end

--------------------------------------------------------
-- UI
--------------------------------------------------------
local ui = Instance.new("ScreenGui", CoreGui)
local box = Instance.new("TextLabel", ui)
box.Size = UDim2.new(0, 210, 0, 40)
box.Position = UDim2.new(0, 10, 0.5, -20)
box.BackgroundColor3 = Color3.fromRGB(20,20,20)
box.TextColor3 = Color3.new(1,1,1)
box.Font = Enum.Font.GothamBold
box.TextSize = 14
box.Text = "Gemini AI: Loaded"
Instance.new("UICorner", box).CornerRadius = UDim.new(0,10)

print("Gemini + Ping + TP Command Loaded (Working)")
