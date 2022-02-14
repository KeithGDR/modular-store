//Pragma
#pragma semicolon 1
#pragma newdecls required

//Module Info
#define MODULE_DESCRIPTION "The store menu module for the modular store system."
#define MODULE_VERSION "1.0.0"

//Sourcemod Includes
#include <sourcemod>
#include <sourcemod-misc>

//Our Includes
#include <modularstore/modularstore-globals>
#include <modularstore/modularstore-menu>

#undef REQUIRE_PLUGIN
#include <modularstore/modularstore-currency>
#define REQUIRE_PLUGIN

//ConVars
ConVar g_Convar_Status;

//Forwards
Handle g_Forward_RegisterItemsPost;

//Globals
ArrayList g_StoreMenu_Items;
StringMap g_StoreMenu_Displays;
StringMap g_StoreMenu_Callbacks;	//Handle Hell

public Plugin myinfo = 
{
	name = "[Modular Store] :: Store Menu", 
	author = "Keith Warren (Shaders Allen)", 
	description = MODULE_DESCRIPTION, 
	version = MODULE_VERSION, 
	url = "https://github.com/ShadersAllen"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	MarkNativeAsOptional("ModularStore_GetCurrency");

	RegPluginLibrary("modularstore-menu");

	CreateNative("ModularStore_ReloadStoreItems", Native_ReloadStoreItems);
	CreateNative("ModularStore_RegisterStoreItem", Native_RegisterStoreItem);
	CreateNative("ModularStore_IsAcceptingItemRegistrations", Native_IsAcceptingItemRegistrations);
	CreateNative("ModularStore_OpenStoreMenu", Native_OpenStoreMenu);

	g_Forward_RegisterItemsPost = CreateGlobalForward("ModularStore_OnRegisterItemsPost", ET_Ignore);

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("modularstore-globals.phrases");
	LoadTranslations("modularstore-menu.phrases");
	
	CreateConVar("sm_modularstore_menu_version", MODULE_VERSION, MODULE_DESCRIPTION, FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_SPONLY | FCVAR_DONTRECORD);
	g_Convar_Status = CreateConVar("sm_modularstore_menu_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	//AutoExecConfig(true, "store-menu", "modularstore");

	g_StoreMenu_Items = new ArrayList(ByteCountToCells(MAX_ITEM_NAME_LENGTH));
	g_StoreMenu_Displays = new StringMap();
	g_StoreMenu_Callbacks = new StringMap();

	RegConsoleCmd("sm_store", Command_Store, "Open the store main menu.");
	RegAdminCmd("sm_reloadstore", Command_ReloadStore, ADMFLAG_ROOT, "Reload the store menu.");
}

public void OnAllPluginsLoaded()
{
	if (!g_Convar_Status.BoolValue)
		return;
	
	ReloadStoreMenu();
}

public Action Command_Store(int client, int args)
{
	if (!g_Convar_Status.BoolValue)
		return Plugin_Handled;
	
	OpenStoreMenu(client);
	return Plugin_Handled;
}

bool OpenStoreMenu(int client)
{
	if (!g_Convar_Status.BoolValue)
		return false;

	char sCurrency[MAX_CURRENCY_NAME_LENGTH + 16];
	if (LibraryExists("modularstore-currency"))
	{
		FindConVar("sm_modularstore_currency_default").GetString(sCurrency, sizeof(sCurrency));
		Format(sCurrency, sizeof(sCurrency), " - %i %s", ModularStore_GetCurrency(client, sCurrency), sCurrency);
	}
	
	Menu menu = new Menu(MenuHandler_StoreMenu);
	menu.SetTitle("Store Menu%s", sCurrency);

	char sInfo[MAX_ITEM_NAME_LENGTH]; char sDisplay[MAX_DISPLAY_NAME_LENGTH];
	for (int i = 0; i < g_StoreMenu_Items.Length; i++)
	{
		g_StoreMenu_Items.GetString(i, sInfo, sizeof(sInfo));

		g_StoreMenu_Displays.GetString(sInfo, sDisplay, sizeof(sDisplay));
		menu.AddItem(sInfo, sDisplay);
	}

	if (menu.ItemCount == 0)
		menu.AddItem("", " -- Not Categories Available --", ITEMDRAW_DISABLED);

	menu.Display(client, MENU_TIME_FOREVER);

	return true;
}

public int MenuHandler_StoreMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sInfo[MAX_ITEM_NAME_LENGTH];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			Handle call;
			if (!g_StoreMenu_Callbacks.GetValue(sInfo, call) || call == null)
			{
				OpenStoreMenu(param1);
				return;
			}

			Call_StartForward(call);
			Call_PushCell(param1);
			Call_Finish();
		}
		case MenuAction_End:
			delete menu;
	}
}

public Action Command_ReloadStore(int client, int args)
{
	if (!g_Convar_Status.BoolValue)
		return Plugin_Handled;
	
	ReloadStoreMenu();
	return Plugin_Handled;
}

bool ReloadStoreMenu()
{
	if (!g_Convar_Status.BoolValue)
		return false;
	
	char sItem[MAX_ITEM_NAME_LENGTH]; Handle call;
	for (int i = 0; i < g_StoreMenu_Items.Length; i++)
	{
		g_StoreMenu_Items.GetString(i, sItem, sizeof(sItem));
		g_StoreMenu_Items.Erase(i);

		g_StoreMenu_Displays.Remove(sItem);

		g_StoreMenu_Callbacks.GetValue(sItem, call);
		delete call;
		g_StoreMenu_Callbacks.Remove(sItem);
	}

	Call_StartForward(g_Forward_RegisterItemsPost);
	Call_Finish();

	return true;
}

public int Native_ReloadStoreItems(Handle plugin, int numParams)
{
	if (!g_Convar_Status.BoolValue)
		return ThrowNativeError(SP_ERROR_NATIVE, "Plugin is currently disabled.");
	
	return ReloadStoreMenu();
}

bool RegisterStoreItem(Handle plugin, const char[] item, const char[] display, Function callback)
{
	if (!g_Convar_Status.BoolValue)
		return false;
	
	Handle call;

	int index = -1;
	if ((index = g_StoreMenu_Items.FindString(item)) != -1)
	{
		g_StoreMenu_Items.Erase(index);

		g_StoreMenu_Callbacks.GetValue(item, call);
		delete call;
	}
	
	g_StoreMenu_Items.PushString(item);
	g_StoreMenu_Displays.SetString(item, display);

	call = CreateForward(ET_Ignore, Param_Cell);
	AddToForward(call, plugin, callback);
	g_StoreMenu_Callbacks.SetValue(item, call);

	return true;
}

public int Native_RegisterStoreItem(Handle plugin, int numParams)
{
	if (!g_Convar_Status.BoolValue)
		return ThrowNativeError(SP_ERROR_NATIVE, "Plugin is currently disabled.");
	
	int size;

	GetNativeStringLength(1, size); size++;
	char[] sItem = new char[size];
	GetNativeString(1, sItem, size);

	GetNativeStringLength(2, size); size++;
	char[] sDisplay = new char[size];
	GetNativeString(2, sDisplay, size);

	Function callback = GetNativeFunction(3);
	
	return RegisterStoreItem(plugin, sItem, sDisplay, callback);
}

bool IsAcceptingItemRegistrations()
{
	if (!g_Convar_Status.BoolValue)
		return false;
	
	return g_StoreMenu_Items != null;
}

public int Native_IsAcceptingItemRegistrations(Handle plugin, int numParams)
{
	if (!g_Convar_Status.BoolValue)
		return ThrowNativeError(SP_ERROR_NATIVE, "Plugin is currently disabled.");
	
	return IsAcceptingItemRegistrations();
}

public int Native_OpenStoreMenu(Handle plugin, int numParams)
{
	OpenStoreMenu(GetNativeCell(1));
}