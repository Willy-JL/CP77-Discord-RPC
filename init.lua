
function file_exists(name)
  local f=io.open(name,"r")
  if f~=nil then io.close(f) return true else return false end
end



registerForEvent("onInit", function()
  os.execute("taskkill /f /im cp77rpc.exe")
  root = "bin/x64/plugins/cyber_engine_tweaks/mods/CP77 Discord RPC/"
  path = io.popen"cd":read'*l'
  if path:sub(-3, -1) == "bin" then
    root = "x64/plugins/cyber_engine_tweaks/mods/CP77 Discord RPC/"
  end
  if path:sub(-3, -1) == "x64" then
    root = "plugins/cyber_engine_tweaks/mods/CP77 Discord RPC/"
  end
  if path:sub(-7, -1) == "plugins" then
    root = "cyber_engine_tweaks/mods/CP77 Discord RPC/"
  end
  if path:sub(-19, -1) == "cyber_engine_tweaks" then
    root = "mods/CP77 Discord RPC/"
  end
  if path:sub(-4, -1) == "mods" then
    root = "CP77 Discord RPC/"
  end
  if path:sub(-11, -1) == "CP77 Discord RPC" then
    root = ""
  end

  f = io.open(root .. "config.json", "r")
  delay = json.decode(f:read("*all")).delay
  io.close(f)

  middleman_path = root .. "middleman.json"
  if file_exists(middleman_path) then
    f = io.open(middleman_path, "r")
    data = json.decode(f:read("*all"))
    io.close(f)
  else
    f = io.open(middleman_path, "w")
    f:write("{\"lvl_stcred\":\"\",\"quest_name\":\"N/A\",\"lifepath\":\"\"}")
    io.close(f)
    f = io.open(middleman_path, "r")
    data = json.decode(f:read("*all"))
    io.close(f)
  end
  function update_middleman()
    f = io.open(middleman_path, "w+")
    f:write(json.encode(data))
    io.close(f)
  end
  data.lvl_stcred = ""
  data.quest_name = "N/A"
  data.lifepath = ""
  update_middleman()

  os.execute("start \"\" \"" .. root .. "cp77rpc.exe\"")
  
  rpcTimer = 0
  oldVelocity = 0

end)


  
registerForEvent("onUpdate", function(deltaTime)

  player = Game.GetPlayer()
  if player then
    newVelocity = player:GetVelocity().z

    rpcTimer = rpcTimer + deltaTime
    if rpcTimer > delay then
      rpcTimer = rpcTimer - delay

      ssc = Game.GetScriptableSystemsContainer()
      pds = ssc:Get('PlayerDevelopmentSystem')
      pdd = pds:GetDevelopmentData(player)
      data.lifepath = pdd:GetLifePath().value
      ss = Game.GetStatsSystem()
      player_id = player:GetEntityID()
      level = ss:GetStatValue(player_id, 'Level')
      street_cred = ss:GetStatValue(player_id, 'StreetCred')
      data.lvl_stcred = "Level " .. math.floor(level) .. " - " .. math.floor(street_cred) .. " St Cred"
      if newVelocity == oldVelocity and newVelocity ~= 0 then
        data.quest_name = "On Pause Menu"
      elseif math.abs(newVelocity) < 0.0001 and newVelocity ~= 0 then
        data.quest_name = "On Main Menu"
        data.lifepath = ""
        data.lvl_stcred = ""
      else
        quest_data = tostring(GameDump(Game.GetJournalManager():GetTrackedEntry()))
        none, start = quest_data:find(", description:", 1, true)
        if not start then
          data.quest_name = "No Active Quest"
        else
          finish, none = quest_data:find(",", start, true)
          quest_loc_key = quest_data:sub(start+1, finish-1)
          data.quest_name = Game['GetLocalizedText'](quest_loc_key)
        end
      end
      update_middleman()
    end
    oldVelocity = newVelocity
  end

end)
