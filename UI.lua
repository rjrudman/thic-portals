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
UI.addonEnabledCheckbox = AceGUI:Create("CheckBox");
UI.soundEnabledCheckbox = AceGUI:Create("CheckBox");
UI.debugModeCheckbox = AceGUI:Create("CheckBox");

-- Function to update the button text and color of the interface configuration options
local function toggleAddonEnabledState()
    Config.Settings.addonEnabled = not Config.Settings.addonEnabled -- Toggle the state

    if Config.Settings.addonEnabled then
        toggleButtonOverlayTexture:SetTexture("Interface\\AddOns\\ThicPortals\\Media\\Logo\\thicportalsopen.tga") -- Replace with the path to your image
        UI.addonEnabledCheckbox:SetValue(true)
        print("|cff87CEEB[Thic-Portals]|r The portal shop is open!")
    else
        toggleButtonOverlayTexture:SetTexture("Interface\\AddOns\\ThicPortals\\Media\\Logo\\thicportalsclosed.tga") -- Replace with the path to your image
        UI.addonEnabledCheckbox:SetValue(false)
        print("|cff87CEEB[Thic-Portals]|r You closed the shop.")
    end
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

-- Function to set the min width allowed of a frame
local function setMinWidth(frame, minWidth)
    frame.frame:SetScript("OnSizeChanged", function(self, width, height)
        if width < minWidth then
            frame:SetWidth(minWidth)
        end
    end)
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
            toggleAddonEnabledState() -- Update the button text
        elseif button == "RightButton" then
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

function UI.setIconSpell(portalButton, destination)
    local portal = Utils.getMatchingPortal(destination)

    -- Set up secure actions for casting the spell
    portalButton:SetAttribute("type", "spell")
    portalButton:SetAttribute("spell", portal.spellName)

    if portal.matched then
        print("Setting icon spell for " .. destination)
    end

    -- Set the icon texture for the portal spell
    UI.setIconSpellTexture(portalButton, portal)
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
    UI.setIconSpell(Events.pendingInvites[sender].portalButton, destination)

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

-- Function to create the options panel
function UI.createOptionsPanel()
    optionsPanel = AceGUI:Create("Frame")

    -- Add the frame as a global variable under the name `MyGlobalFrameName`
    _G["ThicPortalsOptionsPanel"] = optionsPanel.frame
    -- Register the global variable `MyGlobalFrameName` as a "special frame"
    -- so that it is closed when the escape key is pressed.
    tinsert(UISpecialFrames, "ThicPortalsOptionsPanel")

    optionsPanel:SetTitle("Thic-Portals Service Configuration")
    optionsPanel:SetCallback("OnClose", function(widget) optionsPanelHidden = true end)
    optionsPanel:SetLayout("Fill")
    optionsPanel:SetWidth(480)  -- Set initial width

    setMinWidth(optionsPanel, 480)  -- Ensure the width never goes below 1200 pixels

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

    optionsPanel:AddChild(scrollcontainer)

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
    addCheckbox(checkboxGroup, "Enable Addon", UI.addonEnabledCheckbox, Config.Settings.addonEnabled, function(_, _, value)
        toggleAddonEnabledState()
    end)

    -- Sound On/Off Checkbox
    addCheckbox(checkboxGroup, "Enable Sound", UI.soundEnabledCheckbox, Config.Settings.soundEnabled, function(_, _, value)
        Config.Settings.soundEnabled = value
        if Config.Settings.soundEnabled then
            print("|cff87CEEB[Thic-Portals]|r Sound enabled.")
        else
            print("|cff87CEEB[Thic-Portals]|r Sound disabled.")
        end
    end)

    -- Debug Mode Checkbox
    addCheckbox(checkboxGroup, "Enable Debug Mode", UI.debugModeCheckbox, Config.Settings.debugMode, function(_, _, value)
        Config.Settings.debugMode = value
        if Config.Settings.debugMode then
            print("|cff87CEEB[Thic-Portals]|r Debug mode enabled.")
        else
            print("|cff87CEEB[Thic-Portals]|r Debug mode disabled.")
        end
    end)

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
    end)

    -- Approach Mode Checkbox
    addCheckbox(checkboxGroup, "Approach Mode", UI.approachModeCheckbox, Config.Settings.ApproachMode, function(_, _, value)
        Config.Settings.ApproachMode = value
        if Config.Settings.ApproachMode then
            print("|cff87CEEB[Thic-Portals]|r Approach mode enabled.")
        else
            print("|cff87CEEB[Thic-Portals]|r Approach mode disabled.")
        end
    end)

    -- Enable Food and Water Support Checkbox
    -- addCheckbox(checkboxGroup, "Food and Water Support", UI.enableFoodWaterSupportCheckbox, Config.Settings.enableFoodWaterSupport, function(_, _, value)
    --     Config.Settings.enableFoodWaterSupport = value
    --     if Config.Settings.enableFoodWaterSupport then
    --         print("|cff87CEEB[Thic-Portals]|r Food and Water support enabled.")
    --     else
    --         print("|cff87CEEB[Thic-Portals]|r Food and Water support disabled.")
    --     end
    -- end)

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
    local totalGoldLabel = addLabelValuePair("Total Gold Earned:", string.format("%dg %ds %dc", 0, 0, 0))
    scroll:AddChild(totalGoldLabel)
    scroll:AddChild(smallVerticalGap)

    local dailyGoldLabel = addLabelValuePair("Gold Earned Today:", string.format("%dg %ds %dc", 0, 0, 0))
    scroll:AddChild(dailyGoldLabel)
    scroll:AddChild(smallVerticalGap)

    local totalTradesLabel = addLabelValuePair("Total Trades Completed:", Config.Settings.totalTradesCompleted)
    scroll:AddChild(totalTradesLabel)
    scroll:AddChild(largeVerticalGap)
    scroll:AddChild(largeVerticalGap)

    -- Function to draw gold statistics to the ticket frame
    function UI.drawGoldStatisticsToTicketFrame()
        -- Update the total gold label
        totalGoldLabel.children[3]:SetText(string.format(
            "%dg %ds %dc",
            math.floor(Config.Settings.totalGold / 10000),
            math.floor((Config.Settings.totalGold % 10000) / 100),
            Config.Settings.totalGold % 100
        ))

        -- Update the daily gold label
        dailyGoldLabel.children[3]:SetText(string.format(
            "%dg %ds %dc",
            math.floor(Config.Settings.dailyGold / 10000),
            math.floor((Config.Settings.dailyGold % 10000) / 100),
            Config.Settings.dailyGold % 100
        ))

        -- Update the total trades label
        totalTradesLabel.children[3]:SetText(
            Config.Settings.totalTradesCompleted
        )
    end

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
    createKeywordSection("|cFFFFD700Ban List Management|r", Config.Settings.BanList, addToBanListKeywords, removeFromBanListKeywords)
    scroll:AddChild(largeVerticalGap)
    createKeywordSection("|cFFFFD700Intent Keywords Management|r", Config.Settings.IntentKeywords, addToIntentKeywords, removeFromIntentKeywords)
    scroll:AddChild(largeVerticalGap)
    createKeywordSection("|cFFFFD700Destination Keywords Management|r", Config.Settings.DestinationKeywords, addToDestinationKeywords, removeFromDestinationKeywords)
    scroll:AddChild(largeVerticalGap)
    createKeywordSection("|cFFFFD700Service Keywords Management|r", Config.Settings.ServiceKeywords, addToServiceKeywords, removeFromServiceKeywords)
    scroll:AddChild(largeVerticalGap)

    -- Save the options panel reference in the config for other modules to use
    UI.optionsPanel = optionsPanel
end

-- Show the options panel
function UI.showOptionsPanel()
    -- If debug mode is enabled, print a message
    if Config.Settings.debugMode then
        if Config.Settings.optionsPanelHidden then
            print("Showing options panel.")
        end

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
        if Config.Settings.optionsPanelHidden then
            print("Hiding options panel.")
        end

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

_G.UI = UI

return UI