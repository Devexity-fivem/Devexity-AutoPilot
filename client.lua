local veh, tesla_blip = nil, nil
local autopilotenabled, pilot = false, false
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
-- Function to handle autopilot logic
local function handleAutopilot()
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)

    -- Ensure the player is in a vehicle and is the driver
    if not DoesEntityExist(vehicle) or GetPedInVehicleSeat(vehicle, -1) ~= playerPed then
        setMinimapFeedback("You need to be the driver of a vehicle to activate Auto-Pilot.")
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

    -- Prevent overlapping threads
    if autopilotenabled then
        setMinimapFeedback("Auto-Pilot is already active.")
        return
    end

    autopilotenabled = true
    setMinimapFeedback("Auto-Pilot activated.")
    
    -- Set a reasonable speed (e.g., 20.0) and assign the driving task
    TaskVehicleDriveToCoordLongrange(playerPed, vehicle, waypoint.x, waypoint.y, waypoint.z, 75.0, 2883621, 1.0)

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
            if distance < 20.0 then
                TaskVehicleTempAction(playerPed, vehicle, 27, 3000) -- Temporary stop to simulate slowing down
            end

            -- Stop the vehicle once we reach the destination
            if distance < 5.0 then
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
