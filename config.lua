Config = {
    -- Frequency at which the autopilot logic checks conditions (in ms)
    THREAD_WAIT = 500,

    -- Distance threshold at which the waypoint is considered reached
    WAYPOINT_THRESHOLD = 5.0,

    -- Vehicle Driving Speeds & Styles
    DRIVE_SPEED_WANDER = 25.0,
    DRIVE_STYLE_WANDER = 786748,
    DRIVE_SPEED_WAYPOINT = 75.0,
    DRIVE_STYLE_WAYPOINT = 786748,

    -- Vehicle Restrictions
    VEHICLE_RESTRICTIONS = {
        ENABLED = false,   -- If true, only specified vehicles can use autopilot
        ALLOWED_VEHICLES = {
            "t20",
            "zentorno",
            "entityxf"
        },
    },

    -- Vehicle Health Requirements
    MIN_VEHICLE_ENGINE_HEALTH = 400.0,
    MIN_VEHICLE_BODY_HEALTH   = 500.0,

    -- Waypoint Fallback: If no waypoint is set when starting in waypoint mode,
    -- should we fall back to wander mode automatically?
    FALLBACK_TO_WANDER_IF_NO_WAYPOINT = false,

    -- Temporary action parameters (if needed)
    TEMP_ACTION_STOP = 27,
    TEMP_ACTION_DURATION = 4000,
}
