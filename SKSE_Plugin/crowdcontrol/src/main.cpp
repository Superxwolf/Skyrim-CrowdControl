#include "common/ITypes.h"  // SInt32
#include "skse64_common/skse_version.h"  // RUNTIME_VERSION
#include "skse64/GameTypes.h"  // BSFixedString
#include "skse64/PapyrusNativeFunctions.h"  // NativeFunction, StaticFunctionTag
#include "skse64/PapyrusVM.h"  // VMClassRegistry
#include "skse64/PluginAPI.h"  // SKSEInterface, PluginInfo
#include "skse64/GameEvents.h"
#include "skse64/PapyrusEvents.h"
#include "simpleini/SimpleIni.h"
#include "skse64/GameMenus.h"

#include <windows.h>
#include <ShlObj.h>  // CSIDL_MYDOCUMENTS


#include "version.h"  // VERSION_VERSTRING, VERSION_MAJOR

#include "Connector.h"

#define CC_VERSION "1.1"
#define CC_VERSION_MAJOR 1
#define CC_IP "127.0.0.1"
#define CC_PORT "59420"

static Connector* connector = NULL;

class CC_MenuEvent : public BSTEventSink<MenuOpenCloseEvent>
{
	virtual	EventResult	ReceiveEvent(MenuOpenCloseEvent* evn, EventDispatcher<MenuOpenCloseEvent>* dispatcher) override
	{
		if (connector != NULL)
		{
			connector->OnMenu(evn->opening);
		}
		return kEvent_Continue;
	};
};
static CC_MenuEvent CC_OnMenu;

BSFixedString CrowdControlCheck(StaticFunctionTag*)
{
	return BSFixedString(CC_VERSION);
}

BSFixedString CrowdControlState(StaticFunctionTag*)
{
	if (connector == NULL)
	{
		return BSFixedString("uninitialized");
	}
	else if (!connector->IsConnected())
	{
		return BSFixedString("disconnected");
	}
	else if (!connector->IsRunning())
	{
		return BSFixedString("stopped");
	}
	else
	{
		return BSFixedString("running");
	}
}

void CrowdControlReconnect(StaticFunctionTag*)
{
	if (connector == NULL)
	{
		connector = new Connector();
	}
	if (!connector->IsConnected())
	{
		connector->ConnectAsync(CC_PORT);
	}
	else if (!connector->IsRunning())
	{
		connector->Run();
	}
	else
	{
		_MESSAGE("[Reconnect] Already connected");
	}
}

void CrowdControlRun(StaticFunctionTag*)
{
	connector->Run();
}

void CrowdControlRespond(StaticFunctionTag*, SInt32 id, SInt32 status, BSFixedString message, SInt32 miliseconds = 0)
{
	if (connector != NULL)
	{
		connector->Respond(id, status, message, miliseconds);
	}
}

SInt32 CrowdControlItemCount(StaticFunctionTag*)
{
	if (connector == NULL) return 0;

	return connector->GetItemCount();
}

VMResultArray<BSFixedString> CrowdControlPopItem(StaticFunctionTag*)
{
	if (connector == NULL) return VMResultArray<BSFixedString>();

	auto item = connector->PopItem();

	auto arr = VMResultArray<BSFixedString>();

	char buffer[30];
	_itoa_s(item->id, buffer, 10);
	arr.push_back(BSFixedString(buffer));

	arr.push_back(BSFixedString(item->command.c_str()));
	arr.push_back(BSFixedString(item->viewer.c_str()));

	_itoa_s(item->type, buffer, 10);
	arr.push_back(BSFixedString(buffer));

	return arr;
}

SInt32 CrowdControlHasTimer(StaticFunctionTag*, BSFixedString command_name)
{
	if (connector != NULL)
	{
		return connector->HasTimer(command_name.c_str()) ? 1 : 0;
	}
	return 0;
}

void CrowdControlClearTimers(StaticFunctionTag*)
{
	if (connector != NULL)
	{
		connector->ClearTimers();
	}
}

static CSimpleIniA ini;
static bool iniLoaded = false;
bool LoadIni()
{
	if (!iniLoaded)
	{
		char path[MAX_PATH];
		HRESULT error = SHGetFolderPath(NULL, CSIDL_MYDOCUMENTS | CSIDL_FLAG_CREATE, NULL, SHGFP_TYPE_CURRENT, path);
		if (SUCCEEDED(error))
		{
			strcat_s(path, sizeof(path), "\\My Games\\Skyrim Special Edition\\CrowdControl.ini");
			auto error = ini.LoadFile(path);
			if (error < 0)
			{
				//_ERROR("Loading Crowd Control ini failed: %s", error);
				return false;
			}
			iniLoaded = true;
		}
		else
		{
			_ERROR("Getting path to Crowd Control ini failed (result = %08X lasterr = %08X)", error, GetLastError());
			return false;
		}
	}

	return true;
}

SInt32 GetIntSetting(StaticFunctionTag*, BSFixedString section, BSFixedString key)
{
	if (!LoadIni()) return 1;
	return ini.GetLongValue(section, key, 0);
}

float GetFloatSetting(StaticFunctionTag*, BSFixedString section, BSFixedString key)
{
	if (!LoadIni()) return 1;
	return ini.GetDoubleValue(section, key, 0);
}

bool RegisterFuncs(VMClassRegistry* a_registry)
{
	a_registry->RegisterFunction(new NativeFunction0<StaticFunctionTag, BSFixedString>("CC_Version", "CrowdControl", CrowdControlCheck, a_registry));
	a_registry->RegisterFunction(new NativeFunction0<StaticFunctionTag, BSFixedString>("CC_GetState", "CrowdControl", CrowdControlState, a_registry));
	a_registry->RegisterFunction(new NativeFunction0<StaticFunctionTag, void>("CC_Reconnect", "CrowdControl", CrowdControlReconnect, a_registry));
	a_registry->RegisterFunction(new NativeFunction0<StaticFunctionTag, void>("CC_Run", "CrowdControl", CrowdControlRun, a_registry));
	a_registry->RegisterFunction(new NativeFunction0<StaticFunctionTag, SInt32>("CC_GetItemCount", "CrowdControl", CrowdControlItemCount, a_registry));
	a_registry->RegisterFunction(new NativeFunction0<StaticFunctionTag, VMResultArray<BSFixedString>>("CC_PopItem", "CrowdControl", CrowdControlPopItem, a_registry));
	a_registry->RegisterFunction(new NativeFunction4<StaticFunctionTag, void, SInt32, SInt32, BSFixedString, SInt32>("CC_Respond", "CrowdControl", CrowdControlRespond, a_registry));
	a_registry->RegisterFunction(new NativeFunction1<StaticFunctionTag, SInt32, BSFixedString>("CC_HasTimer", "CrowdControl", CrowdControlHasTimer, a_registry));
	a_registry->RegisterFunction(new NativeFunction0<StaticFunctionTag, void>("CC_ClearTimers", "CrowdControl", CrowdControlClearTimers, a_registry));
	a_registry->RegisterFunction(new NativeFunction2<StaticFunctionTag, SInt32, BSFixedString, BSFixedString>("CC_GetIntSetting", "CrowdControl", GetIntSetting, a_registry));
	a_registry->RegisterFunction(new NativeFunction2<StaticFunctionTag, float, BSFixedString, BSFixedString>("CC_GetFloatSetting", "CrowdControl", GetFloatSetting, a_registry));
	return true;
}

extern "C" {
	bool SKSEPlugin_Query(const SKSEInterface* a_skse, PluginInfo* a_info)
	{
		gLog.OpenRelative(CSIDL_MYDOCUMENTS, "\\My Games\\Skyrim Special Edition\\SKSE\\CrowdControl.log");
		gLog.SetPrintLevel(IDebugLog::kLevel_DebugMessage);
		gLog.SetLogLevel(IDebugLog::kLevel_DebugMessage);

		_MESSAGE("CrowControlPlugin v%s", CC_VERSION);

		a_info->infoVersion = PluginInfo::kInfoVersion;
		a_info->name = "CrowControlPlugin";
		a_info->version = CC_VERSION_MAJOR;

		if (a_skse->isEditor) {
			_FATALERROR("[FATAL ERROR] Loaded in editor, marking as incompatible!\n");
			return false;
		} else if (a_skse->runtimeVersion < RUNTIME_VERSION_1_5_53) {
			_FATALERROR("[FATAL ERROR] Unsupported runtime version %08X!\n", a_skse->runtimeVersion);
			return false;
		}

		return true;
	}

	bool SKSEPlugin_Load(const SKSEInterface* a_skse)
	{
		_MESSAGE("CrowControlPlugin loaded");

		try
		{
			connector = new Connector();

			SKSEPapyrusInterface* papyrus = (SKSEPapyrusInterface*)a_skse->QueryInterface(kInterface_Papyrus);

			papyrus->Register(RegisterFuncs);

			if (!connector->Connect(CC_PORT))
			{
				_ERROR(connector->GetError());
			}
			else
			{
				_MESSAGE("Crowd Control Connected");
			}

			auto* messaging = (SKSEMessagingInterface*)a_skse->QueryInterface(kInterface_Messaging);

			auto* mm = MenuManager::GetSingleton();
			mm->MenuOpenCloseEventDispatcher()->AddEventSink(&CC_OnMenu);
		}
		catch (std::exception e)
		{
			_ERROR("[SKSEPlugin_Load] %s", e.what());
		}

		return true;
	}
};