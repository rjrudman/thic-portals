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
function InviteTrade.createPendingInvite(playerName, sender, message, destinationKeyword)
    Events.pendingInvites[playerName] = {
        timestamp = time(),
        destination = destinationKeyword,
        originalMessage = message,
        hasJoined = false,
        hasPaid = false,
        travelled = false,
        fullName = sender
    }
    InviteTrade.setSenderExpiryTimer(playerName)
end

-- Function to handle invite and message for common phrases
function InviteTrade.handleCommonPhraseInvite(sender, playerName, message)
    if InviteTrade.canInvitePlayer(playerName) then
        InviteTrade.invitePlayer(sender)
        local _, destinationKeyword = Utils.findKeywordPosition(message, Config.Settings.DestinationKeywords)
        InviteTrade.createPendingInvite(playerName, sender, message, destinationKeyword)
    else
        print("|cff87CEEB[Thic-Portals]|r Player " .. sender .. " is still on cooldown.")
    end
end

-- Function to handle invites with destination keywords
function InviteTrade.handleDestinationOnlyInvite(sender, playerName, message)
    local destinationPosition, destinationKeyword = Utils.findKeywordPosition(message, Config.Settings.DestinationKeywords)
    if destinationPosition and InviteTrade.canInvitePlayer(playerName) then
        if Config.Settings.debugMode then
            print("|cff87CEEB[Thic-Portals]|r [Destination-only-invite] Matched on destination keyword: " .. destinationKeyword)
        end
        InviteTrade.invitePlayer(sender)
        InviteTrade.createPendingInvite(playerName, sender, message, destinationKeyword)
    elseif destinationPosition then
        print("|cff87CEEB[Thic-Portals]|r Player " .. sender .. " is still on cooldown.")
    end
end

-- Function to handle advanced keyword detection invites
function InviteTrade.handleAdvancedKeywordInvite(sender, playerName, message)
    local intentPosition, intentKeyword = Utils.findKeywordPosition(message, Config.Settings.IntentKeywords)
    if intentPosition then
        local servicePosition, serviceKeyword = Utils.findKeywordPosition(message, Config.Settings.ServiceKeywords)
        local destinationPosition, destinationKeyword = Utils.findKeywordPosition(message, Config.Settings.DestinationKeywords)

        if servicePosition and servicePosition > intentPosition and InviteTrade.canInvitePlayer(playerName) then
            if Config.Settings.debugMode then
                print("|cff87CEEB[Thic-Portals]|r [Advanced-keyword-invite] Matched on intent keyword: " .. intentKeyword)
                print("|cff87CEEB[Thic-Portals]|r [Advanced-keyword-invite] Matched on service keyword: " .. serviceKeyword)
                print("|cff87CEEB[Thic-Portals]|r [Advanced-keyword-invite] Matched on destination keyword: " .. destinationKeyword)
            end
            InviteTrade.invitePlayer(sender)
            InviteTrade.createPendingInvite(playerName, sender, message, destinationKeyword)
        elseif servicePosition and servicePosition > intentPosition then
            print("|cff87CEEB[Thic-Portals]|r Player " .. sender .. " is still on cooldown.")
        end
    end
end

-- Main function to handle invites and messages
function InviteTrade.handleInviteAndMessage(sender, playerName, message, destinationOnly)
    if Utils.isPlayerBanned(sender) then
        print("|cff87CEEB[Thic-Portals]|r Player " .. sender .. " is on the ban list. No invite sent.")
        return
    end

    if Utils.containsCommonPhrase(message, Config.Settings.commonPhrases) then
        InviteTrade.handleCommonPhraseInvite(sender, playerName, message)
    elseif destinationOnly then
        InviteTrade.handleDestinationOnlyInvite(sender, playerName, message)
    else
        InviteTrade.handleAdvancedKeywordInvite(sender, playerName, message)
    end

    -- Update pending invite destination if a destination keyword is found in the new message
    InviteTrade.updatePendingInviteDestination(playerName, message)
end

-- Function to update the destination of a pending invite
function InviteTrade.updatePendingInviteDestination(playerName, message)
    local destinationPosition, destinationKeyword = Utils.findKeywordPosition(message, Config.Settings.DestinationKeywords)
    if destinationPosition and Events.pendingInvites[playerName] then
        Events.pendingInvites[playerName].destination = destinationKeyword
        if Events.pendingInvites[playerName].destinationValue then
            Events.pendingInvites[playerName].destinationValue:SetText(destinationKeyword)
        end
        print("|cff87CEEB[Thic-Portals]|r Updated destination for " .. playerName .. " to " .. destinationKeyword)
    end
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

_G.InviteTrade = InviteTrade

return InviteTrade