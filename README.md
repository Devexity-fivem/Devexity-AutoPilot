# Devexity-AutoPilot
 Simple Fivem autopilot script
  how to use:
  set a waypoint on the map and type /autopilot in chat
  can be used as standalone just change the notfication in client.lua
  to:
  local function setMinimapFeedback(message)
    SetNotificationTextEntry("STRING")
    AddTextComponentString(message)
    DrawNotification(0, 1)
end
 