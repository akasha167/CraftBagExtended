local strings = {
    ["SI_CBE_AND"]                                             = "と",
    ["SI_CBE_WORD_BREAK"]                                      = "",
    ["SI_CBE_DISABLE_GUILDBANK_WITHDRAWAL_AUTO_STASH"]         = "自動ギルドバンククラフトバッグ転送を無効にします",
    ["SI_CBE_DISABLE_GUILDBANK_WITHDRAWAL_AUTO_STASH_TOOLTIP"] = "有効にすると、ギルドバンクからクラフト素材を引き出すことはあなたのバックパックに材料を維持します。彼らは自動的にESO +クラフトバッグに転送されません。"
}

-- Overwrite English strings
for stringId, value in pairs(strings) do
    CRAFTBAGEXTENDED_STRINGS[stringId] = value
end