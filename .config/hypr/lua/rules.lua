-- Fenster- und Layer-Regeln, Workspace-Zuordnung, Aufräumen per SUPER+O

------------------------------------------------------------------------------
-- Layer: Leiste, Launcher, Benachrichtigungen
------------------------------------------------------------------------------

-- Leichtes Milchglas hinter den halbtransparenten Flächen. ignore_alpha lässt die
-- durchsichtigen Ränder aus, sonst sähe man ein unscharfes Rechteck. Muss unter
-- der Deckkraft der Waybar-Inseln liegen (style.css: 0.35).
local frosted = {
    { ns = "waybar" },
    { ns = "launcher",      animation = "popin 94%" }, -- fuzzel
    { ns = "notifications", animation = "slide right" }, -- dunst
}
for _, l in ipairs(frosted) do
    hl.layer_rule({
        name         = "frosted-" .. l.ns,
        match        = { namespace = "^" .. l.ns .. "$" },
        blur         = true,
        ignore_alpha = 0.2,
        animation    = l.animation,
    })
end

-- Auswahl-Overlays ohne Ein-/Ausblenden, sonst landet das verblassende
-- Overlay im Screenshot (slurp für Screenshot und OCR, hyprpicker).
hl.layer_rule({
    name    = "no-anim-selection",
    match   = { namespace = "^(selection|hyprpicker)$" },
    no_anim = true,
})

------------------------------------------------------------------------------
-- Scratchpad (SUPER+Minus, Knopf in der Waybar)
------------------------------------------------------------------------------

-- Als Karte über dem Desktop statt bildschirmfüllend: breiter Rand rundherum,
-- der Desktop dahinter bleibt abgedunkelt sichtbar (decoration.dim_special).
-- Seitenrand 100 px: zwei Terminals nebeneinander haben je 114 Spalten, genug für
-- fastfetch (längste Zeile 112). Bei 280 px waren es nur 96.
hl.workspace_rule({
    workspace = "special:scratch",
    gaps_out  = { top = 80, right = 100, bottom = 80, left = 100 },
})

-- Mail (Klick auf den Mail-Knopf in der Waybar, SUPER+M): Thunderbird als Karte.
-- Etwas schmaler als das Scratchpad, damit Liste + Lesebereich gut proportioniert sind.
hl.workspace_rule({
    workspace = "special:mail",
    gaps_out  = { top = 60, right = 160, bottom = 60, left = 160 },
})
-- Nur das Hauptfenster wandert dorthin (Startzustand unsichtbar). Verfassen-Fenster,
-- Dialoge und mailto:-Links öffnen normal auf dem aktuellen Workspace.
hl.window_rule({
    name      = "mail-panel",
    match     = { class = "^org\\.mozilla\\.Thunderbird$", initial_title = "^Mozilla Thunderbird$" },
    workspace = "special:mail silent",
})

------------------------------------------------------------------------------
-- Fenster: allgemein
------------------------------------------------------------------------------

-- Immer massiv, auch wenn inaktiv: bei Bildern, Videos, Spielen und Streams stört
-- das Glas (look.lua: inactive_opacity).
hl.window_rule({
    name   = "always-opaque",
    match  = { class = "^(BambuStudio|mpv|gimp.*|org\\.kde\\.krita|com\\.obsproject\\.Studio|steam_app_.*|overwatch\\.exe|gamescope|scrcpy|Waydroid|waydroid\\..*)$" },
    opaque = true,
})
-- Spiele als "game" kennzeichnen, auch wenn sie es nicht selbst melden. Nur dann
-- greifen VRR (misc.vrr = 3) und Direct Scanout (render.direct_scanout = 2), look.lua.
hl.window_rule({
    name    = "game-content",
    match   = { class = "^(steam_app_.*|gamescope|overwatch\\.exe)$" },
    content = "game",
})
hl.window_rule({ name = "opaque-video", match = { content = "video" }, opaque = true })
hl.window_rule({ name = "opaque-game",  match = { content = "game" },  opaque = true })

-- Kleine Werkzeugfenster schweben zentriert, statt eine Bildschirmhälfte zu belegen.
hl.window_rule({
    name   = "utility-float",
    match  = { class = "^(org\\.pulseaudio\\.pavucontrol|nm-connection-editor|blueman-manager)$" },
    float  = true,
    center = true,
    size   = { 960, 640 },
})
hl.window_rule({
    name   = "dialog-float",
    match  = { class = "^(swappy|.*hyprpolkitagent)$" },
    float  = true,
    center = true,
})

------------------------------------------------------------------------------
-- Fenster: einzelne Apps
------------------------------------------------------------------------------

-- Waydroid: immer schwebend, zentriert, feste Größe
hl.window_rule({
    name   = "waydroid-float",
    match  = { class = "^(Waydroid)$" },
    float  = true,
    size   = { 1920, 1080 },
    center = true,
})

-- TFT in Waydroid
hl.window_rule({
    name  = "waydroid-tft-float",
    match = { class = "^(waydroid\\.com\\.riotgames\\.league\\.teamfighttactics)$" },
    float = true,
})

-- TFT per scrcpy vom Pixel 10. 2424×1080 ist die native Auflösung im Querformat
-- und passt 1:1 in 2560×1440: kein Skalieren, schärfster Text.
hl.window_rule({
    name      = "scrcpy-tft",
    match     = { class = "^(scrcpy)$" },
    float     = true,
    size      = { 2424, 1080 },
    center    = true,
    no_shadow = true,
})

-- Gamescope
hl.window_rule({
    name       = "gamescope",
    match      = { class = "^(gamescope)$" },
    fullscreen = true,
    immediate  = true,
    no_anim    = true,
    no_shadow  = true,
})

-- Overwatch 2: Tearing/immediate Flips für minimale Latenz.
-- Die Klasse ist overwatch.exe, weil PROTON_ENABLE_WAYLAND=1 das Spiel als nativen
-- Wayland-Client startet. steam_app_<id> vergibt nur XWayland, deshalb beide.
-- Wirkungslos, wenn MESA_VK_WSI_PRESENT_MODE=mailbox in den Startoptionen steht.
hl.window_rule({
    name      = "overwatch2-lowlatency",
    match     = { class = "^(overwatch\\.exe|steam_app_2357570)$" },
    immediate = true,
})

------------------------------------------------------------------------------
-- Workspace-Zuordnung (Daten in ../workspaces.lua)
------------------------------------------------------------------------------

local map = require("workspaces")

-- "steam_app_*" → RE2-Regex für die Fensterregel
local function glob_to_regex(glob)
    local escaped = glob:gsub("[%^%$%.%|%?%+%(%)%[%]%{%}\\]", "\\%0")
    return (escaped:gsub("%*", ".*"))
end

-- "steam_app_*" → Lua-Muster für SUPER+O
local function glob_to_pattern(glob)
    local escaped = glob:lower():gsub("[%^%$%(%)%%%.%[%]%+%-%?]", "%%%0")
    return "^" .. escaped:gsub("%*", ".*") .. "$"
end

local homes = {} -- { workspace, { lua-muster … } } in Reihenfolge der Map

for i, entry in ipairs(map) do
    local ws, regexes, patterns = entry[1], {}, {}
    for j = 2, #entry do
        regexes[#regexes + 1]   = glob_to_regex(entry[j])
        patterns[#patterns + 1] = glob_to_pattern(entry[j])
    end
    homes[#homes + 1] = { ws = ws, patterns = patterns }

    hl.window_rule({
        name      = "workspace-map-" .. i,
        match     = { class = "(?i)^(" .. table.concat(regexes, "|") .. ")$" },
        workspace = ws .. " silent",
    })
end

local function home_of(class)
    class = (class or ""):lower()
    for _, h in ipairs(homes) do
        for _, p in ipairs(h.patterns) do
            if class:match(p) then return h.ws end
        end
    end
end

-- SUPER+O: alle offenen Fenster auf ihren Stamm-Workspace schieben.
-- Fenster im Scratchpad bleiben, wo sie sind, die liegen dort mit Absicht.
local function sort_windows()
    local moved = 0
    for _, w in ipairs(hl.get_windows()) do
        local ws, target = w.workspace, home_of(w.class)
        if ws and not ws.special and target and ws.id ~= target then
            hl.dispatch(hl.dsp.window.move({
                window    = "address:" .. w.address,
                workspace = target,
                follow    = false,
            }))
            moved = moved + 1
        end
    end
    local text = moved > 0 and (moved .. " Fenster verschoben") or "Alles war schon am Platz"
    hl.exec_cmd("notify-send -a Hyprland -t 2500 'Fenster sortiert' '" .. text .. "'")
end

return { sort_windows = sort_windows }
