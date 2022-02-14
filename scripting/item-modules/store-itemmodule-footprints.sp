//Pragma
#pragma semicolon 1
#pragma newdecls required

//Defines
#define MODULE_DESCRIPTION "The item module for Footprints for the modular store system."
#define MODULE_VERSION "1.0.0"
#define MODULE_NAME "footprints"

//Sourcemod Includes
#include <sourcemod>
#include <sourcemod-misc>
#include <tf2attributes>

//Our Includes
#include <modularstore/modularstore-items>

//ConVars
//ConVar g_Convar_Status;

//Forwards

//Globals
float g_Footprints[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "[Modular Store] :: ItemModule - Footprints", 
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
	FindConVar("tf_forced_holiday").SetInt(2);

	if (ModularStore_IsItemTypeRegistered(MODULE_NAME))
		ModularStore_UnregisterItemType(MODULE_NAME);
	
	ModularStore_OnRegisterItemTypesPost();
}

public void ModularStore_OnRegisterItemTypesPost()
{
	RegisterStatus status;
	
	status = Register_Successful;
	if ((status = ModularStore_RegisterItemType(MODULE_NAME, "Footprints", OnAction)) != Register_Successful)
		LogError("Error registering this module with item type '%s'. [Error code %i]", MODULE_NAME, status);
}

public Action OnAction(int client, const char[] action, StringMap itemdata)
{
	if (StrEqual(action, "equip"))
	{
		float id;
		itemdata.GetValue("id", id);
		g_Footprints[client] = id;

		TF2Attrib_SetByName(client, "SPELL: set Halloween footstep type", g_Footprints[client]);
		PrintToChat(client, "%f", g_Footprints[client]);
	}
	else if (StrEqual(action, "unequip"))
	{
		g_Footprints[client] = 0.0;
		TF2Attrib_RemoveByName(client, "SPELL: set Halloween footstep type");
	}
}