-- InviteTrade.lua

local Config = _G.Config
local Utils = _G.Utils

local InviteTrade = {}

-- Function to play a sound when a match is found
local function playMatchSound()
    if Config.Settings.soundEnabled then
        PlaySoundFile("Interface\\AddOns\\ThicPortals\\Media\\Sounds\\invitesent.mp3", "Master")
    end
end

-- Function to match food and water requests
local function matchFoodAndWaterRequests(message)
    local isFoodRequested = false
    local isWaterRequested = false

    for foodKeyword in Config.Settings.FoodKeywords do
        if string.find(message:lower(), foodKeyword:lower()) then
            isFoodRequested = true
        end
    end

    for waterKeyword in Config.Settings.WaterKeywords do
        if string.find(message:lower(), waterKeyword:lower()) then
            isWaterRequested = true
        end
    end

    return isFoodRequested, isWaterRequested
end

-- Function to update the destination of a pending invite
local function updatePendingInviteDestination(playerName, message)
    local destinationPosition, destinationKeyword = Utils.findKeywordPosition(message, Config.Settings.DestinationKeywords)
    if destinationPosition and Events.pendingInvites[playerName] then
        Events.pendingInvites[playerName].destination = destinationKeyword
        if Events.pendingInvites[playerName].destinationValue then
            Events.pendingInvites[playerName].destinationValue:SetText(destinationKeyword)
        end

        print("|cff87CEEB[Thic-Portals]|r Updated destination for " .. playerName .. " to " .. destinationKeyword)

        if Events.pendingInvites[playerName].portalButton then
            -- Set the icon texture for the portal spell
            UI.setIconSpell(Events.pendingInvites[playerName], Events.pendingInvites[playerName].destination)
        end
    end
end

-- Function to handle sending an invite to a player
function InviteTrade.invitePlayer(sender)
    InviteUnit(sender)

    playMatchSound()

    print("|cff87CEEB[Thic-Portals]|r Invited " .. sender .. " to the group.")
end

-- Function to check if a player can be invited (based on cooldown)
function InviteTrade.canInvitePlayer(playerName)
    return not Events.pendingInvites[playerName] or time() - Events.pendingInvites[playerName].timestamp >= Config.Settings.inviteCooldown
end

-- Function to create a pending invite entry
function InviteTrade.createPendingInvite(playerName, playerClass, sender, message, destinationKeyword)
    Events.pendingInvites[playerName] = {
        timestamp = time(),
        class = playerClass,
        name = playerName,
        fullName = sender,
        destination = destinationKeyword,
        originalMessage = message,
        hasJoined = false,
        hasPaid = false,
        travelled = false
    }

    InviteTrade.setSenderExpiryTimer(playerName)
end

-- Function to handle invite and message for common phrases
function InviteTrade.handleCommonPhraseInvite(message)
    local _, destinationKeyword = Utils.findKeywordPosition(message, Config.Settings.DestinationKeywords)

    return destinationKeyword
end

-- Function to handle invites with destination keywords
function InviteTrade.handleDestinationOnlyInvite(message)
    local destinationPosition, destinationKeyword = Utils.findKeywordPosition(message, Config.Settings.DestinationKeywords)

    if destinationPosition then
        if Config.Settings.debugMode then
            print("|cff87CEEB[Thic-Portals]|r [Destination-only-invite] Matched on destination keyword: " .. destinationKeyword)
        end

        return destinationKeyword
    end
end

-- Function to handle advanced keyword detection invites
function InviteTrade.handleAdvancedKeywordInvite(message)
    local intentPosition, intentKeyword = Utils.findKeywordPosition(message, Config.Settings.IntentKeywords)
    if intentPosition then
        local servicePosition, serviceKeyword = Utils.findKeywordPosition(message, Config.Settings.ServiceKeywords)
        local destinationPosition, destinationKeyword = Utils.findKeywordPosition(message, Config.Settings.DestinationKeywords)

        if servicePosition and servicePosition > intentPosition then
            if Config.Settings.debugMode then
                print("|cff87CEEB[Thic-Portals]|r [Advanced-keyword-invite] Matched on intent keyword: " .. intentKeyword)
                print("|cff87CEEB[Thic-Portals]|r [Advanced-keyword-invite] Matched on service keyword: " .. serviceKeyword)
                print("|cff87CEEB[Thic-Portals]|r [Advanced-keyword-invite] Matched on destination keyword: " .. destinationKeyword)
            end

            return destinationKeyword
        end
    end
end

-- Main function to handle invites and messages
function InviteTrade.handleInviteAndMessage(sender, playerName, playerClass, message, destinationOnly)
    -- Here we deal with the player ban list
    if Utils.isPlayerBanned(sender) then
        print("|cff87CEEB[Thic-Portals]|r Player " .. sender .. " is on the ban list. No invite sent.")
        return
    end

    -- Here we deal with the keyword ban list
    if Utils.containsCommonPhrase(message, Config.Settings.KeywordBanList) then
        print("|cff87CEEB[Thic-Portals]|r Player " .. sender .. " used a banned keyword. No invite sent.")
        return
    end

    -- Here we deal with potential invite cooldowns
    if not InviteTrade.canInvitePlayer(playerName) then
        print("|cff87CEEB[Thic-Portals]|r Player " .. sender .. " is still on cooldown.")
        return
    end

    local destinationKeyword = nil
    if Utils.containsCommonPhrase(message, Config.Settings.commonPhrases) then
        destinationKeyword = InviteTrade.handleCommonPhraseInvite(message)
    elseif destinationOnly then
        destinationKeyword = InviteTrade.handleDestinationOnlyInvite(message)
    else
        destinationKeyword = InviteTrade.handleAdvancedKeywordInvite(message)
    end

    if destinationKeyword then
        InviteTrade.invitePlayer(sender)
        InviteTrade.createPendingInvite(playerName, playerClass, sender, message, destinationKeyword)
    end

    -- local isFoodRequested, isWaterRequested = matchFoodAndWaterRequests(message)

    -- if isFoodRequested or isWaterRequested then
    --     print("|cff87CEEB[Thic-Portals]|r " .. playerName .. " requested " .. (isFoodRequested and "food" or "") .. (isFoodRequested and isWaterRequested and " and " or "") .. (isWaterRequested and "water" or "") .. ".")
    -- end

    -- Update pending invite destination if a destination keyword is found in the new message
    updatePendingInviteDestination(playerName, message)
end

-- Function to set an expiry timer for pending invites
function InviteTrade.setSenderExpiryTimer(playerName)
    C_Timer.After(180, function()
        if Events.pendingInvites[playerName] then
            print("|cff87CEEB[Thic-Portals]|r Invite for " .. playerName .. " expired.")
            Events.pendingInvites[playerName] = nil
        end
    end)
end

-- Function to mark yourself with a star when someone accepts the party invite
function InviteTrade.markSelfWithStar()
    SetRaidTarget("player", 1) -- 1 corresponds to the star raid marker
end

-- Function to watch for player's proximity to infer teleportation
function InviteTrade.watchForPlayerProximity(sender)
    local ticker
    local flagProximityReached = false

    ticker = C_Timer.NewTicker(1, function()
        if UnitInParty(sender) then
            if Utils.isPlayerWithinRange(sender, Config.Settings.distanceInferringClose) then
                if not flagProximityReached then
                    print("|cff87CEEB[Thic-Portals]|r " .. sender .. " is nearby and might be taking the portal.")
                    flagProximityReached = true
                end
            elseif flagProximityReached and not Utils.isPlayerWithinRange(sender, Config.Settings.distanceInferringTravelled) then
                if Config.Settings.debugMode then
                    print("|cff87CEEB[Thic-Portals]|r " .. sender .. " has moved away, assuming they took the portal.")
                end

                if Events.pendingInvites[sender] then
                    Events.pendingInvites[sender].travelled = true
                end
                ticker:Cancel() -- Cancel the ticker when the player has moved away
            end
        else
            if Events.pendingInvites[sender] and Events.pendingInvites[sender].ticketFrame then
                Events.pendingInvites[sender].ticketFrame:Hide()
            end
            Events.pendingInvites[sender] = nil
            ticker:Cancel() -- Cancel the ticker if the player is no longer in the party
        end
    end)
end

-- Function to check if there was a tip in the trade
function InviteTrade.checkTradeTip()
    print("|cff87CEEB[Thic-Portals]|r Checking trade tip...");

    local copper = tonumber(Config.currentTraderMoney);
    local silver = math.floor((copper % 10000) / 100);
    local gold = math.floor(copper / 10000);
    local remainingCopper = copper % 100;

    print(string.format("|cff87CEEB[Thic-Portals]|r Received %dg %ds %dc from the trade.", gold, silver, remainingCopper));

    if gold > 0 or silver > 0 or remainingCopper > 0 then
        Utils.incrementTradesCompleted();
        Utils.resetDailyGoldIfNeeded();
        Utils.addTipToRollingTotal(gold, silver, remainingCopper);

        -- If the gold amount is higher than 8g, send a custom message via whisper saying "<3"
        if gold > 8 then
            SendChatMessage("<3", "WHISPER", nil, Events.pendingInvites[Config.currentTraderName].fullName)

            -- Send an emote "thank" to the player after they have accepted the trade
            DoEmote("thank", Config.currentTraderName)
        end

        -- If the gold amount is higher than 8g, send a custom message via whisper saying "<3"
        if gold == 69 or silver == 69 or remainingCopper == 69 then
            SendChatMessage("Nice (⌐□_□)", "WHISPER", nil, Events.pendingInvites[Config.currentTraderName].fullName)

            -- Send an emote "flirt" to the player after they sent a 69 tip
            DoEmote("flirt", Config.currentTraderName)
        end

        -- If the gold amount is higher than 8g, send a custom message via whisper saying "<3"
        if gold == 4 and silver == 20 then
            SendChatMessage("420 blaze it (⌐□_□)-~", "WHISPER", nil, Events.pendingInvites[Config.currentTraderName].fullName)

            -- Send an emote "silly" to the player after they sent a 420 tip
            DoEmote("silly", Config.currentTraderName)
        end

        return true
    else
        return false
    end
end

-- Function to also send mana users a message with water and food stockpiles and none mana users food stock
function InviteTrade.sendFoodAndWaterStockMessage(playerName, playerClass)
    -- foodStock should be a string in the following format: "20 x Conjured Cinnamon Roll"
    local foodStock = nil
    -- waterStock should be a string in the following format: "20 x Conjured Crystal Water"
    local waterStock = nil

    -- -- get the current party member count
    -- local partyMemberCount = GetNumPartyMembers()

    -- -- calculate new party member level by using the party member count
    -- local level = UnitLevel("party" .. partyMemberCount)

    -- print("|cff87CEEB[Thic-Portals]|r Calculated party member level: " .. level)

    -- Check if the player has rank 6 food in their inventory
    local foodCount = GetItemCount(8076, false)
    if foodCount > 0 then
        foodStock = foodCount .. " x Conjured Sweet Roll " .. "(20x: " .. Utils.formatCopperValue(Config.Settings.prices.food["Conjured Sweet Roll"] * 20) .. ")"
    end
    -- Check if the player has rank 7 food in their inventory
    local foodCount = GetItemCount(22895, false)
    if foodCount > 0 then
        foodStock = foodCount .. " x Conjured Cinnamon Roll " .. "(20x: " .. Utils.formatCopperValue(Config.Settings.prices.food["Conjured Cinnamon Roll"] * 20) .. ")"
    end
    -- Check if the player has rank 6 water in their inventory
    local waterCount = GetItemCount(8077, false)
    if waterCount > 0 then
        waterStock = waterCount .. " x Conjured Sparkling Water " .. "(20x: " .. Utils.formatCopperValue(Config.Settings.prices.water["Conjured Sparkling Water"] * 20) .. ")"
    end
    -- Check if the player has rank 7 water in their inventory
    local waterCount = GetItemCount(2136, false)
    if waterCount > 0 then
        waterStock = waterCount .. " x Conjured Crystal Water " .. "(20x: " .. Utils.formatCopperValue(Config.Settings.prices.water["Conjured Crystal Water"] * 20) .. ")"
    end

    -- If the player has no food or water in their inventory, we will not advertise it
    if not foodStock and not waterStock then
        -- Print a warning to the player that they're out of stock
        print("|cff87CEEB[Thic-Portals]|r You have run out of food and water stock. Please restock or disable food and water support.")
        return
    end

    local targetIsManaUser = false

    -- depending on the class of the player, we will advertise water or not
    if playerClass == "MAGE" or playerClass == "PRIEST" or playerClass == "WARLOCK" or playerClass == "DRUID" or playerClass == "SHAMAN" then
        targetIsManaUser = true
    end

    if targetIsManaUser and (waterStock or foodStock) then
        SendChatMessage("I have " .. waterStock .. " and " .. foodStock .. " in stock if you require it - just ask!", "WHISPER", nil, playerName)
    elseif foodStock then
        SendChatMessage("I have " .. foodStock .. " in stock if you require it - just ask!", "WHISPER", nil, playerName)
    end
end

_G.InviteTrade = InviteTrade

return InviteTrade