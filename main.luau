-- @name august.matchmaker.luau
-- @description join numbered matchmaking servers
-- @author august
-- @defaultKeybind M

config = config or {}
alwaysTick = true

-- CHANGE THIS IF MORE SERVERS EVER APPEAR (they shouldnt i dont think so):
local MaxMatchmakingServer = 20

local SelectedServerNumber = math.clamp(tonumber(config.MatchmakingServerNumber or config.matchmakingServerNumber) or 0, 0, MaxMatchmakingServer)
local StatusMessage = ""

local function GetStationName(ServerNumber)
	if ServerNumber == 0 then
		return "Matchmaking"
	end
	return "Matchmaking_" .. tostring(ServerNumber)
end

-- Config helper
local function SaveSettings()
	if saveConfig then
		saveConfig()
	end
end

local function OnGui()
	Gui.textDisabled("Ranked servers aren't visible in the server browser, so you can join via this!")

	Gui.separatorText("server picker")
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
	if StatusMessage ~= "" then
		Gui.newLine()
		Gui.text(StatusMessage)
	end
end

function onGui()
	OnGui()
end

function tick(_DeltaTime)
    camera:followCamera(getCameraById("august.procam"))
	-- Procam ^ support is optional but its just a tiny thing to have that helps lol
end

-- I tried pascal casing, do u like it
