local strings = {
    ["SI_CBE_AND"]                                             = " und ",
    ["SI_CBE_DISABLE_GUILDBANK_WITHDRAWAL_AUTO_STASH"]         = "Handwerksbeutel in Gildenbank übergehen",
    ["SI_CBE_DISABLE_GUILDBANK_WITHDRAWAL_AUTO_STASH_TOOLTIP"] = "Ist diese Option aktiviert, so werden die Materialien aus der Gildenbank nicht in den Handwerksbeutel transferiert, sondern bleiben in Ihrem Inventar. Die Materialien werden also nicht automatisch auf Ihr ESO + Handwerk Beutel überführt werden.",
    ["SI_CBE_PRIMARY_ACTIONS_USE_DEFAULT"]                     = "Def. Wert gilt für Schnell-Verstauen/Auspacken",
    ["SI_CBE_PRIMARY_ACTIONS_USE_DEFAULT_TOOLTIP"]             = "Die Default Checkbox im Verstauen/Auspacken Popup betrifft auch das Schnell-Verstauen/Auspacken. Wenn die Checkbox aktiviert wird, werden auch die Schnell-Verstauen/Auspacken Vorgänge diese Menge verwenden.\n\nWenn du diese Option deaktivierst, dann wird beim Schnell-Verstauen/Auspacken die komplette Menge des Materials verschoben!",
}

-- Overwrite English strings
for stringId, value in pairs(strings) do
    CRAFTBAGEXTENDED_STRINGS[stringId] = value
end