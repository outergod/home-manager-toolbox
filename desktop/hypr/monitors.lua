-- The BenQ PD3200U, matched by model and serial rather than connector, so
-- a cable change keeps its settings.

local benq = "desc:BNQ BenQ PD3200U M9H01833019"

hl.monitor({
    output   = benq,
    mode     = "preferred",
    position = "0x0",
    scale    = 2,
})

-- Any other display, e.g. a laptop panel or an external screen on another
-- machine using this configuration.
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})

return { benq = benq }
