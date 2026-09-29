local nix = require("nix")

-- Launch through uwsm so apps run as units in the session.
local function app(cmd)
    return hl.dsp.exec_cmd("uwsm app -- " .. cmd)
end

hl.bind("SUPER + Q", hl.dsp.window.close())

-- Temporary until the launcher exists.
hl.bind("SUPER + RETURN", app(nix.terminal))
