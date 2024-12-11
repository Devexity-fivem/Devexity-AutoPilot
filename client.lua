-- ================================================
--                 Auto-Pilot Script
--         Wander or Waypoint Mode without Debug
-- ================================================

local QBCore = exports['qb-core']:GetCoreObject()

-- ==================================
--           Config Shortcuts
-- ==================================
local WAYPOINT_THRESHOLD    = Config.WAYPOINT_THRESHOLD
local DRIVE_SPEED_WANDER    = Config.DRIVE_SPEED_WANDER
local DRIVE_SPEED_WAYPOINT  = Config.DRIVE_SPEED_WAYPOINT
local DRIVE_STYLE_WANDER    = Config.DRIVE_STYLE_WANDER
local DRIVE_STYLE_WAYPOINT  = Config.DRIVE_STYLE_WAYPOINT
local THREAD_WAIT           = Config.THREAD_WAIT

local MIN_VEHICLE_ENGINE_HEALTH = Config.MIN_VEHICLE_ENGINE_HEALTH
local MIN_VEHICLE_BODY_HEALTH   = Config.MIN_VEHICLE_BODY_HEALTH
local VEH_RESTR_ENABLED         = Config.VEHICLE_RESTRICTIONS.ENABLED

-- Allowed vehicles set for O(1) lookups if enabled
local allowedVehiclesSet = {}
if VEH_RESTR_ENABLED then
    for _, vName in ipairs(Config.VEHICLE_RESTRICTIONS.ALLOWED_VEHICLES) do
        allowedVehiclesSet[string.lower(vName)] = true
    end
end

-- ==================================
--         Utility Functions
-- ==================================
local NOTIFY_TYPES = {
    SUCCESS = 'success',
    ERROR   = 'error',
    INFORM  = 'inform'
}

local function notify(msg, t)
    t = t or NOTIFY_TYPES.SUCCESS
    if QBCore and QBCore.Functions and QBCore.Functions.Notify then
        QBCore.Functions.Notify(msg, t)
    else
        SetNotificationTextEntry("STRING")
        AddTextComponentString(msg)
        DrawNotification(false, true)
    end
end

local function stopVehicleGradually(playerPed, vehicle)
    if DoesEntityExist(vehicle) and GetPedInVehicleSeat(vehicle, -1) == playerPed then
        TaskVehicleTempAction(playerPed, vehicle, 4, 1000) -- Smart brake
        Citizen.Wait(1000)
        ClearPedTasks(playerPed)
    end
end

local function isVehicleAllowed(vehicle)
    if not VEH_RESTR_ENABLED then return true end
    if not DoesEntityExist(vehicle) then return false end
    local modelName = string.lower(GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)))
    return allowedVehiclesSet[modelName] == true
end

local function vehicleHealthCheck(vehicle)
    if not DoesEntityExist(vehicle) then return false end
    local engineHealth = GetVehicleEngineHealth(vehicle)
    local bodyHealth   = GetVehicleBodyHealth(vehicle)
    local onFire       = IsEntityOnFire(vehicle)

    if onFire then
        return false
    end

    if engineHealth < MIN_VEHICLE_ENGINE_HEALTH then
        return false
    end

    if bodyHealth < MIN_VEHICLE_BODY_HEALTH then
        return false
    end

    return true
end

-- ==================================
--          Autopilot "Class"
-- ==================================
local Autopilot = {
    enabled      = false,
    wander       = false,
    threadActive = false
}

function Autopilot:start(wanderMode)
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)

    if not (DoesEntityExist(vehicle) and GetPedInVehicleSeat(vehicle, -1) == playerPed) then
        notify("You must be driving a vehicle to activate Auto-Pilot.", NOTIFY_TYPES.ERROR)
        return
    end

    if not isVehicleAllowed(vehicle) then
        notify("This vehicle is not allowed for Auto-Pilot.", NOTIFY_TYPES.ERROR)
        return
    end

    if not wanderMode and not IsWaypointActive() then
        if Config.FALLBACK_TO_WANDER_IF_NO_WAYPOINT then
            wanderMode = true
        else
            notify("No active waypoint. Set a waypoint or use Wander mode.", NOTIFY_TYPES.ERROR)
            return
        end
    end

    if self.enabled then
        self:stop()
        return
    end

    self.enabled = true
    self.wander = wanderMode
    local modeText = wanderMode and "Wander" or "Waypoint"
    notify("Auto-Pilot (" .. modeText .. ") activated.", NOTIFY_TYPES.SUCCESS)

    if not self.threadActive then
        self.threadActive = true
        Citizen.CreateThread(function()
            self:runMainLoop()
        end)
    else
        notify("Auto-Pilot thread already running.", NOTIFY_TYPES.ERROR)
    end
end

function Autopilot:stop()
    self.enabled = false
    self.wander = false
    self.threadActive = false

    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    if DoesEntityExist(vehicle) and GetPedInVehicleSeat(vehicle, -1) == playerPed then
        stopVehicleGradually(playerPed, vehicle)
    end

    notify("Auto-Pilot deactivated.", NOTIFY_TYPES.INFORM)
end

function Autopilot:runMainLoop()
    while self.enabled do
        Citizen.Wait(THREAD_WAIT)

        local playerPed = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(playerPed, false)

        if not (DoesEntityExist(vehicle) and GetPedInVehicleSeat(vehicle, -1) == playerPed) then
            notify("Auto-Pilot deactivated: Vehicle invalid or no longer in driver seat.", NOTIFY_TYPES.ERROR)
            self:stop()
            break
        end

        if not vehicleHealthCheck(vehicle) then
            notify("Auto-Pilot deactivated: Vehicle is damaged/unfit.", NOTIFY_TYPES.ERROR)
            self:stop()
            break
        end

        if self.wander then
            if not self:handleWander(playerPed, vehicle) then
                break
            end
        else
            if not self:handleWaypoint(playerPed, vehicle) then
                break
            end
        end
    end

    self.threadActive = false
end

function Autopilot:handleWander(playerPed, vehicle)
    TaskVehicleDriveWander(playerPed, vehicle, DRIVE_SPEED_WANDER, DRIVE_STYLE_WANDER)
    return true
end

function Autopilot:handleWaypoint(playerPed, vehicle)
    if not IsWaypointActive() then
        notify("No active waypoint. Auto-Pilot deactivated.", NOTIFY_TYPES.INFORM)
        self:stop()
        return false
    end

    local waypointBlip = GetFirstBlipInfoId(8)
    if not DoesBlipExist(waypointBlip) then
        notify("Waypoint invalid. Set a new one.", NOTIFY_TYPES.ERROR)
        self:stop()
        return false
    end

    local waypointCoords = GetBlipInfoIdCoord(waypointBlip)
    local currentPos = GetEntityCoords(vehicle)
    local distance = Vdist(currentPos.x, currentPos.y, currentPos.z, waypointCoords.x, waypointCoords.y, waypointCoords.z)

    if distance < WAYPOINT_THRESHOLD then
        notify("Destination reached.", NOTIFY_TYPES.SUCCESS)
        self:stop()
        return false
    else
        TaskVehicleDriveToCoordLongrange(playerPed, vehicle, waypointCoords.x, waypointCoords.y, waypointCoords.z, DRIVE_SPEED_WAYPOINT, DRIVE_STYLE_WAYPOINT, 5.0)
    end
    return true
end

-- ==================================
--       Command Registration
-- ==================================

RegisterCommand("autopilot", function(_, args)
    local mode = string.lower(args[1] or "")
    if mode == "wander" then
        Autopilot:start(true)
    elseif mode == "waypoint" or mode == "" then
        Autopilot:start(false)
    else
        notify("Invalid mode. Use 'wander' or 'waypoint'.", NOTIFY_TYPES.ERROR)
    end
end, false)

-- Optional: Add a Key Mapping
-- RegisterKeyMapping('autopilot', 'Toggle Auto-Pilot', 'keyboard', 'F6')
