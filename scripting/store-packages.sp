//Pragma
#pragma semicolon 1
#pragma newdecls required

//Module Info
#define MODULE_DESCRIPTION "The packages module for the modular store system."
#define MODULE_VERSION "1.0.0"

//Sourcemod Includes
#include <sourcemod>
#include <sourcemod-misc>

//Our Includes
#include <modularstore/modularstore-globals>
#include <modularstore/modularstore-packages>

#undef REQUIRE_PLUGIN
#include <modularstore/modularstore-menu>
#define REQUIRE_PLUGIN

//ConVars
ConVar g_Convar_Status;

//Forwards

//Globals
ArrayList g_Packages;
StringMap g_PackageDescriptions;
StringMap g_PackagePrice;
StringMap g_PackageSale;
StringMap g_PackageItems;	//Handle Hell

public Plugin myinfo = 
{
	name = "[Modular Store] :: Packages", 
	author = "Keith Warren (Shaders Allen)", 
	description = MODULE_DESCRIPTION, 
	version = MODULE_VERSION, 
	url = "https://github.com/ShadersAllen"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("modularstore-packages");

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("modularstore-globals.phrases");
	LoadTranslations("modularstore-packages.phrases");
	
	CreateConVar("sm_modularstore_packages_version", MODULE_VERSION, MODULE_DESCRIPTION, FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_SPONLY | FCVAR_DONTRECORD);
	g_Convar_Status = CreateConVar("sm_modularstore_packages_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	//AutoExecConfig(true, "store-packages", "modularstore");

	g_Packages = new ArrayList(ByteCountToCells(MAX_PACKAGE_NAME_LENGTH));
	g_PackageDescriptions = new StringMap();
	g_PackagePrice = new StringMap();
	g_PackageSale = new StringMap();
	g_PackageItems = new StringMap();

	RegConsoleCmd("sm_packages", Command_Packages);
}

public void OnConfigsExecuted()
{
	if (!g_Convar_Status.BoolValue)
		return;
	
	ParsePackagesConfig();
}

void ParsePackagesConfig()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/modularstore/packages.cfg");

	KeyValues kv = new KeyValues("packages");

	if (kv.ImportFromFile(sPath) && kv.GotoFirstSubKey())
	{
		g_Packages.Clear();
		g_PackageDescriptions.Clear();
		g_PackagePrice.Clear();
		g_PackageSale.Clear();
		g_PackageItems.Clear();

		char sPackage[MAX_PACKAGE_NAME_LENGTH]; char sDescription[MAX_DESCRIPTION_LENGTH]; int price; float sale;
		char sCategory[MAX_CATEGORY_NAME_LENGTH]; char sItem[MAX_ITEM_NAME_LENGTH]; ArrayList categories; ArrayList items;
		do
		{
			kv.GetSectionName(sPackage, sizeof(sPackage));

			if (g_Packages.FindString(sPackage) != -1)
				continue;

			g_Packages.PushString(sPackage);
			
			kv.GetString("description", sDescription, sizeof(sDescription));
			g_PackageDescriptions.SetString(sPackage, sDescription);

			price = kv.GetNum("price", -1);
			g_PackagePrice.SetValue(sPackage, price);

			sale = kv.GetFloat("sale");
			g_PackageSale.SetValue(sPackage, sale);

			if (kv.JumpToKey("items") && kv.GotoFirstSubKey(false))
			{
				categories = new ArrayList(ByteCountToCells(MAX_CATEGORY_NAME_LENGTH));
				items = new ArrayList(ByteCountToCells(MAX_ITEM_NAME_LENGTH));

				do
				{
					kv.GetSectionName(sCategory, sizeof(sCategory));
					categories.PushString(sCategory);

					kv.GetString(NULL_STRING, sItem, sizeof(sItem));
					items.PushString(sItem);
				}
				while (kv.GotoNextKey(false));

				char sBuffer[MAX_PACKAGE_NAME_LENGTH + 12];

				FormatEx(sBuffer, sizeof(sBuffer), "%s_categories", sPackage);
				g_PackageItems.SetValue(sBuffer, categories);
				
				FormatEx(sBuffer, sizeof(sBuffer), "%s_items", sPackage);
				g_PackageItems.SetValue(sBuffer, items);

				kv.GoBack();
				kv.GoBack();
			}
		}
		while (kv.GotoNextKey());
	}

	delete kv;
	LogMessage("%i package%s loaded and available.", g_Packages.Length, g_Packages.Length == 1 ? " is" : "s are");
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
	
	ModularStore_RegisterStoreItem("packages", "Browse Item Packages", OnPress);
}

public void OnPress(int client)
{
	if (!g_Convar_Status.BoolValue)
		return;
	
	OpenPackagesMenu(client, true);
}

public Action Command_Packages(int client, int args)
{
	if (!g_Convar_Status.BoolValue)
		return Plugin_Handled;
	
	OpenPackagesMenu(client, false);
	return Plugin_Handled;
}

void OpenPackagesMenu(int client, bool back)
{
	if (!IsShaders(client))
	{
		PrintToChat(client, "This feature is currently disabled.");

		if (back)
			ModularStore_OpenStoreMenu(client);
		
		return;
	}

	Menu menu = new Menu(MenuHandler_Packages);
	menu.SetTitle("Available Packages:");

	char sPackage[MAX_PACKAGE_NAME_LENGTH]; char sDisplay[MAX_DISPLAY_NAME_LENGTH];
	for (int i = 0; i < g_Packages.Length; i++)
	{
		g_Packages.GetString(i, sPackage, sizeof(sPackage));
		FormatEx(sDisplay, sizeof(sDisplay), "%s", sPackage);
		menu.AddItem(sPackage, sDisplay);
	}

	if (menu.ItemCount == 0)
		menu.AddItem("", " -- No Packages Available --", ITEMDRAW_DISABLED);

	PushMenuBool(menu, "back", back);

	menu.ExitBackButton = back;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Packages(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sPackage[MAX_PACKAGE_NAME_LENGTH];
			menu.GetItem(param2, sPackage, sizeof(sPackage));

			OpenPackageMenu(param1, sPackage);
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				ModularStore_OpenStoreMenu(param1);
		}
		case MenuAction_End:
			delete menu;
	}
}

void OpenPackageMenu(int client, const char[] pack)
{
	char sDescription[MAX_DESCRIPTION_LENGTH];
	g_PackageDescriptions.GetString(pack, sDescription, sizeof(sDescription));

	int price;
	g_PackagePrice.GetValue(pack, price);

	Menu menu = new Menu(MenuHandler_Package);
	menu.SetTitle("Package Information for %s:\n - Description: %s\n - Price: %i\n \n", pack, sDescription, price);

	menu.AddItem("purchase", "Purchase Package");
	menu.AddItem("use", "Open Package");
	menu.AddItem("gift", "Gift Package");

	PushMenuString(menu, "pack", pack);
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Package(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sAction[MAX_ACTION_NAME_LENGTH];
			menu.GetItem(param2, sAction, sizeof(sAction));

			char sPackage[MAX_PACKAGE_NAME_LENGTH];
			GetMenuString(menu, "pack", sPackage, sizeof(sPackage));

			ExecutePackageAction(param1, sPackage, sAction);
		}
		case MenuAction_End:
			delete menu;
	}
}

void ExecutePackageAction(int client, const char[] pack, const char[] action)
{
	PrintToChat(client, "Package: %s - Action: %s", pack, action);
}