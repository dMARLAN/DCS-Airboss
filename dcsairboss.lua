-- DCS Airboss by MARLAN

-- Configuration: General
local carrierName = "CVN-71 Theodore Roosevelt" -- Unit Name in Mission Editor
local tacanChannel = 71 -- TACAN Channel
local ICLSChannel = 1 -- ICLS Channel
local ACLSChannel = 123 -- ACLS Channel
local desiredWindOverDeckKnots = 12 -- Should be 25-30 knots
local isCyclicOps = true -- TRUE = Cyclic Ops with air plan; FALSE = CQ Ops. See README for more info
local isMenuAllGroups = false -- TRUE = Menu for all groups; FALSE = Menu for specific groups
local GROUPS_WITH_MENU = { "UZI", "ENFIELD", "COLT", "PONTIAC", "SPRINGFIELD", "DODGE", "FORD", "CHEVY" } -- Matches if contains any of these strings

-- Configuration: Cyclic Ops
local numOfAirPlanWindows = 8
local timeOfFirstAirPlanWindowHour = 10 -- 10:00
local timeOfFirstAirPlanWindowMinute = 15 -- Above plus 15 minutes; 10:15
local lengthOfAirPlanWindowMinutes = 75 -- 75 minutes

-- Configuration: CQ Ops
local automaticTurnIntoWindRangeNauticalMiles = 50


-- don't edit past this line
local turnShipIntoWind, generateAirPlan, executeCyclicOps, returnShipToInitialPosition, setWaypoint
local forceRecoveryStart, forceRecoveryStop, airPlanResume, createMenusForAll, clearAirPlan
local initialCarrierPosition = Unit.getByName(carrierName):getPoint()

local airbossMenu = {}
local airbossMenuHandler = {}
local airPlanWindowFunctions = {}
local createGroupSpecificMenus, matchAnyName

function airbossMenuHandler:onEvent(event)
    if event.id == world.event.S_EVENT_BIRTH and event.initiator:getPlayerName() ~= nil then
        if matchAnyName(Group.getName(event.initiator:getGroup()), GROUPS_WITH_MENU) then
            local group = event.initiator:getGroup()
            local groupId = Group.getID(group)
            if airbossMenu[groupId] == nil then
                createGroupSpecificMenus(groupId)
            end
        end
    end
end

function matchAnyName(groupNameToCheck, namesTable)
    for _, name in pairs(namesTable) do
        if string.match(groupNameToCheck,name) then
            return true
        end
    end
    return false
end

function createGroupSpecificMenus(groupId, shipName)
    airbossMenu[groupId] = missionCommands.addSubMenuForGroup(groupId, "Airboss Menu")
    missionCommands.addCommandForGroup(groupId, "Force Recovery Start", airbossMenu[groupId], forceRecoveryStart, shipName)
    missionCommands.addCommandForGroup(groupId, "Force Recovery Stop", airbossMenu[groupId], forceRecoveryStop, shipName)
    if (isCyclicOps) then
        missionCommands.addCommandForGroup(groupId, "Air Plan Resume", airbossMenu[groupId], airPlanResume, shipName)
    end
end

function createMenusForAll(shipName)
    local airbossMenuAllGroups = missionCommands.addSubMenu("Airboss Menu")
    missionCommands.addCommand("Force Recovery Start", airbossMenuAllGroups, forceRecoveryStart, shipName)
    missionCommands.addCommand("Force Recovery Stop", airbossMenuAllGroups, forceRecoveryStop, shipName)
    if (isCyclicOps) then
        missionCommands.addCommand("Air Plan Resume", airbossMenuAllGroups, airPlanResume, shipName)
    end
end

function forceRecoveryStart(shipName)
    clearAirPlan()
    turnShipIntoWind(shipName, 30)
end

function forceRecoveryStop(shipName)
    clearAirPlan()
    returnShipToInitialPosition(shipName)
end

function airPlanResume(shipName)

end

function clearAirPlan()
    for i = 1, numOfAirPlanWindows do
        if airPlanWindowFunctions[i] ~= nil then
            timer.removeFunction(airPlanWindowFunctions[i].startFunc)
            airPlanWindowFunctions[i].startFunc = nil
            timer.removeFunction(airPlanWindowFunctions[i].stopFunc)
            airPlanWindowFunctions[i].stopFunc = nil
        end
    end
end

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

    setWaypoint(shipName, waypoint)
end

function returnShipToInitialPosition(shipName)
    local waypoint = { x = initialCarrierPosition.x, y = initialCarrierPosition.y, speed = 30, type = "Turning Point", action = "Turning Point" }
    setWaypoint(shipName, waypoint)
end

function setWaypoint(groupName, waypoint)
    local curPos = Unit.getByName(groupName):getPoint()
    local mission = {
        id = 'Mission',
        params = {
            route = {
                points = {
                    [1] = {
                        x = curPos.x,
                        y = curPos.y,
                        type = "Turning Point",
                        speed = 25,
                        action = "Turning Point",
                    },
                    [2] = {
                        x = waypoint.x,
                        y = waypoint.y,
                        type = waypoint.type,
                        speed = waypoint.speed,
                        action = waypoint.action,
                    },
                },
            },
        },
    }

    local group = Group.getByName(groupName)
    if group then
        local controller = group:getController()
        if controller then
            controller:setTask(mission)
        end
    end
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
    -- TODO: Fix time to absolute
    for i = 1, #airPlanWindows do
        airPlanWindowFunctions[i].startFunc = timer.scheduleFunction(turnShipIntoWind(), { shipName, speedKnots }, timer.getTime() + airPlanWindows[i].startSecs)
        airPlanWindowFunctions[i].stopFunc = timer.scheduleFunction(returnShipToInitialPosition(), { shipName }, timer.getTime() + airPlanWindows[i].endSecs)
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

    if (isMenuAllGroups) then
        world.addEventHandler(airbossMenuHandler)
    else
        createMenusForAll()
    end
end
main()