//Pragma
#pragma semicolon 1
#pragma newdecls required

//Defines
#define MODULE_DESCRIPTION "The item module for Voice Pitches for the modular store system."
#define MODULE_VERSION "1.0.0"
#define MODULE_NAME "voicepitches"

#define MIN_PITCH 30
#define MAX_PITCH 250
#define DEFAULT_PITCH 100

//Sourcemod Includes
#include <sourcemod>
#include <sourcemod-misc>

//Our Includes
#include <modularstore/modularstore-items>

//ConVars
//ConVar g_Convar_Status;

//Forwards

//Globals
int g_Pitch[MAXPLAYERS + 1] = {DEFAULT_PITCH, ...};

public Plugin myinfo = 
{
	name = "[Modular Store] :: ItemModule - Voice Pitches", 
	author = "Keith Warren (Shaders Allen)", 
	description = MODULE_DESCRIPTION, 
	version = MODULE_VERSION, 
	url = "https://github.com/ShadersAllen"
};

public void OnPluginStart()
{
	//LoadTranslations("common.phrases");
	//LoadTranslations("NEWPROJECT.phrases");
	
	//CreateConVar("sm_modularstore_version", MODULE_VERSION, MODULE_DESCRIPTION, FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_SPONLY | FCVAR_DONTRECORD);
	//g_Convar_Status = CreateConVar("sm_modularstore_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	//AutoExecConfig();

	AddNormalSoundHook(NormalSoundHook);
}

public void OnConfigsExecuted()
{
	if (ModularStore_IsItemTypeRegistered(MODULE_NAME))
		ModularStore_UnregisterItemType(MODULE_NAME);
	
	ModularStore_OnRegisterItemTypesPost();
}

public void ModularStore_OnRegisterItemTypesPost()
{
	RegisterStatus status;
	
	status = Register_Successful;
	if ((status = ModularStore_RegisterItemType(MODULE_NAME, "Voice Pitches", OnAction)) != Register_Successful)
		LogError("Error registering this module with item type '%s'. [Error code %i]", MODULE_NAME, status);
}

public Action OnAction(int client, const char[] action, StringMap itemdata)
{
	if (StrEqual(action, "equip"))
	{
		int pitch;
		itemdata.GetValue("pitch", pitch);
		g_Pitch[client] = pitch;
	}
	else if (StrEqual(action, "unequip"))
	{
		g_Pitch[client] = DEFAULT_PITCH;
	}
}

public Action NormalSoundHook(int iClients[64], int &iClientCount, char sSoundPath[PLATFORM_MAX_PATH], int &iEntity, int &iChannel, float &fVolume, int &iLevel, int &iPitch, int &iFlags)
{
	if (iChannel == SNDCHAN_VOICE && g_Pitch[iEntity] != DEFAULT_PITCH)
	{
		iPitch = g_Pitch[iEntity];
		iFlags |= SND_CHANGEPITCH;
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}