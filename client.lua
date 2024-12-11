-- ==========================
--       Auto-Pilot Script
-- ==========================

-- State Management
local autopilotState = {
    enabled = false,
    wander = false,
    threadActive = false
}

-- Cache QBCore Object for Performance
local QBCore = exports['qb-core']:GetCoreObject()

-- Notification Types for Consistency
local NOTIFY_TYPES = {
    SUCCESS = 'success',
    ERROR = 'error',
    INFORM = 'inform'
}

-- Helper Function: Display Notifications
local function setMinimapFeedback(message, type)
    type = type or NOTIFY_TYPES.SUCCESS
    if QBCore and QBCore.Functions and QBCore.Functions.Notify then
        QBCore.Functions.Notify(message, type)
    else
        SetNotificationTextEntry("STRING")
        AddTextComponentString(message)
        DrawNotification(false, true)
    end
end

-- Helper Function: Gradually (Now Smarter) Stop the Vehicle
local function stopVehicleGradually(playerPed, vehicle)
    if DoesEntityExist(vehicle) and GetPedInVehicleSeat(vehicle, -1) == playerPed then
        -- Apply Smart Brake for Immediate Stopping
        TaskVehicleTempAction(playerPed, vehicle, 4, 1000) -- Flag 4: Smart Brake, Duration: 1000ms
        Citizen.Wait(1000) -- Wait for the brake action to complete
        ClearPedTasks(playerPed) -- Clear tasks once stopped
    end
end

-- Function: Stop Autopilot
local function stopAutopilot()
    autopilotState.enabled = false
    autopilotState.wander = false

    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)

    if DoesEntityExist(vehicle) and GetPedInVehicleSeat(vehicle, -1) == playerPed then
        stopVehicleGradually(playerPed, vehicle)
    end

    autopilotState.threadActive = false
    setMinimapFeedback("Auto-Pilot deactivated.", NOTIFY_TYPES.INFORM)
end

-- Function: Validate if the Vehicle is Allowed
local function isVehicleAllowed(vehicle)
    if not Config.VEHICLE_RESTRICTIONS.ENABLED then
        return true -- No restrictions
    end

    if not vehicle then
        return false
    end

    local model = GetEntityModel(vehicle)
    local modelName = string.lower(GetDisplayNameFromVehicleModel(model))

    -- Iterate through allowed vehicles efficiently
    for _, allowedModel in ipairs(Config.VEHICLE_RESTRICTIONS.ALLOWED_VEHICLES) do
        if modelName == string.lower(allowedModel) then
            return true
        end
    end

    return false -- Vehicle not allowed
end

-- Function: Start Autopilot Logic
local function startAutopilot(wanderMode)
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)

    -- Validate if the player is in a vehicle and is the driver
    if not (DoesEntityExist(vehicle) and GetPedInVehicleSeat(vehicle, -1) == playerPed) then
        setMinimapFeedback("You must be driving a vehicle to activate Auto-Pilot.", NOTIFY_TYPES.ERROR)
        return
    end

    -- Validate if the vehicle is allowed
    if not isVehicleAllowed(vehicle) then
        setMinimapFeedback("This vehicle is not allowed for Auto-Pilot.", NOTIFY_TYPES.ERROR)
        return
    end

    -- Toggle Autopilot State
    if autopilotState.enabled then
        stopAutopilot()
        return
    end

    autopilotState.enabled = true
    autopilotState.wander = wanderMode
    local modeText = wanderMode and "Wander" or "Waypoint"
    setMinimapFeedback("Auto-Pilot (" .. modeText .. ") activated.", NOTIFY_TYPES.SUCCESS)

    -- Start Autopilot Thread if not already active
    if not autopilotState.threadActive then
        autopilotState.threadActive = true
        Citizen.CreateThread(function()
            while autopilotState.enabled do
                Citizen.Wait(Config.THREAD_WAIT)

                local currentPlayerPed = PlayerPedId()
                local currentVehicle = GetVehiclePedIsIn(currentPlayerPed, false)

                -- Validate vehicle status continuously
                if not (DoesEntityExist(currentVehicle) and GetPedInVehicleSeat(currentVehicle, -1) == currentPlayerPed) then
                    setMinimapFeedback("Auto-Pilot deactivated: Vehicle invalid.", NOTIFY_TYPES.ERROR)
                    stopAutopilot()
                    break
                end

                if autopilotState.wander then
                    -- Wander Mode: Navigate to Random Destinations
                    local coords = GetEntityCoords(currentVehicle)
                    local randomX = coords.x + math.random(-Config.WANDER_DISTANCE, Config.WANDER_DISTANCE)
                    local randomY = coords.y + math.random(-Config.WANDER_DISTANCE, Config.WANDER_DISTANCE)
                    local success, groundZ = GetGroundZFor_3dCoord(randomX, randomY, coords.z, false)
                    groundZ = success and groundZ or coords.z

                    TaskVehicleDriveToCoordLongrange(currentPlayerPed, currentVehicle, randomX, randomY, groundZ, Config.DRIVE_SPEED_WANDER, Config.DRIVE_STYLE_WANDER, 10.0)
                    Citizen.Wait(math.random(Config.WANDER_WAIT_MIN, Config.WANDER_WAIT_MAX))
                else
                    -- Waypoint Mode: Navigate to User-Set Waypoint
                    if IsWaypointActive() then
                        local waypointBlip = GetFirstBlipInfoId(8) -- Waypoint blip type
                        if DoesBlipExist(waypointBlip) then
                            local waypointCoords = GetBlipInfoIdCoord(waypointBlip)
                            local success, groundZ = GetGroundZFor_3dCoord(waypointCoords.x, waypointCoords.y, waypointCoords.z, false)
                            groundZ = success and groundZ or waypointCoords.z

                            TaskVehicleDriveToCoordLongrange(currentPlayerPed, currentVehicle, waypointCoords.x, waypointCoords.y, groundZ, Config.DRIVE_SPEED_WAYPOINT, Config.DRIVE_STYLE_WAYPOINT, 3.0)

                            -- Check if Destination is Reached
                            local currentPos = GetEntityCoords(currentVehicle)
                            local distance = Vdist(currentPos.x, currentPos.y, currentPos.z, waypointCoords.x, waypointCoords.y, waypointCoords.z)

                            if distance < Config.WAYPOINT_THRESHOLD then
                                setMinimapFeedback("Destination reached.", NOTIFY_TYPES.SUCCESS)
                                stopAutopilot()
                                break
                            end
                        else
                            setMinimapFeedback("Waypoint invalid. Set a new one.", NOTIFY_TYPES.ERROR)
                            stopAutopilot()
                            break
                        end
                    else
                        setMinimapFeedback("No active waypoint. Auto-Pilot deactivated.", NOTIFY_TYPES.INFORM)
                        stopAutopilot()
                        break
                    end
                end
            end
            autopilotState.threadActive = false -- Ensure thread is marked inactive upon completion
        end)
    else
        setMinimapFeedback("Auto-Pilot thread already running.", NOTIFY_TYPES.ERROR)
    end
end

-- Register Command to Toggle Autopilot
RegisterCommand("autopilot", function(source, args)
    local mode = string.lower(args[1] or "") -- Default to empty string if no argument is provided
    if mode == "wander" then
        startAutopilot(true) -- Activate Wander Mode
    elseif mode == "waypoint" or mode == "" then
        -- If no argument is provided, default to Waypoint Mode
        startAutopilot(false) -- Activate Waypoint Mode
    else
        setMinimapFeedback("Invalid mode. Use 'wander' or 'waypoint'.", NOTIFY_TYPES.ERROR)
    end
end, false)

-- Optional: Add a Key Binding for Autopilot Toggle
-- RegisterKeyMapping('autopilot', 'Toggle Auto-Pilot', 'keyboard', 'F6')
