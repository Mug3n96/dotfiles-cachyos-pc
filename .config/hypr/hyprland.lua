-- Hyprland · Einstieg
--
-- Seit 0.55 ist Lua das Config-Format (hyprland.conf wird ab 0.57 nicht mehr gelesen).
-- Diese Datei lädt nur die Module. Jedes `require` läuft in einem eigenen Scope:
-- ein Fehler in einem Modul stoppt die anderen nicht.
--
--   workspaces.lua    welche App auf welchem Workspace landet  ← hier Apps eintragen
--   lua/theme.lua     Farben und Maße (Nord), die eine Quelle für alles Optische
--   lua/system.lua    Monitor, Umgebung, Eingabe, Autostart
--   lua/look.lua      Abstände, Rahmen, Schatten, Blur, Animationen
--   lua/rules.lua     Fenster- und Layer-Regeln, Workspace-Zuordnung, SUPER+O
--   lua/binds.lua     Tastenkürzel
--   scripts/          HDR, Screenshot, Power-Menü, Zwischenablage
--
-- Fehler anzeigen:  hyprctl configerrors
-- Lua live testen:  hyprctl repl

require("lua.system")
require("lua.look")
require("lua.rules")
require("lua.binds")
