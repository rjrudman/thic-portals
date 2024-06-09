local frame = CreateFrame("Frame")
local inviteMessage = "Good day! I am creating a portal for you as we speak, please head over - I'm marked with a star."
local inviteMessageWithoutDestination = "Good day! Please specify a destination and I will create a portal for you."
local tipMessage = "Thank you for your tip. Enjoy your journey and thanks for choosing Thic-Portals. Safe travels!"
local noTipMessage = "Enjoy your journey and thanks for choosing Thic-Portals. Safe travels!"
local commonPhrases = {
    "wtb mage port",
    "wtb mage portal",
    "wtb portal darnassus",
    "wtb portal darnasus",
    "wtb portal darna",
    "wtb portal darn",
    "wtb darnassus port",
    "wtb darnasus port",
    "wtb darn port",
    "wtb darna port",
    "wtb portal",
    "wtb port"
}
local intentKeywords = {"wtb", "wtf", "want to buy", "looking for", "need", "seeking", "buying", "purchasing", "lf", "can anyone make", "can you make", "can anyone do", "can you do"}
local destinationKeywords = {"darn", "darnassuss", "darnas", "darrna", "darnaas", "darnassus", "darnasuss", "dalaran", "darna", "darnasus", "sw", "stormwind", "if", "ironforge"}
local serviceKeywords = {"portal", "port", "prt", "portla", "pportal", "protal", "pport", "teleport", "tp", "tele"}

-- Invite and trade related data
local pendingInvites = {} -- Table to store pending invites with all relevant data
local inviteCooldown = 300 -- Cooldown period in seconds
local distanceInferringClose = 50;
local distanceInferringTravelled = 1000;
local currentTraderName = nil
local currentTraderRealm = nil
local currentTraderMoney = nil
local banList = {"Seduce", "Skrill"}

-- Config checkboxes
local addonEnabled = true
local addonEnabledCheckbox = true;
local soundEnabled = true
local soundEnabledCheckbox = true;
local debugMode = false
local debugModeCheckbox = false;

-- Initialize saved variables
ThicPortalsSaved = false

-- Register event handlers for receiving chat messages, party and trade events
frame:RegisterEvent("CHAT_MSG_SAY")
frame:RegisterEvent("CHAT_MSG_YELL")
frame:RegisterEvent("CHAT_MSG_WHISPER")
frame:RegisterEvent("CHAT_MSG_CHANNEL")
frame:RegisterEvent("PARTY_INVITE_REQUEST")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("TRADE_SHOW")
frame:RegisterEvent("TRADE_ACCEPT_UPDATE")
frame:RegisterEvent("VARIABLES_LOADED")
frame:RegisterEvent("UI_INFO_MESSAGE")


local function printGoldInformation()
    print(string.format("Total trades completed: %d", ThicPortalsSaved.totalTradesCompleted));
    print(string.format("Total gold earned: %dg %ds %dc", math.floor(ThicPortalsSaved.totalGold / 10000), math.floor((ThicPortalsSaved.totalGold % 10000) / 100), ThicPortalsSaved.totalGold % 100));
    print(string.format("Gold earned today: %dg %ds %dc", math.floor(ThicPortalsSaved.dailyGold / 10000), math.floor((ThicPortalsSaved.dailyGold % 10000) / 100), ThicPortalsSaved.dailyGold % 100));
end

local function resetDailyGoldIfNeeded()
    local currentDate = date("%Y-%m-%d");
    if ThicPortalsSaved.lastUpdateDate ~= currentDate then
        ThicPortalsSaved.dailyGold = 0;
        ThicPortalsSaved.lastUpdateDate = currentDate;
        print("Daily gold counter reset for a new day.");
    end
end

local function addTipToRollingTotal(gold, silver, copper)
    local totalCopper = gold * 10000 + silver * 100 + copper;
    ThicPortalsSaved.totalGold = ThicPortalsSaved.totalGold + totalCopper;
    ThicPortalsSaved.dailyGold = ThicPortalsSaved.dailyGold + totalCopper;

    printGoldInformation();
end

local function incrementTradesCompleted()
    ThicPortalsSaved.totalTradesCompleted = ThicPortalsSaved.totalTradesCompleted + 1;
end

-- Function to update the distance label in the ticket window
local function updateDistanceLabel(sender, distanceLabel)
    local ticker
    ticker = C_Timer.NewTicker(1, function()
        if UnitInParty(sender) then
            local playerX, playerY, playerInstanceID = UnitPosition("player")
            local targetX, targetY, targetInstanceID = UnitPosition(sender)

            if playerInstanceID == targetInstanceID then
                local distance = math.sqrt((playerX - targetX)^2 + (playerY - targetY)^2)
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

-- Function to add a player to the ban list
local function addToBanList(player)
    table.insert(banList, player)
    print(player .. " has been added to the ban list.")
end

-- Function to check if a player is on the ban list
local function isPlayerBanned(player)
    for _, bannedPlayer in ipairs(banList) do
        if bannedPlayer == player then
            return true
        end
    end
    return false
end

-- Function to check if there was a tip in the trade
local function checkTradeTip()
    print("Checking trade tip...");

    local copper = tonumber(currentTraderMoney);
    local silver = math.floor((copper % 10000) / 100);
    local gold = math.floor(copper / 10000);
    local remainingCopper = copper % 100;

    print(string.format("Received %dg %ds %dc from the trade.", gold, silver, remainingCopper));

    if gold > 0 or silver > 0 or remainingCopper > 0 then
        resetDailyGoldIfNeeded();
        addTipToRollingTotal(gold, silver, remainingCopper);
        incrementTradesCompleted();

        return true
    else
        return false
    end
end

-- Function to check if a message contains any common phrase
local function containsCommonPhrase(message)
    message = message:lower();
    for _, phrase in ipairs(commonPhrases) do
        if string.find(message, phrase) then
            return true;
        end
    end

    return false;
end

-- Function to check if a message contains any keyword from a list and return the position
local function findKeywordPosition(message, keywordList)
    message = " " .. message:lower() .. " ";  -- Add spaces around the message to match keywords at the start and end
    for _, keyword in ipairs(keywordList) do
        local pattern = "%f[%w]" .. keyword .. "%f[%W]";
        local position = string.find(message, pattern);
        if position then
            return position, keyword;
        end
    end
    return nil, nil;
end

-- Function to update the destination of a pending invite
local function updatePendingInviteDestination(playerName, message)
    local destinationPosition, destinationKeyword = findKeywordPosition(message, destinationKeywords);
    if destinationPosition and pendingInvites[playerName] then
        pendingInvites[playerName].destination = destinationKeyword;
        if pendingInvites[playerName].destinationValue then
            pendingInvites[playerName].destinationValue:SetText(destinationKeyword);
        end
        print("Updated destination for " .. playerName .. " to " .. destinationKeyword);
    end
end

-- Updated function to create and display the ticket window
local function displayTicketWindow(sender, destination)
    -- Create the main frame
    local ticketFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    ticketFrame:SetSize(220, 160)  -- Reduced height
    ticketFrame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", UIParent:GetWidth() * 0.75, UIParent:GetHeight() * 0.75)
    ticketFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    ticketFrame:SetBackdropColor(0, 0, 0, 1)

    -- Make the frame moveable
    ticketFrame:EnableMouse(true)
    ticketFrame:SetMovable(true)
    ticketFrame:RegisterForDrag("LeftButton")
    ticketFrame:SetScript("OnDragStart", ticketFrame.StartMoving)
    ticketFrame:SetScript("OnDragStop", ticketFrame.StopMovingOrSizing)

    -- Create the title text
    local title = ticketFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -20)  -- Added padding from the top
    title:SetText("NEW TICKET")

    -- Create the sender label
    local senderLabel = ticketFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    senderLabel:SetPoint("TOPLEFT", 20, -50)  -- Adjusted position
    senderLabel:SetText("Player:")

    -- Create the sender value
    local senderValue = ticketFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    senderValue:SetPoint("LEFT", senderLabel, "RIGHT", 5, 0)
    senderValue:SetText(sender)

    -- Create the destination label
    local destinationLabel = ticketFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    destinationLabel:SetPoint("TOPLEFT", senderLabel, "BOTTOMLEFT", 0, -10)
    destinationLabel:SetText("Destination:")

    -- Create the destination value
    local destinationValue = ticketFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    destinationValue:SetPoint("LEFT", destinationLabel, "RIGHT", 5, 0)
    destinationValue:SetText(destination or "Requesting...")

    -- Store reference to the destinationValue in pendingInvites
    if pendingInvites[sender] then
        pendingInvites[sender].destinationValue = destinationValue
    end

    -- Create the close button
    local closeButton = CreateFrame("Button", nil, ticketFrame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -5, -5)
    closeButton:SetScript("OnClick", function()
        ticketFrame:Hide()
    end)

    -- Create the distance label
    local distanceLabel = ticketFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    distanceLabel:SetPoint("TOPLEFT", destinationLabel, "BOTTOMLEFT", 0, -10)
    distanceLabel:SetText("Distance: N/A")

    -- Update the distance label
    updateDistanceLabel(sender, distanceLabel)

    -- Create the remove button
    local removeButton = CreateFrame("Button", nil, ticketFrame, "UIPanelButtonTemplate")
    removeButton:SetSize(80, 22)
    removeButton:SetPoint("BOTTOM", 0, 15)
    removeButton:SetText("Remove")
    removeButton:SetEnabled(false)  -- Initially disable the button
    removeButton:SetScript("OnClick", function()
        UninviteUnit(sender)
        print(sender .. " has been removed from the party.")
        pendingInvites[sender] = nil
        ticketFrame:Hide()
    end)

    local ticker
    -- Enable the remove button when the player has travelled
    ticker = C_Timer.NewTicker(1, function()
        if pendingInvites[sender] and pendingInvites[sender].travelled then
            removeButton:SetEnabled(true)
            ticker:Cancel() -- Cancel the ticker when the player has moved away

            -- Update to show "Complete" and tick icon
            destinationLabel:Hide()
            destinationValue:Hide()
            distanceLabel:Hide()  -- Hide the distance label

            local completeText = ticketFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            completeText:SetPoint("CENTER", -10, -10)
            completeText:SetText("Complete")

            local tickIcon = ticketFrame:CreateTexture(nil, "ARTWORK")
            tickIcon:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-Ready") -- Custom tick icon
            tickIcon:SetPoint("LEFT", completeText, "RIGHT", 5, 0)
            tickIcon:SetSize(20, 20)
        end
    end, 180)

    -- Show the frame
    ticketFrame:Show()
end

-- Function to extract player name from full sender string
local function extractPlayerName(sender)
    local name = sender:match("^[^-]+");
    return name;
end

-- Function to automatically remove the user from tracking after a minute since the first request was made
local function setSenderExpiryTimer(playerName)
    C_Timer.After(180, function()
        if pendingInvites[playerName] then
            print("Invite for " .. playerName .. " expired.");
            pendingInvites[playerName] = nil;
        end
    end)
end

-- Function to play a sound when a match is found
local function playMatchSound()
    if soundEnabled then
        print("Playing invite sound")
        PlaySoundFile("Interface\\AddOns\\ThicPortals\\Media\\Sounds\\invitesent.mp3", "Master")
    end
end

-- Function to mark yourself with a star when someone accepts the party invite
local function markSelfWithStar()
    SetRaidTarget("player", 1) -- 1 corresponds to the star raid marker
end

-- Function to check if the player is near us using the UnitPosition API
local function isPlayerWithinRange(sender, range)
    local playerX, playerY, playerInstanceID = UnitPosition("player")
    local targetX, targetY, targetInstanceID = UnitPosition(sender)

    if playerInstanceID == targetInstanceID then
        local distance = math.sqrt((playerX - targetX)^2 + (playerY - targetY)^2)
        return distance <= range -- Example threshold for being "travelled"
    end

    return false
end

-- Function to watch for player's proximity to infer teleportation
local function watchForPlayerProximity(sender)
    local ticker
    local flagProximityReached = false

    print("watchForPlayerProximity: " .. sender)

    ticker = C_Timer.NewTicker(1, function()
        if UnitInParty(sender) then
            if isPlayerWithinRange(sender, distanceInferringClose) then
                if not flagProximityReached then
                    print(sender .. " is nearby and might be taking the portal.");
                    flagProximityReached = true;
                end
            elseif flagProximityReached and not isPlayerWithinRange(sender, distanceInferringTravelled) then
                print(sender .. " has moved away, assuming they took the portal.");
                pendingInvites[sender].travelled = true;
                ticker:Cancel(); -- Cancel the ticker when the player has moved away
            end
        else
            pendingInvites[sender] = nil;
            ticker:Cancel(); -- Cancel the ticker if the player is no longer in the party
        end
    end, 180)
end

-- Function that includes some fluff to the "invite a player" process
local function invitePlayer(sender)
    playMatchSound();
    InviteUnit(sender)
    print("Invited " .. sender .. " to the group.")
end

-- Function to handle invites and messages
local function handleInviteAndMessage(sender, playerName, message)
    if isPlayerBanned(sender) then
        print("Player " .. sender .. " is on the ban list. No invite sent.");
        return
    end

    if containsCommonPhrase(message) then
        -- Handle common phrases
        if not pendingInvites[playerName] or time() - pendingInvites[playerName].timestamp >= inviteCooldown then
            invitePlayer(sender);
            -- Record the time and track the invite as pending
            local destinationPosition, destinationKeyword = findKeywordPosition(message, destinationKeywords);
            pendingInvites[playerName] = {timestamp = time(), destination = destinationKeyword, sentInviteMessage = false, travelled = false, fullName = sender};
            setSenderExpiryTimer(playerName);
        else
            print("Player " .. sender .. " is still on cooldown.");
        end
    else
        -- Handle advanced keyword detection
        local intentPosition, intentKeyword = findKeywordPosition(message, intentKeywords);
        if intentPosition then

            local servicePosition, serviceKeyword = findKeywordPosition(message, serviceKeywords)
            local destinationPosition, destinationKeyword = findKeywordPosition(message, destinationKeywords)

            -- Proceed only if intent is found first
            if (servicePosition and servicePosition > intentPosition) then
                -- Invite the player and create the portal as requested
                if not pendingInvites[playerName] or time() - pendingInvites[playerName].timestamp >= inviteCooldown then
                    invitePlayer(sender);
                    -- Record the time and track the invite as pending
                    pendingInvites[playerName] = {timestamp = time(), destination = destinationKeyword, sentInviteMessage = false, travelled = false, fullName = sender}
                    setSenderExpiryTimer(playerName);
                else
                    print("Player " .. sender .. " is still on cooldown.");
                end
            end
        end
    end

    -- Update pending invite destination if a destination keyword is found in the new message
    updatePendingInviteDestination(playerName, message);
end

-- Event handler function
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "VARIABLES_LOADED" then
        -- Initialize saved variables
        ThicPortalsSaved = ThicPortalsSaved or {}
        ThicPortalsSaved.totalGold = ThicPortalsSaved.totalGold or 0
        ThicPortalsSaved.dailyGold = ThicPortalsSaved.dailyGold or 0
        ThicPortalsSaved.totalTradesCompleted = ThicPortalsSaved.totalTradesCompleted or 0
        ThicPortalsSaved.lastUpdateDate = ThicPortalsSaved.lastUpdateDate or date("%Y-%m-%d")

        printGoldInformation()
    elseif event == "GROUP_ROSTER_UPDATE" then
        if IsInGroup() then
            for sender, inviteData in pairs(pendingInvites) do
                if UnitInParty(sender) and not inviteData.sentInviteMessage then
                    displayTicketWindow(sender, inviteData.destination)

                    if inviteData.destination then
                        SendChatMessage(inviteMessage, "WHISPER", nil, inviteData.fullName)
                    else
                        SendChatMessage(inviteMessageWithoutDestination, "WHISPER", nil, inviteData.fullName)
                    end

                    pendingInvites[sender].sentInviteMessage = true

                    markSelfWithStar() -- Mark yourself with a star

                    watchForPlayerProximity(sender) -- Start tracking player proximity to infer teleportation
                end
            end
        end
    elseif event == "TRADE_SHOW" then
        -- NPC is currently the player you're trading
        currentTraderName, currentTraderRealm = UnitName("NPC", true); -- Store the name of the player when the trade window is opened

        print("Current trader: " .. currentTraderName)
    elseif event == "TRADE_MONEY_CHANGED" then
		currentTraderMoney = GetTargetTradeMoney();
	elseif event == "TRADE_ACCEPT_UPDATE" then
		currentTraderMoney = GetTargetTradeMoney();
	elseif (event == "UI_INFO_MESSAGE") then
		local type, msg = ...;
		if (msg == ERR_TRADE_COMPLETE) then
            if currentTraderName then
                if pendingInvites[currentTraderName] then
                    local messageToSend = checkTradeTip() and tipMessage or noTipMessage

                    -- Send them a thank you!
                    SendChatMessage(messageToSend, "WHISPER", nil, pendingInvites[currentTraderName].fullName)

                    -- Set a flag regarding their status
                    pendingInvites[currentTraderName].waitingToTravel = true

                    currentTraderName = nil
                    currentTraderMoney = nil
                    currentTraderRealm = nil
                else
                    print("No pending invite found for current trader, ignoring transaction.")
                end
            else
                print("No current trader found.")
            end
		end
    elseif event == "CHAT_MSG_SAY" or event == "CHAT_MSG_YELL" or event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_CHANNEL" then
        local message, sender = ...
        local playerName = extractPlayerName(sender)

        -- Check if addon is enabled
        if addonEnabled and message and playerName then
            handleInviteAndMessage(sender, playerName, message)
        end
    end
end)

-- Function to create the interface options panel
local function createOptionsPanel()
    local panel = CreateFrame("Frame")
    panel.name = "Thic Portals"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Thic's Portal Service Configuration")

    -- Addon On/Off Checkbox
    addonEnabledCheckbox = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    addonEnabledCheckbox:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    addonEnabledCheckbox.Text:SetText("Enable Addon")
    addonEnabledCheckbox:SetChecked(addonEnabled)
    addonEnabledCheckbox:SetScript("OnClick", function(self)
        addonEnabled = self:GetChecked()
        if addonEnabled then
            print("Addon watching for new trades.")
        else
            print("Addon disabled.")
        end
    end)

    -- Sound On/Off Checkbox
    soundEnabledCheckbox = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    soundEnabledCheckbox:SetPoint("TOPLEFT", addonEnabledCheckbox, "BOTTOMLEFT", 0, -8)
    soundEnabledCheckbox.Text:SetText("Enable Sound")
    soundEnabledCheckbox:SetChecked(soundEnabled)
    soundEnabledCheckbox:SetScript("OnClick", function(self)
        soundEnabled = self:GetChecked()
        if soundEnabled then
            print("Sound enabled.")
        else
            print("Sound disabled.")
        end
    end)

    -- Test Mode Checkbox
    debugModeCheckbox = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    debugModeCheckbox:SetPoint("TOPLEFT", soundEnabledCheckbox, "BOTTOMLEFT", 0, -8)
    debugModeCheckbox.Text:SetText("Enable Test Mode")
    debugModeCheckbox:SetChecked(debugMode)
    debugModeCheckbox:SetScript("OnClick", function(self)
        debugMode = self:GetChecked()
        if debugMode then
            print("Test mode enabled.")
        else
            print("Test mode disabled.")
        end
    end)

    InterfaceOptions_AddCategory(panel)
end

-- Create the toggle button
local toggleButton = CreateFrame("Button", "ToggleButton", UIParent, "UIPanelButtonTemplate");
toggleButton:SetSize(80, 22); -- Width, Height
toggleButton:SetText("Closed"); -- Initial text
toggleButton:SetPoint("CENTER", 0, 200); -- Position on screen

-- Create textures for the button colors
toggleButton:SetNormalTexture("Interface\\Buttons\\WHITE8X8")
toggleButton:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")

-- Make the button moveable
toggleButton:SetMovable(true);
toggleButton:EnableMouse(true);
toggleButton:RegisterForDrag("LeftButton");
toggleButton:SetScript("OnDragStart", toggleButton.StartMoving);
toggleButton:SetScript("OnDragStop", toggleButton.StopMovingOrSizing);

-- Function to update the button text
local function toggleAddonEnabled()
    if addonEnabled then
        toggleButton:SetText("Open");
        toggleButton:GetNormalTexture():SetVertexColor(0, 1, 0, 1) -- Set color to green
    else
        toggleButton:SetText("Closed");
        toggleButton:GetNormalTexture():SetVertexColor(0.4, 0.4, 0.4, 1) -- Set color to gray
    end
end

-- Update the button text initially
toggleAddonEnabled()

-- Script to handle button clicks
toggleButton:SetScript("OnClick", function(self)
    addonEnabled = not addonEnabled; -- Toggle the state
    toggleAddonEnabled(); -- Update the button text

    if addonEnabled then
        print("Addon enabled.");
    else
        print("Addon disabled.");
    end
end)

-- Create the in game options panel for the addon
createOptionsPanel()

-- Slash command handler for toggling the addon on/off and debug/live modes
SLASH_TP1 = "/Tp"
SlashCmdList["TP"] = function(msg)
    local command, rest = msg:match("^(%S*)%s*(.-)$")
    if command == "on" then
        addonEnabled = true
        print("Addon enabled.")
        addonEnabledCheckbox:SetChecked(true)
    elseif command == "off" then
        addonEnabled = false
        print("Addon disabled.")
        addonEnabledCheckbox:SetChecked(false)
    elseif command == "msg" then
        inviteMessage = rest
        print("Invite message set to: " .. inviteMessage)
    elseif command == "debug" then
        if rest == "on" then
            debugMode = true
            print("Test mode enabled.")
        elseif rest == "off" then
            debugMode = false
            print("Test mode disabled.")
        else
            print("Usage: /Tp debug on/off - Enable or disable debug mode")
        end
    elseif command == "keywords" then
        local action, keywordType, keyword = rest:match("^(%S*)%s*(%S*)%s*(.-)$")
        if action and keywordType and keyword and keyword ~= "" then
            local keywordTable
            if keywordType == "intent" then
                keywordTable = intentKeywords
            elseif keywordType == "destination" then
                keywordTable = destinationKeywords
            elseif keywordType == "service" then
                keywordTable = serviceKeywords
            else
                print("Invalid keyword type. Use 'intent', 'destination', or 'service'.")
                return
            end
            if action == "add" then
                table.insert(keywordTable, keyword)
                print("Added keyword to " .. keywordType .. ": " .. keyword)
            elseif action == "remove" then
                for i, k in ipairs(keywordTable) do
                    if k == keyword then
                        table.remove(keywordTable, i)
                        print("Removed keyword from " .. keywordType .. ": " .. keyword)
                        break
                    end
                end
            else
                print("Invalid action. Use 'add' or 'remove'.")
            end
        else
            print("Usage: /Tp keywords add/remove intent/destination/service [keyword]")
        end
    elseif command == "cooldown" then
        local seconds = tonumber(rest)
        if seconds then
            inviteCooldown = seconds
            print("Invite cooldown set to " .. inviteCooldown .. " seconds.")
        else
            print("Usage: /Tp cooldown [seconds] - Set the invite cooldown period")
        end
    elseif command == "help" then
        print("Usage:")
        print("/Tp on - Enable the addon")
        print("/Tp off - Disable the addon")
        print("/Tp msg [message] - Set the invite message")
        print("/Tp debug on/off - Enable or disable debug mode")
        print("/Tp author - The creator")
        print("/Tp help - Show this help message")
        print("/Tp keywords add/remove intent/destination/service [keyword] - Add or remove a keyword")
        print("/Tp cooldown [seconds] - Set the invite cooldown period")
    elseif command == "author" then
        print("This addon was created by [Thic-Ashbringer EU].")
    else
        print("Invalid command. Type /Tp help for usage instructions.")
    end
end

-- Print message when the addon is loaded
print("Addon loaded. Type /Tp help for usage instructions.");