-- Aussehen: Abstände, Rahmen, Schatten, Blur, Animationen
--
-- Leitlinie: ruhig und präzise. Ein Raster (10 px), eine Rundung (10 px), ein Akzent.
-- Effekte sind kurz und dezent. Im Vollbild-Spiel kosten sie nichts: Direct Scanout
-- umgeht den Compositor, Übergänge laufen nur beim Wechseln.

local t = require("lua.theme")
local c, rgba = t.color, t.rgba

hl.config({
    general = {
        layout      = "dwindle",
        gaps_in     = t.gap_in,
        gaps_out    = t.gap_out,
        border_size = t.border,
        -- Fokus als Licht von oben: nur die Oberkante des aktiven Fensters leuchtet im
        -- Akzent und läuft an den Seiten aus (Verlauf 90°). Inaktive Fenster: keine Kante.
        col = {
            active_border   = { colors = { rgba(c.accent, 0.9), rgba(c.accent2, 0) }, angle = 90 },
            inactive_border = rgba(c.base, 0),
        },
        -- Hauptschalter für Tearing. Wirkt nur für Fenster mit `immediate` (rules.lua).
        allow_tearing = true,
    },

    decoration = {
        rounding       = t.radius,
        rounding_power = 2,
        dim_special    = 0.4, -- Desktop hinter dem offenen Scratchpad abdunkeln

        -- Tiefe durch Material statt Schatten: das aktive Fenster ist massiv, inaktive
        -- werden mattes Glas (durchscheinend, dahinter weichgezeichnet). Beim Fokuswechsel
        -- blendet das Fenster in 150 ms von Glas zu massiv. Ausnahmen (immer massiv): rules.lua.
        active_opacity   = 1.0,
        inactive_opacity = 0.88,
        shadow           = { enabled = false },

        -- Blur hinter Leiste, Launcher, Benachrichtigungen (Layer-Regeln in rules.lua)
        -- und hinter inaktiven Fenstern (das Glas). Massive Fenster kosten keinen Blur.
        blur = {
            enabled           = true,
            -- Effektiver Radius ≈ size × 2^passes ≈ 24 px: Text dahinter verschwindet,
            -- die großen Formen im Wallpaper bleiben erkennbar.
            size              = 6,
            passes            = 2,
            -- Den Blur selbst abdunkeln statt stärker zu tönen: das Wallpaper bleibt
            -- farbig sichtbar, der Grund ist überall dunkel genug für hellen Text.
            brightness        = 0.72,
            contrast          = 1.0,
            vibrancy          = 0.15,
            new_optimizations = true,
        },
    },

    dwindle = {
        preserve_split = true, -- Teilungen bleiben, wie man sie gesetzt hat
    },

    misc = {
        vrr                      = 2, -- VRR nur im Vollbild
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        force_default_wallpaper  = 0,
        background_color         = "rgb(" .. c.base .. ")", -- sichtbar, bis das Wallpaper da ist
    },

    render   = { direct_scanout = 1 },
    xwayland = { force_zero_scaling = true },
    binds    = { allow_workspace_cycles = true },
})

------------------------------------------------------------------------------
-- Animationen · kurz (100–150 ms), ohne Nachfedern
------------------------------------------------------------------------------

hl.config({ animations = { enabled = true } })

-- Schnell los, weich aus: fühlt sich direkt an, ohne hart zu stoppen.
hl.curve("out",    { type = "bezier", points = { { 0.22, 1 }, { 0.36, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 },    { 1, 1 } } })

-- speed: 1 = 100 ms
hl.animation({ leaf = "global",           enabled = true,  speed = 1.5, bezier = "out" })
hl.animation({ leaf = "windowsIn",        enabled = true,  speed = 1.5, bezier = "out",    style = "popin 92%" })
hl.animation({ leaf = "windowsOut",       enabled = true,  speed = 1.0, bezier = "linear", style = "popin 92%" })
hl.animation({ leaf = "windowsMove",      enabled = true,  speed = 1.5, bezier = "out" })
hl.animation({ leaf = "fadeIn",           enabled = true,  speed = 1.5, bezier = "out" })
hl.animation({ leaf = "fadeOut",          enabled = true,  speed = 1.0, bezier = "linear" })
hl.animation({ leaf = "layersIn",         enabled = true,  speed = 1.5, bezier = "out",    style = "fade" })
hl.animation({ leaf = "layersOut",        enabled = true,  speed = 1.0, bezier = "linear", style = "fade" })
hl.animation({ leaf = "workspaces",       enabled = true,  speed = 1.5, bezier = "out",    style = "slidefade 12%" })
hl.animation({ leaf = "specialWorkspace", enabled = true,  speed = 1.5, bezier = "out",    style = "slidefadevert 12%" })
hl.animation({ leaf = "border",           enabled = true,  speed = 1.5, bezier = "out" })
-- Glanzlicht schwingt beim Fokuswechsel einmal ein (once). Nie "loop": das erzwingt
-- dauerhaftes Rendern mit 165 Hz, auch im Spiel.
hl.animation({ leaf = "borderangle",      enabled = true,  speed = 8,   bezier = "out",    style = "once" })
