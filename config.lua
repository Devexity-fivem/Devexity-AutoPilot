
Config = {
    -- Waypoint Settings
    WAYPOINT_THRESHOLD = 5.0, -- Distance to consider waypoint reached

    -- Driving Settings
    DRIVE_SPEED_WANDER = 25.0, -- Speed for wander mode (m/s)
    DRIVE_SPEED_WAYPOINT = 75.0, -- Speed for waypoint mode (m/s)
    DRIVE_STYLE = 524607, -- Driving style for all modes

    -- Vehicle Restrictions (Optional)
    VEHICLE_RESTRICTIONS = {
        ENABLED = false, -- Restrict to specific vehicles
        ALLOWED_VEHICLES = { "adder", "zentorno", "teslax" } -- Add vehicle model names here
    }
}