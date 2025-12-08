--//==================================================\\--
--||        UNXHub Gemini AI + TP + Walk + Info      ||--
--\\==================================================//--

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")

----------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------
local PREFIX = "!"
local MODEL_ID = "gemini-2.5-flash"
local FILE = "APIKey_Executor_Mode.gem"

----------------------------------------------------------------
-- STORAGE
----------------------------------------------------------------
_G.GeminiKey = isfile(FILE) and readfile(FILE) or nil
_G.GeminiBusy = false
_G.AutoWalkTarget = nil

----------------------------------------------------------------
-- SEND CHAT
----------------------------------------------------------------
function SendChat(msg)
	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		local ch = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
		if ch then ch:SendAsync(msg) end
		return
	end
	local d = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
	if d then d.SayMessageRequest:FireServer(msg, "All") end
end

----------------------------------------------------------------
-- GEMINI API
----------------------------------------------------------------
local function AskAI(prompt)
	if not _G.GeminiKey then return "❌ No API key — save it in ".. FILE end
	if _G.GeminiBusy then return "⏳ Wait, I'm thinking..." end

	_G.GeminiBusy = true

	local res = request({
		Url = "https://generativelanguage.googleapis.com/v1beta/models/"..MODEL_ID..":generateContent?key=".._G.GeminiKey,
		Method = "POST",
		Headers = {["Content-Type"] = "application/json"},
		Body = HttpService:JSONEncode({
			contents = {{ parts = {{ text = prompt }} }}
		})
	})

	_G.GeminiBusy = false

	if not res or not res.Body then return "❌ API Error!" end

	local decoded = HttpService:JSONDecode(res.Body)
	return decoded.candidates and decoded.candidates[1].content.parts[1].text or "❌ No Response"
end

----------------------------------------------------------------
-- FIND PLAYER
----------------------------------------------------------------
local function FindPlayer(name)
	name = name:lower()
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name:lower():sub(1,#name) == name
		or p.DisplayName:lower():sub(1,#name) == name then
			return p
		end
	end
end

----------------------------------------------------------------
-- TELEPORT PLAYER
----------------------------------------------------------------
local function TeleportToPlayer(targetName)
	local lp = Players.LocalPlayer
	local target = FindPlayer(targetName)

	if not target then SendChat("❌ Player not found: "..targetName) return end

	local myHRP = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
	local theirHRP = target.Character and target.Character:FindFirstChild("HumanoidRootPart")

	if myHRP and theirHRP then
		myHRP.CFrame = theirHRP.CFrame + Vector3.new(0,3,0)
		SendChat("✅ Teleported to **"..target.Name.."**")
	end
end

----------------------------------------------------------------
-- AUTO WALK TO PLAYER
----------------------------------------------------------------
RunService.RenderStepped:Connect(function()
	if _G.AutoWalkTarget then
		local lp = Players.LocalPlayer
		local target = FindPlayer(_G.AutoWalkTarget)
		if target and target.Character and lp.Character then
			local myHRP = lp.Character:FindFirstChild("HumanoidRootPart")
			local theirHRP = target.Character:FindFirstChild("HumanoidRootPart")
			local hum = lp.Character:FindFirstChildOfClass("Humanoid")

			if myHRP and theirHRP and hum then
				hum:MoveTo(theirHRP.Position)
			end
		end
	end
end)

----------------------------------------------------------------
-- PLAYER INFO (FIXED)
----------------------------------------------------------------
local function GetPlayerInfo(name)
	local p = FindPlayer(name)
	if not p then return "❌ Player not found: "..name end

	local char = p.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")

	local health = hum and (math.floor(hum.Health) .. "/" .. math.floor(hum.MaxHealth)) or "N/A"
	local pos = hrp and string.format("%.1f, %.1f, %.1f", hrp.Position.X, hrp.Position.Y, hrp.Position.Z) or "N/A"
	local team = p.Team and p.Team.Name or "None"

	return string.format(
		"🧍 **Player Info: %s**\n"..
		"👤 Username: %s\n"..
		"🏷 Display: %s\n"..
		"🆔 UserId: %s\n"..
		"📅 Age: %s days\n"..
		"❤️ Health: %s\n"..
		"📌 Position: %s\n"..
		"🎨 Team: %s",
		p.Name, p.Name, p.DisplayName, p.UserId, p.AccountAge, health, pos, team
	)
end

----------------------------------------------------------------
-- WEATHER
----------------------------------------------------------------
local function GetWeather(city)
	local geo = request({Url = "https://geocoding-api.open-meteo.com/v1/search?name="..city, Method="GET"})
	if not geo or not geo.Body then return "❌ Failed to get location" end

	local decoded = HttpService:JSONDecode(geo.Body)
	if not decoded.results or #decoded.results == 0 then return "❌ City not found" end

	local lat = decoded.results[1].latitude
	local lon = decoded.results[1].longitude

	local weather = request({
		Url = string.format("https://api.open-meteo.com/v1/forecast?latitude=%s&longitude=%s&current_weather=true", lat, lon),
		Method="GET"
	})

	local w = weather.Body and HttpService:JSONDecode(weather.Body).current_weather
	if not w then return "❌ Weather unavailable." end

	return string.format(
		"🌦 Weather in %s\n🌡 %s°C\n💨 %s km/h\n⛅ Code: %s",
		city, w.temperature, w.windspeed, w.weathercode
	)
end

----------------------------------------------------------------
-- HANDLE CHAT
----------------------------------------------------------------
local function Handle(sender, message)
	local lower = message:lower()

	-- PREFIX
	if lower:sub(1,#PREFIX) == PREFIX then
		local cmd = lower:sub(#PREFIX + 1)

		if cmd == "ping" then SendChat("🏓 Pong! " .. math.random(40,80).. "ms") return end
		
		if cmd:sub(1,3) == "tp " then TeleportToPlayer(cmd:sub(4)) return end
		
		if cmd:sub(1,3) == "ai " then SendChat(AskAI(message:sub(#PREFIX + 5))) return end
		
		if cmd:sub(1,5) == "info " then SendChat(GetPlayerInfo(cmd:sub(6))) return end

		if cmd:sub(1,5) == "walk " then
			_G.AutoWalkTarget = cmd:sub(6)
			SendChat("🚶 Auto-walking to: **"..cmd:sub(6).."**")
			return
		end

		if cmd == "walkoff" then
			_G.AutoWalkTarget = nil
			SendChat("🛑 Auto-walk stopped.")
		end

		if cmd:sub(1,8) == "weather " then SendChat(GetWeather(cmd:sub(9))) return end
	end

	-- Auto AI kalau dipanggil nama
	if lower:find(Players.LocalPlayer.Name:lower()) then
		SendChat(AskAI(message))
	end
end

----------------------------------------------------------------
-- CHAT LISTENER
----------------------------------------------------------------
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

----------------------------------------------------------------
-- UI
----------------------------------------------------------------
local ui = Instance.new("ScreenGui", CoreGui)
local box = Instance.new("TextLabel", ui)
box.Size = UDim2.new(0, 260, 0, 40)
box.Position = UDim2.new(0, 10, 0.5, -20)
box.BackgroundColor3 = Color3.fromRGB(20,20,20)
box.TextColor3 = Color3.new(1,1,1)
box.Font = Enum.Font.GothamBold
box.TextSize = 14
box.Text = "UNXHub Gemini Loaded (".. PREFIX ..")"
Instance.new("UICorner", box).CornerRadius = UDim.new(0,10)
