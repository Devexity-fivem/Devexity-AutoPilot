
-- config.lua
-- Configuration for Autopilot Script

Config = {
    WAYPOINT_THRESHOLD = 5.0,       -- Distance threshold to consider waypoint reached (in units)
    DRIVE_SPEED_WANDER = 25.0,      -- Driving speed for wander mode (in units)
    DRIVE_SPEED_WAYPOINT = 75.0,    -- Driving speed for waypoint mode (in units)
    DRIVE_STYLE_WANDER = 786603,    -- Driving style flag for wander mode
    DRIVE_STYLE_WAYPOINT = 2883621, -- Driving style flag for waypoint mode
    TEMP_ACTION_STOP = 27,          -- Temporary action flag to stop the vehicle
    TEMP_ACTION_DURATION = 3000,    -- Duration for temporary action (in ms)

    -- Autopilot Vehicle Restrictions
    VEHICLE_RESTRICTIONS = {
        ENABLED = true,               -- Set to true to restrict autopilot to specific vehicles
        ALLOWED_VEHICLES = {          -- List of allowed vehicle model names (as strings)
            "t20",                     -- Example: T20
            "zentorno",                -- Example: Zentorno
            "entityxf",                -- Example: Entity XF
            -- Add more vehicle model names as needed
        },
    },
}
