local AceGUI = LibStub("AceGUI-3.0")

local inviteMessage = "Good day! I am creating a portal for you as we speak, please head over - I'm marked with a star."
local inviteMessageWithoutDestination = "[Thic-Portals] Good day! Please specify a destination and I will create a portal for you."
local tipMessage = "[Thic-Portals] Thank you for your tip, enjoy your journey - safe travels!"
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

-- Config checkboxes
local addonEnabled = false
local addonEnabledCheckbox = false;
local soundEnabled = true
local soundEnabledCheckbox = true;
local debugMode = false
local debugModeCheckbox = false;

-- Initialize saved variables
ThicPortalsSaved = false
BanList = false
IntentKeywords = false
DestinationKeywords = false
ServiceKeywords = false

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
    removeButton:SetEnabled(false)  -- Initially disable the button
    removeButton:SetScript("OnClick", function()
        UninviteUnit(sender)

        if debugMode then
            print("|cff87CEEB[Thic-Portals]|r " .. sender .. " has been removed from the party.")
        end

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
            local destinationPosition, destinationKeyword = findKeywordPosition(message, DestinationKeywords);
            pendingInvites[playerName] = {timestamp = time(), destination = destinationKeyword, hasJoined = false, hasPaid = false, travelled = false, fullName = sender};
            setSenderExpiryTimer(playerName);
        else
            print("Player " .. sender .. " is still on cooldown.");
        end
    else
        -- Handle advanced keyword detection
        local intentPosition, intentKeyword = findKeywordPosition(message, IntentKeywords);
        if intentPosition then

            local servicePosition, serviceKeyword = findKeywordPosition(message, ServiceKeywords)
            local destinationPosition, destinationKeyword = findKeywordPosition(message, DestinationKeywords)

            -- Proceed only if intent is found first
            if (servicePosition and servicePosition > intentPosition) then
                -- Invite the player and create the portal as requested
                if not pendingInvites[playerName] or time() - pendingInvites[playerName].timestamp >= inviteCooldown then
                    invitePlayer(sender);
                    -- Record the time and track the invite as pending
                    pendingInvites[playerName] = {timestamp = time(), destination = destinationKeyword, hasJoined = false, hasPaid = false, travelled = false, fullName = sender}
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
        print("|cff87CEEB[Thic-Portals]|r Opening settings...");
        createOptionsPanel()
    end
end)

local function createOptionsPanel()
    -- Create a container frame
    local frame = AceGUI:Create("Frame")
    frame:SetTitle("Thic-Portals Service Configuration")
    frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
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

    -- Add spacer before checkboxes
    local spacer = AceGUI:Create("Label")
    spacer:SetWidth(30)
    checkboxGroup:AddChild(spacer)
    -- Addon On/Off Checkbox
    addonEnabledCheckbox = AceGUI:Create("CheckBox")
    addonEnabledCheckbox:SetLabel("Enable Addon")
    addonEnabledCheckbox:SetValue(addonEnabled)
    addonEnabledCheckbox:SetCallback("OnValueChanged", function(_, _, value)
        addonEnabled = value
        toggleAddonEnabled()
    end)
    checkboxGroup:AddChild(addonEnabledCheckbox)
    checkboxGroup:AddChild(tinyVerticalGap)

    -- Add spacer between checkboxes
    local spacerBetween2 = AceGUI:Create("Label")
    spacerBetween2:SetWidth(30)
    checkboxGroup:AddChild(spacerBetween2)
    -- Sound On/Off Checkbox
    soundEnabledCheckbox = AceGUI:Create("CheckBox")
    soundEnabledCheckbox:SetLabel("Enable Sound")
    soundEnabledCheckbox:SetValue(soundEnabled)
    soundEnabledCheckbox:SetCallback("OnValueChanged", function(_, _, value)
        soundEnabled = value
        if soundEnabled then
            print("|cff87CEEB[Thic-Portals]|r Sound enabled.")
        else
            print("|cff87CEEB[Thic-Portals]|r Sound disabled.")
        end
    end)
    checkboxGroup:AddChild(soundEnabledCheckbox)
    checkboxGroup:AddChild(tinyVerticalGap)

    -- Add spacer between checkboxes
    local spacerBetween3 = AceGUI:Create("Label")
    spacerBetween3:SetWidth(30)
    checkboxGroup:AddChild(spacerBetween3)
    -- Debug Mode Checkbox
    debugModeCheckbox = AceGUI:Create("CheckBox")
    debugModeCheckbox:SetLabel("Enable Debug Mode")
    debugModeCheckbox:SetValue(debugMode)
    debugModeCheckbox:SetCallback("OnValueChanged", function(_, _, value)
        debugMode = value
        if debugMode then
            print("|cff87CEEB[Thic-Portals]|r Test mode enabled.")
        else
            print("|cff87CEEB[Thic-Portals]|r Test mode disabled.")
        end
    end)
    checkboxGroup:AddChild(debugModeCheckbox)

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

    -- Helper function to create a label-value pair with a fixed label width and bold value
    local function createLabelValuePair(labelText, valueText)
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

    -- Add label-value pairs to the scroll frame
    local totalGoldLabel = createLabelValuePair("Total Gold Earned:", string.format("%dg %ds %dc", math.floor(ThicPortalsSaved.totalGold / 10000), math.floor((ThicPortalsSaved.totalGold % 10000) / 100), ThicPortalsSaved.totalGold % 100))
    scroll:AddChild(totalGoldLabel)
    scroll:AddChild(smallVerticalGap)

    local dailyGoldLabel = createLabelValuePair("Gold Earned Today:", string.format("%dg %ds %dc", math.floor(ThicPortalsSaved.dailyGold / 10000), math.floor((ThicPortalsSaved.dailyGold % 10000) / 100), ThicPortalsSaved.dailyGold % 100))
    scroll:AddChild(dailyGoldLabel)
    scroll:AddChild(smallVerticalGap)

    local totalTradesLabel = createLabelValuePair("Total Trades Completed:", ThicPortalsSaved.totalTradesCompleted)
    scroll:AddChild(totalTradesLabel)
    scroll:AddChild(largeVerticalGap)
    scroll:AddChild(largeVerticalGap)

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

        -- Add/Remove Keyword EditBox
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
        userListContent:SetWidth(200)
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
end

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
    if event == "CHAT_MSG_SAY" or event == "CHAT_MSG_YELL" or event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_CHANNEL" then
        local message, sender = ...
        local playerName = extractPlayerName(sender)

        -- Check if addon is enabled
        if addonEnabled and message and playerName then
            handleInviteAndMessage(sender, playerName, message)
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
    elseif event == "GROUP_ROSTER_UPDATE" then
        for sender, inviteData in pairs(pendingInvites) do
            if UnitInParty(sender) and not inviteData.hasJoined then
                inviteData.hasJoined = true
                displayTicketWindow(sender, inviteData.destination)

                if inviteData.destination then
                    SendChatMessage(inviteMessage, "WHISPER", nil, inviteData.fullName)
                else
                    SendChatMessage(inviteMessageWithoutDestination, "WHISPER", nil, inviteData.fullName)
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
                    local messageToSend = checkTradeTip() and tipMessage or noTipMessage

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
    elseif command == "msg" then
        inviteMessage = rest
        print("|cff87CEEB[Thic-Portals]|r Invite message set to: " .. inviteMessage)
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