#include <string_view>
#include <filesystem>
#include <fstream>
#include <thread>
#include <chrono>

#include <jsoncons/json.hpp>
#include <discord.h>

#include <Windows.h>

using namespace std::literals;
using namespace std::chrono_literals;

constexpr auto MODNAME = "CP77 Discord RPC"sv;

static discord::Core* core{};
static std::filesystem::path rootDir;
static HANDLE modInstanceMutex { nullptr };
static std::unique_ptr<std::thread> rpcThread { };
static std::atomic_bool rpcThreadRunning { true };
static unsigned long long timestamp = std::chrono::duration_cast<std::chrono::seconds>(std::chrono::system_clock::now().time_since_epoch()).count();


discord::Result updatePresence();
bool shouldRun() {
    return rpcThreadRunning;
}


BOOL APIENTRY DllMain(HMODULE module, DWORD reasonForCall, LPVOID) {

    DisableThreadLibraryCalls(module);

    switch(reasonForCall) {
        case DLL_PROCESS_ATTACH: {

            // Check for correct product name
            wchar_t exePathBuf[MAX_PATH] { 0 };
            GetModuleFileName(GetModuleHandle(nullptr), exePathBuf, std::size(exePathBuf));
            std::filesystem::path exePath = exePathBuf;
            rootDir = exePath.parent_path() / "plugins/cyber_engine_tweaks/mods" / MODNAME;

            // Quit if companion was not found
            if (!std::filesystem::exists(rootDir / "init.lua")) {
                break;
            }

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

            // Create mutex for single instancing
            modInstanceMutex = CreateMutexW(NULL, TRUE, L"DiscordRPCHelper Instance");
            if (!modInstanceMutex) {
                break;
            }

            // Setup and run thread to update presence data
            rpcThread = std::make_unique<std::thread>([]() {

                // Initialize Discord RPC
                discord::Core::Create(798867051820351539, DiscordCreateFlags_NoRequireDiscord, &core);

                // Main job
                while (shouldRun()) {

                    // Update presence
                    auto result = updatePresence();

                    // Try reconnecting if Discord was not found
                    // if (result == discord::Result::NotRunning) {
                    //     discord::Core::Create(798867051820351539, DiscordCreateFlags_NoRequireDiscord, &core);
                    // }
                    // Crashes the game, big daddy discord is mean and doesn't want multiple sdk inits

                    // Only update every 2 seconds
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


discord::Result updatePresence() {
    // Only attempt updating presence if file exists
    if (std::filesystem::exists(rootDir / "middleman.json")) {

        // Open and read json
        std::ifstream middlemanFile (rootDir / "middleman.json");
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
            return core->RunCallbacks();
        }
    } else {
        return discord::Result::Ok;
    }
}
