local veh, tesla_blip = nil, nil
local autopilotenabled, pilot = false, false
local speed = 23.0
local crash = true

-- Helper function for notifications using qb-core's notify system
local function setMinimapFeedback(message)
    local QBCore = exports['qb-core']:GetCoreObject()

    -- Use QB-Core Notify to display the notification
    if QBCore and QBCore.Functions and QBCore.Functions.Notify then
        QBCore.Functions.Notify(message, 'success')  -- 'success' can be changed to 'error', 'inform', etc.
    else
        print("Notification system unavailable. Message: " .. message)
    end
end

--uncommet if using standalone and commit the function above^^^^
--local function setMinimapFeedback(message) SetNotificationTextEntry("STRING") AddTextComponentString(message) DrawNotification(0, 1) end

local function checkForObstacles()
    local vehicle = GetVehiclePedIsIn(GetPlayerPed(-1), false)
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
            TaskVehicleTempAction(GetPlayerPed(-1), vehicle, 23, 1000) -- Emergency braking
            setMinimapFeedback("Obstacle detected! Braking.")
        end
    end
end

Citizen.CreateThread(function()
    while crash do
        if autopilotenabled then
            checkForObstacles()
        end
        Wait(100)
    end
end)

local function handleAutopilot()
    local playerPed = GetPlayerPed(-1)
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    local waypoint = nil

    if IsWaypointActive() then
        waypoint = Citizen.InvokeNative(0xFA7C7F0AADF25D09, GetFirstBlipInfoId(8), Citizen.ResultAsVector())
    end

    if waypoint then
        if autopilotenabled then
            autopilotenabled = false
            setMinimapFeedback("Auto-Pilot canceled.")
            ClearPedTasks(playerPed)
        else
            autopilotenabled = true
            setMinimapFeedback("Auto-Pilot activated.")
            TaskVehicleDriveToCoordLongrange(playerPed, vehicle, waypoint.x, waypoint.y, waypoint.z, speed, 2883621, 1.0)

            Citizen.CreateThread(function()
                while autopilotenabled do
                    Wait(500)

                    -- Check if the player is still in the driver's seat
                    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= playerPed then
                        setMinimapFeedback("Auto-Pilot stopped: Driver left the seat.")
                        autopilotenabled = false
                        TaskVehicleTempAction(playerPed, vehicle, 27, 3000) -- Gradual stop
                        break
                    end

                    -- Check if waypoint is still active
                    if not IsWaypointActive() then
                        setMinimapFeedback("Auto-Pilot deactivated.")
                        autopilotenabled = false
                        TaskVehicleTempAction(playerPed, vehicle, 27, 3000) -- Gradual stop
                        break
                    end

                    -- Check distance to waypoint
                    local currentPos = GetEntityCoords(vehicle)
                    local distance = Vdist(currentPos.x, currentPos.y, currentPos.z, waypoint.x, waypoint.y, waypoint.z)

                    if distance < 10.0 and GetEntitySpeed(vehicle) > 0 then
                        SetVehicleForwardSpeed(vehicle, math.max(GetEntitySpeed(vehicle) - 1.0, 0.0))
                    end

                    if distance < 2.0 then
                        setMinimapFeedback("Destination reached.")
                        autopilotenabled = false
                        TaskVehicleTempAction(playerPed, vehicle, 27, 3000) -- Gradual stop
                        break
                    end
                end
            end)
        end
    else
        setMinimapFeedback("No waypoint set.")
    end
end

RegisterCommand("autopilot", function()
    handleAutopilot()
end, false)
