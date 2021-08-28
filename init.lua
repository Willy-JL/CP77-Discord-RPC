--    __     __     __     __         __         __  __       __     __          --
--   /\ \  _ \ \   /\ \   /\ \       /\ \       /\ \_\ \     /\ \   /\ \         --
--   \ \ \/ ".\ \  \ \ \  \ \ \____  \ \ \____  \ \____ \   _\_\ \  \ \ \____    --
--    \ \__/".~\_\  \ \_\  \ \_____\  \ \_____\  \/\_____\ /\_____\  \ \_____\   --
--     \/_/   \/_/   \/_/   \/_____/   \/_____/   \/_____/ \/_____/   \/_____/   --
--  ---------------------------------------------------------------------------  --
--  This mod was made by WillyJL (WillyJL#3633) from the CP2077 Modding Discord  --
--                  https://github.com/Willy-JL/cp77-discord-rpc                 --
--  ------------------------------- CONDITIONS --------------------------------  --
--                     You can use use this mod as long as:                      --
--           ~ You don't reupload / repost this without my permission            --
--  ~ You credit me / the original author when you use a code snippet from here  --
--   ~ You don't fork this and make a competing version available for download   --
--  --------------------------------- CREDITS ---------------------------------  --
--   HUGE thanks to WhySoSerious? (WSSDude420) for the help with the DLL / ASI   --
--   Very big thanks to psiberx (NoNameNoNumber) for his libraries (eg GameUI)   --
--  ---------------------------------------------------------------------------  --


function fileExists(filename)
    local f=io.open(filename,"r") if (f~=nil) then io.close(f) return true else return false end
end
function getCWD(mod_name)
    if fileExists("bin/x64/plugins/cyber_engine_tweaks/mods/"..mod_name.."/init.lua") then return "bin/x64/plugins/cyber_engine_tweaks/mods/"..mod_name.."/" elseif fileExists("x64/plugins/cyber_engine_tweaks/mods/"..mod_name.."/init.lua") then return "x64/plugins/cyber_engine_tweaks/mods/"..mod_name.."/" elseif fileExists("plugins/cyber_engine_tweaks/mods/"..mod_name.."/init.lua") then return "plugins/cyber_engine_tweaks/mods/"..mod_name.."/" elseif fileExists("cyber_engine_tweaks/mods/"..mod_name.."/init.lua") then return "cyber_engine_tweaks/mods/"..mod_name.."/" elseif fileExists("mods/"..mod_name.."/init.lua") then return "mods/"..mod_name.."/" elseif  fileExists(mod_name.."/init.lua") then return mod_name.."/" elseif  fileExists("init.lua") then return "" end
end
function getGameVersion()
    return ({string.format("%.3f", tonumber(Game.EnumValueFromString("gameGameVersion", "Current")) / 1000):gsub("00$", "0"):gsub("0$", "")})[1]
end


CP77DiscordRPC = {
    description = "CP77 Discord RPC",
    version = "3.0h1",
    rootPath =  getCWD("CP77 Discord RPC"),
    middlemanPath = getCWD("CP77 Discord RPC") .. "middleman.json",
    timer = 2,
    delay = 2,
    state = "none",
    activity = {
        details = "Loading Up",
        state = "",
        large_image_key = "keyart",
        large_image_text = "Patch ???",
        small_image_key = "",
        small_image_text = ""
    }
}


-- Save current state to middleman file
function updateMiddleman()
    f = io.open(CP77DiscordRPC.middlemanPath, "w+")
    f:write(json.encode(CP77DiscordRPC.activity))
    io.close(f)
end


-- Get game version + Setup ingame and main, pause and death menu states detection
local GameUI = require('GameUI')
registerForEvent('onInit', function()

    CP77DiscordRPC.activity.large_image_text = "Patch " .. getGameVersion()

    GameUI.OnMenuOpen(function(state)
        if state.menu == 'MainMenu' then
            CP77DiscordRPC.state = "mainmenu"
        elseif state.menu == 'PauseMenu' then
            CP77DiscordRPC.state = "pausemenu"
        elseif state.menu == 'DeathMenu' then
            CP77DiscordRPC.state = "deathmenu"
        end
    end)

    GameUI.OnMenuClose(function(state)
        if state.lastMenu ~= "MainMenu" and state.lastMenu ~= "DeathMenu" then
            CP77DiscordRPC.state = "ingame"
        end
    end)

    GameUI.OnSessionStart(function(state)
        CP77DiscordRPC.state = "ingame"
    end)

    GameUI.OnLoadingStart(function(state)
        CP77DiscordRPC.state = "loading"
    end)

end)


-- Fetch player's lifepath's respective asset string
function getLifepathAsset(player)
    ssc = Game.GetScriptableSystemsContainer()
    pds = ssc:Get('PlayerDevelopmentSystem')
    pdd = pds:GetDevelopmentData(player)
    if pdd then
        lifepath = pdd:GetLifePath().value
        if lifepath == "StreetKid" then
            return "stkid"
        elseif lifepath == "Nomad" then
            return "nomad"
        elseif lifepath == "Corporate" then
            return "corpo"
        else
            return ""
        end
    else
        return ""
    end
end


-- Get single level + st cred string
function getLevelCred(player)
    ss = Game.GetStatsSystem()
    player_id = player:GetEntityID()
    level = ss:GetStatValue(player_id, 'Level')
    street_cred = ss:GetStatValue(player_id, 'StreetCred')
    return "Lvl " .. math.floor(level) .. " - " .. math.floor(street_cred) .. " Cred"
end


-- Get current quest title + description
function getQuestInfo()
    jm = Game.GetJournalManager()
    objective = jm:GetTrackedEntry()
    if objective then

        objDescKey = objective:GetDescription()
        if objDescKey then
            objDesc = Game['GetLocalizedText'](objDescKey)
        end

        questPhase = jm:GetParentEntry(objective)
        if questPhase then
            quest = jm:GetParentEntry(questPhase)
            if quest then
                questTitleKey = quest:GetTitle(jm)
                if questTitleKey then
                    questTitle = Game['GetLocalizedText'](questTitleKey)
                end
            end
        end

    end

    if objDesc and questTitle then
        return { title = questTitle, desc = objDesc }
    else
        return { title = "No Active Quest", desc = "Just Vibing" }
    end
end


-- Run every frame
registerForEvent("onUpdate", function(deltaTime)

    -- Only update every x seconds
    CP77DiscordRPC.timer = CP77DiscordRPC.timer + deltaTime
    if CP77DiscordRPC.timer > CP77DiscordRPC.delay then
        CP77DiscordRPC.timer = CP77DiscordRPC.timer - CP77DiscordRPC.delay

        player = Game.GetPlayer()
        if player then

            if CP77DiscordRPC.state == "none" then
                CP77DiscordRPC.activity.details = "Loading Up"
                CP77DiscordRPC.activity.state = ""
                CP77DiscordRPC.activity.small_image_key = ""
                CP77DiscordRPC.activity.small_image_text = ""

            elseif CP77DiscordRPC.state == "loading" then
                CP77DiscordRPC.activity.details = "Loading..."
                CP77DiscordRPC.activity.state = ""
                CP77DiscordRPC.activity.small_image_key = ""
                CP77DiscordRPC.activity.small_image_text = ""

            elseif CP77DiscordRPC.state == "mainmenu" then
                CP77DiscordRPC.activity.details = "On Main Menu"
                CP77DiscordRPC.activity.state = ""
                CP77DiscordRPC.activity.small_image_key = ""
                CP77DiscordRPC.activity.small_image_text = ""

            elseif CP77DiscordRPC.state == "pausemenu" then
                CP77DiscordRPC.activity.details = "On Pause Menu"
                CP77DiscordRPC.activity.state = ""
                CP77DiscordRPC.activity.small_image_key = getLifepathAsset(player)
                CP77DiscordRPC.activity.small_image_text = getLevelCred(player)

            elseif CP77DiscordRPC.state == "deathmenu" then
                CP77DiscordRPC.activity.details = "On Death Menu"
                CP77DiscordRPC.activity.state = "About to Rage Quit"
                CP77DiscordRPC.activity.small_image_key = ""
                CP77DiscordRPC.activity.small_image_text = ""

            elseif CP77DiscordRPC.state == "ingame" then
                questInfo = getQuestInfo()
                CP77DiscordRPC.activity.details = questInfo.title
                CP77DiscordRPC.activity.state = questInfo.desc
                CP77DiscordRPC.activity.small_image_key = getLifepathAsset(player)
                CP77DiscordRPC.activity.small_image_text = getLevelCred(player)

            end

            updateMiddleman()

        end
    end

end)


updateMiddleman()

return CP77DiscordRPC