-- State Variables
local autopilotEnabled = false
local autopilotWander = false
local autopilotThreadActive = false

-- Helper function for notifications
local function setMinimapFeedback(message, type)
    local QBCore = exports['qb-core']:GetCoreObject()
    if QBCore and QBCore.Functions and QBCore.Functions.Notify then
        QBCore.Functions.Notify(message, type or 'success') -- 'success', 'error', 'inform', etc.
    else
        SetNotificationTextEntry("STRING")
        AddTextComponentString(message)
        DrawNotification(false, true)
    end
end

-- Gradual stop for the vehicle
local function stopVehicleGradually(playerPed, vehicle)
    if DoesEntityExist(vehicle) and GetPedInVehicleSeat(vehicle, -1) == playerPed then
        TaskVehicleTempAction(playerPed, vehicle, 1, 3000) -- Gradually stop the vehicle
        Citizen.Wait(3000) -- Allow time for the vehicle to stop
        ClearPedTasks(playerPed) -- Clear tasks once stopped
    end
end

-- Stop Autopilot
local function stopAutopilot()
    autopilotEnabled = false
    autopilotWander = false

    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)

    if DoesEntityExist(vehicle) and GetPedInVehicleSeat(vehicle, -1) == playerPed then
        stopVehicleGradually(playerPed, vehicle)
    end

    autopilotThreadActive = false
    setMinimapFeedback("Auto-Pilot deactivated.", 'inform')
end

-- Validate Vehicle
local function isVehicleAllowed(vehicle)
    if not Config.VEHICLE_RESTRICTIONS.ENABLED then
        return true -- No restrictions
    end

    if not vehicle then return false end

    local model = GetEntityModel(vehicle)
    local modelName = GetDisplayNameFromVehicleModel(model):lower()

    for _, allowedModel in ipairs(Config.VEHICLE_RESTRICTIONS.ALLOWED_VEHICLES) do
        if modelName == allowedModel:lower() then
            return true
        end
    end

    return false -- Not in allowed list
end

-- Start Autopilot Logic
local function startAutopilot(wanderMode)
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)

    if not DoesEntityExist(vehicle) or GetPedInVehicleSeat(vehicle, -1) ~= playerPed then
        setMinimapFeedback("You must be driving a vehicle to activate Auto-Pilot.", 'error')
        return
    end

    if not isVehicleAllowed(vehicle) then
        setMinimapFeedback("This vehicle is not allowed for Auto-Pilot.", 'error')
        return
    end

    -- Toggle autopilot state
    if autopilotEnabled then
        stopAutopilot()
        return
    end

    autopilotEnabled = true
    autopilotWander = wanderMode
    local modeText = wanderMode and "Wander" or "Waypoint"
    setMinimapFeedback("Auto-Pilot (" .. modeText .. ") activated.", 'success')

    -- Start Autopilot Thread
    if not autopilotThreadActive then
        Citizen.CreateThread(function()
            autopilotThreadActive = true
            while autopilotEnabled do
                Citizen.Wait(Config.THREAD_WAIT)

                playerPed = PlayerPedId()
                vehicle = GetVehiclePedIsIn(playerPed, false)

                if not DoesEntityExist(vehicle) or GetPedInVehicleSeat(vehicle, -1) ~= playerPed then
                    setMinimapFeedback("Auto-Pilot deactivated: Vehicle invalid.", 'error')
                    stopAutopilot()
                    break
                end

                if autopilotWander then
                    -- Wander Mode: Random destinations
                    local x, y, z = table.unpack(GetEntityCoords(vehicle))
                    local randomX = x + math.random(-Config.WANDER_DISTANCE, Config.WANDER_DISTANCE)
                    local randomY = y + math.random(-Config.WANDER_DISTANCE, Config.WANDER_DISTANCE)
                    local groundZ = GetGroundZFor_3dCoord(randomX, randomY, z, false) or z

                    TaskVehicleDriveToCoordLongrange(playerPed, vehicle, randomX, randomY, groundZ, Config.DRIVE_SPEED_WANDER, Config.DRIVE_STYLE_WANDER, 10.0)
                    Citizen.Wait(math.random(Config.WANDER_WAIT_MIN, Config.WANDER_WAIT_MAX))
                else
                    -- Waypoint Mode
                    if IsWaypointActive() then
                        local waypointBlip = GetFirstBlipInfoId(8) -- Waypoint blip type
                        if DoesBlipExist(waypointBlip) then
                            local waypointCoords = GetBlipInfoIdCoord(waypointBlip)
                            TaskVehicleDriveToCoordLongrange(playerPed, vehicle, waypointCoords.x, waypointCoords.y, waypointCoords.z, Config.DRIVE_SPEED_WAYPOINT, Config.DRIVE_STYLE_WAYPOINT, 3.0)

                            -- Check distance
                            local currentPos = GetEntityCoords(vehicle)
                            local distance = Vdist(currentPos.x, currentPos.y, currentPos.z, waypointCoords.x, waypointCoords.y, waypointCoords.z)

                            if distance < Config.WAYPOINT_THRESHOLD then
                                setMinimapFeedback("Destination reached.", 'success')
                                stopAutopilot()
                                break
                            end
                        else
                            setMinimapFeedback("Waypoint invalid. Set a new one.", 'error')
                            stopAutopilot()
                            break
                        end
                    else
                        setMinimapFeedback("No active waypoint. Auto-Pilot deactivated.", 'inform')
                        stopAutopilot()
                        break
                    end
                end
            end
            autopilotThreadActive = false -- Ensure thread cleanup
        end)
    else
        setMinimapFeedback("Auto-Pilot thread already running.", 'error')
    end
end

-- Command to toggle autopilot
RegisterCommand("autopilot", function(source, args)
    local mode = args[1]
    if mode == "wander" then
        startAutopilot(true) -- Wander mode
    else
        startAutopilot(false) -- Waypoint mode
    end
end, false)

-- Optional: Add a key binding
-- RegisterKeyMapping('autopilot', 'Toggle Auto-Pilot', 'keyboard', 'F6')
