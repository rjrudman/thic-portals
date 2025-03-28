-- UI.lua

local Config = _G.Config
local Utils = _G.Utils

local UI = {}

local optionsPanel
local toggleButton
local toggleButtonOverlayTexture

local fixedLabelWidth = 150 -- Set a fixed width for the labels

local AceGUI = LibStub("AceGUI-3.0")  -- Use LibStub to load AceGUI

if not AceGUI then
    print("Error: AceGUI-3.0 is not loaded properly.")
    return
end

-- Initialize saved variables to Config (Version 1.3.0)
UI.hideIconCheckbox = AceGUI:Create("CheckBox")
UI.approachModeCheckbox = AceGUI:Create("CheckBox");
UI.enableFoodWaterSupportCheckbox = AceGUI:Create("CheckBox");
UI.disableSmartMatchingCheckbox = AceGUI:Create("CheckBox");
UI.removeRealmFromInviteCommandCheckbox = AceGUI:Create("CheckBox");
UI.addonEnabledCheckbox = AceGUI:Create("CheckBox");
UI.disableGlobalChannelsCheckbox = AceGUI:Create("CheckBox");
UI.disableAFKProtectionCheckbox = AceGUI:Create("CheckBox");
UI.soundEnabledCheckbox = AceGUI:Create("CheckBox");
UI.debugModeCheckbox = AceGUI:Create("CheckBox");

local function addCheckbox(group, label, checkbox, initialValue, callback, tooltipText)
    -- Add spacer between checkboxes
    local spacer = AceGUI:Create("Label")
    spacer:SetWidth(30)
    group:AddChild(spacer)

    -- Create checkbox
    checkbox:SetLabel(label)
    checkbox:SetValue(initialValue)
    checkbox:SetCallback("OnValueChanged", callback)
    checkbox:SetWidth(300)
    group:AddChild(checkbox)

    -- Add tooltip functionality
    if tooltipText then
        checkbox:SetCallback("OnEnter", function()
            GameTooltip:SetOwner(checkbox.frame, "ANCHOR_TOPRIGHT")
            GameTooltip:SetText(tooltipText, 1, 1, 1, true)
            GameTooltip:Show()
        end)

        checkbox:SetCallback("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

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

-- Helper function to create a label and small edit that only needs to support 6 number digits
local function addNumberEditBox(labelText, numberVar, callback)
    local group = AceGUI:Create("SimpleGroup")
    group:SetFullWidth(true)
    group:SetLayout("Flow")

    -- Add spacer between checkboxes
    local spacer = AceGUI:Create("Label")
    spacer:SetWidth(30)
    group:AddChild(spacer)

    -- Create a label element with the formatted copper value (0g, 0s, 0c) that updates after the user confirms a new numberVar value
    local valueLabel = AceGUI:Create("Label")
    valueLabel:SetText(Utils.formatCopperValue(numberVar) .. " each (20x " .. Utils.formatCopperValue(numberVar * 20) .. ")")
    valueLabel:SetWidth(100)

    -- Create an edit box for the number
    local editBox = AceGUI:Create("EditBox")
    editBox:SetText(numberVar)
    editBox:SetWidth(150)
    editBox:SetLabel(labelText)
    editBox:SetCallback("OnEnterPressed", function(_, _, text)
        local value = tonumber(text)
        callback(value)
        valueLabel:SetText(Utils.formatCopperValue(value) .. " each (20x " .. Utils.formatCopperValue(value * 20) .. ")")
    end)
    group:AddChild(editBox)

    -- Add spacer between checkboxes
    local spacer = AceGUI:Create("Label")
    spacer:SetWidth(10)
    group:AddChild(spacer)

    -- Finally add the value label
    group:AddChild(valueLabel)

    return group
end

-- Helper function to add price edit boxes for a category (food or water)
local function addPriceEditBoxes(group, category, prices)
    for itemName, price in pairs(prices) do
        local priceEditBox = addNumberEditBox(itemName .. ":", price, function(value)
            prices[itemName] = value
            print("|cff87CEEB[Thic-Portals]|r " .. itemName .. " price updated to " .. value .. ".")
        end)
        group:AddChild(priceEditBox)
    end
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

    -- Callback for when the text changes
    editBox:SetCallback("OnTextChanged", function(widget, _, text)
        if #text > 255 then
            -- Truncate the text to 255 characters
            widget:SetText(string.sub(text, 1, 255))
        end
    end)

    -- Callback for when Enter is pressed
    editBox:SetCallback("OnEnterPressed", function(_, _, text)
        if #text > 255 then
            text = string.sub(text, 1, 255) -- Ensure no overflow
        end
        callback(text)
    end)

    editBoxGroup:AddChild(editBox)
    group:AddChild(editBoxGroup)

    return group
end

-- Function to set the min width allowed of a frame
local function setMinWidth(frame, minWidth)
    frame.frame:SetScript("OnSizeChanged", function(self, width, height)
        if width < minWidth then
            frame:SetWidth(minWidth)
        end
    end)
end

-- Function to update the button text and color of the interface configuration options
function UI.toggleAddonEnabledState()
    Config.Settings.addonEnabled = not Config.Settings.addonEnabled -- Toggle the state

    if Config.Settings.addonEnabled then
        toggleButtonOverlayTexture:SetTexture("Interface\\AddOns\\ThicPortals\\Media\\Logo\\thicportalsopen.tga") -- Replace with the path to your image
        UI.addonEnabledCheckbox:SetValue(true)
        print("|cff87CEEB[Thic-Portals]|r The portal shop is open!")
    else
        toggleButtonOverlayTexture:SetTexture("Interface\\AddOns\\ThicPortals\\Media\\Logo\\thicportalsclosed.tga") -- Replace with the path to your image
        UI.addonEnabledCheckbox:SetValue(false)
        print("|cff87CEEB[Thic-Portals]|r You closed the shop.")

        -- Clear any tracked players and their data
        Events.pendingInvites = {}
    end
end

-- Function to create the toggle button
function UI.createToggleButton()
    toggleButton = CreateFrame("Button", "ToggleButton", UIParent, "UIPanelButtonTemplate")
    toggleButton:SetSize(64, 64) -- Width, Height

    -- Set the point using the saved position in the config or default to 0, 200
    toggleButton:SetPoint(
        Config.Settings.toggleButtonPosition.point or "CENTER",
        Config.Settings.toggleButtonPosition.x or 0,
        Config.Settings.toggleButtonPosition.y or 200
    )

    -- Disable the default draw layers to hide the button's default textures
    toggleButton:DisableDrawLayer("BACKGROUND")
    toggleButton:DisableDrawLayer("BORDER")
    toggleButton:DisableDrawLayer("ARTWORK")

    -- Make the button moveable
    toggleButton:SetMovable(true)
    toggleButton:EnableMouse(true)
    toggleButton:RegisterForDrag("LeftButton")
    toggleButton:SetScript("OnDragStart", toggleButton.StartMoving)
    toggleButton:SetScript("OnDragStop", toggleButton.StopMovingOrSizing)

    -- Create the background texture
    toggleButtonOverlayTexture = toggleButton:CreateTexture(nil, "OVERLAY")
    toggleButtonOverlayTexture:SetTexture("Interface\\AddOns\\ThicPortals\\Media\\Logo\\thicportalsclosed.tga") -- Replace with the path to your image
    toggleButtonOverlayTexture:SetAllPoints(toggleButton)
    toggleButtonOverlayTexture:SetTexCoord(0, 1, 1, 0)

    -- Script to handle button clicks
    toggleButton:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            UI.toggleAddonEnabledState() -- Update the button text
        elseif button == "RightButton" then
            -- If debug mode log the current options panel state
            if Config.Settings.debugMode then
                print("Options Panel Hidden: " .. tostring(Config.Settings.optionsPanelHidden))
            end

            if Config.Settings.optionsPanelHidden then
                UI.showOptionsPanel()
            else
                UI.hideOptionsPanel()
            end
        end
    end)

    -- Script to handle dragging
    toggleButton:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()

        -- Get the current position
        local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint()

        -- If debug mode is enabled, print the position
        if Config.Settings.debugMode then
            print("Icon moved to Point: " .. point)
            print("Icon moved to X: " .. xOfs)
            print("Icon moved to Y: " .. yOfs)
        end

        -- Save the position in the config
        Config.Settings.toggleButtonPosition = {
            point = point,
            x = xOfs,
            y = yOfs,
        }
    end)

    -- Save the button reference in the config for other modules to use
    UI.toggleButton = toggleButton

    -- If hideIcon is true, toggleButton should be set to hidden
    if Config.Settings.hideIcon then
        UI.toggleButton:Hide()
    end
end

-- Function to apply an icon texture representing the portal spell attributed to the button
function UI.setIconSpellTexture(portalButton, portal)
    if not portalButton.icon then
        -- Apply the icon texture to the button
        local icon = portalButton:CreateTexture(nil, "BACKGROUND")

        icon:SetAllPoints()

        portalButton.icon = icon
    end

    -- If portal.matched === false, the player's destination did not match any known portal so disable the button
    if portal.matched then
        -- Enable the button
        portalButton:SetEnabled(true)

        -- Get the icon texture for the portal spell
        local iconTexture = GetSpellTexture(portal.spellID)
        if iconTexture then
            -- Set the icon texture for the portal spell
            portalButton.icon:SetTexture(iconTexture)

            -- Set the icon to full color
            portalButton.icon:SetDesaturated(false)
        else
            print("Error: Could not fetch icon for spell name " .. portal.spellName)
        end
    else
        -- Disable the button
        portalButton:SetEnabled(false)

        -- Set the icon to a question mark
        portalButton.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        -- Grey it out
        portalButton.icon:SetDesaturated(true)
    end
end

function UI.setIconSpell(inviteData, destination)
    -- Save the matching portal details to the invite tracker
    inviteData.portal = Utils.getMatchingPortal(destination)

    -- Set up secure actions for casting the spell
    inviteData.portalButton:SetAttribute("type", "spell")
    inviteData.portalButton:SetAttribute("spell", inviteData.portal.spellName)

    if Config.Settings.debugMode and inviteData.portal.matched then
        print("Setting icon spell for " .. destination)
    end

    -- Set the icon texture for the portal spell
    UI.setIconSpellTexture(inviteData.portalButton, inviteData.portal)
end

function UI.setTradeIcon(inviteData)
    if not inviteData.portalButton.icon then
        -- Create the icon texture if it doesn't exist
        local icon = inviteData.portalButton:CreateTexture(nil, "BACKGROUND")
        icon:SetAllPoints()
        inviteData.portalButton.icon = icon
    end

    -- Update the icon texture to a "trade" icon
    inviteData.portalButton.icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01") -- Example trade icon
    inviteData.portalButton.icon:SetDesaturated(false)

    -- Enable the button and set the tooltip to inform the user that this button opens a trade window with the player
    inviteData.portalButton:SetEnabled(true)
    inviteData.portalButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Now would be the time to trade " .. inviteData.fullName)
        GameTooltip:Show()
    end)
    inviteData.portalButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
end

function UI.setAllMatchingPortalButtonsToTrade(spellName)
    for sender, inviteData in pairs(Events.pendingInvites) do
        if inviteData.portal and inviteData.portal.spellName and inviteData.portal.spellName:lower() == spellName:lower() and inviteData.portalButton then
            UI.setTradeIcon(inviteData)
        end
    end
end

function UI.setAllMatchingTradeButtonsToPortal(spellName)
    for sender, inviteData in pairs(Events.pendingInvites) do
        if inviteData.portal and inviteData.portal.spellName and inviteData.portal.spellName:lower() == spellName:lower() and inviteData.portalButton then
            UI.setIconSpell(inviteData, inviteData.destination)
        end
    end
end

-- Function to create and show the ticket window
function UI.showTicketWindow(sender, destination)
    -- Create the main frame
    local ticketFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    ticketFrame:SetSize(220, 250) -- Initial size
    ticketFrame:SetPoint("CENTER", UIParent, "CENTER", UIParent:GetWidth() * 0.3, 0)
    ticketFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    ticketFrame:SetBackdropColor(0, 0, 0, 1)
    ticketFrame:EnableMouse(true)
    ticketFrame:SetMovable(true)
    ticketFrame:RegisterForDrag("LeftButton")
    ticketFrame:SetScript("OnDragStart", ticketFrame.StartMoving)
    ticketFrame:SetScript("OnDragStop", ticketFrame.StopMovingOrSizing)

    -- Create the close button
    local closeButton = CreateFrame("Button", nil, ticketFrame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -5, -5)
    closeButton:SetScript("OnClick", function()
        ticketFrame:Hide()
    end)

    -- Create a container frame for labels
    local labelContainer = CreateFrame("Frame", nil, ticketFrame)
    labelContainer:SetSize(200, 100) -- Adjust size to fit labels
    labelContainer:SetPoint("TOP", ticketFrame, "TOP", 0, -10) -- Position inside ticketFrame

    -- Make the frame moveable
    local title = labelContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -20)
    title:SetText("NEW TICKET")

    -- Create the sender label
    local senderLabel = labelContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    senderLabel:SetPoint("TOPLEFT", 20, -50)
    senderLabel:SetText("Player:")

    -- Create the sender value
    local senderValue = labelContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    senderValue:SetPoint("LEFT", senderLabel, "RIGHT", 5, 0)
    senderValue:SetText(sender)

    -- Create the destination label
    local destinationLabel = labelContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    destinationLabel:SetPoint("TOPLEFT", senderLabel, "BOTTOMLEFT", 0, -10)
    destinationLabel:SetText("Destination:")

    -- Create the destination value
    local destinationValue = labelContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    destinationValue:SetPoint("LEFT", destinationLabel, "RIGHT", 5, 0)
    destinationValue:SetText(destination or "Requesting...")

    -- Create the distance label
    local distanceLabel = labelContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    distanceLabel:SetPoint("TOPLEFT", destinationLabel, "BOTTOMLEFT", 0, -10)
    distanceLabel:SetText("Distance: N/A")

    -- Update the distance label
    Utils.updateDistanceLabel(sender, distanceLabel)

    -- Create a button to start casting the portal creation spell that's relevant for this ticket (e.g., Portal: Stormwind)
    local portalButton = CreateFrame("Button", nil, ticketFrame, "SecureActionButtonTemplate")

    portalButton:SetSize(64, 64) -- Adjust size for icon display
    portalButton:SetPoint("TOP", labelContainer, "BOTTOM", 0, -20)

    -- attach it to the player object for reference
    Events.pendingInvites[sender].portalButton = portalButton

    -- Set the icon texture for the portal spell
    UI.setIconSpell(Events.pendingInvites[sender], destination)

    -- If the portal is already created (check the Config.CurrentAlivePortals table), set the icon to a trade icon
    if Events.pendingInvites[sender].portal and Events.pendingInvites[sender].portal.matched and Config.CurrentAlivePortals[Events.pendingInvites[sender].portal.spellName] then
        UI.setTradeIcon(Events.pendingInvites[sender])
    end

    -- Create the remove button
    local removeButton = CreateFrame("Button", nil, ticketFrame, "UIPanelButtonTemplate")
    removeButton:SetSize(80, 22)
    removeButton:SetPoint("TOP", portalButton, "BOTTOM", 0, -10)
    removeButton:SetText("Remove")
    removeButton:SetEnabled(false)
    removeButton:SetScript("OnClick", function()
        UninviteUnit(sender)
        if Config.Settings.debugMode then
            print("|cff87CEEB[Thic-Portals]|r " .. sender .. " has been removed from the party.")
        end
        Events.pendingInvites[sender] = nil
        ticketFrame:Hide()
    end)

    -- Variables for managing "Complete TICK" elements
    local ticker, completeText, tickIcon

    -- Function to show "Complete TICK" and hide unnecessary elements
    local function showCompleteTick()
        destinationLabel:Hide()
        destinationValue:Hide()
        distanceLabel:Hide()
        portalButton:Hide()

        completeText = ticketFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        completeText:SetPoint("CENTER", -10, -10)
        completeText:SetText("Complete")

        tickIcon = ticketFrame:CreateTexture(nil, "ARTWORK")
        tickIcon:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-Ready")
        tickIcon:SetPoint("LEFT", completeText, "RIGHT", 5, 0)
        tickIcon:SetSize(20, 20)

        ticketFrame:SetHeight(190)

        removeButton:ClearAllPoints()
        removeButton:SetPoint("TOP", completeText, "BOTTOM", 5, -30) -- Positioned below "Complete" with a gap
        removeButton:Show()
    end

    -- Function to hide "Complete TICK"
    local function hideCompleteTick()
        if completeText then completeText:Hide() end
        if tickIcon then tickIcon:Hide() end
    end

    local viewingMessage = false
    local originalMessageLabel = nil
    local originalMessageValue = nil

    -- Add an icon to the top left that allows us to switch to a "display original message mode"
    local iconButton = CreateFrame("Button", nil, ticketFrame)
    iconButton:SetSize(20, 20)
    iconButton:SetPoint("TOPLEFT", 12, -12)
    iconButton:SetNormalTexture("Interface\\Icons\\INV_Letter_15")
    iconButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")

    function toggleMessageView()
        if not viewingMessage then
            if Config.Settings.debugMode then
                print("Toggling to message view")
            end

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
            -- Hide the portal button
            portalButton:Hide()

            -- Create a label for the original message
            originalMessageLabel = ticketFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            originalMessageLabel:SetPoint("TOPLEFT", senderLabel, "BOTTOMLEFT", 0, -10)
            originalMessageLabel:SetText("Original Message:")

            if Events.pendingInvites[sender] then
                -- Create a font string to calculate the height required
                originalMessageValue = ticketFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                local requiredHeight = Utils.calculateTextHeight(originalMessageValue, Events.pendingInvites[sender].originalMessage, 180)

                -- Adjust the frame height based on the required height
                local newHeight = 180 - 40 + requiredHeight  -- Base height + required height
                ticketFrame:SetHeight(newHeight)

                -- Display the original message
                originalMessageValue:SetPoint("TOPLEFT", originalMessageLabel, "BOTTOMLEFT", 0, -10)
                originalMessageValue:SetWidth(180)
                originalMessageValue:SetJustifyH("LEFT")
                originalMessageValue:SetText(Events.pendingInvites[sender].originalMessage)
                originalMessageValue:SetWordWrap(true)
            end
        else
            if Config.Settings.debugMode then
                print("Toggling back to original view")
            end

            viewingMessage = false

            -- Change the icon back to the original icon
            iconButton:SetNormalTexture("Interface\\Icons\\INV_Letter_15")

            -- Reset the frame size to its original dimensions
            ticketFrame:SetHeight(250)

            -- Show the destination label and value
            destinationLabel:Show()
            destinationValue:Show()
            -- Show the distance label
            distanceLabel:Show()
            -- Show the remove button
            removeButton:Show()
            -- Show the portal button
            portalButton:Show()
            -- Hide the original message label and value
            originalMessageLabel:Hide()
            originalMessageValue:Hide()
        end
    end

    toggleMessageView()
    iconButton:SetScript("OnClick", toggleMessageView)

    -- Enable the remove button when the player has traveled
    ticker = C_Timer.NewTicker(1, function()
        if Events.pendingInvites[sender] and Events.pendingInvites[sender].travelled then
            -- If we're currently viewing the message screen, switch back to the original view
            if viewingMessage then
                toggleMessageView()
            end

            -- Update to show "Complete TICK"
            showCompleteTick()
            -- Enable the remove button
            removeButton:SetEnabled(true)
            -- Disable the icon button
            iconButton:SetEnabled(false)
            -- Cancel the ticker
            ticker:Cancel()
        end
    end, 180)

    -- Store reference to the destinationValue in Events.pendingInvites
    if Events.pendingInvites[sender] then
        Events.pendingInvites[sender].destinationValue = destinationValue
        Events.pendingInvites[sender].ticketFrame = ticketFrame
    end

    -- Show the frame
    ticketFrame:Show()
end

-- Function to draw gold statistics to the ticket frame
function UI.drawGoldStatisticsToTicketFrame()
    if UI.totalGoldLabel and UI.dailyGoldLabel and UI.totalTradesLabel then
        -- Update the total gold label
        UI.totalGoldLabel.children[3]:SetText(string.format(
            "%dg %ds %dc",
            math.floor(Config.Settings.totalGold / 10000),
            math.floor((Config.Settings.totalGold % 10000) / 100),
            Config.Settings.totalGold % 100
        ))

        -- Update the daily gold label
        UI.dailyGoldLabel.children[3]:SetText(string.format(
            "%dg %ds %dc",
            math.floor(Config.Settings.dailyGold / 10000),
            math.floor((Config.Settings.dailyGold % 10000) / 100),
            Config.Settings.dailyGold % 100
        ))

        -- Update the total trades label
        UI.totalTradesLabel.children[3]:SetText(
            Config.Settings.totalTradesCompleted
        )
    end
end

-- Function to create keyword management section
local function createKeywordSection(scroll, titleText, keywordTable, keywordTableType, description)
    local userListGroup = AceGUI:Create("InlineGroup")
    local userListContent = AceGUI:Create("SimpleGroup")
    local keywordsText = AceGUI:Create("Label")

    local function updateKeywordsText()
        local text = ""
        for _, keyword in ipairs(keywordTable) do
            text = text .. keyword .. "\n"
        end
        keywordsText:SetText(text)

        -- Ensure the layout is updated when content changes
        userListContent:DoLayout()
        userListGroup:DoLayout()
        scroll:DoLayout()
    end

    -- Add to Keywords Function
    local function addFunc(keyword)
        if keyword and keyword:trim() ~= "" then
            -- If it doesn't already exist
            if not Utils.keywordInTable(keyword, keywordTable) then
                table.insert(keywordTable, keyword)
                updateKeywordsText()
                print("|cff87CEEB[Thic-Portals]|r " .. keyword .. " has been added.")
            else -- If it already exists
                print("|cff87CEEB[Thic-Portals]|r " .. keyword .. " is already in the list.")
            end
        else
            print("|cff87CEEB[Thic-Portals]|r Cannot add an empty or invalid keyword.")
        end
    end

    -- Remove from Keywords Function
    local function removeFunc(keyword)
        if keyword and keyword:trim() ~= "" then
            for i, k in ipairs(keywordTable) do
                if k == keyword then
                    table.remove(keywordTable, i)
                    updateKeywordsText()
                    print("|cff87CEEB[Thic-Portals]|r " .. keyword .. " has been removed.")
                    break
                end
            end
        else
            print("|cff87CEEB[Thic-Portals]|r Cannot remove an empty or invalid keyword.")
        end
    end

    -- Create and add the title label
    local sectionTitle = AceGUI:Create("Label")
    sectionTitle:SetText(titleText)
    sectionTitle:SetFontObject(GameFontNormalLarge)
    sectionTitle:SetFullWidth(true)
    scroll:AddChild(sectionTitle)

    -- Add optional description if provided
    if description then
        local sectionDescription = AceGUI:Create("Label")
        sectionDescription:SetText(description)
        sectionDescription:SetFontObject(GameFontHighlightSmall)
        sectionDescription:SetFullWidth(true)
        scroll:AddChild(sectionDescription)
    end

    -- Create an InlineGroup for keyword management
    local keywordGroup = AceGUI:Create("InlineGroup")
    keywordGroup:SetFullWidth(true)
    keywordGroup:SetLayout("Flow")
    scroll:AddChild(keywordGroup)

    -- Add/Remove Keyword MultiLineEditBox
    local editBox = AceGUI:Create("EditBox")
    editBox:SetLabel("Add/Remove " .. (keywordTableType or "Keyword")) -- Use the passed keywordTableType or default to "Keyword"
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
    userListGroup:SetFullWidth(true)
    userListGroup:SetLayout("Flow")
    userListGroup:SetAutoAdjustHeight(true)
    keywordGroup:AddChild(userListGroup)

    -- Add padding to the internal panel
    userListContent:SetFullWidth(true)
    userListContent:SetLayout("List")
    userListContent:SetAutoAdjustHeight(true) -- Adjust height automatically
    userListGroup:AddChild(userListContent)

    -- Keywords Text Label
    keywordsText:SetFullWidth(true)
    userListContent:AddChild(keywordsText)

    updateKeywordsText()
end

-- Function to create the options panel
function UI.createOptionsPanel()
    optionsPanel = AceGUI:Create("Frame")

    -- Add the frame as a global variable under the name `MyGlobalFrameName`
    _G["ThicPortalsOptionsPanel"] = optionsPanel.frame
    -- Register the global variable `MyGlobalFrameName` as a "special frame"
    -- so that it is closed when the escape key is pressed.
    tinsert(UISpecialFrames, "ThicPortalsOptionsPanel")

    optionsPanel:SetTitle("Thic-Portals Service Configuration")
    optionsPanel:SetCallback("OnClose", function(widget) Config.Settings.optionsPanelHidden = true end)
    optionsPanel:SetLayout("Fill")
    optionsPanel:SetWidth(480)

    setMinWidth(optionsPanel, 480) -- Ensure the width never goes below the set value

    local largeVerticalGap = AceGUI:Create("Label")
    largeVerticalGap:SetText("\n\n")
    largeVerticalGap:SetFullWidth(true)

    local smallVerticalGap = AceGUI:Create("Label")
    smallVerticalGap:SetText("\n")
    smallVerticalGap:SetFullWidth(true)

    local tinyVerticalGap = AceGUI:Create("Label")
    tinyVerticalGap:SetText("")
    tinyVerticalGap:SetFullWidth(true)

    -- Create a scroll container
    local scrollcontainer = AceGUI:Create("SimpleGroup")
    scrollcontainer:SetFullWidth(true)
    scrollcontainer:SetFullHeight(true)
    scrollcontainer:SetLayout("Fill")
    optionsPanel:AddChild(scrollcontainer)

    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Flow")
    scrollcontainer:AddChild(scroll)

    -- Example content
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
    addCheckbox(checkboxGroup, "Enable Addon", UI.addonEnabledCheckbox, Config.Settings.addonEnabled, function(_, _, value)
        UI.toggleAddonEnabledState()
    end, "Enables or disables the addon functionality entirely.")

    -- Global Channels On/Off Checkbox
    addCheckbox(checkboxGroup, "Disable Global Channels", UI.disableGlobalChannelsCheckbox, Config.Settings.disableGlobalChannels, function(_, _, value)
        Config.Settings.disableGlobalChannels = value
        if Config.Settings.disableGlobalChannels then
            print("|cff87CEEB[Thic-Portals]|r Global channels disabled.")
        else
            print("|cff87CEEB[Thic-Portals]|r Global channels enabled.")
        end
    end, "Enables or disables the addon from listening to global channels for requests.")

    -- Approach Mode Checkbox
    addCheckbox(checkboxGroup, "Approach Mode", UI.approachModeCheckbox, Config.Settings.ApproachMode, function(_, _, value)
        Config.Settings.ApproachMode = value
        if Config.Settings.ApproachMode then
            print("|cff87CEEB[Thic-Portals]|r Approach mode enabled.")
        else
            print("|cff87CEEB[Thic-Portals]|r Approach mode disabled.")
        end
    end, "When enabled, the addon will require only a destination value to be provided in either a say/whisper.")

    -- Enable Food and Water Support Checkbox
    addCheckbox(checkboxGroup, "Food and Water Support", UI.enableFoodWaterSupportCheckbox, Config.Settings.enableFoodWaterSupport, function(_, _, value)
        Config.Settings.enableFoodWaterSupport = value
        if Config.Settings.enableFoodWaterSupport then
            print("|cff87CEEB[Thic-Portals]|r Food and Water support enabled.")
        else
            print("|cff87CEEB[Thic-Portals]|r Food and Water support disabled.")
        end
    end, "Enables or disables the ability to sell food and water items through the portal service. Food and water will be advertised to relevant customers depending on stock levels.")

    -- Disable smart matching and use only common phrase matching
    addCheckbox(checkboxGroup, "Only Use Common Phrase Matching", UI.disableSmartMatchingCheckbox, Config.Settings.disableSmartMatching, function(_, _, value)
        Config.Settings.disableSmartMatching = value
        if Config.Settings.disableSmartMatching then
            print("|cff87CEEB[Thic-Portals]|r Smart matching disabled.")
        else
            print("|cff87CEEB[Thic-Portals]|r Smart matching enabled.")
        end
    end, "Disables advanced smart matching algorithms and only uses the predefined common phrases to match requests (configurable below).")

    -- Don't use realm when inviting
    addCheckbox(checkboxGroup, "Remove Realm Affix From Invite Command", UI.removeRealmFromInviteCommandCheckbox, Config.Settings.removeRealmFromInviteCommand, function(_, _, value)
        Config.Settings.removeRealmFromInviteCommand = value
        if Config.Settings.removeRealmFromInviteCommand then
            print("|cff87CEEB[Thic-Portals]|r Smart matching disabled.")
        else
            print("|cff87CEEB[Thic-Portals]|r Smart matching enabled.")
        end
    end, "When enabled, removes the realm name e.g. '-Ashbringer' from invite commands, making invites suitable for certain single realm servers.")

    -- AFK Protection Checkbox
    addCheckbox(checkboxGroup, "Disable AFK Protection", UI.disableAFKProtectionCheckbox, Config.Settings.disableAFKProtection, function(_, _, value)
        Config.Settings.disableAFKProtection = value
        if Config.Settings.disableAFKProtection then
            print("|cff87CEEB[Thic-Portals]|r AFK protection disabled.")
        else
            print("|cff87CEEB[Thic-Portals]|r AFK protection enabled.")
        end
    end, "Disables the AFK protection feature which is in place to prevent potentially over-inviting players if the user forgets the addon is running. Two players in a row leaving the party without payment triggers shop close.")

    -- Hide Icon Checkbox
    addCheckbox(checkboxGroup, "Hide Icon", UI.hideIconCheckbox, Config.Settings.hideIcon, function(_, _, value)
        Config.Settings.hideIcon = value
        if Config.Settings.hideIcon then
            print("|cff87CEEB[Thic-Portals]|r Open/Closed icon marked visible.")
            toggleButton:Hide()
        else
            print("|cff87CEEB[Thic-Portals]|r Open/Closed icon marked hidden.")
            toggleButton:Show()
        end
    end, "Hides or shows the toggle button on the screen. You can use '/Tp show' to reveal the hidden icon again.")

    -- Sound On/Off Checkbox
    addCheckbox(checkboxGroup, "Enable Sound", UI.soundEnabledCheckbox, Config.Settings.soundEnabled, function(_, _, value)
        Config.Settings.soundEnabled = value
        if Config.Settings.soundEnabled then
            print("|cff87CEEB[Thic-Portals]|r Sound enabled.")
        else
            print("|cff87CEEB[Thic-Portals]|r Sound disabled.")
        end
    end, "Enables or disables sound notifications.")

    -- Debug Mode Checkbox
    addCheckbox(checkboxGroup, "Enable Debug Mode", UI.debugModeCheckbox, Config.Settings.debugMode, function(_, _, value)
        Config.Settings.debugMode = value
        if Config.Settings.debugMode then
            print("|cff87CEEB[Thic-Portals]|r Debug mode enabled.")
        else
            print("|cff87CEEB[Thic-Portals]|r Debug mode disabled.")
        end
    end, "Toggles debug mode for additional console logging.")

    -- Create a label for the food and water prices
    scroll:AddChild(checkboxGroup)
    scroll:AddChild(largeVerticalGap)

    -- Create a group for food and water prices
    local foodWaterPricesGroup = AceGUI:Create("SimpleGroup")
    foodWaterPricesGroup:SetFullWidth(true)
    foodWaterPricesGroup:SetLayout("Flow")

    -- Create a title for the food and water prices
    local foodWaterPricesTitle = AceGUI:Create("Label")
    foodWaterPricesTitle:SetText("|cFFFFD700Food and Water Prices|r")
    foodWaterPricesTitle:SetFontObject(GameFontNormalLarge)
    foodWaterPricesTitle:SetFullWidth(true)
    scroll:AddChild(foodWaterPricesTitle)
    scroll:AddChild(smallVerticalGap)

    -- Create a description for the food and water prices
    local foodWaterPricesDescription = AceGUI:Create("Label")
    foodWaterPricesDescription:SetText("Set the prices for food and water in copper.")
    foodWaterPricesDescription:SetFontObject(GameFontHighlightSmall)
    foodWaterPricesDescription:SetFullWidth(true)
    scroll:AddChild(foodWaterPricesDescription)
    scroll:AddChild(largeVerticalGap)

    -- Add price edit boxes for food and water
    addPriceEditBoxes(foodWaterPricesGroup, "Food", Config.Settings.prices.food)
    addPriceEditBoxes(foodWaterPricesGroup, "Water", Config.Settings.prices.water)

    -- Add the group to the scroll frame
    scroll:AddChild(foodWaterPricesGroup)

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
    UI.totalGoldLabel = addLabelValuePair("Total Gold Earned:", string.format("%dg %ds %dc", 0, 0, 0))
    scroll:AddChild(UI.totalGoldLabel)
    scroll:AddChild(smallVerticalGap)

    UI.dailyGoldLabel = addLabelValuePair("Gold Earned Today:", string.format("%dg %ds %dc", 0, 0, 0))
    scroll:AddChild(UI.dailyGoldLabel)
    scroll:AddChild(smallVerticalGap)

    UI.totalTradesLabel = addLabelValuePair("Total Trades Completed:", Config.Settings.totalTradesCompleted)
    scroll:AddChild(UI.totalTradesLabel)
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
    local inviteMessageGroup = addMessageMultiLineEditBox("Invite Message:", Config.Settings.inviteMessage, function(text)
        Config.Settings.inviteMessage = text
        print("|cff87CEEB[Thic-Portals]|r Invite message updated.")
    end)
    messageConfigGroup:AddChild(inviteMessageGroup)
    messageConfigGroup:AddChild(smallVerticalGap)

    -- Invite Message Without Destination
    local inviteMessageWithoutDestinationGroup = addMessageMultiLineEditBox("Invite Message (No Destination):", Config.Settings.inviteMessageWithoutDestination, function(text)
        Config.Settings.inviteMessageWithoutDestination = text
        print("|cff87CEEB[Thic-Portals]|r Invite message without destination updated.")
    end)
    messageConfigGroup:AddChild(inviteMessageWithoutDestinationGroup)
    messageConfigGroup:AddChild(smallVerticalGap)

    -- Tip Message
    local tipMessageGroup = addMessageMultiLineEditBox("Tip Message:", Config.Settings.tipMessage, function(text)
        Config.Settings.tipMessage = text
        print("|cff87CEEB[Thic-Portals]|r Tip message updated.")
    end)
    messageConfigGroup:AddChild(tipMessageGroup)
    messageConfigGroup:AddChild(smallVerticalGap)

    -- No Tip Message
    local noTipMessageGroup = addMessageMultiLineEditBox("No Tip Message:", Config.Settings.noTipMessage, function(text)
        Config.Settings.noTipMessage = text
        print("|cff87CEEB[Thic-Portals]|r No tip message updated.")
    end)
    messageConfigGroup:AddChild(noTipMessageGroup)
    messageConfigGroup:AddChild(largeVerticalGap)

    -- Creating Keyword Sections
    createKeywordSection(scroll, "|cFFFFD700Any Keyword Ban List Management|r", Config.Settings.KeywordBanList, "Keyword", "If the addon matches one of these keywords or phrases in any evaluated message, it will ignore it. This is an exact match by default, to use a partial match where the keyword exists within another word, wrap the keyword in '%' (e.g. %keyword%).")
    scroll:AddChild(largeVerticalGap)
    createKeywordSection(scroll, "|cFFFFD700Common Phrases Management|r", Config.Settings.commonPhrases, "Common Phrase", "Common Phrases are the first compared list of terms before any other keyword matching occurs. The only way to send an automated invite in this scenario is to match one of the below phrases. This is an exact match by default, but it may be contained in a sentence.")
    scroll:AddChild(largeVerticalGap)
    createKeywordSection(scroll, "|cFFFFD700Intent Keywords Management|r", Config.Settings.IntentKeywords, "Intent", "Intent is used to match the player's intent to trade or request a service (e.g. wtb, need). Exact match only.")
    scroll:AddChild(largeVerticalGap)
    createKeywordSection(scroll, "|cFFFFD700Destination Keywords Management|r", Config.Settings.DestinationKeywords, "Destination", "Destination is used to match the player's intended destination (e.g. darna, if). Exact match only.")
    scroll:AddChild(largeVerticalGap)
    createKeywordSection(scroll, "|cFFFFD700Service Keywords Management|r", Config.Settings.ServiceKeywords, "Service", "Service is used to match the player's intended service (e.g. portal, tp). Exact match only.")
    scroll:AddChild(largeVerticalGap)
    createKeywordSection(scroll, "|cFFFFD700Player Ban List Management|r", Config.Settings.BanList, "Player", "The addon will scan each message and discard any message from a player in this list. Enter values in the format 'Player-Realm'. Exact match only.")
    scroll:AddChild(largeVerticalGap)

    -- Save the options panel reference in the config for other modules to use
    UI.optionsPanel = optionsPanel
end

-- Show the options panel
function UI.showOptionsPanel()
    -- If debug mode is enabled, print a message
    if Config.Settings.debugMode then
        print("|cff87CEEB[Thic-Portals]|r Showing options panel.")
    end

    if not optionsPanel then
        UI.createOptionsPanel()
    else
        UI.drawGoldStatisticsToTicketFrame()
    end

    optionsPanel:Show()

    Config.Settings.optionsPanelHidden = false
end

-- Hide the options panel
function UI.hideOptionsPanel()
    -- If debug mode is enabled, print a message
    if Config.Settings.debugMode then
        print("|cff87CEEB[Thic-Portals]|r Hiding options panel.")
    end

    if optionsPanel then
        optionsPanel:Hide()

        Config.Settings.optionsPanelHidden = true
    end
end

-- Function to show a food and water request in the UI
function UI.showFoodWaterRequest(sender, foodRequested, waterRequested)
    local message = ""
    local iconPath = ""

    if foodRequested and waterRequested then
        message = "Food and Water requested by " .. sender
        iconPath = "Interface\\Icons\\INV_Misc_Food_15" -- Example icon path
    elseif foodRequested then
        message = "Food requested by " .. sender
        iconPath = "Interface\\Icons\\INV_Misc_Food_14"
    elseif waterRequested then
        message = "Water requested by " .. sender
        iconPath = "Interface\\Icons\\INV_Drink_04"
    end

    -- Display the message and icon
    print(message)
    -- Code to display the icon in the UI (e.g., create a frame and set the icon texture)
end

-- Function to show the toggle button
function UI.showToggleButton()
    toggleButton:Show()
    Config.Settings.optionsPanelHidden = true

    Config.Settings.hideIcon = false
    UI.hideIconCheckbox:SetValue(false)
end

-- Function to reset the position of the toggle button back to default
function UI.resetToggleButtonPosition()
    Config.Settings.toggleButtonPosition = {
        point = "CENTER",
        x = 0,
        y = 200
    }

    toggleButton:ClearAllPoints()
    toggleButton:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
end

_G.UI = UI

return UI