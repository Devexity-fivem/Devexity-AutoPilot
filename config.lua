Config = {
    WAYPOINT_THRESHOLD = 5.0,       -- Distance threshold to consider waypoint reached (in units)
    DRIVE_SPEED_WANDER = 25.0,      -- Driving speed for wander mode (in units)
    DRIVE_SPEED_WAYPOINT = 75.0,    -- Driving speed for waypoint mode (in units)
    DRIVE_STYLE_WANDER = 2883620,    -- Driving style flag for wander mode
    DRIVE_STYLE_WAYPOINT = 2883621, -- Driving style flag for waypoint mode
    TEMP_ACTION_STOP = 1,           -- Temporary action flag to stop the vehicle (1 = gradual stop)
    TEMP_ACTION_DURATION = 2000,    -- Duration for temporary action (in ms)

    THREAD_WAIT = 500,              -- Time interval for autopilot logic checks (in ms)

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

    -- Wander Mode Configuration
    WANDER_DISTANCE = 1000,          -- Max distance for random wander points (in units)
    WANDER_WAIT_MIN = 5000,          -- Minimum wait time between wander points (in ms)
    WANDER_WAIT_MAX = 10000,         -- Maximum wait time between wander points (in ms)
}
