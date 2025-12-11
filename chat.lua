-- // UNXHub Gemini Bot v3 (Full Script + AI Personality System)

local HttpService=game:GetService("HttpService")
local Players=game:GetService("Players")
local TextChatService=game:GetService("TextChatService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local CoreGui=game:GetService("CoreGui")
local RunService=game:GetService("RunService")

local PREFIX="!"
local MODEL_ID="gemini-2.5-flash"
local FILE="APIKey_Executor_Mode.gem"

_G.GeminiKey = isfile(FILE) and readfile(FILE) or nil
_G.GeminiBusy = false
_G.AutoWalkTarget = nil

-- =========================
-- AI PERSONALITY SETTINGS
-- =========================
_G.AIConfig = {
	PersonalityName = "AquaBot",
	Tone = "roleplay", -- friendly / toxic / formal / chaotic / tsundere / helper / roleplay
	WritingStyle = "short", -- simple / detailed / short / long / meme
	SpecialRules = [[
Selalu roleplay sebagai karakter anime yang imut
]],
}

-- SEND CHAT
local function SendChat(msg)
	if TextChatService.ChatVersion==Enum.ChatVersion.TextChatService then
		local ch=TextChatService.TextChannels:FindFirstChild("RBXGeneral")
		if ch then ch:SendAsync(msg) end
	else
		local d=ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
		if d then d.SayMessageRequest:FireServer(msg,"All") end
	end
end

-- AI FUNCTION
local function AskAI(prompt)
	if not _G.GeminiKey then return "No API key. Save in "..FILE end
	if _G.GeminiBusy then return "AI busy" end

	_G.GeminiBusy=true

	-- Personality Injection
	local finalPrompt = string.format([[
Nama Kepribadian: %s
Gaya Bicara: %s
Gaya Penulisan: %s

Aturan Tambahan:
%s

User: %s
AI:
]],
	_G.AIConfig.PersonalityName,
	_G.AIConfig.Tone,
	_G.AIConfig.WritingStyle,
	_G.AIConfig.SpecialRules,
	prompt
	)

	local res = request({
		Url="https://generativelanguage.googleapis.com/v1beta/models/"..MODEL_ID..":generateContent?key=".._G.GeminiKey,
		Method="POST",
		Headers={["Content-Type"]="application/json"},
		Body=HttpService:JSONEncode({
			contents={{parts={{text=finalPrompt}}}}
		})
	})

	_G.GeminiBusy=false

	if not res or not res.Body then return "API error" end

	local data=HttpService:JSONDecode(res.Body)
	local txt=data.candidates and data.candidates[1] and data.candidates[1].content.parts[1].text

	return txt or "No response"
end

-- Find Player
local function FindPlayer(name)
	name=name:lower()
	for _,p in ipairs(Players:GetPlayers()) do
		if p.Name:lower():sub(1,#name)==name or p.DisplayName:lower():sub(1,#name)==name then
			return p
		end
	end
end

-- Teleport
local function TeleportToPlayer(name)
	local lp=Players.LocalPlayer
	local t=FindPlayer(name)
	if not t then return SendChat("Player not found: "..name) end

	local hrp=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
	local thr=t.Character and t.Character:FindFirstChild("HumanoidRootPart")

	if hrp and thr then
		hrp.CFrame=thr.CFrame+Vector3.new(0,3,0)
		SendChat("Teleported to "..t.Name)
	end
end

-- AutoWalk
RunService.RenderStepped:Connect(function()
	if _G.AutoWalkTarget then
		local lp=Players.LocalPlayer
		local t=FindPlayer(_G.AutoWalkTarget)
		if t and t.Character and lp.Character then
			local my=lp.Character:FindFirstChild("HumanoidRootPart")
			local th=t.Character:FindFirstChild("HumanoidRootPart")
			local hum=lp.Character:FindFirstChildOfClass("Humanoid")
			if my and th and hum then
				hum:MoveTo(th.Position)
			end
		end
	end
end)

-- Player Info
local function GetPlayerInfo(name)
	local p=FindPlayer(name)
	if not p then return "Player not found: "..name end
	return "Player Info:\nUsername: "..p.Name..
	"\nDisplayName: "..p.DisplayName..
	"\nAccount Age: "..p.AccountAge.." days"
end

-- Weather
local function GetWeather(city)
	city=tostring(city)

	local geo=request({
		Url="https://geocoding-api.open-meteo.com/v1/search?name="..city,
		Method="GET"
	})
	if not geo or not geo.Body then return "Geo API error" end

	local d1=HttpService:JSONDecode(geo.Body)
	if not d1.results or #d1.results==0 then return "City not found" end

	local lat=d1.results[1].latitude
	local lon=d1.results[1].longitude

	local w=request({
		Url="https://api.open-meteo.com/v1/forecast?latitude="..lat.."&longitude="..lon.."&current_weather=true",
		Method="GET"
	})
	if not w or not w.Body then return "Weather API error" end

	local d2=HttpService:JSONDecode(w.Body).current_weather
	if not d2 then return "No weather data" end

	return "⛅ Weather "..city..
	"\n🌡 Temp: "..d2.temperature.."°C"..
	"\n💨 Wind: "..d2.windspeed.." km/h"..
	"\n🔖 Code: "..d2.weathercode
end

-- IP Lookup (SAFE)
local function trim(s) return (s:gsub("^%s*(.-)%s*$","%1")) end
local function IPLookup(ip)
	ip=trim(ip); if ip=="" then return "Invalid IP" end

	local res=request({
		Url="http://ip-api.com/json/"..ip.."?fields=status,message,country,city,query",
		Method="GET"
	})
	if not res or not res.Body then return "IP lookup failed" end

	local d=HttpService:JSONDecode(res.Body)
	if d.status~="success" then return "Lookup failed" end

	return "IP Lookup\nIP: "..d.query..
	"\nCountry: "..d.country..
	"\nCity: "..d.city
end

-- Ping
local function CommandPing()
	local start=tick()
	request({Url="https://api.ipify.org",Method="GET"})
	local ms=math.floor((tick()-start)*1000)
	SendChat("Ping: "..ms.." ms")
end

-- HANDLE COMMAND
local function Handle(sender,msg)
	if not msg then return end
	local lower=msg:lower()

	if lower:sub(1,#PREFIX)==PREFIX then
		local cmd=lower:sub(#PREFIX+1)

		if cmd=="ping" then CommandPing() return end
		if cmd:sub(1,3)=="tp " then TeleportToPlayer(trim(cmd:sub(4))) return end
		if cmd:sub(1,3)=="ai " then SendChat(AskAI(msg:sub(#PREFIX+5))) return end
		if cmd:sub(1,5)=="info " then SendChat(GetPlayerInfo(trim(cmd:sub(6)))) return end
		if cmd:sub(1,5)=="walk " then _G.AutoWalkTarget=trim(cmd:sub(6)) SendChat("Auto walk → ".._G.AutoWalkTarget) return end
		if cmd=="walkoff" then _G.AutoWalkTarget=nil SendChat("Auto walk OFF") return end
		if cmd:sub(1,8)=="weather " then SendChat(GetWeather(trim(cmd:sub(9)))) return end
		if cmd:sub(1,9)=="iplookup " then SendChat(IPLookup(trim(cmd:sub(10)))) return end
	end

	-- Auto AI reply if user mentions your name
	if lower:find(Players.LocalPlayer.Name:lower()) then
		SendChat(AskAI(msg))
	end
end

-- CHAT LISTENER
if TextChatService.ChatVersion==Enum.ChatVersion.TextChatService then
	TextChatService.MessageReceived:Connect(function(packet)
		local plr=Players:GetPlayerByUserId(packet.TextSource.UserId)
		if plr then Handle(plr,packet.Text) end
	end)
else
	Players.PlayerChatted:Connect(function(plr,msg)
		Handle(plr,msg)
	end)
end

-- UI
local ui=Instance.new("ScreenGui",CoreGui)
local box=Instance.new("TextLabel",ui)
box.Size=UDim2.new(0,260,0,40)
box.Position=UDim2.new(0,10,0.5,-20)
box.BackgroundColor3=Color3.fromRGB(20,20,20)
box.TextColor3=Color3.new(1,1,1)
box.Font=Enum.Font.GothamBold
box.TextSize=14
box.Text="UNXHub Gemini ("..PREFIX..")"
Instance.new("UICorner",box).CornerRadius=UDim.new(0,10) di
