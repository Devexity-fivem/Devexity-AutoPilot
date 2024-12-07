local veh, tesla_blip = nil, nil
local autopilotenabled, autopilotWander, pilot = false, false, false
local crash = true
local autopilotThreadActive = false -- Prevent multiple threads

-- Helper function for notifications
local function setMinimapFeedback(message, type)
    local QBCore = exports['qb-core']:GetCoreObject()
    if QBCore and QBCore.Functions and QBCore.Functions.Notify then
        QBCore.Functions.Notify(message, type or 'success') -- 'success' can be 'error', 'inform', etc.
    else
        SetNotificationTextEntry("STRING")
        AddTextComponentString(message)
        DrawNotification(false, true) -- Changed parameters for better compatibility
    end
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

    -- Prevent overlapping threads
    if autopilotenabled then
        -- If autopilot is already enabled, deactivate it
        autopilotenabled = false
        autopilotWander = false
        setMinimapFeedback("Auto-Pilot deactivated.", 'inform')
        -- Stop the vehicle gradually
        TaskVehicleTempAction(playerPed, vehicle, 27, 3000) -- Gradual stop
        return
    end

    autopilotenabled = true
    autopilotWander = wanderMode
    setMinimapFeedback(wanderMode and "Auto-Pilot (Wander) activated." or "Auto-Pilot activated.", 'success')

    Citizen.CreateThread(function()
        if autopilotThreadActive then
            setMinimapFeedback("Auto-Pilot thread is already running.", 'error')
            return
        end
        autopilotThreadActive = true

        while autopilotenabled do
            Citizen.Wait(500)

            -- Ensure the vehicle is still valid
            if not DoesEntityExist(vehicle) or IsEntityDead(vehicle) or not IsEntityAVehicle(vehicle) then
                setMinimapFeedback("Auto-Pilot deactivated: Vehicle is no longer valid.", 'error')
                autopilotenabled = false
                break
            end

            if autopilotWander then
                -- Wandering logic: Pick random points
                local x, y, z = table.unpack(GetEntityCoords(vehicle))
                local randomX = x + math.random(-500, 500)
                local randomY = y + math.random(-500, 500)
                local groundZ = GetGroundZFor_3dCoord(randomX, randomY, z, 0)
                
                TaskVehicleDriveToCoordLongrange(playerPed, vehicle, randomX, randomY, groundZ, 25.0, 786603, 10.0)


                Citizen.Wait(math.random(40000, 50000)) -- Wait a random time between 10-20 seconds before choosing a new point
            else
                -- Regular waypoint-following mode
                if IsWaypointActive() then
                    local waypoint = Citizen.InvokeNative(0xFA7C7F0AADF25D09, GetFirstBlipInfoId(8), Citizen.ResultAsVector())
                    if waypoint and waypoint.x and waypoint.y and waypoint.z then
                        TaskVehicleDriveToCoordLongrange(playerPed, vehicle, waypoint.x, waypoint.y, waypoint.z, 75.0, 2883621, 3.0)

                        -- Stop the vehicle once we reach the destination
                        local currentPos = GetEntityCoords(vehicle)
                        local distance = Vdist(currentPos.x, currentPos.y, currentPos.z, waypoint.x, waypoint.y, waypoint.z)

                        if distance < 5.0 then
                            setMinimapFeedback("Destination reached.", 'success')
                            autopilotenabled = false
                            TaskVehicleTempAction(playerPed, vehicle, 27, 3000) -- Gradual stop
                            ClearGpsMultiRoute() -- Clear GPS route
                            SetWaypointOff() -- Remove the waypoint
                            break
                        end
                    else
                        setMinimapFeedback("Waypoint data is invalid. Please reset the waypoint.", 'error')
                        autopilotenabled = false
                        break
                    end
                else
                    setMinimapFeedback("Auto-Pilot deactivated: No active waypoint.", 'inform')
                    autopilotenabled = false
                    TaskVehicleTempAction(playerPed, vehicle, 27, 3000) -- Gradual stop
                    break
                end
            end
        end

        autopilotThreadActive = false -- Mark thread as inactive
    end)
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






