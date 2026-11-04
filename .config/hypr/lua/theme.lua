-- Farben und Maße · Nord (nordtheme.com)
--
-- Ein Akzent (Frost), sonst ruhige Grautöne. Rot und Gelb nur für Zustände
-- (Fehler, stumm, Warnung), nie als Dekoration.
--
-- Dieselben Werte stehen in waybar/style.css, dunst/dunstrc, fuzzel/fuzzel.ini
-- und alacritty/alacritty.toml. Wer hier etwas ändert, zieht die dort mit.

local color = {
    -- Polar Night · Flächen
    base    = "2e3440", -- Hintergrund
    surface = "3b4252", -- erhöhte Fläche, inaktiver Rahmen
    overlay = "434c5e",
    muted   = "4c566a", -- gedämpfter Text, Trennlinien
    -- Snow Storm · Text
    text    = "d8dee9",
    bright  = "eceff4",
    -- Frost · der Akzent
    accent  = "88c0d0",
    accent2 = "81a1c1",
    -- Aurora · nur Zustände
    red     = "bf616a",
    yellow  = "ebcb8b",
}

-- "rgba(rrggbbaa)" aus Hex + Deckkraft 0..1
local function rgba(hex, alpha)
    return string.format("rgba(%s%02x)", hex, math.floor((alpha or 1) * 255 + 0.5))
end

return {
    color  = color,
    rgba   = rgba,

    -- Raster: 10 px überall. Zum Bildschirmrand 10, zwischen zwei Fenstern
    -- 2 × 5 = 10, um die Waybar herum 10.
    gap_out = 10,
    gap_in  = 5,
    radius  = 10,
    border  = 2,
}
