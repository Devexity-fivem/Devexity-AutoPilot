local veh, tesla_blip = nil, nil
local autopilotenabled, pilot = false, false
local speed = 45.0
local crash = true

-- Helper function for notifications
local function setMinimapFeedback(message)
    local QBCore = exports['qb-core']:GetCoreObject()
    if QBCore and QBCore.Functions and QBCore.Functions.Notify then
        QBCore.Functions.Notify(message, 'success') -- 'success' can be 'error', 'inform', etc.
    else
        SetNotificationTextEntry("STRING")
        AddTextComponentString(message)
        DrawNotification(0, 1)
    end
end

-- Function to check for obstacles in front of the vehicle
local function checkForObstacles()
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)

    -- Validate vehicle existence
    if not DoesEntityExist(vehicle) or not IsEntityAVehicle(vehicle) then
        return -- Exit silently if no valid vehicle
    end

    -- Get vehicle position and detection area
    local startPos = GetEntityCoords(vehicle)
    local detectionDistance = 10.0 -- Distance to check in front of the vehicle
    local detectionWidth = 2.0 -- Width of the detection box

    -- Calculate detection box corners
    local frontLeft = GetOffsetFromEntityInWorldCoords(vehicle, -detectionWidth, detectionDistance, 0.0)
    local frontRight = GetOffsetFromEntityInWorldCoords(vehicle, detectionWidth, detectionDistance, 0.0)

    -- Check for nearby vehicles (no feedback or stopping)
    local nearbyVehicle = GetClosestVehicle(frontLeft.x, frontLeft.y, frontLeft.z, detectionDistance, 0, 70)

    -- Simply detect; do nothing further
    if DoesEntityExist(nearbyVehicle) then
        -- Placeholder for future logic if needed
    end
end








-- Obstacle detection thread
Citizen.CreateThread(function()
    while crash do
        if autopilotenabled then
            checkForObstacles()
        end
        Wait(100)
    end
end)

-- Function to handle autopilot logic
local function handleAutopilot()
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)

    -- Ensure the player is in a vehicle
    if not DoesEntityExist(vehicle) then
        setMinimapFeedback("You need to be in a vehicle to activate Auto-Pilot.")
        return
    end

    local waypoint = nil

    -- Check if a waypoint is set and retrieve it
    if IsWaypointActive() then
        waypoint = Citizen.InvokeNative(0xFA7C7F0AADF25D09, GetFirstBlipInfoId(8), Citizen.ResultAsVector())
        if not waypoint or not waypoint.x or not waypoint.y or not waypoint.z then
            setMinimapFeedback("Waypoint data is invalid. Please reset the waypoint.")
            return
        end
    else
        setMinimapFeedback("Please set a valid waypoint.")
        return
    end

    if autopilotenabled then
        autopilotenabled = false
        setMinimapFeedback("Auto-Pilot canceled.")
        ClearPedTasks(playerPed)
    else
        autopilotenabled = true
        setMinimapFeedback("Auto-Pilot activated.")
        TaskVehicleDriveToCoordLongrange(playerPed, vehicle, waypoint.x, waypoint.y, waypoint.z, speed, 2883621, 1.0)

        -- Thread to handle distance and stopping logic
        Citizen.CreateThread(function()
            while autopilotenabled do
                Wait(500)

                -- If the waypoint is no longer active, cancel autopilot
                if not IsWaypointActive() then
                    setMinimapFeedback("Auto-Pilot deactivated: No active waypoint.")
                    autopilotenabled = false
                    TaskVehicleTempAction(playerPed, vehicle, 27, 3000) -- Gradual stop
                    break
                end

                -- Ensure the vehicle is still valid
                if not DoesEntityExist(vehicle) then
                    setMinimapFeedback("Auto-Pilot deactivated: Vehicle no longer exists.")
                    autopilotenabled = false
                    break
                end

                -- Check the current distance from the waypoint
                local currentPos = GetEntityCoords(vehicle)
                local distance = Vdist(currentPos.x, currentPos.y, currentPos.z, waypoint.x, waypoint.y, waypoint.z)

                -- Gradually slow down if close to the waypoint
                if distance < 50.0 and GetEntitySpeed(vehicle) > speed then
                    SetVehicleForwardSpeed(vehicle, speed - 10.0) -- Gradual slowdown
                elseif distance < 10.0 and GetEntitySpeed(vehicle) > 0 then
                    SetVehicleForwardSpeed(vehicle, math.max(GetEntitySpeed(vehicle) - 1.0, 0.0))
                end

                -- Stop the vehicle once we reach the destination
                if distance < 2.0 then
                    setMinimapFeedback("Destination reached.")
                    autopilotenabled = false
                    TaskVehicleTempAction(playerPed, vehicle, 27, 3000) -- Gradual stop
                    break
                end
            end
        end)
    end
end


-- Command to activate/deactivate autopilot
RegisterCommand("autopilot", function()
    handleAutopilot()
end, false)