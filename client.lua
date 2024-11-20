local veh, tesla_blip = nil, nil
local autopilotenabled, pilot = false, false
local speed = 45.0
local crash = true

-- Helper function for notifications
local function setMinimapFeedback(message)
    local QBCore = exports['qb-core']:GetCoreObject()
    if QBCore and QBCore.Functions and QBCore.Functions.Notify then
        QBCore.Functions.Notify(message, 'success')  -- 'success' can be 'error', 'inform', etc.
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
    local speed = GetEntitySpeed(vehicle)
    local radius = math.max(5.0, speed / 2)

    local forwardVector = GetEntityForwardVector(vehicle)
    local startPos = GetEntityCoords(vehicle)
    local endPos = vector3(
        startPos.x + forwardVector.x * radius,
        startPos.y + forwardVector.y * radius,
        startPos.z
    )

    local rayHandle = StartShapeTestRay(startPos.x, startPos.y, startPos.z, endPos.x, endPos.y, endPos.z, 10, vehicle, 0)
    local _, hit, _, _, entity = GetShapeTestResult(rayHandle)

    if hit then
        local entityType = GetEntityType(entity)
        if entityType == 2 or entityType == 3 then  -- vehicle or object
            TaskVehicleTempAction(playerPed, vehicle, 23, 1000) -- Emergency braking
            setMinimapFeedback("Obstacle detected! Braking.")
        end
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
    local waypoint = nil

    -- Check if a waypoint is set and retrieve it
    if IsWaypointActive() then
        waypoint = Citizen.InvokeNative(0xFA7C7F0AADF25D09, GetFirstBlipInfoId(8), Citizen.ResultAsVector())
    end

    -- Validate waypoint and return if invalid
    if not IsWaypointActive() or not waypoint then
        setMinimapFeedback("Please set a valid waypoint.")
        return
    end

    -- If waypoint exists, either activate or cancel autopilot
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

                -- Check the current distance from the waypoint
                local currentPos = GetEntityCoords(vehicle)
                local distance = Vdist(currentPos.x, currentPos.y, currentPos.z, waypoint.x, waypoint.y, waypoint.z)

                -- Gradually slow down if close to the waypoint
                if distance < 10.0 and GetEntitySpeed(vehicle) > 0 then
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
