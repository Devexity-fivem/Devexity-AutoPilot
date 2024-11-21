local veh, tesla_blip = nil, nil
local autopilotenabled, pilot = false, false
local speed = 45.0
local crash = true
local autopilotThreadActive = false -- Prevent multiple threads

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
        -- Fallback to check if waypoint data is valid
        if not waypoint or not waypoint.x or not waypoint.y or not waypoint.z then
            setMinimapFeedback("Waypoint data is invalid. Attempting fallback detection...")
            waypoint = GetBlipCoords(GetFirstBlipInfoId(8)) -- Use a simpler method to retrieve waypoint coordinates
            if not waypoint or waypoint == vector3(0.0, 0.0, 0.0) then
                setMinimapFeedback("Waypoint data is still invalid. Please reset the waypoint.")
                return
            end
        end
    else
        setMinimapFeedback("Please set a valid waypoint.")
        return
    end

    -- Prevent overlapping threads
    if autopilotenabled then
        setMinimapFeedback("Auto-Pilot is already active.")
        return
    end

    autopilotenabled = true
    setMinimapFeedback("Auto-Pilot activated.")
    TaskVehicleDriveToCoordLongrange(playerPed, vehicle, waypoint.x, waypoint.y, waypoint.z, speed, 2883621, 1.0)

    -- Thread to handle distance and stopping logic
    Citizen.CreateThread(function()
        if autopilotThreadActive then
            setMinimapFeedback("Auto-Pilot thread is already running.")
            return
        end
        autopilotThreadActive = true

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

        autopilotThreadActive = false -- Mark thread as inactive
    end)
end

-- Command to activate/deactivate autopilot
RegisterCommand("autopilot", function()
    handleAutopilot()
end, false)
