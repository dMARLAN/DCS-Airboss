-- DCS Airboss by MARLAN

-- Configuration: General
local carrierName = "CVN-71 Theodore Roosevelt" -- Unit Name in Mission Editor
local tacanChannel = 71 -- TACAN Channel
local ICLSChannel = 1 -- ICLS Channel
local ACLSChannel = 123 -- ACLS Channel
local desiredWindOverDeckKnots = 12 -- Should be 25-30 knots
local isCyclicOps = true -- TRUE = Cyclic Ops with air plan; FALSE = CQ Ops. See README for more info

-- Configuration: Cyclic Ops
local numOfAirPlanWindows = 8
local timeOfFirstAirPlanWindowHour = 10 -- 10:00
local timeOfFirstAirPlanWindowMinute = 15 -- Above plus 15 minutes; 10:15
local lengthOfAirPlanWindowMinutes = 75 -- 75 minutes

-- Configuration: CQ Ops
local automaticTurnIntoWindRangeNauticalMiles = 50


-- don't edit past this line
local turnShipIntoWind, generateAirPlan, executeCyclicOps, returnToStart, setWaypoint
local initialCarrierPosition = Unit.getByName(carrierName):getPoint()

function turnShipIntoWind(shipName, speedKnots)
    local curPos = Unit.getByName(shipName):getPoint()

    local wind = atmosphere.getWind(curPos)
    local bearing = math.atan2(wind.z, wind.x)
    local velocity = math.sqrt(wind.x ^ 2 + wind.z ^ 2)

    bearing = bearing - math.pi + 0.15708 -- inverse the direction and add 9 degrees to get angle of landing area

    local offsetVel = speedKnots - velocity
    if offsetVel < 5 then
        -- cant have negative number so might as well make the ship go slow
        offsetVel = 5
    end

    local waypoint = { x = 0, y = 0, speed = offsetVel, type = "Turning Point", action = "Turning Point" }
    waypoint.x = math.cos(bearing) * 100000 + curPos.x -- gives 100km long track in a given direction
    waypoint.y = math.sin(bearing) * 100000 + curPos.z
end

function returnToStart()
    local waypoint = { x = initialCarrierPosition.x, y = initialCarrierPosition.y, speed = 30, type = "Turning Point", action = "Turning Point" }
end

function setWaypoint()

end

function generateAirPlan(timeFirstAirPlanWindowHour, timeFirstAirPlanWindowMinute, lengthAirPlanWindowMinutes, numAirPlanWindows)
    local airPlanWindows = {}

    local firstEventInSeconds = ((timeFirstAirPlanWindowHour * 60) + timeFirstAirPlanWindowMinute) * 60

    for i = 1, numAirPlanWindows do
        local airPlanWindow = {}
        airPlanWindow.startSecs = (firstEventInSeconds * i) - 900 -- 15 minutes before
        airPlanWindow.endSecs = airPlanWindow.startSecs + (lengthAirPlanWindowMinutes * 60)
        airPlanWindows[i] = airPlanWindow
    end

    return airPlanWindows
end

function executeCyclicOps(shipName, speedKnots, timeFirstAirPlanWindowHour, timeFirstAirPlanWindowMinute, lengthAirPlanWindowMinutes, numAirPlanWindows)
    local airPlanWindows = generateAirPlan(timeFirstAirPlanWindowHour, timeFirstAirPlanWindowMinute, lengthAirPlanWindowMinutes, numAirPlanWindows)

    for i = 1, #airPlanWindows do
        timer.scheduleFunction(turnShipIntoWind(), { shipName, speedKnots }, timer.getTime() + airPlanWindows[i].startSecs)
        timer.scheduleFunction(returnToStart(), { shipName }, timer.getTime() + airPlanWindows[i].endSecs)
    end
end

local function main()
    if (isCyclicOps) then
        executeCyclicOps(
                carrierName,
                desiredWindOverDeckKnots,
                timeOfFirstAirPlanWindowHour,
                timeOfFirstAirPlanWindowMinute,
                lengthOfAirPlanWindowMinutes,
                numOfAirPlanWindows
        )
    else
        -- do CQ ops (not implemented)
    end
end
main()