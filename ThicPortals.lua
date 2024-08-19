local AceGUI = LibStub("AceGUI-3.0")

-- Initialize saved variables
InviteMessage = "[Thic-Portals] Good day! I am creating a portal for you as we speak, please head over - I'm marked with a star."
InviteMessageWithoutDestination = "[Thic-Portals] Good day! Please specify a destination and I will create a portal for you."
TipMessage = "[Thic-Portals] Thank you for your tip, enjoy your journey - safe travels!"
NoTipMessage = "[Thic-Portals] Enjoy your journey and thanks for choosing Thic-Portals. Safe travels!"
ThicPortalsSaved = false
HideIcon = false
ApproachMode = false;
BanList = false
IntentKeywords = false
DestinationKeywords = false
ServiceKeywords = false

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
local fixedLabelWidth = 150 -- Set a fixed width for the labels

-- Invite and trade related data
local pendingInvites = {} -- Table to store pending invites with all relevant data
local inviteCooldown = 300 -- Cooldown period in seconds
local distanceInferringClose = 50;
local distanceInferringTravelled = 1000;
local consecutiveLeavesWithoutPayment = 0
local leaveWithoutPaymentThreshold = 2;
local currentTraderName = nil
local currentTraderRealm = nil
local currentTraderMoney = nil

-- Config panel
local optionsPanelHidden = true

-- Config checkboxes
local hideIconCheckbox = AceGUI:Create("CheckBox")
local approachModeCheckbox = AceGUI:Create("CheckBox");
local addonEnabled = false
local addonEnabledCheckbox = AceGUI:Create("CheckBox");
local soundEnabled = true
local soundEnabledCheckbox = AceGUI:Create("CheckBox");
local debugMode = false
local debugModeCheckbox = AceGUI:Create("CheckBox");

-- Our global frame
local frame = CreateFrame("Frame")

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
    print(string.format("|cff87CEEB[Thic-Portals]|r Total trades completed: %d", ThicPortalsSaved.totalTradesCompleted));
    print(string.format("|cff87CEEB[Thic-Portals]|r Total gold earned: %dg %ds %dc", math.floor(ThicPortalsSaved.totalGold / 10000), math.floor((ThicPortalsSaved.totalGold % 10000) / 100), ThicPortalsSaved.totalGold % 100));
    print(string.format("|cff87CEEB[Thic-Portals]|r Gold earned today: %dg %ds %dc", math.floor(ThicPortalsSaved.dailyGold / 10000), math.floor((ThicPortalsSaved.dailyGold % 10000) / 100), ThicPortalsSaved.dailyGold % 100));
end

local function resetDailyGoldIfNeeded()
    local currentDate = date("%Y-%m-%d");
    if ThicPortalsSaved.lastUpdateDate ~= currentDate then
        ThicPortalsSaved.dailyGold = 0;
        ThicPortalsSaved.lastUpdateDate = currentDate;

        print("|cff87CEEB[Thic-Portals]|r Daily gold counter reset for a new day.");
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

-- Function to check if a player is on the ban list
local function isPlayerBanned(player)
    for _, bannedPlayer in ipairs(BanList) do
        if bannedPlayer == player then
            return true
        end
    end
    return false
end

-- Function to check if there was a tip in the trade
local function checkTradeTip()
    print("|cff87CEEB[Thic-Portals]|r Checking trade tip...");

    local copper = tonumber(currentTraderMoney);
    local silver = math.floor((copper % 10000) / 100);
    local gold = math.floor(copper / 10000);
    local remainingCopper = copper % 100;

    print(string.format("|cff87CEEB[Thic-Portals]|r Received %dg %ds %dc from the trade.", gold, silver, remainingCopper));

    if gold > 0 or silver > 0 or remainingCopper > 0 then
        resetDailyGoldIfNeeded();
        addTipToRollingTotal(gold, silver, remainingCopper);
        incrementTradesCompleted();

        -- If the gold amount is higher than 8g, send a custom message via whisper saying "<3"
        if gold > 8 then
            SendChatMessage("<3", "WHISPER", nil, pendingInvites[currentTraderName].fullName)
        end

        -- If the gold amount is higher than 8g, send a custom message via whisper saying "<3"
        if gold == 69 or silver == 69 or remainingCopper == 69 then
            SendChatMessage("Nice (⌐□_□)", "WHISPER", nil, pendingInvites[currentTraderName].fullName)
        end

        -- If the gold amount is higher than 8g, send a custom message via whisper saying "<3"
        if gold == 4 and silver == 20 then
            SendChatMessage("420 blaze it (⌐□_□)-~", "WHISPER", nil, pendingInvites[currentTraderName].fullName)
        end

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
    local destinationPosition, destinationKeyword = findKeywordPosition(message, DestinationKeywords);
    if destinationPosition and pendingInvites[playerName] then
        pendingInvites[playerName].destination = destinationKeyword;
        if pendingInvites[playerName].destinationValue then
            pendingInvites[playerName].destinationValue:SetText(destinationKeyword);
        end
        print("|cff87CEEB[Thic-Portals]|r Updated destination for " .. playerName .. " to " .. destinationKeyword);
    end
end

-- Function to calculate the required height for text
local function calculateTextHeight(fontString, text, width)
    fontString:SetWidth(width)
    fontString:SetText(text)
    fontString:SetWordWrap(true)
    local height = fontString:GetStringHeight()
    return height
end

-- Updated function to create and display the ticket window
local function displayTicketWindow(sender, destination)
    -- Create the main frame
    local ticketFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    ticketFrame:SetSize(220, 160)  -- Initial size
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
    title:SetPoint("TOP", 0, -20)
    title:SetText("NEW TICKET")

    -- Create the sender label
    local senderLabel = ticketFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    senderLabel:SetPoint("TOPLEFT", 20, -50)
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
        pendingInvites[sender].ticketFrame = ticketFrame
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
    removeButton:SetEnabled(false)
    removeButton:SetScript("OnClick", function()
        UninviteUnit(sender)

        if debugMode then
            print("|cff87CEEB[Thic-Portals]|r " .. sender .. " has been removed from the party.")
        end

        pendingInvites[sender] = nil

        ticketFrame:Hide()
    end)

    local viewingMessage = false
    local originalMessageLabel = nil
    local originalMessageValue = nil

    -- Add an icon to the top left that allows us to switch to a "display original message mode"
    local iconButton = CreateFrame("Button", nil, ticketFrame)
    iconButton:SetSize(20, 20)
    iconButton:SetPoint("TOPLEFT", 12, -12)
    iconButton:SetNormalTexture("Interface\\Icons\\INV_Letter_15")
    iconButton:SetScript("OnClick", function()
        if not viewingMessage then
            viewingMessage = true

            -- Change the icon to a back icon that will return us to the original view on click
            iconButton:SetNormalTexture("Interface\\Icons\\achievement_bg_returnxflags_def_wsg")

            -- Hide the destination label and value
            destinationLabel:Hide()
            destinationValue:Hide()

            -- Hide the distance label
            distanceLabel:Hide()

            -- Hide the remove button
            removeButton:Hide()

            -- Create a label for the original message
            originalMessageLabel = ticketFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            originalMessageLabel:SetPoint("TOPLEFT", senderLabel, "BOTTOMLEFT", 0, -10)
            originalMessageLabel:SetText("Original Message:")

            -- Create a font string to calculate the height required
            originalMessageValue = ticketFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            local requiredHeight = calculateTextHeight(originalMessageValue, pendingInvites[sender].originalMessage, 180)

            -- Adjust the frame height based on the required height
            local newHeight = 160 - 40 + requiredHeight  -- Base height + required height
            ticketFrame:SetHeight(newHeight)

            -- Display the original message
            originalMessageValue:SetPoint("TOPLEFT", originalMessageLabel, "BOTTOMLEFT", 0, -10)
            originalMessageValue:SetWidth(180)
            originalMessageValue:SetJustifyH("LEFT")
            originalMessageValue:SetText(pendingInvites[sender].originalMessage)
            originalMessageValue:SetWordWrap(true)
        else
            viewingMessage = false

            -- Change the icon back to the original icon
            iconButton:SetNormalTexture("Interface\\Icons\\INV_Letter_15")

            -- Reset the frame size to its original dimensions
            ticketFrame:SetHeight(160)

            -- Show the destination label and value
            destinationLabel:Show()
            destinationValue:Show()

            -- Show the distance label
            distanceLabel:Show()

            -- Show the remove button
            removeButton:Show()

            -- Hide the original message label and value
            originalMessageLabel:Hide()
            originalMessageValue:Hide()
        end
    end)

    -- Variables for managing "Complete TICK" elements
    local ticker, completeText, tickIcon

    -- Function to show "Complete TICK" and hide unnecessary elements
    local function showCompleteTick()
        destinationLabel:Hide()
        destinationValue:Hide()
        distanceLabel:Hide()

        completeText = ticketFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        completeText:SetPoint("CENTER", -10, -10)
        completeText:SetText("Complete")

        tickIcon = ticketFrame:CreateTexture(nil, "ARTWORK")
        tickIcon:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-Ready")
        tickIcon:SetPoint("LEFT", completeText, "RIGHT", 5, 0)
        tickIcon:SetSize(20, 20)
    end

    -- Function to hide "Complete TICK"
    local function hideCompleteTick()
        if completeText then completeText:Hide() end
        if tickIcon then tickIcon:Hide() end
    end

    -- Handling icon button click to toggle between message panel and original panel
    iconButton:SetScript("OnClick", function()
        if not viewingMessage then
            viewingMessage = true
            iconButton:SetNormalTexture("Interface\\Icons\\achievement_bg_returnxflags_def_wsg")
            destinationLabel:Hide()
            destinationValue:Hide()
            distanceLabel:Hide()
            removeButton:Hide()

            -- Hide the "Complete TICK" if it's visible
            hideCompleteTick()

            originalMessageLabel = ticketFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            originalMessageLabel:SetPoint("TOPLEFT", senderLabel, "BOTTOMLEFT", 0, -10)
            originalMessageLabel:SetText("Original Message:")

            originalMessageValue = ticketFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            local requiredHeight = calculateTextHeight(originalMessageValue, pendingInvites[sender].originalMessage, 180)
            ticketFrame:SetHeight(160 - 40 + requiredHeight)
            originalMessageValue:SetPoint("TOPLEFT", originalMessageLabel, "BOTTOMLEFT", 0, -10)
            originalMessageValue:SetWidth(180)
            originalMessageValue:SetJustifyH("LEFT")
            originalMessageValue:SetText(pendingInvites[sender].originalMessage)
            originalMessageValue:SetWordWrap(true)
        else
            viewingMessage = false
            iconButton:SetNormalTexture("Interface\\Icons\\INV_Letter_15")
            ticketFrame:SetHeight(160)
            destinationLabel:Show()
            destinationValue:Show()
            distanceLabel:Show()
            removeButton:Show()
            if pendingInvites[sender].travelled then
                showCompleteTick()  -- Show the "Complete TICK" if applicable
            end
            originalMessageLabel:Hide()
            originalMessageValue:Hide()
        end
    end)

    -- Enable the remove button when the player has traveled
    ticker = C_Timer.NewTicker(1, function()
        if pendingInvites[sender] and pendingInvites[sender].travelled then
            removeButton:SetEnabled(true)
            ticker:Cancel()

            -- Update to show "Complete TICK"
            showCompleteTick()
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
            print("|cff87CEEB[Thic-Portals]|r Invite for " .. playerName .. " expired.");
            pendingInvites[playerName] = nil;
        end
    end)
end

-- Function to play a sound when a match is found
local function playMatchSound()
    if soundEnabled then
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

    ticker = C_Timer.NewTicker(1, function()
        if UnitInParty(sender) then
            if isPlayerWithinRange(sender, distanceInferringClose) then
                if not flagProximityReached then
                    print("|cff87CEEB[Thic-Portals]|r " .. sender .. " is nearby and might be taking the portal.")
                    flagProximityReached = true;
                end
            elseif flagProximityReached and not isPlayerWithinRange(sender, distanceInferringTravelled) then
                if debugMode then
                    print("|cff87CEEB[Thic-Portals]|r " .. sender .. " has moved away, assuming they took the portal.")
                end

                    pendingInvites[sender].travelled = true;
                ticker:Cancel(); -- Cancel the ticker when the player has moved away
            end
        else
            if pendingInvites[sender] and pendingInvites[sender].ticketFrame then
                pendingInvites[sender].ticketFrame:Hide()
            end
            pendingInvites[sender] = nil;
            ticker:Cancel(); -- Cancel the ticker if the player is no longer in the party
        end
    end)
end

-- Function that includes some fluff to the "invite a player" process
local function invitePlayer(sender)
    InviteUnit(sender)
    playMatchSound();
    print("|cff87CEEB[Thic-Portals]|r Invited " .. sender .. " to the group.")
end

-- Function to check if a player can be invited
local function canInvitePlayer(playerName)
    return not pendingInvites[playerName] or time() - pendingInvites[playerName].timestamp >= inviteCooldown
end

-- Function to create a pending invite entry
local function createPendingInvite(playerName, sender, message, destinationKeyword)
    pendingInvites[playerName] = {
        timestamp = time(),
        destination = destinationKeyword,
        originalMessage = message,
        hasJoined = false,
        hasPaid = false,
        travelled = false,
        fullName = sender
    }
    setSenderExpiryTimer(playerName)
end

-- Function to handle common phrase invites
local function handleCommonPhraseInvite(sender, playerName, message)
    if canInvitePlayer(playerName) then
        invitePlayer(sender)
        local _, destinationKeyword = findKeywordPosition(message, DestinationKeywords)
        createPendingInvite(playerName, sender, message, destinationKeyword)
    else
        print("Player " .. sender .. " is still on cooldown.")
    end
end

-- Function to handle destination-only invites
local function handleDestinationOnlyInvite(sender, playerName, message)
    local destinationPosition, destinationKeyword = findKeywordPosition(message, DestinationKeywords)
    if destinationPosition and canInvitePlayer(playerName) then
        invitePlayer(sender)
        createPendingInvite(playerName, sender, message, destinationKeyword)
    elseif destinationPosition then
        print("Player " .. sender .. " is still on cooldown.")
    end
end

-- Function to handle advanced keyword detection invites
local function handleAdvancedKeywordInvite(sender, playerName, message)
    local intentPosition, intentKeyword = findKeywordPosition(message, IntentKeywords)
    if intentPosition then
        local servicePosition, serviceKeyword = findKeywordPosition(message, ServiceKeywords)
        local destinationPosition, destinationKeyword = findKeywordPosition(message, DestinationKeywords)

        if servicePosition and servicePosition > intentPosition and canInvitePlayer(playerName) then
            invitePlayer(sender)
            createPendingInvite(playerName, sender, message, destinationKeyword)
        elseif servicePosition and servicePosition > intentPosition then
            print("Player " .. sender .. " is still on cooldown.")
        end
    end
end

-- Main function to handle invites and messages
local function handleInviteAndMessage(sender, playerName, message, destinationOnly)
    if isPlayerBanned(sender) then
        print("Player " .. sender .. " is on the ban list. No invite sent.")
        return
    end

    if containsCommonPhrase(message) then
        handleCommonPhraseInvite(sender, playerName, message)
    elseif destinationOnly then
        handleDestinationOnlyInvite(sender, playerName, message)
    else
        handleAdvancedKeywordInvite(sender, playerName, message)
    end

    -- Update pending invite destination if a destination keyword is found in the new message
    updatePendingInviteDestination(playerName, message)
end

-- Function to set the min width allowed of a frame
local function SetMinWidth(frame, minWidth)
    frame.frame:SetScript("OnSizeChanged", function(self, width, height)
        if width < minWidth then
            frame:SetWidth(minWidth)
        end
    end)
end

-- Create the toggle button
local toggleButton = CreateFrame("Button", "ToggleButton", UIParent, "UIPanelButtonTemplate");
toggleButton:SetSize(64, 64); -- Width, Height
toggleButton:SetPoint("CENTER", 0, 200); -- Position on screen

-- Disable the default draw layers to hide the button's default textures
toggleButton:DisableDrawLayer("BACKGROUND")
toggleButton:DisableDrawLayer("BORDER")
toggleButton:DisableDrawLayer("ARTWORK")

-- Make the button moveable
toggleButton:SetMovable(true);
toggleButton:EnableMouse(true);
toggleButton:RegisterForDrag("LeftButton");
toggleButton:SetScript("OnDragStart", toggleButton.StartMoving);
toggleButton:SetScript("OnDragStop", toggleButton.StopMovingOrSizing);

-- Create the background texture
local toggleButtonOverlayTexture = toggleButton:CreateTexture(nil, "OVERLAY")
toggleButtonOverlayTexture:SetTexture("Interface\\AddOns\\ThicPortals\\Media\\Logo\\thicportalsclosed.tga") -- Replace with the path to your image
toggleButtonOverlayTexture:SetAllPoints(toggleButton)
toggleButtonOverlayTexture:SetTexCoord(0, 1, 1, 0)

-- Function to update the button text and color of the interface configuration options
local function toggleAddonEnabled()
    if addonEnabled then
        toggleButtonOverlayTexture:SetTexture("Interface\\AddOns\\ThicPortals\\Media\\Logo\\thicportalsopen.tga") -- Replace with the path to your image
        addonEnabledCheckbox:SetValue(true)
        print("|cff87CEEB[Thic-Portals]|r The portal shop is open!")
    else
        toggleButtonOverlayTexture:SetTexture("Interface\\AddOns\\ThicPortals\\Media\\Logo\\thicportalsclosed.tga") -- Replace with the path to your image
        addonEnabledCheckbox:SetValue(false)
        print("|cff87CEEB[Thic-Portals]|r You closed the shop.")
    end
end

local function setOptionsPanelHiddenToFalse()
    optionsPanelHidden = true
end

local function addCheckbox(group, label, checkbox, initialValue, callback)
    -- Add spacer between checkboxes
    local spacer = AceGUI:Create("Label")
    spacer:SetWidth(30)
    group:AddChild(spacer)

    -- Create checkbox
    checkbox:SetLabel(label)
    checkbox:SetValue(initialValue)
    checkbox:SetCallback("OnValueChanged", callback)
    group:AddChild(checkbox)

    -- Add tiny vertical gap
    local tinyVerticalGap = AceGUI:Create("Label")
    tinyVerticalGap:SetText("")
    tinyVerticalGap:SetFullWidth(true)
    group:AddChild(tinyVerticalGap)
end

-- Helper function to create a label-value pair with a fixed label width and bold value
local function addLabelValuePair(labelText, valueText)
    local group = AceGUI:Create("SimpleGroup")
    group:SetFullWidth(true)
    group:SetLayout("Flow")

    local spacer = AceGUI:Create("Label")
    spacer:SetWidth(30)
    group:AddChild(spacer)

    local label = AceGUI:Create("Label")
    label:SetText(labelText)
    label:SetWidth(fixedLabelWidth)
    group:AddChild(label)

    local value = AceGUI:Create("Label")
    value:SetText("|cFFFFD700" .. valueText .. "|r") -- Make the value bold
    group:AddChild(value)

    return group
end

-- Helper function to create a label and editbox pair
local function addMessageMultiLineEditBox(labelText, messageVar, callback)
    local group = AceGUI:Create("SimpleGroup")
    group:SetFullWidth(true)
    group:SetLayout("Flow")

    local editBoxGroup = AceGUI:Create("SimpleGroup")
    editBoxGroup:SetFullWidth(true)
    editBoxGroup:SetLayout("Flow")

    local editBox = AceGUI:Create("MultiLineEditBox")
    editBox:SetText(messageVar)
    editBox:SetFullWidth(true)
    editBox:SetNumLines(3)
    editBox:SetLabel(labelText)
    editBox:SetCallback("OnEnterPressed", function(_, _, text)
        callback(text)
    end)
    editBoxGroup:AddChild(editBox)

    group:AddChild(editBoxGroup)

    return group
end

local optionsPanel
local function createOptionsPanel()
    if optionsPanel then
        return optionsPanel
    end

    -- Create a container frame
    local frame = AceGUI:Create("Frame")

    -- Add the frame as a global variable under the name `MyGlobalFrameName`
    _G["ThicPortalsOptionsPanel"] = frame.frame
    -- Register the global variable `MyGlobalFrameName` as a "special frame"
    -- so that it is closed when the escape key is pressed.
    tinsert(UISpecialFrames, "ThicPortalsOptionsPanel")

    frame:SetTitle("Thic-Portals Service Configuration")
    frame:SetCallback("OnClose", function(widget) setOptionsPanelHiddenToFalse() end)
    frame:SetLayout("Fill")
    frame:SetWidth(480)  -- Set initial width

    SetMinWidth(frame, 480)  -- Ensure the width never goes below 1200 pixels

    local largeVerticalGap = AceGUI:Create("Label")
    largeVerticalGap:SetText("\n\n")
    largeVerticalGap:SetFullWidth(true)

    local smallVerticalGap = AceGUI:Create("Label")
    smallVerticalGap:SetText("\n")
    smallVerticalGap:SetFullWidth(true)

    local tinyVerticalGap = AceGUI:Create("Label")
    tinyVerticalGap:SetText("")
    tinyVerticalGap:SetFullWidth(true)

    -- Create a scroll frame
    local scrollcontainer = AceGUI:Create("SimpleGroup")
    scrollcontainer:SetFullWidth(true)
    scrollcontainer:SetFullHeight(true)
    scrollcontainer:SetLayout("Fill")

    frame:AddChild(scrollcontainer)

    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Flow")
    scrollcontainer:AddChild(scroll)

    -- General Settings Title
    local generalSettingsTitle = AceGUI:Create("Label")
    generalSettingsTitle:SetText("|cFFFFD700General Settings|r")
    generalSettingsTitle:SetFontObject(GameFontNormalLarge)
    generalSettingsTitle:SetFullWidth(true)
    scroll:AddChild(generalSettingsTitle)
    scroll:AddChild(largeVerticalGap)

    -- Create a group for the checkboxes
    local checkboxGroup = AceGUI:Create("SimpleGroup")
    checkboxGroup:SetFullWidth(true)
    checkboxGroup:SetLayout("Flow")

    -- Addon On/Off Checkbox
    addCheckbox(checkboxGroup, "Enable Addon", addonEnabledCheckbox, addonEnabled, function(_, _, value)
        addonEnabled = value
        toggleAddonEnabled()
    end)

    -- Sound On/Off Checkbox
    addCheckbox(checkboxGroup, "Enable Sound", soundEnabledCheckbox, soundEnabled, function(_, _, value)
        soundEnabled = value
        if soundEnabled then
            print("|cff87CEEB[Thic-Portals]|r Sound enabled.")
        else
            print("|cff87CEEB[Thic-Portals]|r Sound disabled.")
        end
    end)

    -- Debug Mode Checkbox
    addCheckbox(checkboxGroup, "Enable Debug Mode", debugModeCheckbox, debugMode, function(_, _, value)
        debugMode = value
        if debugMode then
            print("|cff87CEEB[Thic-Portals]|r Test mode enabled.")
        else
            print("|cff87CEEB[Thic-Portals]|r Test mode disabled.")
        end
    end)

    -- Hide Icon Checkbox
    addCheckbox(checkboxGroup, "Hide Icon", hideIconCheckbox, HideIcon, function(_, _, value)
        HideIcon = value
        if HideIcon then
            print("|cff87CEEB[Thic-Portals]|r Open/Closed icon marked visible.")
            toggleButton:Hide()
        else
            print("|cff87CEEB[Thic-Portals]|r Open/Closed icon marked hidden.")
            toggleButton:Show()
        end
    end)

    -- Approach Mode Checkbox
    addCheckbox(checkboxGroup, "Approach Mode", approachModeCheckbox, ApproachMode, function(_, _, value)
        ApproachMode = value
        if ApproachMode then
            print("|cff87CEEB[Thic-Portals]|r Approach mode enabled.")
        else
            print("|cff87CEEB[Thic-Portals]|r Approach mode disabled.")
        end
    end)

    scroll:AddChild(checkboxGroup)

    scroll:AddChild(smallVerticalGap)
    scroll:AddChild(largeVerticalGap)

    -- Gold Stats Section
    local goldStatsTitle = AceGUI:Create("Label")
    goldStatsTitle:SetText("|cFFFFD700Gold Statistics|r")
    goldStatsTitle:SetFontObject(GameFontNormalLarge)
    goldStatsTitle:SetFullWidth(true)
    scroll:AddChild(goldStatsTitle)
    scroll:AddChild(largeVerticalGap)

    -- Add label-value pairs to the scroll frame
    local totalGoldLabel = addLabelValuePair(
        "Total Gold Earned:", string.format("%dg %ds %dc",
        math.floor(ThicPortalsSaved.totalGold / 10000),
        math.floor((ThicPortalsSaved.totalGold % 10000) / 100),
        ThicPortalsSaved.totalGold % 100
    ))
    scroll:AddChild(totalGoldLabel)
    scroll:AddChild(smallVerticalGap)

    local dailyGoldLabel = addLabelValuePair(
        "Gold Earned Today:", string.format("%dg %ds %dc",
        math.floor(ThicPortalsSaved.dailyGold / 10000),
        math.floor((ThicPortalsSaved.dailyGold % 10000) / 100),
        ThicPortalsSaved.dailyGold % 100
    ))
    scroll:AddChild(dailyGoldLabel)
    scroll:AddChild(smallVerticalGap)

    local totalTradesLabel = addLabelValuePair(
        "Total Trades Completed:",
        ThicPortalsSaved.totalTradesCompleted
    )
    scroll:AddChild(totalTradesLabel)
    scroll:AddChild(largeVerticalGap)
    scroll:AddChild(largeVerticalGap)

    -- Message Configuration Title
    local messageConfigTitle = AceGUI:Create("Label")
    messageConfigTitle:SetText("|cFFFFD700Message Configuration|r")
    messageConfigTitle:SetFontObject(GameFontNormalLarge)
    messageConfigTitle:SetFullWidth(true)
    scroll:AddChild(messageConfigTitle)
    scroll:AddChild(largeVerticalGap)

    -- Create a parent group for the message configuration
    local messageConfigGroup = AceGUI:Create("SimpleGroup")
    messageConfigGroup:SetFullWidth(true)
    messageConfigGroup:SetLayout("Flow")
    scroll:AddChild(messageConfigGroup)

    -- Invite Message
    local inviteMessageGroup = addMessageMultiLineEditBox("Invite Message:", InviteMessage, function(text)
        InviteMessage = text
        print("|cff87CEEB[Thic-Portals]|r Invite message updated.")
    end)
    messageConfigGroup:AddChild(inviteMessageGroup)
    messageConfigGroup:AddChild(smallVerticalGap)

    -- Invite Message Without Destination
    local inviteMessageWithoutDestinationGroup = addMessageMultiLineEditBox("Invite Message (No Destination):", InviteMessageWithoutDestination, function(text)
        InviteMessageWithoutDestination = text
        print("|cff87CEEB[Thic-Portals]|r Invite message without destination updated.")
    end)
    messageConfigGroup:AddChild(inviteMessageWithoutDestinationGroup)
    messageConfigGroup:AddChild(smallVerticalGap)

    -- Tip Message
    local tipMessageGroup = addMessageMultiLineEditBox("Tip Message:", TipMessage, function(text)
        TipMessage = text
        print("|cff87CEEB[Thic-Portals]|r Tip message updated.")
    end)
    messageConfigGroup:AddChild(tipMessageGroup)
    messageConfigGroup:AddChild(smallVerticalGap)

    -- No Tip Message
    local noTipMessageGroup = addMessageMultiLineEditBox("No Tip Message:", NoTipMessage, function(text)
        NoTipMessage = text
        print("|cff87CEEB[Thic-Portals]|r No tip message updated.")
    end)
    messageConfigGroup:AddChild(noTipMessageGroup)
    messageConfigGroup:AddChild(largeVerticalGap)

    -- Function to create keyword management section
    local function createKeywordSection(titleText, keywords, addFunc, removeFunc)
        local sectionTitle = AceGUI:Create("Label")
        sectionTitle:SetText(titleText)
        sectionTitle:SetFontObject(GameFontNormalLarge)
        sectionTitle:SetFullWidth(true)
        scroll:AddChild(sectionTitle)

        -- Create an InlineGroup for keyword management
        local keywordGroup = AceGUI:Create("InlineGroup")
        keywordGroup:SetFullWidth(true)
        keywordGroup:SetLayout("Flow")
        scroll:AddChild(keywordGroup)

        -- Add/Remove Keyword MultiLineEditBox
        local editBox = AceGUI:Create("EditBox")
        editBox:SetLabel("Add/Remove Keyword")
        editBox:SetWidth(200)
        editBox:DisableButton(true)
        editBox:SetCallback("OnEnterPressed", function(widget, event, text)
            if text ~= "" then
                addFunc(text)
                widget:SetText("")
            end
        end)
        keywordGroup:AddChild(editBox)

        -- Add Button
        local addButton = AceGUI:Create("Button")
        addButton:SetText("Add")
        addButton:SetWidth(100)
        addButton:SetCallback("OnClick", function()
            local keyword = editBox:GetText()
            if keyword ~= "" then
                addFunc(keyword)
                editBox:SetText("")
            end
        end)
        keywordGroup:AddChild(addButton)

        -- Remove Button
        local removeButton = AceGUI:Create("Button")
        removeButton:SetText("Remove")
        removeButton:SetWidth(100)
        removeButton:SetCallback("OnClick", function()
            local keyword = editBox:GetText()
            if keyword ~= "" then
                removeFunc(keyword)
                editBox:SetText("")
            end
        end)
        keywordGroup:AddChild(removeButton)

        -- Internal panel for user list with padding
        local userListGroup = AceGUI:Create("InlineGroup")
        userListGroup:SetFullWidth(true)
        userListGroup:SetLayout("Flow")
        userListGroup:SetAutoAdjustHeight(true)
        keywordGroup:AddChild(userListGroup)

        -- Add padding to the internal panel
        local userListContent = AceGUI:Create("SimpleGroup")
        userListContent:SetFullWidth(true)
        userListContent:SetLayout("List")
        userListContent:SetAutoAdjustHeight(true) -- Adjust height automatically
        userListGroup:AddChild(userListContent)

        -- Keywords Text Label
        local keywordsText = AceGUI:Create("Label")
        keywordsText:SetFullWidth(true)
        userListContent:AddChild(keywordsText)

        local function updateKeywordsText()
            local text = ""
            for _, keyword in ipairs(keywords) do
                text = text .. keyword .. "\n"
            end
            keywordsText:SetText(text)

            -- Ensure the layout is updated when content changes
            userListContent:DoLayout()
            userListGroup:DoLayout()
            scroll:DoLayout()
        end

        updateKeywordsText()

        -- Add to Keywords Function
        function addFunc(keyword)
            table.insert(keywords, keyword)
            updateKeywordsText()
            print("|cff87CEEB[Thic-Portals]|r " .. keyword .. " has been added.")
        end

        -- Remove from Keywords Function
        function removeFunc(keyword)
            for i, k in ipairs(keywords) do
                if k == keyword then
                    table.remove(keywords, i)
                    updateKeywordsText()
                    print("|cff87CEEB[Thic-Portals]|r " .. keyword .. " has been removed.")
                    break
                end
            end
        end
    end

    -- Creating Keyword Sections
    createKeywordSection("|cFFFFD700Ban List Management|r", BanList, addToBanListKeywords, removeFromBanListKeywords)
    scroll:AddChild(largeVerticalGap)
    createKeywordSection("|cFFFFD700Intent Keywords Management|r", IntentKeywords, addToIntentKeywords, removeFromIntentKeywords)
    scroll:AddChild(largeVerticalGap)
    createKeywordSection("|cFFFFD700Destination Keywords Management|r", DestinationKeywords, addToDestinationKeywords, removeFromDestinationKeywords)
    scroll:AddChild(largeVerticalGap)
    createKeywordSection("|cFFFFD700Service Keywords Management|r", ServiceKeywords, addToServiceKeywords, removeFromServiceKeywords)
    scroll:AddChild(largeVerticalGap)

    frame:Hide()

    optionsPanel = frame

    return optionsPanel
end

local function showOptionsPanel()
    if not optionsPanel then
        createOptionsPanel()
    end
    if debugMode then
        print("|cff87CEEB[Thic-Portals]|r Opening settings...");
    end
    optionsPanel:Show()
    optionsPanelHidden = false
end

local function hideOptionsPanel()
    if optionsPanel then
        optionsPanel:Hide()
        optionsPanelHidden = true
    end
end

-- Script to handle button clicks
toggleButton:SetScript("OnMouseUp", function(self, button)
    if button == "LeftButton" then
        addonEnabled = not addonEnabled; -- Toggle the state
        toggleAddonEnabled(); -- Update the button text

        if addonEnabled then
            print("|cff87CEEB[Thic-Portals]|r Addon enabled.");
        else
            print("|cff87CEEB[Thic-Portals]|r Addon disabled.");
        end
    elseif button == "RightButton" then

        if optionsPanelHidden then
            showOptionsPanel()
        else
            hideOptionsPanel()
        end
    end
end)

-- Initialize saved variables
local function initializeSavedVariables()
    if type(ThicPortalsSaved) ~= "table" then
        ThicPortalsSaved = {}
    end

    if type(BanList) ~= "table" then
        BanList = {}
    end

    if type(IntentKeywords) ~= "table" then
        IntentKeywords = {"wtb", "wtf", "want to buy", "looking for", "need", "seeking", "buying", "purchasing", "lf", "can anyone make", "can you make", "can anyone do", "can you do"}
    end

    if type(DestinationKeywords) ~= "table" then
        DestinationKeywords = {"darn", "darnassuss", "darnas", "darrna", "darnaas", "darnassus", "darnasuss", "dalaran", "darna", "darnasus", "sw", "stormwind", "if", "ironforge"}
    end

    if type(ServiceKeywords) ~= "table" then
        ServiceKeywords = {"portal", "port", "prt", "portla", "pportal", "protal", "pport", "teleport", "tp", "tele"}
    end

    ThicPortalsSaved.totalGold = ThicPortalsSaved.totalGold or 0
    ThicPortalsSaved.dailyGold = ThicPortalsSaved.dailyGold or 0
    ThicPortalsSaved.totalTradesCompleted = ThicPortalsSaved.totalTradesCompleted or 0
    ThicPortalsSaved.lastUpdateDate = ThicPortalsSaved.lastUpdateDate or date("%Y-%m-%d")
end

-- Event handler function
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "CHAT_MSG_SAY" or event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_YELL" or event == "CHAT_MSG_CHANNEL" then
        local destinationOnly = false
        local message, sender = ...
        local playerName = extractPlayerName(sender)

        -- If we are running approach mode, when we are handling say/whisper messages, we should evaluate destination only for a match
        if ApproachMode and (event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_SAY") then
            destinationOnly = true
        end

        -- Check if addon is enabled
        if addonEnabled and message and playerName then
            handleInviteAndMessage(sender, playerName, message, destinationOnly)
        end
    elseif event == "VARIABLES_LOADED" then
        -- Initialize saved variables
        initializeSavedVariables()

        -- Print gold info to the console
        printGoldInformation()

        -- Create the in-game options panel for the addon
        createOptionsPanel()

        -- Update the button text initially
        toggleAddonEnabled()

        -- If HideIcon is true, toggleButton should be set to hidden
        if HideIcon then
            toggleButton:Hide()
        end
    elseif event == "GROUP_ROSTER_UPDATE" then
        for sender, inviteData in pairs(pendingInvites) do
            if UnitInParty(sender) and not inviteData.hasJoined then
                inviteData.hasJoined = true

                FlashClientIcon() -- Flash the WoW icon in the taskbar

                displayTicketWindow(sender, inviteData.destination)

                if inviteData.destination then
                    SendChatMessage(InviteMessage, "WHISPER", nil, inviteData.fullName)
                else
                    SendChatMessage(InviteMessageWithoutDestination, "WHISPER", nil, inviteData.fullName)
                end

                markSelfWithStar() -- Mark yourself with a star

                watchForPlayerProximity(sender) -- Start tracking player proximity to infer teleportation
            elseif not UnitInParty(sender) and inviteData.hasJoined then
                if inviteData.ticketFrame then
                    inviteData.ticketFrame:Hide()
                end

                pendingInvites[sender] = nil

                if debugMode then
                    print("|cff87CEEB[Thic-Portals]|r " .. sender .. " has left the party and has been removed from tracking.")
                end

                if not inviteData.hasPaid then
                    -- Increment the counter for leaving without payment
                    consecutiveLeavesWithoutPayment = consecutiveLeavesWithoutPayment + 1
                    print("|cff87CEEB[Thic-Portals]|r Consecutive players who have left the party without payment: " .. consecutiveLeavesWithoutPayment)

                    -- Check if the counter reaches 3 and shut down the addon
                    if consecutiveLeavesWithoutPayment >= leaveWithoutPaymentThreshold then
                        addonEnabled = false
                        print("|cff87CEEB[Thic-Portals]|r Three people in a row left without payment - you are likely AFK. Shutting down the addon.")
                        toggleAddonEnabled()  -- Update the button text to reflect the shutdown
                    end
                end
            end
        end
    elseif event == "TRADE_SHOW" then
        -- Reset the counter when a trade is initiated
        consecutiveLeavesWithoutPayment = 0

        if debugMode then
            print("|cff87CEEB[Thic-Portals]|r Trade initiated. Resetting consecutive leaves without payment counter.")
        end

        -- NPC is currently the player you're trading
        currentTraderName, currentTraderRealm = UnitName("NPC", true); -- Store the name of the player when the trade window is opened

        if debugMode then
            print("|cff87CEEB[Thic-Portals]|r Current trader: " .. currentTraderName)
        end
    elseif event == "TRADE_MONEY_CHANGED" then
		currentTraderMoney = GetTargetTradeMoney();
	elseif event == "TRADE_ACCEPT_UPDATE" then
		currentTraderMoney = GetTargetTradeMoney();
    elseif event == "UI_INFO_MESSAGE" then
		local type, msg = ...;
		if (msg == ERR_TRADE_COMPLETE) then
            if currentTraderName then
                if pendingInvites[currentTraderName] then
                    local messageToSend = checkTradeTip() and TipMessage or NoTipMessage

                    -- Send them a thank you!
                    SendChatMessage(messageToSend, "WHISPER", nil, pendingInvites[currentTraderName].fullName)

                    -- Set a flag regarding their status
                    pendingInvites[currentTraderName].waitingToTravel = true
                    pendingInvites[currentTraderName].hasPaid = true

                    currentTraderName = nil
                    currentTraderMoney = nil
                    currentTraderRealm = nil
                else
                    if debugMode then
                        print("|cff87CEEB[Thic-Portals]|r No pending invite found for current trader, ignoring transaction.")
                    end
                end
            elseif debugMode then
                print("|cff87CEEB[Thic-Portals]|r No current trader found.")
            end
		end
    end
end)

-- Slash command handler for toggling the addon on/off and debug/live modes
SLASH_TP1 = "/Tp"
SlashCmdList["TP"] = function(msg)
    local command, rest = msg:match("^(%S*)%s*(.-)$")

    if command == "on" then
        addonEnabled = true
        print("|cff87CEEB[Thic-Portals]|r Addon enabled.")
        addonEnabledCheckbox:SetValue(true)
    elseif command == "off" then
        addonEnabled = false
        print("|cff87CEEB[Thic-Portals]|r Addon disabled.")
        addonEnabledCheckbox:SetValue(false)
    elseif command == "show" then
        toggleButton:Show()
        HideIcon = false
        hideIconCheckbox:SetValue(HideIcon)
        print("|cff87CEEB[Thic-Portals]|r Addon management icon displayed.")
    elseif command == "msg" then
        InviteMessage = rest
        print("|cff87CEEB[Thic-Portals]|r Invite message set to: " .. InviteMessage)
    elseif command == "debug" then
        if rest == "on" then
            debugMode = true
            print("|cff87CEEB[Thic-Portals]|r Test mode enabled.")
        elseif rest == "off" then
            debugMode = false
            print("|cff87CEEB[Thic-Portals]|r Test mode disabled.")
        else
            print("|cff87CEEB[Thic-Portals]|r Usage: /Tp debug on/off - Enable or disable debug mode")
        end
    elseif command == "keywords" then
        local action, keywordType, keyword = rest:match("^(%S*)%s*(%S*)%s*(.-)$")
        if action and keywordType and keyword and keyword ~= "" then
            local keywordTable
            if keywordType == "intent" then
                keywordTable = IntentKeywords
            elseif keywordType == "destination" then
                keywordTable = DestinationKeywords
            elseif keywordType == "service" then
                keywordTable = ServiceKeywords
            else
                print("|cff87CEEB[Thic-Portals]|r Invalid keyword type. Use 'intent', 'destination', or 'service'.")
                return
            end
            if action == "add" then
                table.insert(keywordTable, keyword)
                print("Added keyword to " .. keywordType .. ": " .. keyword)
            elseif action == "remove" then
                for i, k in ipairs(keywordTable) do
                    if k == keyword then
                        table.remove(keywordTable, i)
                        print("|cff87CEEB[Thic-Portals]|r Removed keyword from " .. keywordType .. ": " .. keyword)
                        break
                    end
                end
            else
                print("|cff87CEEB[Thic-Portals]|r Invalid action. Use 'add' or 'remove'.")
            end
        else
            print("|cff87CEEB[Thic-Portals]|r Usage: /Tp keywords add/remove intent/destination/service [keyword]")
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
        print("|cff87CEEB[Thic-Portals]|r Usage:")
        print("/Tp show - Show the addon button")
        print("/Tp on - Enable the addon")
        print("/Tp off - Disable the addon")
        print("/Tp msg [message] - Set the invite message")
        print("/Tp debug on/off - Enable or disable debug mode")
        print("/Tp author - The creator")
        print("/Tp help - Show this help message")
        print("/Tp keywords add/remove intent/destination/service [keyword] - Add or remove a keyword")
        print("/Tp cooldown [seconds] - Set the invite cooldown period")
    elseif command == "author" then
        print("|cff87CEEB[Thic-Portals]|r This addon was created by [Thic-Ashbringer EU].")
    else
        print("|cff87CEEB[Thic-Portals]|r Invalid command. Type /Tp help for usage instructions.")
    end
end

-- Print message when the addon is loaded
print("Thic-Portals loaded. Type /Tp help for usage instructions or head to settings.");