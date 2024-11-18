-- Events.lua
local Config = _G.Config

-- Utils.lua
local Utils = {}

-- Function to calculate the distance between two points using the Pythagorean theorem
function Utils.calculateDistance(playerX, playerY, targetX, targetY)
    return math.sqrt((playerX - targetX)^2 + (playerY - targetY)^2)
end

-- Function to check if a message contains any common phrase from a list
function Utils.containsCommonPhrase(message, commonPhrases)
    message = message:lower()
    for _, phrase in ipairs(commonPhrases) do
        if string.find(message, phrase) then
            return true
        end
    end
    return false
end

-- Function to find if a message contains any keyword from a list and return the position and matched keyword
function Utils.findKeywordPosition(message, keywordList)
    message = " " .. message:lower() .. " " -- Add spaces around the message to match keywords at the start and end
    for _, keyword in ipairs(keywordList) do
        local pattern = "%f[%w]" .. keyword .. "%f[%W]"
        local position = string.find(message, pattern)
        if position then
            return position, keyword
        end
    end
    return nil, nil
end

-- Function to update the distance label in the UI based on the distance between two players
function Utils.updateDistanceLabel(sender, distanceLabel)
    local ticker
    ticker = C_Timer.NewTicker(1, function()
        if UnitInParty(sender) then
            local playerX, playerY, playerInstanceID = UnitPosition("player")
            local targetX, targetY, targetInstanceID = UnitPosition(sender)

            if playerInstanceID == targetInstanceID then
                local distance = Utils.calculateDistance(playerX, playerY, targetX, targetY)
                distanceLabel:SetText(string.format("Distance: %.1f yards", distance))
            else
                distanceLabel:SetText("Distance: Unknown")
            end
        else
            distanceLabel:SetText("Distance: N/A")
            ticker:Cancel() -- Cancel the ticker if the player is no longer in the party
        end
    end)
end

-- Function to calculate the required height for text
function Utils.calculateTextHeight(fontString, text, width)
    fontString:SetWidth(width)
    fontString:SetText(text)
    fontString:SetWordWrap(true)
    local height = fontString:GetStringHeight()
    return height
end

-- Function to extract player name from full sender string (e.g., "Player-Realm")
function Utils.extractPlayerName(sender)
    local name = sender:match("^[^-]+")
    return name
end

-- Function to add tip to rolling total
function Utils.addTipToRollingTotal(gold, silver, copper)
    local totalCopper = gold * 10000 + silver * 100 + copper

    Config.Settings.totalGold = Config.Settings.totalGold + totalCopper
    Config.Settings.dailyGold = Config.Settings.dailyGold + totalCopper

    Utils.printGoldInformation()
end

-- Function to print gold information
function Utils.printGoldInformation()
    print(string.format("|cff87CEEB[Thic-Portals]|r Total trades completed: %d", Config.Settings.totalTradesCompleted))
    print(string.format("|cff87CEEB[Thic-Portals]|r Total gold earned: %dg %ds %dc",
        math.floor(Config.Settings.totalGold / 10000),
        math.floor((Config.Settings.totalGold % 10000) / 100),
        Config.Settings.totalGold % 100
    ))
    print(string.format("|cff87CEEB[Thic-Portals]|r Gold earned today: %dg %ds %dc",
        math.floor(Config.Settings.dailyGold / 10000),
        math.floor((Config.Settings.dailyGold % 10000) / 100),
        Config.Settings.dailyGold % 100
    ))
end

-- Function to reset daily gold if needed
function Utils.resetDailyGoldIfNeeded()
    local currentDate = date("%Y-%m-%d")
    if Config.Settings.lastUpdateDate ~= currentDate then
        Config.Settings.dailyGold = 0
        Config.Settings.lastUpdateDate = currentDate
        print("|cff87CEEB[Thic-Portals]|r Daily gold counter reset for a new day.")
    end
end

-- Function to increment trades completed
function Utils.incrementTradesCompleted()
    Config.Settings.totalTradesCompleted = Config.Settings.totalTradesCompleted + 1
end

-- Function to check if the player is within range using the UnitPosition API
function Utils.isPlayerWithinRange(sender, range)
    local playerX, playerY, playerInstanceID = UnitPosition("player")
    local targetX, targetY, targetInstanceID = UnitPosition(sender)

    if playerInstanceID == targetInstanceID then
        local distance = Utils.calculateDistance(playerX, playerY, targetX, targetY)
        return distance <= range -- Example threshold for being "travelled"
    end

    return false
end

-- Function to check if a player is on the ban list
function Utils.isPlayerBanned(player)
    for _, bannedPlayer in ipairs(Config.Settings.BanList) do
        if bannedPlayer == player then
            return true
        end
    end
    return false
end

function Utils.getMatchingPortal(destination)
    local portal = {
        matched = false,
        spellID = 10059,
        spellName = "Portal: Stormwind",
        locationName = "Stormwind",
    }

    if not destination then
        return portal
    end

    -- Use the destination value to initially find the absolute spell match (Portal: Stormwind or Portal: Ironforge or ...)
    -- If no match is found, return nil

    -- Destination could be "if, "ironforge", "sw", "stormwind", "darn", "darna", "darnas", "darnasuss", ... - we need to take account for typos, abbreviations, etc.
    -- The best bet is to check every letter of the destination word and check if it matches in the destination part of the Portal: MATCH spell name
    -- The official spell destination name with the most matches is the correct one
    -- If there are multiple matching names, we can use the one with the most matches

    -- Example: destination = "darn" produces "Portal: Darnassus" as the best match

    -- Config.Portals = {
    --     "Portal: Darnassus",
    --     "Portal: Stormwind",
    --     "Portal: Ironforge",
    --     "Portal: Orgrimmar",
    --     "Portal: Thunder Bluff",
    --     "Portal: Undercity",
    -- }

    local destinationLength = string.len(destination)
    local bestMatch = nil
    local maxMatches = 0
    for _, portalName in ipairs(Config.Portals) do
        local spellName = portalName:match("Portal: (.+)")
        local spellDestination = spellName:lower()

        local matches = 0
        for i = 1, destinationLength do
            local letter = destination:sub(i, i)
            if spellDestination:find(letter) then
                matches = matches + 1
            end
        end

        if matches > maxMatches then
            maxMatches = matches
            bestMatch = portalName
        end
    end

    if bestMatch then
        if Config.Settings.debugMode then
            print("Best match for destination: " .. bestMatch)
        end

        local spellID = nil

        if bestMatch == "Portal: Darnassus" then
            spellID = 11419
        elseif bestMatch == "Portal: Stormwind" then
            spellID = 10059
        elseif bestMatch == "Portal: Ironforge" then
            spellID = 11416
        elseif bestMatch == "Portal: Orgrimmar" then
            spellID = 11417
        elseif bestMatch == "Portal: Thunder Bluff" then
            spellID = 11420
        elseif bestMatch == "Portal: Undercity" then
            spellID = 11418
        end

        portal = {
            matched = true,
            spellID = spellID,
            spellName = bestMatch,
            locationName = bestMatch:match("Portal: (.+)")
        }
    end

    return portal
end

_G.Utils = Utils

return Utils