-- @name august.matchmaker.luau
-- @description join numbered matchmaking servers and search by owner name
-- @author august
-- @defaultKeybind M

config = config or {}
alwaysTick = true
-- i tried pascal casing do u lik iet
local MaxMatchmakingServer = 20
local SearchServerTimeout = 3
local SearchPlayerCheckDelay = 3
local SelectedServerNumber = math.clamp(tonumber(config.MatchmakingServerNumber or config.matchmakingServerNumber) or 0, 0, MaxMatchmakingServer)
local OwnerName = config.OwnerName or config.ownerName or "namehere"
local AutoFindState = config.AutoFindActive and "searching" or nil
local SearchServerNumber = config.AutoFindActive and math.clamp(tonumber(config.AutoFindServerNumber) or 0, 0, MaxMatchmakingServer) or -1
local SearchStationName = ""
local SearchElapsed = 0
local SearchConnectAccepted = false
local SearchNeedsConnect = config.AutoFindActive == true
local StatusMessage = ""

-- matchmaking servers
local function GetStationName(ServerNumber)
	if ServerNumber == 0 then
		return "Matchmaking"
	end
	return "Matchmaking_" .. tostring(ServerNumber)
end

-- it config says we were in middle of autofind, try to recover
if AutoFindState == "searching" then
	SearchStationName = GetStationName(SearchServerNumber)
end

-- save the resume point before asking the client to change servers
local function SaveSettings()
	if saveConfig then
		saveConfig()
	end
end

local function TrimmedOwnerName()
	return (OwnerName or ""):match("^%s*(.-)%s*$")
end

local function IsUsableOwnerName(Name)
	return string.lower(Name or "") ~= ""
end

local function StopAutoFind(Message)
	AutoFindState = nil
	SearchNeedsConnect = false
	config.AutoFindActive = false
	config.AutoFindServerNumber = nil
	StatusMessage = Message
	SaveSettings()
end

local function StartSearchServer(ServerNumber)
	-- stop
	if ServerNumber > MaxMatchmakingServer then
		StopAutoFind("auto-find finished, not found! :(")
		return
	end

	SearchServerNumber = ServerNumber
	SearchStationName = GetStationName(ServerNumber)
	SearchElapsed = 0
	SearchConnectAccepted = false
	SearchNeedsConnect = true
	config.AutoFindActive = true
	config.AutoFindServerNumber = ServerNumber
	SaveSettings()
end

local function StartAutoFind()
	StatusMessage = ""
	AutoFindState = "searching"
	StartSearchServer(0)
end

local function CancelAutoFind()
	StopAutoFind("cancelled :/")
end

local function CurrentServerHasOwner()
	-- no replaypl s
	if not getGameData then
		return false
	end

	local GameData = getGameData()
	if not GameData or not GameData.players then
		return false
	end

	local TargetName = string.lower(TrimmedOwnerName())
	for _, PlayerInfo in ipairs(GameData.players) do
		local Player = PlayerInfo
		if PlayerInfo.playerId and GameData.getPlayerById then
			Player = GameData:getPlayerById(PlayerInfo.playerId) or PlayerInfo
		end
		if Player and Player.playerName and string.lower(Player.playerName) == TargetName then
			return true
		end
	end
	return false
end

local function OnGui()
	-- gui
	if AutoFindState == "searching" then
		Gui.separatorText("looking...")
        Gui.textDisabled("pls stay patient, even if the script is off it's doing it in the background!")
		Gui.text("looking for " .. TrimmedOwnerName())
		Gui.text("server " .. tostring(SearchServerNumber) .. " of " .. tostring(MaxMatchmakingServer))
		Gui.text("joining: " .. SearchStationName)
		if Gui.buttonColored(LinearColor.new(1, 0, 0, 0.4), "cancel") then
			CancelAutoFind()
		end
		return
	end

	if AutoFindState == "confirm" then
		Gui.separatorText("auto-find")
        Gui.textDisabled("pls stay patient, even if the script is off it's doing it in the background!")
		Gui.text("confirm to look for " .. TrimmedOwnerName() ~= "" and TrimmedOwnerName() or "(blank)")
		if Gui.button("yes, continue") then
			if IsUsableOwnerName(TrimmedOwnerName()) then
				StartAutoFind()
			else
				AutoFindState = "owner"
			end
		end
		Gui.sameLine()
        if Gui.buttonColored(LinearColor.new(1, 0, 0, 0.4), "cancel##confirmAutoFind") then
			AutoFindState = nil
		end
		return
	end

	if AutoFindState == "owner" then
		Gui.separatorText("name")
		Gui.text("write your player name before auto-finding")
		local NewOwnerName = Gui.inputText("name", OwnerName)
		if NewOwnerName ~= OwnerName then
			OwnerName = NewOwnerName
			config.OwnerName = OwnerName
			SaveSettings()
		end
		if IsUsableOwnerName(TrimmedOwnerName()) then
			if Gui.button("continue") then
				StartAutoFind()
			end
		else
			Gui.text("enter a name!!")
		end
		if Gui.buttonColored(LinearColor.new(1, 0, 0, 0.4), "cancel##setOwner") then
			AutoFindState = nil
		end
		return
	end

    Gui.text("matchmaker")

	Gui.separatorText("manually join a server")
	Gui.textDisabled("select server num (eg. 2 for Matchmaking_2)")
	SelectedServerNumber = Gui.sliderInt("server num", SelectedServerNumber, 0, MaxMatchmakingServer)
	if SelectedServerNumber ~= config.MatchmakingServerNumber then
		config.MatchmakingServerNumber = SelectedServerNumber
		SaveSettings()
	end
	if Gui.button("Join " .. GetStationName(SelectedServerNumber)) then
		local StationName = GetStationName(SelectedServerNumber)
		local Connected = Network.connectToServer(StationName)
		StatusMessage = Connected and ("joining " .. StationName .. "...") or ("could NOT join " .. StationName .. ".")
	end

	Gui.newLine()

    Gui.separatorText("auto-find owner")
    Gui.textDisabled("goes through every matchmaking server to find the owner")

	local NewOwnerName = Gui.inputText("name", OwnerName)
	if NewOwnerName ~= OwnerName then
		OwnerName = NewOwnerName
		config.OwnerName = OwnerName
		SaveSettings()
	end
	if Gui.button("auto-find") then
		AutoFindState = "confirm"
		StatusMessage = ""
	end

	if StatusMessage ~= "" then
		Gui.newLine()
		Gui.text(StatusMessage)
	end
end

-- recovers
local function Tick(DeltaTime)
	-- recovery i think works
	if AutoFindState ~= "searching" then
		return
	end

	SearchElapsed += DeltaTime
	if SearchNeedsConnect then
		SearchNeedsConnect = false
		local CurrentStation = Network.getCurrentServer()
		if string.lower(CurrentStation or "") == string.lower(SearchStationName) then
			SearchConnectAccepted = true
		else
			SearchConnectAccepted = Network.connectToServer(SearchStationName)
			return
		end
	end

	-- wait for server ebefore check player list
	local CurrentServer = Network.getCurrentServer()
	if SearchConnectAccepted and string.lower(CurrentServer or "") == string.lower(SearchStationName) then
		if SearchElapsed >= SearchPlayerCheckDelay and CurrentServerHasOwner() then
			StopAutoFind("found! server was " .. SearchStationName .. ".")
			return
		end
	end

	if SearchElapsed >= SearchServerTimeout then
		StartSearchServer(SearchServerNumber + 1)
	end
end

function onGui()
	OnGui()
end

function tick(DeltaTime)
	Tick(DeltaTime)
    camera:followCamera(getCameraById("august.procam"))
end
