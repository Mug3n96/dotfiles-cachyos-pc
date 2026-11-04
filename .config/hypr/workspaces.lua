-- Welche App landet auf welchem Workspace.
--
-- Das ist die einzige Stelle, die du dafür anfassen musst:
--   · neue Fenster dieser Apps öffnen direkt auf ihrem Workspace (still, ohne Sprung)
--   · SUPER+O räumt bereits offene Fenster dorthin
-- Speichern genügt, Hyprland lädt die Config automatisch neu.
--
-- Eine Zeile pro Workspace: zuerst die Nummer, dann Fensterklassen.
-- Groß-/Kleinschreibung ist egal, * steht für beliebige Zeichen.
--
-- Klasse eines laufenden Fensters herausfinden:
--   hyprctl clients -j | jq -r '.[].class'

return {
    { 2, "brave-browser", "firefox" },
    { 4, "steam" },
    { 6, "discord", "discord-canary" },

    -- Spiele: steam_app_* deckt alles ab, was über Steam/Proton als XWayland läuft.
    -- Native Wayland-Clients (PROTON_ENABLE_WAYLAND=1) melden stattdessen ihren
    -- Exe-Namen und brauchen einen eigenen Eintrag.
    { 5, "steam_app_*", "overwatch.exe", "gamescope" },
}
