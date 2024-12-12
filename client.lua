-- ================================================
--                  Auto-Pilot Script
-- ================================================

local QBCore = exports['qb-core']:GetCoreObject()

-- Config Variables
local WAYPOINT_THRESHOLD = Config.WAYPOINT_THRESHOLD
local DRIVE_SPEED_WANDER = Config.DRIVE_SPEED_WANDER
local DRIVE_SPEED_WAYPOINT = Config.DRIVE_SPEED_WAYPOINT
local DRIVE_STYLE = Config.DRIVE_STYLE

-- Auto-Pilot State
local isAutoPilotActive = false
local autoPilotMode = nil -- Tracks current mode ("wander" or "waypoint")

-- Start or Stop Auto-Pilot
local function toggleAutoPilot(mode)
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)

    if not vehicle then
        QBCore.Functions.Notify("You need to be in a vehicle to use Auto-Pilot.", "error")
        return
    end

    if isAutoPilotActive and autoPilotMode == mode then
        -- Stop Auto-Pilot
        ClearPedTasks(playerPed)
        isAutoPilotActive = false
        autoPilotMode = nil
        QBCore.Functions.Notify("Auto-Pilot deactivated.", "success")
    else
        if mode == "wander" then
            -- Start Wander Mode
            TaskVehicleDriveWander(playerPed, vehicle, DRIVE_SPEED_WANDER, DRIVE_STYLE)
            QBCore.Functions.Notify("Auto-Pilot activated in Wander mode.", "success")
        elseif mode == "waypoint" then
            -- Start Waypoint Mode
            local waypoint = GetFirstBlipInfoId(8)
            if not DoesBlipExist(waypoint) then
                QBCore.Functions.Notify("Set a waypoint on your map.", "error")
                return
            end

            local coord = GetBlipInfoIdCoord(waypoint)
            local distance = #(GetEntityCoords(playerPed) - coord)

            if distance < WAYPOINT_THRESHOLD then
                QBCore.Functions.Notify("Waypoint is too close.", "error")
                return
            end

            TaskVehicleDriveToCoordLongrange(playerPed, vehicle, coord.x, coord.y, coord.z, DRIVE_SPEED_WAYPOINT, DRIVE_STYLE, WAYPOINT_THRESHOLD)
            QBCore.Functions.Notify("Auto-Pilot activated to Waypoint.", "success")
        else
            QBCore.Functions.Notify("Invalid Auto-Pilot mode.", "error")
            return
        end

        -- Set State
        isAutoPilotActive = true
        autoPilotMode = mode
    end
end

-- Register Commands
RegisterCommand("autopilot", function(source, args)
    local mode = args[1] or "waypoint" -- Default to waypoint mode if no argument is provided
    toggleAutoPilot(mode)
end, false)
