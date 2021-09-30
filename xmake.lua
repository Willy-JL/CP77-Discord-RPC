set_xmakever("2.5.1")

set_languages("cxx20")
set_arch("x64")

add_requires("discord")
add_requires("jsoncons")

add_rules("mode.debug","mode.releasedbg", "mode.release")
add_rules("plugin.vsxmake.autoupdate")

if is_mode("debug") then
    set_optimize("none")
elseif is_mode("releasedbg") then
    set_optimize("fastest")
elseif is_mode("release") then
    add_defines("NDEBUG")
    set_optimize("fastest")
end

add_cxflags("/bigobj", "/MP")
add_defines("UNICODE")

target("DiscordRPCHelper")
    add_defines("WIN32_LEAN_AND_MEAN", "NOMINMAX", "WINVER=0x0601")
    set_kind("shared")
    set_filename("DiscordRPCHelper.asi")
    add_files("./**.cpp")
    add_includedirs("./")
    add_syslinks("User32", "Version")
    add_packages("discord", "jsoncons")
	on_package(function(target)
		os.mkdir("package/bin/x64/plugins/cyber_engine_tweaks/mods/CP77 Discord RPC")
		os.cp(target:targetfile(), "package/bin/x64/plugins/")
		os.cp("init.lua", "package/bin/x64/plugins/cyber_engine_tweaks/mods/CP77 Discord RPC")
		os.cp("cp2077-cet-kit/GameUI.lua", "package/bin/x64/plugins/cyber_engine_tweaks/mods/CP77 Discord RPC")
		os.cp("discord-game-sdk-binaries/lib/x86_64/discord_game_sdk.dll", "package/bin/x64/plugins")
	end)
