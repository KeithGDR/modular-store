//Pragma
#pragma semicolon 1
#pragma newdecls required

//Defines
#define MODULE_DESCRIPTION "The item module for Trails for the modular store system."
#define MODULE_VERSION "1.0.0"
#define MODULE_NAME "trails"

//Sourcemod Includes
#include <sourcemod>
#include <sourcemod-misc>

//Our Includes
#include <modularstore/modularstore-items>

//ConVars
//ConVar g_Convar_Status;

//Forwards

//Globals
StringMap g_TrailPrecaches;
char g_TrailFile[MAXPLAYERS + 1][PLATFORM_MAX_PATH];
int g_TrailColor[MAXPLAYERS + 1][4];
float gF_LastPosition[MAXPLAYERS + 1][3];

public Plugin myinfo = 
{
	name = "[Modular Store] :: ItemModule - Trails", 
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

	g_TrailPrecaches = new StringMap();
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
	if ((status = ModularStore_RegisterItemType(MODULE_NAME, "Trails", OnAction)) != Register_Successful)
		LogError("Error registering this module with item type '%s'. [Error code %i]", MODULE_NAME, status);
}

public Action OnAction(int client, const char[] action, StringMap itemdata)
{
	if (StrEqual(action, "equip"))
	{
		char sFile[PLATFORM_MAX_PATH];
		itemdata.GetString("file", sFile, sizeof(sFile));

		if (StrContains(sFile, "materials/", false) != 0)
			Format(sFile, sizeof(sFile), "materials/%s", sFile);

		if (strlen(sFile) > 0 && !IsModelPrecached(sFile))
		{
			char sPrecache[PLATFORM_MAX_PATH];
			FormatEx(sPrecache, sizeof(sPrecache), "%s.vmt", sFile);
			g_TrailPrecaches.SetValue(sFile, PrecacheModel(sPrecache));
			AddFileToDownloadsTable(sPrecache);

			FormatEx(sPrecache, sizeof(sPrecache), "%s.vtf", sFile);
			AddFileToDownloadsTable(sPrecache);
		}

		strcopy(g_TrailFile[client], PLATFORM_MAX_PATH, sFile);

		int color[4];
		itemdata.GetArray("color", color, sizeof(color));
		CopyArrayToArray(color, g_TrailColor[client], 4);
	}
	else if (StrEqual(action, "unequip"))
	{
		g_TrailFile[client][0] = '\0';
		FillArrayToValue(g_TrailColor[client], 4, 255);
	}
}

public Action OnPlayerRunCmd(int client)
{
	ForceTrails(client);
	return Plugin_Continue;
}

void ForceTrails(int client)
{
	float fOrigin[3];
	GetClientAbsOrigin(client, fOrigin);
	
	CreatePlayerTrail(client, fOrigin);
	gF_LastPosition[client] = fOrigin;
}

void CreatePlayerTrail(int client, float origin[3])
{
	bool bClientTeleported = GetVectorDistance(origin, gF_LastPosition[client], false) > 50.0;
	
	if (strlen(g_TrailFile[client]) == 0 || !IsPlayerAlive(client) || bClientTeleported)
		return;
	
	if (TF2_IsPlayerInCondition(client, TFCond_Cloaked))
		return;
	
	float fFirstPos[3];
	fFirstPos[0] = origin[0];
	fFirstPos[1] = origin[1];
	fFirstPos[2] = origin[2] + 5.0;
	
	float fSecondPos[3];
	fSecondPos[0] = gF_LastPosition[client][0];
	fSecondPos[1] = gF_LastPosition[client][1];
	fSecondPos[2] = gF_LastPosition[client][2] + 5.0;

	int sprite;
	g_TrailPrecaches.GetValue(g_TrailFile[client], sprite);

	TE_SetupBeamPoints(fFirstPos, fSecondPos, sprite, 0, 0, 0, 1.5, 1.5, 1.5, 10, 0.0, g_TrailColor[client], 0);
	//TE_SendToAllInRange(origin, RangeType_Visibility, 0.0);
	TE_SendToAll();
}