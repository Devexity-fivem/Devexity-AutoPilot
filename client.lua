
local autopilotEnabled = false
local autopilotWander = false
local autopilotThreadActive = false -- Prevent multiple threads

-- Helper function for notifications
local function setMinimapFeedback(message, type)
    local QBCore = exports['qb-core']:GetCoreObject()
    if QBCore and QBCore.Functions and QBCore.Functions.Notify then
        QBCore.Functions.Notify(message, type or 'success') -- 'success', 'error', 'inform', etc.
    else
        SetNotificationTextEntry("STRING")
        AddTextComponentString(message)
        DrawNotification(false, true) -- Better compatibility
    end
end

-- Function to stop the vehicle smoothly
local function stopVehicle(playerPed, vehicle)
    TaskVehicleTempAction(playerPed, vehicle, Config.TEMP_ACTION_STOP, Config.TEMP_ACTION_DURATION)
end

-- Function to check if the vehicle is allowed for autopilot
local function isVehicleAllowed(vehicle)
    if not Config.VEHICLE_RESTRICTIONS.ENABLED then
        return true -- No restrictions enabled, allow any vehicle
    end

    if not vehicle then
        return false
    end

    local model = GetEntityModel(vehicle)
    local modelName = GetDisplayNameFromVehicleModel(model):lower()

    for _, allowedModel in ipairs(Config.VEHICLE_RESTRICTIONS.ALLOWED_VEHICLES) do
        if modelName == allowedModel:lower() then
            return true
        end
    end

    return false -- Vehicle not in the allowed list
end

-- Function to handle autopilot logic
local function handleAutopilot(wanderMode)
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)

    -- Ensure the player is in a vehicle and is the driver
    if not DoesEntityExist(vehicle) or GetPedInVehicleSeat(vehicle, -1) ~= playerPed then
        setMinimapFeedback("You need to be the driver of a vehicle to activate Auto-Pilot.", 'error')
        return
    end

    -- Check if the vehicle is allowed
    if not isVehicleAllowed(vehicle) then
        setMinimapFeedback("Auto-Pilot cannot be used in this vehicle.", 'error')
        return
    end

    -- Toggle autopilot state
    if autopilotEnabled then
        -- Deactivate autopilot
        autopilotEnabled = false
        autopilotWander = false
        setMinimapFeedback("Auto-Pilot deactivated.", 'inform')
        stopVehicle(playerPed, vehicle)
        return
    end

    -- Activate autopilot
    autopilotEnabled = true
    autopilotWander = wanderMode
    local modeText = wanderMode and "Wander" or "Waypoint"
    setMinimapFeedback("Auto-Pilot (" .. modeText .. ") activated.", 'success')

    -- Start autopilot thread if not already active
    if not autopilotThreadActive then
        autopilotThreadActive = true

        Citizen.CreateThread(function()
            while autopilotEnabled do
                Citizen.Wait(500) -- Fixed THREAD_WAIT value (500 milliseconds)

                -- Re-fetch player and vehicle status
                playerPed = PlayerPedId()
                vehicle = GetVehiclePedIsIn(playerPed, false)

                -- Validate vehicle
                if not DoesEntityExist(vehicle) or IsEntityDead(vehicle) or not IsEntityAVehicle(vehicle) or GetPedInVehicleSeat(vehicle, -1) ~= playerPed then
                    setMinimapFeedback("Auto-Pilot deactivated: Vehicle is no longer valid.", 'error')
                    autopilotEnabled = false
                    break
                end

                -- Check if the vehicle is allowed (in case restrictions were changed)
                if not isVehicleAllowed(vehicle) then
                    setMinimapFeedback("Auto-Pilot deactivated: Vehicle is not allowed.", 'error')
                    autopilotEnabled = false
                    break
                end

                if autopilotWander then
                    -- Wander Mode: Select random destination within specified distance
                    local x, y, z = table.unpack(GetEntityCoords(vehicle))
                    local randomX = x + math.random(-500, 500) -- Fixed WANDER_DISTANCE value (500 units)
                    local randomY = y + math.random(-500, 500) -- Fixed WANDER_DISTANCE value (500 units)
                    local groundZ = GetGroundZFor_3dCoord(randomX, randomY, z, false)

                    if not groundZ then
                        groundZ = z -- Fallback to current Z if ground not found
                    end

                    TaskVehicleDriveToCoordLongrange(playerPed, vehicle, randomX, randomY, groundZ, Config.DRIVE_SPEED_WANDER, Config.DRIVE_STYLE_WANDER, 10.0)

                    -- Wait for a random duration before selecting a new point
                    local waitTime = math.random(40000, 50000) -- Fixed WANDER_WAIT_MIN and WANDER_WAIT_MAX values (40-50 seconds)
                    Citizen.Wait(waitTime)
                else
                    -- Waypoint Mode: Follow GPS route
                    if IsWaypointActive() then
                        local waypointBlip = GetFirstBlipInfoId(8) -- 8 corresponds to the waypoint type
                        if DoesBlipExist(waypointBlip) then
                            local waypointCoords = GetBlipInfoIdCoord(waypointBlip)
                            TaskVehicleDriveToCoordLongrange(playerPed, vehicle, waypointCoords.x, waypointCoords.y, waypointCoords.z, Config.DRIVE_SPEED_WAYPOINT, Config.DRIVE_STYLE_WAYPOINT, 3.0)

                            -- Check distance to waypoint
                            local currentPos = GetEntityCoords(vehicle)
                            local distance = Vdist(currentPos.x, currentPos.y, currentPos.z, waypointCoords.x, waypointCoords.y, waypointCoords.z)

                            if distance < Config.WAYPOINT_THRESHOLD then -- Use WAYPOINT_THRESHOLD from config
                                setMinimapFeedback("Destination reached.", 'success')
                                autopilotEnabled = false
                                stopVehicle(playerPed, vehicle)
                                ClearGpsMultiRoute()
                                SetWaypointOff()
                                break
                            end
                        else
                            setMinimapFeedback("Waypoint data is invalid. Please set a new waypoint.", 'error')
                            autopilotEnabled = false
                            break
                        end
                    else
                        setMinimapFeedback("Auto-Pilot deactivated: No active waypoint.", 'inform')
                        autopilotEnabled = false
                        stopVehicle(playerPed, vehicle)
                        break
                    end
                end
            end

            autopilotThreadActive = false -- Mark thread as inactive
        end)
    else
        setMinimapFeedback("Auto-Pilot thread is already running.", 'error')
    end
end

-- Command to activate/deactivate autopilot
RegisterCommand("autopilot", function(source, args)
    local mode = args[1]
    if mode == "wander" then
        handleAutopilot(true) -- Enable wandering mode
    else
        handleAutopilot(false) -- Enable regular waypoint mode
    end
end, false)

-- Optional: Add a key binding for autopilot activation
--RegisterKeyMapping('autopilot', 'Toggle Auto-Pilot', 'keyboard', 'Y')
