//Pragma
#pragma semicolon 1
#pragma newdecls required

//Defines
#define MODULE_DESCRIPTION "The item module for Join Sounds for the modular store system."
#define MODULE_VERSION "1.0.0"
#define MODULE_NAME "joinsounds"

//Sourcemod Includes
#include <sourcemod>
#include <sourcemod-misc>

//Our Includes
#include <modularstore/modularstore-items>
#include <modularstore/modularstore-shop>

//ConVars
//ConVar g_Convar_Status;

//Forwards

//Globals
bool g_Connecting[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "[Modular Store] :: ItemModule - Join Sounds", 
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
	if ((status = ModularStore_RegisterItemType(MODULE_NAME, "Join Sounds", OnAction)) != Register_Successful)
		LogError("Error registering this module with item type '%s'. [Error code %i]", MODULE_NAME, status);
}

public Action OnAction(int client, const char[] action, StringMap itemdata)
{

}

public void ModularStore_OnEquipItemPost(int client, const char[] category, const char[] item, bool equipped)
{
	if (!g_Connecting[client])
		return;
	
	g_Connecting[client] = false;
	
	if (!StrEqual(category, "Join Sounds"))
		return;
	
	char sSound[PLATFORM_MAX_PATH];
	ModularStore_GetItemDataString(category, item, "sound", sSound, sizeof(sSound));

	if (strlen(sSound) > 0)
	{
		if (!IsSoundPrecached(sSound))
			PrecacheSound(sSound);
		
		char sDownload[PLATFORM_MAX_PATH];
		FormatEx(sDownload, sizeof(sDownload), "sound/%s", sSound);
		AddFileToDownloadsTable(sSound);
		
		EmitSoundToAll(sSound);
	}
}

public void OnClientConnected(int client)
{
	g_Connecting[client] = true;
}

public void OnClientDisconnect_Post(int client)
{
	g_Connecting[client] = false;
}