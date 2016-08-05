local strings = {
    ["SI_CBE_AND"]                                             = " et ",
    ["SI_CBE_DISABLE_GUILDBANK_WITHDRAWAL_AUTO_STASH"]         = "Retrait de banque de guilde sans sac d'artisanat",
    ["SI_CBE_DISABLE_GUILDBANK_WITHDRAWAL_AUTO_STASH_TOOLTIP"] = "Lorsqu'elle est activée , le retrait des matériaux d'artisanat à partir d'une banque de guilde gardera les matériaux dans votre sac d'inventaire . Ils ne seront pas transférés automatiquement à votre ESO+ sac de artisanat ."
}

-- Overwrite English strings
for stringId, value in pairs(strings) do
    CBE_STRINGS[stringId] = value
end