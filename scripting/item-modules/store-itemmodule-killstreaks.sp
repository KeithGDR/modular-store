//Pragma
#pragma semicolon 1
#pragma newdecls required

//Defines
#define MODULE_DESCRIPTION "The item module for Killstreaks for the modular store system."
#define MODULE_VERSION "1.0.0"
#define MODULE_NAME_KILLSTREAKTIERS "killstreaktiers"
#define MODULE_NAME_KILLSTREAKEFFECTS "killstreakeffects"
#define MODULE_NAME_KILLSTREAKSHEENS "killstreaksheens"

//Sourcemod Includes
#include <sourcemod>
#include <sourcemod-misc>
#include <tf2items>

//Our Includes
#include <modularstore/modularstore-items>

//ConVars
//ConVar g_Convar_Status;

//Forwards

//Globals
float g_KillstreakTier[MAXPLAYERS + 1];
float g_KillstreakEffect[MAXPLAYERS + 1];
float g_KillstreakSheen[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "[Modular Store] :: ItemModule - Killstreaks", 
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
	if (ModularStore_IsItemTypeRegistered(MODULE_NAME_KILLSTREAKTIERS))
		ModularStore_UnregisterItemType(MODULE_NAME_KILLSTREAKTIERS);
	
	if (ModularStore_IsItemTypeRegistered(MODULE_NAME_KILLSTREAKEFFECTS))
		ModularStore_UnregisterItemType(MODULE_NAME_KILLSTREAKEFFECTS);
	
	if (ModularStore_IsItemTypeRegistered(MODULE_NAME_KILLSTREAKSHEENS))
		ModularStore_UnregisterItemType(MODULE_NAME_KILLSTREAKSHEENS);
	
	ModularStore_OnRegisterItemTypesPost();
}

public void ModularStore_OnRegisterItemTypesPost()
{
	RegisterStatus status;
	
	status = Register_Successful;
	if ((status = ModularStore_RegisterItemType(MODULE_NAME_KILLSTREAKTIERS, "Killstreak Tiers", OnAction_Tiers)) != Register_Successful)
		LogError("Error registering this module with item type '%s'. [Error code %i]", MODULE_NAME_KILLSTREAKTIERS, status);
	
	status = Register_Successful;
	if ((status = ModularStore_RegisterItemType(MODULE_NAME_KILLSTREAKEFFECTS, "Killstreak Effects", OnAction_Effect)) != Register_Successful)
		LogError("Error registering this module with item type '%s'. [Error code %i]", MODULE_NAME_KILLSTREAKEFFECTS, status);
	
	status = Register_Successful;
	if ((status = ModularStore_RegisterItemType(MODULE_NAME_KILLSTREAKSHEENS, "Killstreak Sheens", OnAction_Sheen)) != Register_Successful)
		LogError("Error registering this module with item type '%s'. [Error code %i]", MODULE_NAME_KILLSTREAKSHEENS, status);
}

public Action OnAction_Tiers(int client, const char[] action, StringMap itemdata)
{
	if (StrEqual(action, "equip"))
	{
		float effect;
		itemdata.GetValue("effect", effect);

		g_KillstreakTier[client] = effect;
		TF2Attrib_SetByName_Weapons(client, -1, "killstreak tier", g_KillstreakTier[client]);
	}
	else if (StrEqual(action, "unequip"))
	{
		g_KillstreakTier[client] = 0.0;
		TF2Attrib_RemoveByName_Weapons(client, -1, "killstreak tier");
	}
}

public Action OnAction_Effect(int client, const char[] action, StringMap itemdata)
{
	if (StrEqual(action, "equip"))
	{
		float effect;
		itemdata.GetValue("effect", effect);

		g_KillstreakEffect[client] = effect;
		TF2Attrib_SetByName_Weapons(client, -1, "killstreak effect", g_KillstreakEffect[client]);
	}
	else if (StrEqual(action, "unequip"))
	{
		g_KillstreakEffect[client] = 0.0;
		TF2Attrib_RemoveByName_Weapons(client, -1, "killstreak effect");
	}
}

public Action OnAction_Sheen(int client, const char[] action, StringMap itemdata)
{
	if (StrEqual(action, "equip"))
	{
		float effect;
		itemdata.GetValue("effect", effect);

		g_KillstreakSheen[client] = effect;
		TF2Attrib_SetByName_Weapons(client, -1, "killstreak idleeffect", g_KillstreakSheen[client]);
	}
	else if (StrEqual(action, "unequip"))
	{
		g_KillstreakSheen[client] = 0.0;
		TF2Attrib_RemoveByName_Weapons(client, -1, "killstreak idleeffect");
	}
}

public Action TF2Items_OnGiveNamedItem(int client, char[] classname, int iItemDefinitionIndex, Handle& hItem)
{
	if (g_KillstreakTier[client] > 0.0 || g_KillstreakEffect[client] > 0.0 || g_KillstreakSheen[client] > 0.0)
	{
		hItem = TF2Items_CreateItem(OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES);
		int amount;
		
		if (g_KillstreakTier[client] > 0.0)
		{
			TF2Items_SetAttribute(hItem, amount, 2025, g_KillstreakTier[client]);
			amount++;
		}

		if (g_KillstreakEffect[client] > 0.0)
		{
			TF2Items_SetAttribute(hItem, amount, 2013, g_KillstreakEffect[client]);
			amount++;
		}

		if (g_KillstreakSheen[client] > 0.0)
		{
			TF2Items_SetAttribute(hItem, amount, 2014, g_KillstreakSheen[client]);
			amount++;
		}

		TF2Items_SetNumAttributes(hItem, amount);
		
		TF2Items_SetFlags(hItem, OVERRIDE_ATTRIBUTES|PRESERVE_ATTRIBUTES);
		return Plugin_Changed;
	}

	return Plugin_Continue;
}

public void TF2Items_OnGiveNamedItem_Post(int client, char[] classname, int itemDefinitionIndex, int itemLevel, int itemQuality, int entityIndex)
{
	int slot = GetWeaponSlot(client, entityIndex);

	if (g_KillstreakTier[client] > 0.0)
		TF2Attrib_SetByName_Weapons(client, slot, "killstreak tier", g_KillstreakTier[client]);

	if (g_KillstreakEffect[client] > 0.0)
		TF2Attrib_SetByName_Weapons(client, slot, "killstreak effect", g_KillstreakEffect[client]);

	if (g_KillstreakSheen[client] > 0.0)
		TF2Attrib_SetByName_Weapons(client, slot, "killstreak idleeffect", g_KillstreakSheen[client]);
}