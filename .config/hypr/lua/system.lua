-- Monitor, Umgebung, Eingabe, Autostart

------------------------------------------------------------------------------
-- Monitor
------------------------------------------------------------------------------

-- Standard ist SDR. HDR schaltet SUPER+F4 (scripts/hdr-toggle) nur für Spiele und
-- Filme zu, weil SDR-Inhalte auf diesem DisplayHDR-400-Panel im HDR-Modus flau wirken.
-- Achtung: jeder Config-Reload setzt den Monitor wieder auf diese Werte (also SDR).
hl.monitor({
    output   = "DP-3",
    mode     = "2560x1440@165",
    position = "0x0",
    scale    = 1,
    bitdepth = 8,
    cm       = "srgb",
})

------------------------------------------------------------------------------
-- Umgebung
------------------------------------------------------------------------------

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")  -- setzt Hyprland nicht selbst, die Portale brauchen es
hl.env("LIBVA_DRIVER_NAME", "radeonsi")
hl.env("mesa_glthread", "true")
hl.env("XCURSOR_THEME", "Nordzy-cursors")
hl.env("XCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")     -- Qt-Apps übernehmen Schrift und Icons von GTK
hl.env("QT_STYLE_OVERRIDE", "kvantum")     -- Qt-Widgets im Nordic-Kvantum-Stil

------------------------------------------------------------------------------
-- Eingabe
------------------------------------------------------------------------------

hl.config({
    input = {
        kb_layout     = "us",
        kb_variant    = "intl",
        follow_mouse  = 1,
        sensitivity   = 0,
        accel_profile = "flat",
    },
})

------------------------------------------------------------------------------
-- Autostart
------------------------------------------------------------------------------

-- "0.56.2" → true, wenn älter als major.minor
local function older_than(major, minor)
    local maj, min = tostring(hl.version()):match("(%d+)%.(%d+)")
    if not maj then return false end
    maj, min = tonumber(maj), tonumber(min)
    return maj < major or (maj == major and min < minor)
end

hl.on("hyprland.start", function()
    -- Session-Umgebung an systemd/D-Bus geben, dann die Portale neu starten.
    -- Die Reihenfolge muss garantiert sein (eine verkettete Zeile statt paralleler
    -- Starts), sonst startet xdg-desktop-portal ohne WAYLAND_DISPLAY und das
    -- ScreenCast-Backend fehlt: Discord-Screenshare und OBS-Capture sind dann tot.
    local session = {
        "systemctl --user import-environment WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP",
        "dbus-update-activation-environment --systemd WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP",
    }
    -- Ab 0.57 startet Hyprland hyprland-session.target selbst.
    if older_than(0, 57) then
        table.insert(session, "systemctl --user start hyprland-session.target")
    end
    table.insert(session, "systemctl --user restart xdg-desktop-portal-hyprland.service xdg-desktop-portal.service")
    hl.exec_cmd(table.concat(session, " && "))

    hl.exec_cmd("waybar")
    hl.exec_cmd("dunst")
    hl.exec_cmd("nm-applet")
    hl.exec_cmd("command -v cliphist >/dev/null && wl-paste --watch cliphist store")
    hl.exec_cmd("command -v qs >/dev/null && qs -p ~/.config/quickshell/nord-overview -n -d") -- Workspace-Übersicht (SUPER+W)
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/waybar-mail start")             -- Thunderbird unsichtbar (SUPER+M)

    -- Animiert, wenn mpvpaper da ist, sonst Standbild (scripts/wallpaper)
    hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/wallpaper start")
end)
