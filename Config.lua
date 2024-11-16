-- Config.lua

local Config = {}

local AceGUI = LibStub("AceGUI-3.0")  -- Use LibStub to load AceGUI

if not AceGUI then
    print("Error: AceGUI-3.0 is not loaded properly.")
    return
end

ThicPortalsSaved = false

-- Initialize saved variables (Version 1.2.2)
InviteMessage = false
InviteMessageWithoutDestination = false
TipMessage = false
NoTipMessage = false
-- List variables (Version 1.2.2)
BanList = false
ApproachMode = false
IntentKeywords = false
DestinationKeywords = false
ServiceKeywords = false
-- General settings (Version 1.2.2)
addonEnabled = false
soundEnabled = true
debugMode = false
hideIcon = false
-- Variables for gold tracking (Version 1.2.2)
totalGold = 0
dailyGold = 0
totalTradesCompleted = 0
lastUpdateDate = date("%Y-%m-%d")

Config.currentTraderName = nil
Config.currentTraderRealm = nil
Config.currentTraderMoney = nil

-- Define default settings - these will be used if the saved variables are not found
ThicPortalSettings = {
    totalGold = 0,
    dailyGold = 0,
    totalTradesCompleted = 0,
    lastUpdateDate = date("%Y-%m-%d"),

    BanList = {},

    IntentKeywords = {
        "wtb", "wtf", "want to buy", "looking for", "need", "seeking",
        "buying", "purchasing", "lf", "can anyone make", "can you make",
        "can anyone do", "can you do"
    },
    DestinationKeywords = {
        "darn", "darnassuss", "darnas", "darrna", "darnaas",
        "darnassus", "darnasuss", "dalaran", "darna", "darnasus",
        "sw", "stormwind", "if", "ironforge"
    },
    ServiceKeywords = {
        "portal", "port", "prt", "portla", "pportal",
        "protal", "pport", "teleport", "tp", "tele"
    },

    inviteMessage = "[Thic-Portals] Good day! I am creating a portal for you as we speak, please head over - I'm marked with a star.",
    inviteMessageWithoutDestination = "[Thic-Portals] Good day! Please specify a destination and I will create a portal for you.",
    tipMessage = "[Thic-Portals] Thank you for your tip, enjoy your journey - safe travels!",
    noTipMessage = "[Thic-Portals] Enjoy your journey and thanks for choosing Thic-Portals. Safe travels!",

    commonPhrases = {
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
    },

    inviteCooldown = 300,
    distanceInferringClose = 50,
    distanceInferringTravelled = 1000,
    consecutiveLeavesWithoutPayment = 0,
    leaveWithoutPaymentThreshold = 2,

    addonEnabled = false,
    soundEnabled = true,
    debugMode = false,
    approachMode = false,
    optionsPanelHidden = true,
    hideIcon = false,

    toggleButtonPosition = {
        point = "CENTER",
        x = 0,
        y = 200
    }
}

-- Initialize saved variables
function Config.initializeSavedVariables()
    -- Define default settings
    Config.Settings = ThicPortalSettings

    if type(ThicPortalsSaved) ~= "table" then
        print("ThicPortalsSaved is not a table. Initializing.")

        ThicPortalsSaved = {}
    else
        for key, value in pairs(ThicPortalsSaved) do
            print(key, value)
        end
    end

    -- Migrate old saved variables into the new structure if they exist
    Config.Settings.totalGold = ThicPortalsSaved and ThicPortalsSaved.totalGold or Config.Settings.totalGold
    Config.Settings.dailyGold = ThicPortalsSaved and ThicPortalsSaved.dailyGold or Config.Settings.dailyGold
    Config.Settings.totalTradesCompleted = ThicPortalsSaved and ThicPortalsSaved.totalTradesCompleted or Config.Settings.totalTradesCompleted
    Config.Settings.lastUpdateDate = ThicPortalsSaved and ThicPortalsSaved.lastUpdateDate or Config.Settings.lastUpdateDate
    --
    Config.Settings.BanList = BanList or Config.Settings.BanList
    Config.Settings.IntentKeywords = IntentKeywords or Config.Settings.IntentKeywords
    Config.Settings.DestinationKeywords = DestinationKeywords or Config.Settings.DestinationKeywords
    Config.Settings.ServiceKeywords = ServiceKeywords or Config.Settings.ServiceKeywords
    --
    Config.Settings.inviteMessage = InviteMessage or Config.Settings.inviteMessage
    Config.Settings.inviteMessageWithoutDestination = InviteMessageWithoutDestination or Config.Settings.inviteMessageWithoutDestination
    Config.Settings.tipMessage = TipMessage or Config.Settings.tipMessage
    Config.Settings.noTipMessage = NoTipMessage or Config.Settings.noTipMessage
    --
    Config.Settings.hideIcon = hideIcon or Config.Settings.hideIcon
    Config.Settings.ApproachMode = ApproachMode or Config.Settings.ApproachMode

    if not Config.Settings.toggleButtonPosition then
        Config.Settings.toggleButtonPosition = ThicPortalSettings.ToggleButtonPosition
    end

    -- Override addonEnabled to false on startup
    Config.Settings.addonEnabled = false

    -- Remove old global variables if needed (Version 1.2.2)
    --
    -- ThicPortalsSaved = nil
    -- BanList = nil
    -- IntentKeywords = nil
    -- DestinationKeywords = nil
    -- ServiceKeywords = nil
    -- InviteMessage = nil
    -- InviteMessageWithoutDestination = nil
    -- TipMessage = nil
    -- noTipMessage = nil
    -- hideIcon = nil
    -- ApproachMode = nil
end

_G.Config = Config

return Config