local strings = {
    ["SI_CBE_AND"]                                             = " и ",
    ["SI_CBE_DISABLE_GUILDBANK_WITHDRAWAL_AUTO_STASH"]         = "Отключить автоматическую гильдий банковский перевод корабля мешок",
    ["SI_CBE_DISABLE_GUILDBANK_WITHDRAWAL_AUTO_STASH_TOOLTIP"] = "Если эта функция включена , вывод крафта материалов из банка гильдии будет держать материалы в вашем рюкзаке . Они не будут автоматически переведены на ваш ESO + ремесленной мешок ."
}

-- Overwrite English strings
for stringId, value in pairs(strings) do
    CBE_STRINGS[stringId] = value
end