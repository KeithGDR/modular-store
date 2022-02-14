//Pragma
#pragma semicolon 1
#pragma newdecls required

//Module Info
#define MODULE_DESCRIPTION "The distributions module for the modular store system."
#define MODULE_VERSION "1.0.0"

//Sourcemod Includes
#include <sourcemod>
#include <sourcemod-misc>
#include <colorvariables>

//Our Includes
#include <modularstore/modularstore-globals>
#include <modularstore/modularstore-distributions>

#undef REQUIRE_PLUGIN
#include <modularstore/modularstore-currency>
#include <modularstore/modularstore-menu>
#define REQUIRE_PLUGIN

//ConVars
ConVar g_Convar_Status;

//Forwards

//Globals
bool g_Late;

ArrayList g_Distributions;
StringMap g_Setting_Type;
StringMap g_Setting_Description;
StringMap g_Setting_Print;
StringMap g_Setting_Credits;
StringMap g_Setting_Minutes;

public Plugin myinfo = 
{
	name = "[Modular Store] :: Distributions", 
	author = "Keith Warren (Shaders Allen)", 
	description = MODULE_DESCRIPTION, 
	version = MODULE_VERSION, 
	url = "https://github.com/ShadersAllen"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("modularstore-distributions");

	//CreateNative("ModularStore_GetCurrency", Native_GetCurrency);

	g_Late = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("modularstore-globals.phrases");
	LoadTranslations("modularstore-distributions.phrases");
	
	CreateConVar("sm_modularstore_distributions_version", MODULE_VERSION, MODULE_DESCRIPTION, FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_SPONLY | FCVAR_DONTRECORD);
	g_Convar_Status = CreateConVar("sm_modularstore_distributions_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	//AutoExecConfig(true, "store-distributions", "modularstore");

	g_Distributions = new ArrayList(ByteCountToCells(MAX_DISTRIBUTION_NAME_LENGTH));
	g_Setting_Type = new StringMap();
	g_Setting_Description = new StringMap();
	g_Setting_Print = new StringMap();
	g_Setting_Credits = new StringMap();
	g_Setting_Minutes = new StringMap();

	RegConsoleCmd("sm_distributions", Command_Distributions);
}

public void OnConfigsExecuted()
{
	if (g_Late)
	{
		g_Late = false;
	}
}

public void OnMapStart()
{
	if (!g_Convar_Status.BoolValue)
		return;
	
	ParseDistributions();

	char sDistribution[MAX_DISTRIBUTION_NAME_LENGTH]; char sType[MAX_TYPE_NAME_LENGTH]; char sPrint[255]; int credits; float minutes;
	DataPack pack;
	for (int i = 0; i < g_Distributions.Length; i++)
	{
		g_Distributions.GetString(i, sDistribution, sizeof(sDistribution));
		g_Setting_Type.GetString(sDistribution, sType, sizeof(sType));
		g_Setting_Print.GetString(sDistribution, sPrint, sizeof(sPrint));

		if (!StrEqual(sType, "timer", false))
			continue;
		
		g_Setting_Credits.GetValue(sDistribution, credits);
		g_Setting_Minutes.GetValue(sDistribution, minutes);

		pack = new DataPack();
		pack.WriteCell(credits);
		pack.WriteString(sPrint);

		CreateTimer((minutes * 60.0), Timer_GiveDistribution, pack, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_GiveDistribution(Handle timer, DataPack data)
{
	if (!g_Convar_Status.BoolValue)
		return Plugin_Continue;
	
	data.Reset();
	int credits = data.ReadCell();

	char sPrint[255];
	data.ReadString(sPrint, sizeof(sPrint));

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;
		
		ModularStore_AddCurrency(i, credits);
		
		if (strlen(sPrint) > 0)
			CPrintToChat(i, sPrint);
	}

	return Plugin_Continue;
}

void ParseDistributions()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/modularstore/distributions.cfg");

	KeyValues kv = new KeyValues("distributions");

	if (kv.ImportFromFile(sPath) && kv.GotoFirstSubKey())
	{
		g_Distributions.Clear();

		char sDistribution[MAX_DISTRIBUTION_NAME_LENGTH]; char sType[MAX_TYPE_NAME_LENGTH]; char sDescription[MAX_DESCRIPTION_LENGTH]; char sPrint[255]; int credits; float minutes;
		do
		{
			kv.GetSectionName(sDistribution, sizeof(sDistribution));

			if (g_Distributions.FindString(sDistribution) != -1)
				continue;

			g_Distributions.PushString(sDistribution);

			kv.GetString("type", sType, sizeof(sType));
			g_Setting_Type.SetString(sDistribution, sType);

			kv.GetString("description", sDescription, sizeof(sDescription));
			g_Setting_Description.SetString(sDistribution, sDescription);

			kv.GetString("print", sPrint, sizeof(sPrint));
			g_Setting_Print.SetString(sDistribution, sPrint);

			credits = kv.GetNum("credits");
			g_Setting_Credits.SetValue(sDistribution, credits);

			minutes = kv.GetFloat("minutes");
			g_Setting_Minutes.SetValue(sDistribution, minutes);
		}
		while (kv.GotoNextKey());
	}

	delete kv;
	LogMessage("Parsed %i distributions.", g_Distributions.Length);
}

public void OnAllPluginsLoaded()
{
	if (!g_Convar_Status.BoolValue)
		return;
	
	if (ModularStore_IsAcceptingItemRegistrations())
		ModularStore_OnRegisterItemsPost();
}

public void ModularStore_OnRegisterItemsPost()
{
	if (!g_Convar_Status.BoolValue)
		return;
	
	ModularStore_RegisterStoreItem("distributions", "How to Gain Credits", OnPress);
}

public void OnPress(int client)
{
	if (!g_Convar_Status.BoolValue)
		return;
	
	OpenDistributionsMenu(client, true);
}

public Action Command_Distributions(int client, int args)
{
	if (!g_Convar_Status.BoolValue)
		return Plugin_Handled;
	
	OpenDistributionsMenu(client, false);
	return Plugin_Handled;
}

void OpenDistributionsMenu(int client, bool back)
{
	Menu menu = new Menu(MenuHandler_Distributions);
	menu.SetTitle("How to Gain Credits:\n \n");

	char sDistribution[MAX_DISTRIBUTION_NAME_LENGTH]; char sDescription[MAX_DESCRIPTION_LENGTH]; char sDisplay[255];
	for (int i = 0; i < g_Distributions.Length; i++)
	{
		g_Distributions.GetString(i, sDistribution, sizeof(sDistribution));
		g_Setting_Description.GetString(sDistribution, sDescription, sizeof(sDescription));
		FormatEx(sDisplay, sizeof(sDisplay), "%s\n - %s", sDistribution, sDescription);
		menu.AddItem(sDistribution, sDisplay, ITEMDRAW_DISABLED);	
	}

	if (menu.ItemCount == 0)
		menu.AddItem("", " -- No Distributions Available --", ITEMDRAW_DISABLED);

	PushMenuBool(menu, "back", back);

	menu.ExitBackButton = back;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Distributions(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
			delete menu;
	}
}