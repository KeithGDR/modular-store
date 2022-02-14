//Pragma
#pragma semicolon 1
#pragma newdecls required

//Defines
#define MODULE_DESCRIPTION "The item module for Models for the modular store system."
#define MODULE_VERSION "1.0.0"
#define MODULE_NAME "models"

//Sourcemod Includes
#include <sourcemod>
#include <sourcemod-misc>

//Our Includes
#include <modularstore/modularstore-items>
#include <modularstore/modularstore-globals>
#include <modularstore/modularstore-items>
#include <modularstore/modularstore-shop>
#include <modularstore/modularstore-inventory>

//ConVars
//ConVar g_Convar_Status;

//Forwards

//Globals

public Plugin myinfo = 
{
	name = "[Modular Store] :: ItemModule - Models", 
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
	if ((status = ModularStore_RegisterItemType(MODULE_NAME, "Models", OnAction)) != Register_Successful)
		LogError("Error registering this module with item type '%s'. [Error code %i]", MODULE_NAME, status);
}

public Action OnAction(int client, const char[] action, StringMap itemdata)
{
	if (StrEqual(action, "equip"))
	{
		char sModel[PLATFORM_MAX_PATH];
		itemdata.GetString("model", sModel, sizeof(sModel));

		if (StrContains(sModel, "models/", false) != 0)
			Format(sModel, sizeof(sModel), "models/%s", sModel);

		if (StrContains(sModel, ".mdl", false) == -1)
			Format(sModel, sizeof(sModel), "%s.mdl", sModel);

		if (!IsModelPrecached(sModel))
			PrecacheModel(sModel);

		SetModel(client, sModel);

		char sTeam[64];
		GetTeamName(GetClientTeam(client), sTeam, sizeof(sTeam));
		Format(sTeam, sizeof(sTeam), "skin_%s", sTeam);

		int skin;
		itemdata.GetValue(sTeam, skin);
		DispatchKeyValueInt(client, "skin", skin);
	}
	else if (StrEqual(action, "unequip"))
		SetModel(client, "");
}