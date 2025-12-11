local HttpService=game:GetService("HttpService")
local Players=game:GetService("Players")
local TextChatService=game:GetService("TextChatService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local CoreGui=game:GetService("CoreGui")
local RunService=game:GetService("RunService")

local PREFIX="."
local MODEL_ID="gemini-2.5-flash"
local FILE="APIKey_Executor_Mode.gem"

_G.GeminiKey=isfile(FILE) and readfile(FILE) or nil
_G.GeminiBusy=false
_G.AutoWalkTarget=nil

local function SendChat(msg)
	if TextChatService.ChatVersion==Enum.ChatVersion.TextChatService then
		local ch=TextChatService.TextChannels:FindFirstChild("RBXGeneral")
		if ch then ch:SendAsync(msg) end
	else
		local d=ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
		if d then d.SayMessageRequest:FireServer(msg,"All") end
	end
end

local function AskAI(prompt)
	if not _G.GeminiKey then return "No API key. Save it in "..FILE end
	if _G.GeminiBusy then return "AI busy" end
	_G.GeminiBusy=true
	local res=request({
		Url="https://generativelanguage.googleapis.com/v1beta/models/"..MODEL_ID..":generateContent?key=".._G.GeminiKey,
		Method="POST",
		Headers={["Content-Type"]="application/json"},
		Body=HttpService:JSONEncode({
			contents={{parts={{text=prompt}}}}
		})
	})
	_G.GeminiBusy=false
	if not res or not res.Body then return "API error" end
	local d=HttpService:JSONDecode(res.Body)
	if d.candidates and d.candidates[1] then
		return d.candidates[1].content.parts[1].text
	end
	return "No response"
end

local function FindPlayer(name)
	name=name:lower()
	for _,p in ipairs(Players:GetPlayers()) do
		if p.Name:lower():sub(1,#name)==name or p.DisplayName:lower():sub(1,#name)==name then
			return p
		end
	end
end

local function TeleportToPlayer(name)
	local lp=Players.LocalPlayer
	local t=FindPlayer(name)
	if not t then SendChat("Player not found: "..name) return end
	local my=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
	local th=t.Character and t.Character:FindFirstChild("HumanoidRootPart")
	if my and th then
		my.CFrame=th.CFrame+Vector3.new(0,3,0)
		SendChat("Teleported to "..t.Name)
	end
end

RunService.RenderStepped:Connect(function()
	if _G.AutoWalkTarget then
		local lp=Players.LocalPlayer
		local t=FindPlayer(_G.AutoWalkTarget)
		if t and t.Character and lp.Character then
			local my=lp.Character:FindFirstChild("HumanoidRootPart")
			local th=t.Character:FindFirstChild("HumanoidRootPart")
			local hum=lp.Character:FindFirstChildOfClass("Humanoid")
			if my and th and hum then hum:MoveTo(th.Position) end
		end
	end
end)

local function GetPlayerInfo(name)
	local p=FindPlayer(name)
	if not p then return "Player not found: "..name end

	return
		"Player Info:\n"..
		"Username: "..p.Name.."\n"..
		"DisplayName: "..p.DisplayName.."\n"..
		"Account Age: "..p.AccountAge.." days"
	    "Account ID:  "..p.UserId"
end

local function GetWeather(city)
	local geo=request({Url="https://geocoding-api.open-meteo.com/v1/search?name="..city,Method="GET"})
	if not geo or not geo.Body then return "Geo error" end
	local g=HttpService:JSONDecode(geo.Body)
	if not g.results or #g.results==0 then return "City not found" end
	local lat=g.results[1].latitude
	local lon=g.results[1].longitude

	local w=request({
		Url="https://api.open-meteo.com/v1/forecast?latitude="..lat.."&longitude="..lon.."&current_weather=true",
		Method="GET"
	})
	if not w or not w.Body then return "Weather error" end
	local d=HttpService:JSONDecode(w.Body).current_weather
	if not d then return "No weather data" end

	return "Weather "..city.."\nTemp: "..d.temperature.."C\nWind: "..d.windspeed.."km/h\nCode: "..d.weathercode
end

local function Handle(sender,msg)
	local lower=msg:lower()
	if lower:sub(1,#PREFIX)==PREFIX then
		local cmd=lower:sub(#PREFIX+1)

		if cmd=="ping" then SendChat("Pong") return end
		if cmd:sub(1,3)=="tp " then TeleportToPlayer(cmd:sub(4)) return end
		if cmd:sub(1,3)=="ai " then SendChat(AskAI(msg:sub(#PREFIX+5))) return end
		if cmd:sub(1,5)=="info " then SendChat(GetPlayerInfo(cmd:sub(6))) return end
		if cmd:sub(1,5)=="walk " then _G.AutoWalkTarget=cmd:sub(6) SendChat("Auto walk: "..cmd:sub(6)) return end
		if cmd=="walkoff" then _G.AutoWalkTarget=nil SendChat("Auto walk off") return end
		if cmd:sub(1,8)=="weather " then SendChat(GetWeather(cmd:sub(9))) return end
	end

	if lower:find(Players.LocalPlayer.Name:lower()) then
		SendChat(AskAI(msg))
	end
end

if TextChatService.ChatVersion==Enum.ChatVersion.TextChatService then
	TextChatService.MessageReceived:Connect(function(p)
		local plr=Players:GetPlayerByUserId(p.TextSource.UserId)
		if plr then Handle(plr,p.Text) end
	end)
else
	Players.PlayerChatted:Connect(function(plr,msg)
		Handle(plr,msg)
	end)
end

local ui=Instance.new("ScreenGui",CoreGui)
local box=Instance.new("TextLabel",ui)
box.Size=UDim2.new(0,260,0,40)
box.Position=UDim2.new(0,10,0.5,-20)
box.BackgroundColor3=Color3.fromRGB(20,20,20)
box.TextColor3=Color3.new(1,1,1)
box.Font=Enum.Font.GothamBold
box.TextSize=14
box.Text="UNXHub Gemini ("..PREFIX..")"
Instance.new("UICorner",box).CornerRadius=UDim.new(0,10)
