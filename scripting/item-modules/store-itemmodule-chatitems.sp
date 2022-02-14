//Pragma
#pragma semicolon 1
#pragma newdecls required

//Defines
#define MODULE_DESCRIPTION "The item module for Chat Items for the modular store system."
#define MODULE_VERSION "1.0.0"
#define MODULE_NAME_TAGS "tags"
#define MODULE_NAME_TAGCOLORS "tagcolors"
#define MODULE_NAME_NAMECOLORS "namecolors"
#define MODULE_NAME_CHATCOLORS "chatcolors"

//Sourcemod Includes
#include <sourcemod>
#include <sourcemod-misc>
#include <chat-processor>

//Our Includes
#include <modularstore/modularstore-items>

//ConVars
//ConVar g_Convar_Status;

//Forwards

//Globals
char g_EquippedTag[MAXPLAYERS + 1][MAXLENGTH_NAME];
char g_EquippedTagColor[MAXPLAYERS + 1][MAXLENGTH_NAME];

public Plugin myinfo = 
{
	name = "[Modular Store] :: ItemModule - Chat Items", 
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
	if (ModularStore_IsItemTypeRegistered(MODULE_NAME_TAGS))
		ModularStore_UnregisterItemType(MODULE_NAME_TAGS);
	
	if (ModularStore_IsItemTypeRegistered(MODULE_NAME_TAGCOLORS))
		ModularStore_UnregisterItemType(MODULE_NAME_TAGCOLORS);
	
	if (ModularStore_IsItemTypeRegistered(MODULE_NAME_NAMECOLORS))
		ModularStore_UnregisterItemType(MODULE_NAME_NAMECOLORS);
	
	if (ModularStore_IsItemTypeRegistered(MODULE_NAME_CHATCOLORS))
		ModularStore_UnregisterItemType(MODULE_NAME_CHATCOLORS);
	
	ModularStore_OnRegisterItemTypesPost();
}

public void ModularStore_OnRegisterItemTypesPost()
{
	RegisterStatus status;
	
	status = Register_Successful;
	if ((status = ModularStore_RegisterItemType(MODULE_NAME_TAGS, "Tags", OnAction_Tag)) != Register_Successful)
		LogError("Error registering this module with item type '%s'. [Error code %i]", MODULE_NAME_TAGS, status);
	
	status = Register_Successful;
	if ((status = ModularStore_RegisterItemType(MODULE_NAME_TAGCOLORS, "Tag Colors", OnAction_TagColor)) != Register_Successful)
		LogError("Error registering this module with item type '%s'. [Error code %i]", MODULE_NAME_TAGCOLORS, status);
	
	status = Register_Successful;
	if ((status = ModularStore_RegisterItemType(MODULE_NAME_NAMECOLORS, "Name Colors", OnAction_NameColor)) != Register_Successful)
		LogError("Error registering this module with item type '%s'. [Error code %i]", MODULE_NAME_NAMECOLORS, status);
	
	status = Register_Successful;
	if ((status = ModularStore_RegisterItemType(MODULE_NAME_CHATCOLORS, "Chat Colors", OnAction_ChatColor)) != Register_Successful)
		LogError("Error registering this module with item type '%s'. [Error code %i]", MODULE_NAME_CHATCOLORS, status);
}

public Action OnAction_Tag(int client, const char[] action, StringMap itemdata)
{
	if (StrEqual(action, "equip"))
	{
		char sTag[MAXLENGTH_NAME];
		itemdata.GetString("tag", sTag, sizeof(sTag));
		
		ChatProcessor_AddClientTag(client, sTag);
		strcopy(g_EquippedTag[client], MAXLENGTH_NAME, sTag);

		if (strlen(g_EquippedTagColor[client]) > 0)
			ChatProcessor_SetTagColor(client, g_EquippedTag[client], g_EquippedTagColor[client]);
	}
	else if (StrEqual(action, "unequip"))
	{
		ChatProcessor_RemoveClientTag(client, g_EquippedTag[client]);
		g_EquippedTag[client][0] = '\0';
	}
}

public Action OnAction_TagColor(int client, const char[] action, StringMap itemdata)
{
	if (StrEqual(action, "equip"))
	{
		char sColor[MAXLENGTH_NAME];
		itemdata.GetString("color", sColor, sizeof(sColor));
		strcopy(g_EquippedTagColor[client], MAXLENGTH_NAME, sColor);

		if (strlen(g_EquippedTag[client]) > 0)
			ChatProcessor_SetTagColor(client, g_EquippedTag[client], sColor);
	}
	else if (StrEqual(action, "unequip"))
	{
		g_EquippedTagColor[client][0] = '\0';
		
		if (strlen(g_EquippedTag[client]) > 0)
			ChatProcessor_SetTagColor(client, g_EquippedTag[client], "");
	}
}

public Action OnAction_NameColor(int client, const char[] action, StringMap itemdata)
{
	if (StrEqual(action, "equip"))
	{
		char sColor[MAXLENGTH_NAME];
		itemdata.GetString("color", sColor, sizeof(sColor));
		
		ChatProcessor_SetNameColor(client, sColor);
	}
	else if (StrEqual(action, "unequip"))
	{
		ChatProcessor_SetNameColor(client, "");
	}
}

public Action OnAction_ChatColor(int client, const char[] action, StringMap itemdata)
{
	if (StrEqual(action, "equip"))
	{
		char sColor[MAXLENGTH_NAME];
		itemdata.GetString("color", sColor, sizeof(sColor));
		
		ChatProcessor_SetChatColor(client, sColor);
	}
	else if (StrEqual(action, "unequip"))
	{
		ChatProcessor_SetChatColor(client, "");
	}
}