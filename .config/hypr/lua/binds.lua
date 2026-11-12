-- Tastenkürzel
--
-- Aufbau: SUPER + Taste = tun · + SHIFT = mitnehmen/verschieben · + CTRL = still.

local mod      = "SUPER"
local terminal = "alacritty"
local scripts  = os.getenv("HOME") .. "/.config/hypr/scripts/"
local exec     = hl.dsp.exec_cmd
local bind     = hl.bind

------------------------------------------------------------------------------
-- System
------------------------------------------------------------------------------

bind(mod .. " + Return",        exec(terminal))
bind(mod .. " + D",             exec("fuzzel"))
bind(mod .. " + V",             exec(scripts .. "clipboard"))
bind(mod .. " + SHIFT + Q",     hl.dsp.window.close())
bind(mod .. " + SHIFT + E",     exec(scripts .. "powermenu"))
bind(mod .. " + SHIFT + C",     exec("hyprctl reload"))
bind(mod .. " + SHIFT + B",     hl.dsp.force_renderer_reload())

------------------------------------------------------------------------------
-- Apps und Werkzeuge
------------------------------------------------------------------------------

bind(mod .. " + F1",            exec("code"))
bind(mod .. " + F2",            exec("brave"))
bind(mod .. " + F3",            exec("pcmanfm"))
bind(mod .. " + SHIFT + F3",    exec("pcmanfm_pkexec"))
bind(mod .. " + F4",            exec(scripts .. "hdr-toggle"))
bind(mod .. " + SHIFT + W",     exec(scripts .. "wallpaper toggle"))
bind(mod .. " + F5",            exec(terminal .. " -e mocp"))
bind(mod .. " + F12",           exec("systemctl --user restart wireplumber pipewire pipewire-pulse"))
bind(mod .. " + CTRL + M",      exec(terminal .. " -e alsamixer"))
bind("CTRL + SHIFT + Escape",   exec("missioncenter"))
bind(mod .. " + SHIFT + D",     exec("killall dunst; notify-send 'Dunst neu gestartet'"))
bind(mod .. " + SHIFT + T",     exec(os.getenv("HOME") .. "/.local/bin/ocr-shot"))

-- Fenster auf ihren Stamm-Workspace räumen (Zuordnung in workspaces.lua)
local sort_windows = require("lua.rules").sort_windows
if sort_windows then bind(mod .. " + O", sort_windows) end

-- TFT Excel (Brave als eigenes Fenster)
bind(mod .. " + E",             exec("brave --new-window --class=TFTExcel https://google.de"))

------------------------------------------------------------------------------
-- Screenshots · gespeichert in ~/Bilder/Screenshots und in der Zwischenablage
------------------------------------------------------------------------------

bind("Print",                   exec(scripts .. "screenshot screen"))
bind(mod .. " + SHIFT + S",     exec(scripts .. "screenshot area"))

------------------------------------------------------------------------------
-- Fenster
------------------------------------------------------------------------------

local directions = {
    { "H", "left" }, { "J", "down" }, { "K", "up" }, { "L", "right" },
    { "left", "left" }, { "down", "down" }, { "up", "up" }, { "right", "right" },
}
for _, d in ipairs(directions) do
    bind(mod .. " + " .. d[1],             hl.dsp.focus({ direction = d[2] }))
    bind(mod .. " + SHIFT + " .. d[1],     hl.dsp.window.move({ direction = d[2] }))
end

bind(mod .. " + Q",             hl.dsp.layout("togglesplit"))
bind(mod .. " + Space",         hl.dsp.window.fullscreen())
bind(mod .. " + SHIFT + Space", hl.dsp.window.float())
bind(mod .. " + A",             hl.dsp.focus({ last = true }))

-- Maus: ziehen, Größe ändern, schweben lassen
bind(mod .. " + mouse:272",     hl.dsp.window.drag(),   { mouse = true })
bind(mod .. " + mouse:273",     hl.dsp.window.resize(), { mouse = true })
bind(mod .. " + mouse:274",     hl.dsp.window.float())

-- Größe per Tastatur: SUPER+R, dann HJKL/Pfeile, Enter/Esc beendet
bind(mod .. " + R",             hl.dsp.submap("resize"))
hl.define_submap("resize", function()
    local steps = {
        { "H", -10, 0 }, { "J", 0, 10 }, { "K", 0, -10 }, { "L", 10, 0 },
        { "left", -10, 0 }, { "down", 0, 10 }, { "up", 0, -10 }, { "right", 10, 0 },
    }
    for _, s in ipairs(steps) do
        hl.bind(s[1], hl.dsp.window.resize({ x = s[2], y = s[3], relative = true }), { repeating = true })
    end
    hl.bind("Return", hl.dsp.submap("reset"))
    hl.bind("Escape", hl.dsp.submap("reset"))
end)

------------------------------------------------------------------------------
-- Workspaces
------------------------------------------------------------------------------

bind(mod .. " + Tab",           hl.dsp.focus({ workspace = "previous" }))
bind(mod .. " + SHIFT + Tab",   hl.dsp.window.move({ workspace = "previous" }))
bind(mod .. " + CTRL + Tab",    hl.dsp.window.move({ workspace = "previous", follow = false }))

for i = 1, 8 do
    bind(mod .. " + " .. i,             hl.dsp.focus({ workspace = i }))
    bind(mod .. " + SHIFT + " .. i,     hl.dsp.window.move({ workspace = i }))
    bind(mod .. " + CTRL + " .. i,      hl.dsp.window.move({ workspace = i, follow = false }))
    bind("ALT + SHIFT + " .. i,         hl.dsp.window.move({ workspace = i })) -- alte Variante
end

-- Scratchpad
bind(mod .. " + minus",         hl.dsp.workspace.toggle_special("scratch"))
bind(mod .. " + SHIFT + minus", hl.dsp.window.move({ workspace = "special:scratch" }))
bind(mod .. " + CTRL + minus",  hl.dsp.window.move({ workspace = "special:scratch", follow = false }))
bind(mod .. " + mouse_down",    hl.dsp.workspace.toggle_special("scratch"))
bind(mod .. " + mouse_up",      hl.dsp.workspace.toggle_special("scratch"))

-- Mail: Thunderbird als Karte ein-/ausblenden (wie der Mail-Knopf in der Waybar)
bind(mod .. " + M",             exec(scripts .. "waybar-mail toggle"))

------------------------------------------------------------------------------
-- Übersicht der belegten Workspaces mit Live-Vorschau (~/.config/quickshell/nord-overview)
-- Öffnen zoomt den Bildschirm in seine Kachel, Klick zoomt die gewählte Kachel auf.
------------------------------------------------------------------------------

local overview = "qs ipc -p ~/.config/quickshell/nord-overview call overview toggle"
bind(mod .. " + W",             exec(overview))
-- Mit Touchpad (Laptop) zusätzlich per Geste:
-- hl.gesture({ fingers = 4, direction = "down", action = function() hl.exec_cmd(overview) end })

------------------------------------------------------------------------------
-- Medien · funktionieren auch bei gesperrtem Bildschirm
------------------------------------------------------------------------------

local volume = "wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ "
bind("XF86AudioRaiseVolume",    exec(volume .. "3%+"), { locked = true, repeating = true })
bind("XF86AudioLowerVolume",    exec(volume .. "3%-"), { locked = true, repeating = true })
bind("XF86AudioMute",           exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),   { locked = true })
bind("XF86AudioMicMute",        exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
bind("XF86AudioPlay",           exec("playerctl play-pause"), { locked = true })
bind("XF86AudioPause",          exec("playerctl play-pause"), { locked = true })
bind("XF86AudioNext",           exec("playerctl next"),       { locked = true })
bind("XF86AudioPrev",           exec("playerctl previous"),   { locked = true })
