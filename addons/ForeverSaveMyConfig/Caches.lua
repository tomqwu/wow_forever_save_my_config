-- Hand-maintained list of addon saved variables that hold price, history or
-- inventory caches rather than settings. Kept apart from the generated
-- Registry.lua so re-running the registry scanner never drops it.
-- Caches are skipped on save, restore and verification unless the player
-- opts in, because they are large and restoring them replaces newer data.
local _, NS = ...
NS.Caches = {
    Auctionator = {
        AUCTIONATOR_POSTING_HISTORY = true,
        AUCTIONATOR_PRICE_DATABASE = true,
        AUCTIONATOR_RECENT_SEARCHES = true,
        AUCTIONATOR_VENDOR_PRICE_CACHE = true,
    },
    Baganator = {
        BAGANATOR_DATA = true,
    },
    Syndicator = {
        SYNDICATOR_DATA = true,
        SYNDICATOR_SUMMARIES = true,
    },
}
function NS.IsCache(addon, name)
    local caches = NS.Caches[addon]
    return caches and caches[name] == true or false
end
function NS.IncludeCaches()
    return NS.db ~= nil and type(NS.db.ui) == 'table' and NS.db.ui.addonCaches == true
end
function NS.SkipCache(addon, name)
    return NS.IsCache(addon, name) and not NS.IncludeCaches()
end
