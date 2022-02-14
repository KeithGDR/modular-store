//Pragma
#pragma semicolon 1
#pragma newdecls required

//Module Info
#define MODULE_DESCRIPTION "The TEMPLATE module for the modular store system."
#define MODULE_VERSION "1.0.0"

//Sourcemod Includes
#include <sourcemod>
#include <sourcemod-misc>
#include <colorvariables>

//Our Includes
#include <modularstore/modularstore-globals>
#include <modularstore/modularstore-TEMPLATE>

#undef REQUIRE_PLUGIN
#include <modularstore/modularstore-menu>
#define REQUIRE_PLUGIN

//ConVars
ConVar g_Convar_Status;

//Forwards

//Globals
bool g_Late;

public Plugin myinfo = 
{
	name = "[Modular Store] :: TEMPLATE", 
	author = "Keith Warren (Shaders Allen)", 
	description = MODULE_DESCRIPTION, 
	version = MODULE_VERSION, 
	url = "https://github.com/ShadersAllen"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("modularstore-TEMPLATE");

	//CreateNative("ModularStore_GetCurrency", Native_GetCurrency);

	g_Late = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("modularstore-globals.phrases");
	LoadTranslations("modularstore-TEMPLATE.phrases");
	
	CreateConVar("sm_modularstore_TEMPLATE_version", MODULE_VERSION, MODULE_DESCRIPTION, FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_SPONLY | FCVAR_DONTRECORD);
	g_Convar_Status = CreateConVar("sm_modularstore_TEMPLATE_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	//AutoExecConfig(true, "store-TEMPLATE", "modularstore");

	RegConsoleCmd("sm_TEMPLATE", Command_TEMPLATE);
}

public void OnConfigsExecuted()
{
	if (g_Late)
	{
		g_Late = false;
	}
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
	
	ModularStore_RegisterStoreItem("TEMPLATE", "How to TEMPLATE", OnPress);
}

public void OnPress(int client)
{
	if (!g_Convar_Status.BoolValue)
		return;
	
	OpenTEMPLATEMenu(client, true);
}

public Action Command_TEMPLATE(int client, int args)
{
	if (!g_Convar_Status.BoolValue)
		return Plugin_Handled;
	
	OpenTEMPLATEMenu(client, false);
	return Plugin_Handled;
}

void OpenTEMPLATEMenu(int client, bool back)
{
	Menu menu = new Menu(MenuHandler_TEMPLATE);
	menu.SetTitle("How to TEMPLATE:\n \n");

	if (menu.ItemCount == 0)
		menu.AddItem("", " -- No TEMPLATE Available --", ITEMDRAW_DISABLED);

	PushMenuBool(menu, "back", back);

	menu.ExitBackButton = back;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_TEMPLATE(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
			delete menu;
	}
}