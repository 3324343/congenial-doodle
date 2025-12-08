--====================================================--
--                 CONFIG (EDIT DI SINI)              --
--====================================================--

local PREFIX = "!"                 -- << Ubah prefix di sini
local MODEL_ID = "gemini-2.5-flash"
local FILE = "APIKey.gem"

--====================================================--
--                    STORAGE                         --
--====================================================--

_G.GeminiKey = isfile(FILE) and readfile(FILE) or nil
_G.GeminiBusy = false

if not _G.GeminiKey then
    writefile(FILE, "ISI_API_KEY_DISINI")
    warn("[Gemini] File APIKey.gem dibuat. ISI API KEY DULU!")
end

--====================================================--
--                SERVICES + FUNCTIONS               --
--====================================================--

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LP = Players.LocalPlayer

local requestFunc =
    request or http_request or syn and syn.request or
    fluxus and fluxus.request or function() return nil end

local function SendChat(msg)
    local chatEvent = game.ReplicatedStorage.DefaultChatSystemChatEvents
    chatEvent.SayMessageRequest:FireServer(msg, "All")
end

--====================================================--
--                GEMINI API REQUEST                 --
--====================================================--

local function AskAI(prompt)
    if not _G.GeminiKey then
        return "No API Key in file: " .. FILE
    end

    if _G.GeminiBusy then
        return "Thinking..."
    end

    _G.GeminiBusy = true

    local body = {
        contents = {{
            parts = {{ text = prompt }}
        }}
    }

    local res = requestFunc({
        Url = "https://generativelanguage.googleapis.com/v1beta/models/"..MODEL_ID..":generateContent?key=".._G.GeminiKey,
        Method = "POST",
        Headers = {["Content-Type"] = "application/json"},
        Body = HttpService:JSONEncode(body)
    })

    _G.GeminiBusy = false

    if not res or not res.Body then
        return "API Error."
    end

    local decoded = HttpService:JSONDecode(res.Body)
    return decoded.candidates and decoded.candidates[1].content.parts[1].text or "No Response"
end

--====================================================--
--                    TELEPORT                       --
--====================================================--

local function TeleportToPlayer(p)
    if not p.Character or not LP.Character then return end

    local t = p.Character:FindFirstChild("HumanoidRootPart")
    local me = LP.Character:FindFirstChild("HumanoidRootPart")

    if t and me then
        me.CFrame = t.CFrame + Vector3.new(0, 3, 0)
    end
end

--====================================================--
--                AUTO WALK TO PLAYER                --
--====================================================--

local walking = false

local function FindPlayer(name)
    name = name:lower()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Name:lower():sub(1, #name) == name then
            return plr
        end
    end
end

local function AutoWalk(name)
    local target = FindPlayer(name)
    if not target then SendChat("Player tidak ditemukan.") return end

    walking = true
    SendChat("Walking to "..target.Name.."...")

    task.spawn(function()
        while walking and target.Character and LP.Character do
            local tHRP = target.Character:FindFirstChild("HumanoidRootPart")
            local mHRP = LP.Character:FindFirstChild("HumanoidRootPart")

            if tHRP and mHRP then
                mHRP.CFrame = mHRP.CFrame:Lerp(tHRP.CFrame, 0.08)
            end

            RunService.Heartbeat:Wait()
        end
    end)
end

local function StopWalk()
    walking = false
    SendChat("Stopped walking.")
end

--====================================================--
--                  CHAT COMMANDS                    --
--====================================================--

local function OnMessage(player, message)
    if player == LP then return end
    local msg = message:lower()

    -- prefix basic
    if msg:sub(1, #PREFIX) == PREFIX then
        local args = message:split(" ")
        local cmd = args[1]:sub(#PREFIX+1):lower()

        if cmd == "ping" then
            SendChat("Pong! "..math.random(40,120).."ms")

        elseif cmd == "tp" and args[2] then
            local to = FindPlayer(args[2])
            if to then
                TeleportToPlayer(to)
                SendChat("Teleported to "..to.Name)
            else
                SendChat("Player tidak ditemukan.")
            end

        elseif cmd == "walk" and args[2] then
            AutoWalk(args[2])

        elseif cmd == "stopwalk" then
            StopWalk()

        elseif cmd == "ai" then
            local q = message:sub(#PREFIX + 4)
            local ans = AskAI(q)
            if ans then SendChat(ans) end
        end

        return
    end

    -- Auto AI when someone mention you
    if msg:find(LP.Name:lower()) then
        local ans = AskAI(message)
        if ans then SendChat(ans) end
    end
end

--====================================================--
--                CONNECT LISTENERS                  --
--====================================================--

for _, p in ipairs(Players:GetPlayers()) do
    p.Chatted:Connect(function(msg)
        OnMessage(p, msg)
    end)
end

Players.PlayerAdded:Connect(function(p)
    p.Chatted:Connect(function(msg)
        OnMessage(p, msg)
    end)
end)

print("[Gemini] Loaded with prefix: "..PREFIX)
print("[Gemini] Using API Key File: "..FILE)
