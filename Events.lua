-- Events.lua

local Config = _G.Config
local InviteTrade = _G.InviteTrade
local UI = _G.UI
local Utils = _G.Utils
local Events = {}

Events.pendingInvites = {} -- Table to store pending invites with all relevant data

local function printEvent(event)
    if Config.Settings and Config.Settings.debugMode then
        print("|cff87CEEB[Thic-Portals]|r " .. event .. " event fired.")
    end
end

-- Event handler function
function Events.onEvent(self, event, ...)
    if event == "VARIABLES_LOADED" then
        printEvent(event)

        -- Initialize saved variables
        Config.initializeSavedVariables()

        -- Print gold info to the console
        Utils.printGoldInformation()

        -- Create the in-game toggle button for the addon
        UI.createToggleButton()

        -- Create the in-game options panel for the addon
        UI.createOptionsPanel()

        return
    end

    -- If the addon is disabled, don't do anything
    if not Config.Settings.addonEnabled then
        return
    end

    if event == "CHAT_MSG_SAY" or event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_YELL" or event == "CHAT_MSG_CHANNEL" or event == "CHAT_MSG_PARTY" then
        printEvent(event)

        local args = { ... }

        if args[12] then
            local localizedClass, englishClass, localizedRace, englishRace, sex, name, realm = GetPlayerInfoByGUID(args[12])
            local message, nameAndServer = args[1], args[2]

            -- Check if addon is enabled
            if message and name then
                local destinationOnly = false

                -- If we are running approach mode, when we are handling say/whisper messages, we should evaluate destination only for a match
                if Config.Settings.ApproachMode and (event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_SAY") then
                    destinationOnly = true
                end

                -- Handle the invite and message logic
                InviteTrade.handleInviteAndMessage(nameAndServer, name, englishClass, message, destinationOnly)
            end
        end

    elseif event == "GROUP_ROSTER_UPDATE" then
        printEvent(event)

        for sender, inviteData in pairs(Events.pendingInvites) do
            if UnitInParty(sender) and not inviteData.hasJoined then
                inviteData.hasJoined = true

                FlashClientIcon() -- Flash the WoW icon in the taskbar

                UI.showTicketWindow(sender, inviteData.destination)

                if inviteData.destination then
                    SendChatMessage(Config.Settings.inviteMessage, "WHISPER", nil, inviteData.fullName)
                else
                    SendChatMessage(Config.Settings.inviteMessageWithoutDestination, "WHISPER", nil, inviteData.fullName)
                end

                -- If enableFoodWaterSupport is True, send a message with food and water stock
                if Config.Settings.enableFoodWaterSupport then
                    InviteTrade.sendFoodAndWaterStockMessage(inviteData.name, inviteData.class)
                end

                InviteTrade.markSelfWithStar() -- Mark yourself with a star
                InviteTrade.watchForPlayerProximity(sender) -- Start tracking player proximity to infer teleportation
            elseif not UnitInParty(sender) and inviteData.hasJoined then
                if inviteData.ticketFrame then
                    inviteData.ticketFrame:Hide()
                end

                Events.pendingInvites[sender] = nil

                if Config.Settings.debugMode then
                    print("|cff87CEEB[Thic-Portals]|r " .. sender .. " has left the party and has been removed from tracking.")
                end

                if not inviteData.hasPaid then
                    -- Increment the counter for leaving without payment
                    Events.handleConsecutiveLeavesWithoutPayment()
                end
            end
        end

    elseif event == "TRADE_SHOW" then
        printEvent(event)

        -- Reset the counter when a trade is initiated
        Events.resetConsecutiveLeavesWithoutPaymentCounter()

        -- Store the name of the player when the trade window is opened
        Events.storeCurrentTrader()

    elseif event == "TRADE_MONEY_CHANGED" then
        printEvent(event)

        Events.updateTradeMoney()

    elseif event == "TRADE_ACCEPT_UPDATE" then
        printEvent(event)

        Events.updateTradeMoney()

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if unit == "player" then
            local spellName = GetSpellInfo(spellID)
            for _, portalName in ipairs(Config.Portals) do
                if spellName:lower() == portalName:lower() then
                    if Config.Settings.debugMode then
                        print("|cff87CEEB[Thic-Portals]|r Portal to " .. spellName .. " successfully cast!")
                    end

                    Config.CurrentAlivePortals[spellName] = true

                    -- send just the location name
                    UI.setAllMatchingPortalButtonsToTrade(spellName)

                    -- Add a timer for a minute's time to remove the portal from the list
                    C_Timer.After(60, function()
                        Config.CurrentAlivePortals[spellName] = nil

                        UI.setAllMatchingTradeButtonsToPortal(spellName)
                    end)

                    break
                end
            end
        end

    elseif event == "UI_INFO_MESSAGE" then
        printEvent(event)

        local type, msg = ...
        if (msg == ERR_TRADE_COMPLETE) then
            Events.handleTradeComplete()
        end
    end
end

-- Function to handle consecutive leaves without payment
function Events.handleConsecutiveLeavesWithoutPayment()
    Config.Settings.consecutiveLeavesWithoutPayment = Config.Settings.consecutiveLeavesWithoutPayment + 1
    print("|cff87CEEB[Thic-Portals]|r Consecutive players who have left the party without payment: " .. Config.Settings.consecutiveLeavesWithoutPayment)

    if Config.Settings.consecutiveLeavesWithoutPayment >= Config.Settings.leaveWithoutPaymentThreshold then
        Config.Settings.addonEnabled = false
        print("|cff87CEEB[Thic-Portals]|r Three people in a row left without payment - you are likely AFK. Shutting down the addon.")
        if UI.addonEnabledCheckbox then
            UI.addonEnabledCheckbox:SetValue(false)
        end
    end
end

-- Function to reset the consecutive leaves without payment counter
function Events.resetConsecutiveLeavesWithoutPaymentCounter()
    Config.Settings.consecutiveLeavesWithoutPayment = 0
    if Config.Settings.debugMode then
        print("|cff87CEEB[Thic-Portals]|r Trade initiated. Resetting consecutive leaves without payment counter.")
    end
end

-- Function to store the current trader's information
function Events.storeCurrentTrader()
    Config.currentTraderName, Config.currentTraderRealm = UnitName("NPC", true)
    if Config.Settings.debugMode then
        print("|cff87CEEB[Thic-Portals]|r Current trader: " .. (Config.currentTraderName or "Unknown"))
    end
end

-- Function to update trade money
function Events.updateTradeMoney()
    Config.currentTraderMoney = GetTargetTradeMoney()
    if Config.Settings.debugMode then
        print("|cff87CEEB[Thic-Portals]|r Current trade money: " .. (Config.currentTraderMoney or "Unknown"))
    end
end

-- Function to handle trade completion
function Events.handleTradeComplete()
    if Config.currentTraderName then
        if Events.pendingInvites[Config.currentTraderName] then
            if InviteTrade.checkTradeTip() then
                -- Send them a thank you!
                SendChatMessage(Config.Settings.tipMessage, "WHISPER", nil, Events.pendingInvites[Config.currentTraderName].fullName)
            else
                SendChatMessage(Config.Settings.noTipMessage, "WHISPER", nil, Events.pendingInvites[Config.currentTraderName].fullName)
            end

            Events.pendingInvites[Config.currentTraderName].hasPaid = true
            Config.currentTraderName = nil
            Config.currentTraderMoney = nil
            Config.currentTraderRealm = nil
        else
            if Config.Settings.debugMode then
                print("|cff87CEEB[Thic-Portals]|r No pending invite found for current trader, ignoring transaction.")
            end
        end
    elseif Config.Settings.debugMode then
        print("|cff87CEEB[Thic-Portals]|r No current trader found.")
    end
end

_G.Events = Events

return Events