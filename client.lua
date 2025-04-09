local veh, tesla_blip = nil, nil
local autopilotEnabled = false
local autopilotThreadActive = false

-- Notify wrapper
local function notify(msg, type)
    local QBCore = exports['qb-core']:GetCoreObject()
    if QBCore?.Functions?.Notify then
        QBCore.Functions.Notify(msg, type or 'inform')
    else
        SetNotificationTextEntry("STRING")
        AddTextComponentString(msg)
        DrawNotification(0, 1)
    end
end

-- Get current waypoint vector3
local function getWaypointCoords()
    if not IsWaypointActive() then return nil end
    local blip = GetFirstBlipInfoId(8)
    local coords = Citizen.InvokeNative(0xFA7C7F0AADF25D09, blip, Citizen.ResultAsVector())
    if coords and coords.x and coords.y and coords.z then
        return coords
    end
    return nil
end

-- Cancel autopilot and reset tasks
local function stopAutopilot(vehicle, playerPed, reason)
    autopilotEnabled = false
    if reason then notify(reason, 'error') end
    if DoesEntityExist(vehicle) and GetPedInVehicleSeat(vehicle, -1) == playerPed then
        TaskVehicleTempAction(playerPed, vehicle, 27, 3000)
    end
    ClearPedTasks(playerPed)
end

-- Main autopilot logic
local function startAutopilot()
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)

    if autopilotEnabled then
        stopAutopilot(vehicle, playerPed, "Auto-Pilot deactivated.")
        return
    end

    if not DoesEntityExist(vehicle) or GetPedInVehicleSeat(vehicle, -1) ~= playerPed then
        return notify("You must be driving a vehicle to use Auto-Pilot.", "error")
    end

    local waypoint = getWaypointCoords()
    if not waypoint then
        return notify("Please set a valid waypoint before enabling Auto-Pilot.", "error")
    end

    autopilotEnabled = true
    notify("Auto-Pilot activated.", "success")
    TaskVehicleDriveToCoordLongrange(playerPed, vehicle, waypoint.x, waypoint.y, waypoint.z, 75.0, 787004, 1.0)

    -- Thread to monitor autopilot state
    if autopilotThreadActive then return end
    autopilotThreadActive = true

    Citizen.CreateThread(function()
        while autopilotEnabled do
            Wait(500)

            -- Cancel if waypoint removed
            if not IsWaypointActive() then
                stopAutopilot(vehicle, playerPed, "Auto-Pilot deactivated: No active waypoint.")
                break
            end

            if not DoesEntityExist(vehicle) then
                stopAutopilot(vehicle, playerPed, "Auto-Pilot deactivated: Vehicle lost.")
                break
            end

            local currentPos = GetEntityCoords(vehicle)
            local distance = Vdist(currentPos.x, currentPos.y, currentPos.z, waypoint.x, waypoint.y, waypoint.z)

            if distance < 20.0 then
                TaskVehicleTempAction(playerPed, vehicle, 27, 1000)
            end

            if distance < 5.0 then
                stopAutopilot(vehicle, playerPed, "Destination reached.")
                break
            end
        end

        autopilotThreadActive = false
    end)
end

-- Command binding
RegisterCommand("autopilot", startAutopilot, false)
