local nix = require("nix")

-- Launch through uwsm so apps run as units in the session.
local function app(cmd)
    return hl.dsp.exec_cmd("uwsm app -- " .. cmd)
end

hl.bind("SUPER + Q", hl.dsp.window.close())

-- Every lock goes through logind, which has hypridle run hyprlock.
hl.bind("SUPER + L", hl.dsp.exec_cmd("loginctl lock-session"))

-- Temporary until the launcher exists.
hl.bind("SUPER + RETURN", app(nix.terminal))
