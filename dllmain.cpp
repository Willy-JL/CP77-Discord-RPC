#include <filesystem>
#include <fstream>
#include <thread>
#include <chrono>

#include <jsoncons/json.hpp>
#include <discord.h>

#include <Windows.h>

using namespace std::chrono_literals;

#define MODNAME "CP77 Discord RPC"

static HANDLE modInstanceMutex { nullptr };
static std::unique_ptr<std::thread> rpcThread { };
static std::atomic_bool rpcThreadRunning { true };


std::string getCWD(std::string);
void updatePresence(std::string, discord::Core*, unsigned long long);
bool shouldRun() {
    return rpcThreadRunning;
}


BOOL APIENTRY DllMain(HMODULE module, DWORD reasonForCall, LPVOID) {

    DisableThreadLibraryCalls(module);

    switch(reasonForCall) {
        case DLL_PROCESS_ATTACH: {

            std::string rootDir = getCWD(MODNAME);

            // Quit if companion was not found
            if (rootDir == "null") {
                break;
            }

            // Check for correct product name
            wchar_t exePathBuf[MAX_PATH] { 0 };
            GetModuleFileName(GetModuleHandle(nullptr), exePathBuf, std::size(exePathBuf));
            std::filesystem::path exePath = exePathBuf;

            bool exeValid = false;
            int verInfoSz = GetFileVersionInfoSize(exePathBuf, nullptr);
            if (verInfoSz) {
                auto verInfo = std::make_unique<BYTE[]>(verInfoSz);
                if (GetFileVersionInfo(exePathBuf, 0, verInfoSz, verInfo.get())) {
                    struct {
                        WORD Language;
                        WORD CodePage;
                    } *pTranslations;
                    // Thanks WhySoSerious?, I have no idea what this block is doing but it works :D
                    UINT transBytes = 0;
                    if (VerQueryValueW(verInfo.get(), L"\\VarFileInfo\\Translation", reinterpret_cast<void**>(&pTranslations), &transBytes)) {
                        UINT dummy;
                        TCHAR* productName = nullptr;
                        TCHAR subBlock[64];
                        for (UINT i = 0; i < (transBytes / sizeof(*pTranslations)); i++) {
                            swprintf(subBlock, L"\\StringFileInfo\\%04x%04x\\ProductName", pTranslations[i].Language, pTranslations[i].CodePage);
                            if (VerQueryValueW(verInfo.get(), subBlock, reinterpret_cast<void**>(&productName), &dummy)) {
                                if (wcscmp(productName, L"Cyberpunk 2077") == 0) {
                                    exeValid = true;
                                    break;
                                }
                            }
                        }
                    }
                }
            }

            // Check for correct exe name if product name check fails
            exeValid = exeValid || (exePath.filename() == L"Cyberpunk2077.exe");

            // Quit if not attaching to CP77
            if (!exeValid) {
                break;
            }

            // Get process start time
            auto timestamp = std::chrono::duration_cast<std::chrono::seconds>(std::chrono::system_clock::now().time_since_epoch()).count();

            // Create mutex for single instancing
            modInstanceMutex = CreateMutexW(NULL, TRUE, L"DiscordRPCHelper Instance");
            if (!modInstanceMutex) {
                break;
            }

            // Setup and run thread to update presence data
            rpcThread = std::make_unique<std::thread>([timestamp]() {

                std::string rootDir = getCWD(MODNAME);

                // Initialize Discord RPC
                discord::Core* core{};
                auto result = discord::Core::Create(798867051820351539, DiscordCreateFlags_NoRequireDiscord, &core);

                // Main job
                while (shouldRun()) {
                    updatePresence(rootDir, core, timestamp);
                    std::this_thread::sleep_for(2000ms);
                }

            });
            break;
        }

        case DLL_PROCESS_DETACH: {
            if (modInstanceMutex) {
                rpcThreadRunning = false;
                rpcThread->join();
                rpcThread = nullptr;
                ReleaseMutex(modInstanceMutex);
                modInstanceMutex = nullptr;
            }
            break;
        }

        default: {
            break;
        }
    }

    return TRUE;
}


void updatePresence(std::string rootDir, discord::Core* core, unsigned long long timestamp) {
    // Only attempt updating presence if file exists
    if (std::filesystem::exists(rootDir + "middleman.json")) {

        // Open and read json
        std::ifstream middlemanFile (rootDir + "middleman.json");
        if (middlemanFile.is_open()) {
            jsoncons::json middleman = jsoncons::json::parse(middlemanFile);
            middlemanFile.close();

            // Setup activity object
            discord::Activity activity{};
            activity.SetDetails(middleman["details"].as<const char *>());
            activity.SetState(  middleman[ "state" ].as<const char *>());
            activity.GetAssets().SetSmallImage(middleman["small_image_key" ].as<const char *>());
            activity.GetAssets().SetSmallText( middleman["small_image_text"].as<const char *>());
            activity.GetAssets().SetLargeImage(middleman["large_image_key" ].as<const char *>());
            activity.GetAssets().SetLargeText( middleman["large_image_text"].as<const char *>());
            activity.GetTimestamps().SetStart(timestamp);
            activity.SetType(discord::ActivityType::Playing);

            // Update activity
            core->ActivityManager().UpdateActivity(activity, [](discord::Result result) { });
            core->RunCallbacks();
        }
    }
}


std::string getCWD(std::string modName) {
    // Find Lua companion mod dir
    if (std::filesystem::exists("bin/x64/plugins/cyber_engine_tweaks/mods/" + modName + "/init.lua")) {
        return "bin/x64/plugins/cyber_engine_tweaks/mods/" + modName + "/";
    }
    if (std::filesystem::exists("x64/plugins/cyber_engine_tweaks/mods/" + modName + "/init.lua")) {
        return "x64/plugins/cyber_engine_tweaks/mods/" + modName + "/";
    }
    if (std::filesystem::exists("plugins/cyber_engine_tweaks/mods/" + modName + "/init.lua")) {
        return "plugins/cyber_engine_tweaks/mods/" + modName + "/";
    }
    if (std::filesystem::exists("cyber_engine_tweaks/mods/" + modName + "/init.lua")) {
        return "cyber_engine_tweaks/mods/" + modName + "/";
    }
    if (std::filesystem::exists("mods/" + modName + "/init.lua")) {
        return "mods/" + modName + "/";
    }
    if (std::filesystem::exists("" + modName + "/init.lua")) {
        return "" + modName + "/";
    }
    if (std::filesystem::exists("init.lua")) {
        return "";
    }
    return "null";
}
