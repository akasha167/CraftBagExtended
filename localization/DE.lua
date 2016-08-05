local strings = {
    ["SI_CBE_AND"]                                             = " und ",
    ["SI_CBE_DISABLE_GUILDBANK_WITHDRAWAL_AUTO_STASH"]         = "Handwerksbeutel in Gildenbank übergehen",
    ["SI_CBE_DISABLE_GUILDBANK_WITHDRAWAL_AUTO_STASH_TOOLTIP"] = "Ist diese Option aktiviert, so werden die Materialien aus der Gildenbank nicht in den Handwerksbeutel transferiert, sondern bleiben in Ihrem Inventar. Die Materialien werden also nicht automatisch auf Ihr ESO + Handwerk Beutel überführt werden."
}

-- Overwrite English strings
for stringId, value in pairs(strings) do
    CBE_STRINGS[stringId] = value
end