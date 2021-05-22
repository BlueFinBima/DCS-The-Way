local tcpServer = nil
local udpSpeaker = nil
package.path  = package.path..";"..lfs.currentdir().."/LuaSocket/?.lua"
package.cpath = package.cpath..";"..lfs.currentdir().."/LuaSocket/?.dll"
package.path  = package.path..";"..lfs.currentdir().."/Scripts/?.lua"
local socket = require("socket")

local JSON = loadfile("Scripts\\JSON.lua")()
local needDelay = false
local keypressinprogress = false
local isPressed = false
local hadDelay = false
local frameCounter = 0
local data
local delay = 0
local code = ""
local device = ""
local nextIndex = 1

local upstreamLuaExportStart = LuaExportStart
local upstreamLuaExportAfterNextFrame = LuaExportAfterNextFrame
local upstreamLuaExportBeforeNextFrame = LuaExportBeforeNextFrame


function LuaExportStart()
    successful, err = pcall(upstreamLuaExportStart)
    if not successful then
        log.write("THEWAY", log.ERROR, "Error in upstream LuaExportStart function: "..err) 
    end
    
	udpSpeaker = socket.udp()
	udpSpeaker:settimeout(0)
	tcpServer = socket.tcp()
    tcpServer:bind("127.0.0.1", 42070)
    tcpServer:listen(1)
    tcpServer:settimeout(0)
end

function LuaExportBeforeNextFrame()
    successful, err = pcall(upstreamLuaExportBeforeNextFrame)
    if not successful then
        log.write("THEWAY", log.ERROR, "Error in upstream LuaExportBeforeNextFrame function: "..err) 
    end

    if needDelay then
		if frameCounter < delay then
			frameCounter = frameCounter + 1
		else
			needDelay = false
			frameCounter = 0
			GetDevice(device):performClickableAction(code, 0)
		end
	else
		if keypressinprogress then
			local keys = JSON:decode(data)
			for i=nextIndex, #keys do
				local keyObj = keys[i]
				device = keyObj["device"]
				code = keyObj["code"]
				delay = tonumber(keyObj["delay"])
				
				local activate = tonumber(keyObj["activate"])

				if delay > 0 then
					needDelay = true
					GetDevice(device):performClickableAction(code, activate)
					nextIndex = i+1
					break
				else
					GetDevice(device):performClickableAction(code, activate)
					GetDevice(device):performClickableAction(code, 0)
				end
			end
			if not needDelay then
				keypressinprogress = false
				nextIndex = 1
			end
		else
			local client, error = tcpServer:accept()
            if error ~= nil then
                log.write("THEWAY", log.ERROR, "Error at accepting connection: "..error)  
            end
            if client ~= nil then
                client:settimeout(10)
			    data, err = client:receive()
			    if err then
				    log.write("THEWAY", log.ERROR, "Error at receiving: "..err)  
			    end

			    if data then 
				    keypressinprogress = true
			    end
            end
		end
	end
end

function LuaExportAfterNextFrame()
    successful, err = pcall(upstreamLuaExportAfterNextFrame)
    if not successful then
        log.write("THEWAY", log.ERROR, "Error in upstream LuaExprtAfterNextFrame function: "..err) 
    end

    local camPos = LoGetCameraPosition()
	local loX = camPos['p']['x']
	local loZ = camPos['p']['z']
	local coords = LoLoCoordinatesToGeoCoordinates(loX, loZ)
	local model = LoGetSelfData()["Name"];

	local toSend = "{ ".."\"model\": ".."\""..model.."\""..", ".."\"coords\": ".. "{ ".."\"lat\": ".."\""..coords.latitude.."\""..", ".."\"long\": ".."\""..coords.longitude.."\"".."} ".."}"

	if pcall(function()
		socket.try(udpSpeaker:sendto(toSend, "127.0.0.1", 42069)) 
	end) then
	else
		log.write("THEWAY", log.ERROR, "Unable to send data")
	end
end