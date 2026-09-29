-- Both BenQ PD3200U side by side, matched by serial so a cable change
-- doesn't swap them. Positions are logical pixels (3840 / 2).

hl.monitor({
    output   = "desc:BNQ BenQ PD3200U M9H01833019",
    mode     = "preferred",
    position = "0x0",
    scale    = 2,
})

hl.monitor({
    output   = "desc:BNQ BenQ PD3200U V5H01247019",
    mode     = "preferred",
    position = "1920x0",
    scale    = 2,
})

-- Anything else, e.g. a temporarily attached display.
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})
