//Pragma
#pragma semicolon 1
#pragma newdecls required

//Defines
#define CATEGORY_DELIMITER "||"

//Module Info
#define MODULE_DESCRIPTION "The shop module for the modular store system."
#define MODULE_VERSION "1.0.0"

//Sourcemod Includes
#include <sourcemod>
#include <sourcemod-misc>
#include <colorvariables>

//Our Includes
#include <modularstore/modularstore-globals>
#include <modularstore/modularstore-shop>

#undef REQUIRE_PLUGIN
#include <modularstore/modularstore-items>
#include <modularstore/modularstore-inventory>
#include <modularstore/modularstore-menu>
#include <modularstore/modularstore-currency>
#define REQUIRE_PLUGIN

//ConVars
ConVar g_Convar_Status;

//Forwards
Handle g_Forward_OnShopOpen;
Handle g_Forward_OnShopOpenPost;

//Globals
ArrayList g_Categories;
StringMap g_ItemsData;	//Handle Hell

public Plugin myinfo = 
{
	name = "[Modular Store] :: Shop", 
	author = "Keith Warren (Shaders Allen)", 
	description = MODULE_DESCRIPTION, 
	version = MODULE_VERSION, 
	url = "https://github.com/ShadersAllen"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("modularstore-shop");

	CreateNative("ModularStore_OpenShopMenu", Native_OpenShopMenu);
	CreateNative("ModularStore_OpenCategoriesMenu", Native_OpenCategoriesMenu);
	CreateNative("ModularStore_OpenShopItemMenu", Native_OpenShopItemMenu);
	CreateNative("ModularStore_GetItemType", Native_GetItemType);
	CreateNative("ModularStore_GetItemsList", Native_GetItemsList);
	CreateNative("ModularStore_GetItemsData", Native_GetItemsData);
	CreateNative("ModularStore_GetItemData", Native_GetItemData);
	CreateNative("ModularStore_GetItemDataValue", Native_GetItemDataValue);
	CreateNative("ModularStore_GetItemDataFloat", Native_GetItemDataFloat);
	CreateNative("ModularStore_GetItemDataString", Native_GetItemDataString);
	CreateNative("ModularStore_GetItemDataBool", Native_GetItemDataBool);

	g_Forward_OnShopOpen = CreateGlobalForward("ModularStore_OnShopOpen", ET_Event, Param_Cell);
	g_Forward_OnShopOpenPost = CreateGlobalForward("ModularStore_OnShopOpenPost", ET_Ignore, Param_Cell);

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("modularstore-globals.phrases");
	LoadTranslations("modularstore-shop.phrases");
	
	CreateConVar("sm_modularstore_shop_version", MODULE_VERSION, MODULE_DESCRIPTION, FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_SPONLY | FCVAR_DONTRECORD);
	g_Convar_Status = CreateConVar("sm_modularstore_shop_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	//AutoExecConfig(true, "store-shop", "modularstore");

	g_Categories = new ArrayList(ByteCountToCells(MAX_CATEGORY_NAME_LENGTH));
	g_ItemsData = new StringMap();

	RegConsoleCmd("sm_shop", Command_Shop);
	RegAdminCmd("sm_reloadshop", Command_ReloadShop, ADMFLAG_ROOT);
}

public void OnConfigsExecuted()
{
	if (!g_Convar_Status.BoolValue)
		return;
	
	ParseShopConfig();
}

public Action Command_ReloadShop(int client, int args)
{
	if (!g_Convar_Status.BoolValue)
		return Plugin_Handled;
	
	ParseShopConfig();
	CPrintToChat(client, "Categories and items have been updated.");
	return Plugin_Handled;
}

void ParseShopConfig()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/modularstore/shop.cfg");

	KeyValues kv = new KeyValues("shop");
	int total_items;

	if (kv.ImportFromFile(sPath) && kv.GotoFirstSubKey())
	{
		g_Categories.Clear();

		char sCategory[MAX_CATEGORY_NAME_LENGTH];
		
		do
		{
			kv.GetSectionName(sCategory, sizeof(sCategory));

			if (strlen(sCategory) == 0)
				continue;
			
			g_Categories.PushString(sCategory);

			if (kv.GotoFirstSubKey(false))
			{
				StringMap itemsdata = new StringMap();
				ArrayList itemslist = new ArrayList(ByteCountToCells(MAX_ITEM_NAME_LENGTH));
				char sItemName[MAX_ITEM_NAME_LENGTH]; 
				
				do
				{
					kv.GetSectionName(sItemName, sizeof(sItemName));
					
					if (kv.GotoFirstSubKey(false))
					{
						StringMap itemdata = new StringMap();
						char sKey[512];
						
						int iValue;
						float fValue;
						char sValue[2048];
						int cValue[4];

						do
						{
							kv.GetSectionName(sKey, sizeof(sKey));
							
							if (StrEqual(sKey, "downloads"))
								continue;

							switch (kv.GetDataType(NULL_STRING))
							{
								case KvData_Int:
								{
									iValue = kv.GetNum(NULL_STRING);
									itemdata.SetValue(sKey, iValue);
								}
								case KvData_Float:
								{
									fValue = kv.GetFloat(NULL_STRING);
									itemdata.SetValue(sKey, fValue);
								}
								case KvData_String:
								{
									kv.GetString(NULL_STRING, sValue, sizeof(sValue));
									itemdata.SetString(sKey, sValue);
								}
								case KvData_Color:
								{
									kv.GetColor4(NULL_STRING, cValue);
									itemdata.SetArray(sKey, cValue, sizeof(cValue));
								}
							}
						}
						while (kv.GotoNextKey(false));

						itemsdata.SetValue(sItemName, itemdata);
						itemslist.PushString(sItemName);
						total_items++;

						kv.GoBack();
					}

					if (kv.JumpToKey("downloads") && kv.GotoFirstSubKey(false))
					{
						char sDKey[12]; char sDValue[PLATFORM_MAX_PATH];
						do
						{
							kv.GetSectionName(sDKey, sizeof(sDKey));
							kv.GetString(NULL_STRING, sDValue, sizeof(sDValue));

							AddFileToDownloadsTable(sDValue);
						}
						while (kv.GotoNextKey(false));

						kv.GoBack();
						kv.GoBack();
					}
				}
				while (kv.GotoNextKey(false));

				g_ItemsData.SetValue(sCategory, itemsdata);

				char sCategoryList[MAX_CATEGORY_NAME_LENGTH + 12];
				FormatEx(sCategoryList, sizeof(sCategoryList), "%s_list", sCategory);
				g_ItemsData.SetValue(sCategoryList, itemslist);

				kv.GoBack();
			}
		}
		while (kv.GotoNextKey());
	}

	delete kv;
	LogMessage("Parsed %i categories and %i total items.", g_Categories.Length, total_items);
}

public void OnAllPluginsLoaded()
{
	if (!g_Convar_Status.BoolValue)
		return;
	
	//if (ModularStore_IsAcceptingItemRegistrations())
		//ModularStore_OnRegisterItemsPost();
}

public void ModularStore_OnRegisterItemsPost()
{
	if (!g_Convar_Status.BoolValue)
		return;
	
	ModularStore_RegisterStoreItem("shop", "Shop for Items", OnPress);
}

public void OnPress(int client)
{
	if (!g_Convar_Status.BoolValue)
		return;
	
	OpenShopMenu(client, true);
}

public Action Command_Shop(int client, int args)
{
	if (!g_Convar_Status.BoolValue)
		return Plugin_Handled;
	
	OpenShopMenu(client, false);
	return Plugin_Handled;
}

bool OpenShopMenu(int client, bool back)
{
	if (!g_Convar_Status.BoolValue)
		return false;
	
	Call_StartForward(g_Forward_OnShopOpen);
	Call_PushCell(client);
	Call_Finish();

	Menu menu = new Menu(MenuHandler_Shop);
	menu.SetTitle("Pick a category:");

	char sCategory[MAX_CATEGORY_NAME_LENGTH];
	for (int i = 0; i < g_Categories.Length; i++)
	{
		g_Categories.GetString(i, sCategory, sizeof(sCategory));
		menu.AddItem(sCategory, sCategory);
	}
	
	if (menu.ItemCount == 0)
		menu.AddItem("", " -- No Categories Available --");

	PushMenuBool(menu, "back", back);

	menu.ExitBackButton = back;
	menu.Display(client, MENU_TIME_FOREVER);

	Call_StartForward(g_Forward_OnShopOpenPost);
	Call_PushCell(client);
	Call_Finish();

	return true;
}

public int MenuHandler_Shop(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sCategory[MAX_CATEGORY_NAME_LENGTH];
			menu.GetItem(param2, sCategory, sizeof(sCategory));

			bool back = GetMenuBool(menu, "back");

			OpenCategoryMenu(param1, sCategory, back);
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

public int Native_OpenShopMenu(Handle plugin, int numParams)
{
	if (!g_Convar_Status.BoolValue)
		return ThrowNativeError(SP_ERROR_NATIVE, "Plugin is currently disabled.");
	
	int client = GetNativeCell(1);

	return OpenShopMenu(client, false);
}

bool OpenCategoryMenu(int client, const char[] category, bool back)
{
	if (!g_Convar_Status.BoolValue)
		return false;
	
	StringMap itemsdata;
	if (!g_ItemsData.GetValue(category, itemsdata) || itemsdata == null)
	{
		PrintToChat(client, "No Items available for this category.");
		OpenShopMenu(client, back);
		return false;
	}

	char sCategoryList[MAX_CATEGORY_NAME_LENGTH + 12];
	FormatEx(sCategoryList, sizeof(sCategoryList), "%s_list", category);

	ArrayList itemslist;
	if (!g_ItemsData.GetValue(sCategoryList, itemslist) || itemslist == null)
	{
		PrintToChat(client, "No Items available for this category.");
		OpenShopMenu(client, back);
		return false;
	}

	Menu menu = new Menu(MenuHandler_Category);
	menu.SetTitle("Pick an item under %s:", category);

	char sItemName[MAX_ITEM_NAME_LENGTH]; char sItemDisplay[MAX_DISPLAY_NAME_LENGTH]; int draw = ITEMDRAW_DEFAULT; char sStatus[MAX_STATUS_NAME_LENGTH];
	for (int i = 0; i < itemslist.Length; i++)
	{
		itemslist.GetString(i, sItemName, sizeof(sItemName));

		if (ModularStore_GetItemDataString(category, sItemName, "status", sStatus, sizeof(sStatus)) && StrEqual(sStatus, "invisible", false))
			draw = ITEMDRAW_RAWLINE;
		else
			FormatEx(sItemDisplay, sizeof(sItemDisplay), "%s %s", sItemName, ModularStore_IsItemEquipped(client, category, sItemName) ? "(equipped)" : "");
		
		menu.AddItem(sItemName, sItemDisplay, draw);
	}

	PushMenuString(menu, "category", category);
	PushMenuBool(menu, "back", back);
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);

	return true;
}

public int MenuHandler_Category(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sItemName[MAX_ITEM_NAME_LENGTH];
			menu.GetItem(param2, sItemName, sizeof(sItemName));

			char sCategory[MAX_CATEGORY_NAME_LENGTH];
			GetMenuString(menu, "category", sCategory, sizeof(sCategory));

			bool back = GetMenuBool(menu, "back");

			OpenShopItemMenu(param1, sCategory, sItemName, back);
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				bool back = GetMenuBool(menu, "back");
				OpenShopMenu(param1, back);
			}
		}
		case MenuAction_End:
			delete menu;
	}
}

public int Native_OpenCategoriesMenu(Handle plugin, int numParams)
{
	if (!g_Convar_Status.BoolValue)
		return ThrowNativeError(SP_ERROR_NATIVE, "Plugin is currently disabled.");
	
	int client = GetNativeCell(1);

	int size;
	GetNativeStringLength(2, size); size++;
	
	char[] sCategory = new char[size];
	GetNativeString(2, sCategory, size);

	return OpenCategoryMenu(client, sCategory, false);
}

bool OpenShopItemMenu(int client, const char[] category, const char[] item, bool back)
{
	if (!g_Convar_Status.BoolValue)
		return false;
	
	StringMap itemsdata;
	if (!g_ItemsData.GetValue(category, itemsdata) || itemsdata == null)
	{
		PrintToChat(client, "Item %s not available.", item);
		OpenCategoryMenu(client, category, false);
		return false;
	}

	StringMap itemdata;
	if (!itemsdata.GetValue(item, itemdata) || itemdata == null)
	{
		PrintToChat(client, "Item %s not available.", item);
		OpenCategoryMenu(client, category, false);
		return false;
	}
	
	char sItemDescription[MAX_DESCRIPTION_LENGTH];
	itemdata.GetString("description", sItemDescription, sizeof(sItemDescription));

	char sItemType[MAX_TYPE_NAME_LENGTH];
	itemdata.GetString("type", sItemType, sizeof(sItemType));

	int iPrice;
	itemdata.GetValue("price", iPrice);

	char sItemTypeDisplay[MAX_DISPLAY_NAME_LENGTH];
	ModularStore_GetItemTypeDisplay(sItemType, sItemTypeDisplay, sizeof(sItemTypeDisplay));

	int amount = ModularStore_GetItemCount(client, category, item);
	
	char sDescription[64];
	FormatEx(sDescription, sizeof(sDescription), "Description: %s\n", sItemDescription);

	char sPrice[64];
	FormatEx(sPrice, sizeof(sPrice), "Price: %i\n", iPrice);

	char sType[64];
	FormatEx(sType, sizeof(sType), "Type: %s\n", sItemTypeDisplay);

	char sAmount[12];
	FormatEx(sAmount, sizeof(sAmount), "Owned: %i\n ", amount);

	Menu menu = new Menu(MenuHandler_Item);
	menu.SetTitle("Item Information for %s:\n%s%s%s%s \n", item, strlen(sItemDescription) > 0 ? sDescription : "\n", iPrice > 0 ? sPrice : "\n", strlen(sItemTypeDisplay) > 0 ? sType : "\n", amount > 0 ? sAmount : "\n");

	char sItemActions[MAX_ACTIONS_LENGTH];
	itemdata.GetString("actions", sItemActions, sizeof(sItemActions));

	bool buyable = true;

	char sFlags_Buyable[MAX_FLAGS_LENGTH];
	itemdata.GetString("flags_buyable", sFlags_Buyable, sizeof(sFlags_Buyable));

	if (itemdata.GetString("flags_buyable", sFlags_Buyable, sizeof(sFlags_Buyable)) && strlen(sFlags_Buyable) > 0 && !CheckCommandAccess(client, "", ReadFlagString(sFlags_Buyable), true))
		buyable = false;
	
	char sSteamIDs_Buyable[2048];
	if (itemdata.GetString("steamids_buyable", sSteamIDs_Buyable, sizeof(sSteamIDs_Buyable)) && strlen(sSteamIDs_Buyable) > 0)
	{
		char sSteamID[MAX_STEAMID_LENGTH];
		GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));
		
		if (StrContains(sSteamIDs_Buyable, sSteamID, false) == -1)
			buyable = false;
	}

	int max_player;
	if (itemdata.GetValue("max_player", max_player) && max_player > 0 && amount > max_player)
		buyable = false;

	int price;
	if (itemdata.GetValue("price", price) && price > 0 && price > ModularStore_GetCurrency(client))
		buyable = false;
	
	if (StrEqual(sItemActions, STORE_ITEMACTION_ALL, false))
	{
		menu.AddItem(STORE_ITEMACTION_BUY, "Buy Item", buyable ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		menu.AddItem(STORE_ITEMACTION_SELL, "Sell Item", amount > 0 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		menu.AddItem(STORE_ITEMACTION_PREVIEW, "Preview Item");
	}
	else
	{
		if (StrContains(sItemActions, STORE_ITEMACTION_BUY, false) != -1)
			menu.AddItem(STORE_ITEMACTION_BUY, "Buy Item", buyable ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

		if (StrContains(sItemActions, STORE_ITEMACTION_SELL, false) != -1)
			menu.AddItem(STORE_ITEMACTION_SELL, "Sell Item", amount > 0 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		
		if (StrContains(sItemActions, STORE_ITEMACTION_PREVIEW, false) != -1)
			menu.AddItem(STORE_ITEMACTION_PREVIEW, "Preview Item");
	}

	if (menu.ItemCount == 0)
		menu.AddItem("", " -- No Actions Available --");

	PushMenuString(menu, "item", item);
	PushMenuString(menu, "category", category);
	PushMenuBool(menu, "back", back);

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);

	return true;
}

public int MenuHandler_Item(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sItemAction[MAX_ACTION_NAME_LENGTH];
			menu.GetItem(param2, sItemAction, sizeof(sItemAction));

			char sCategory[MAX_CATEGORY_NAME_LENGTH];
			GetMenuString(menu, "category", sCategory, sizeof(sCategory));

			char sItemName[MAX_ITEM_NAME_LENGTH];
			GetMenuString(menu, "item", sItemName, sizeof(sItemName));

			ModularStore_ExecuteItemAction(param1, sCategory, sItemName, sItemAction);

			if (StrContains(sItemAction, STORE_ITEMACTION_PREVIEW, false) != -1)
			{
				bool back = GetMenuBool(menu, "back");
				OpenShopItemMenu(param1, sCategory, sItemName, back);
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				char sCategory[MAX_CATEGORY_NAME_LENGTH];
				GetMenuString(menu, "category", sCategory, sizeof(sCategory));

				bool back = GetMenuBool(menu, "back");

				OpenCategoryMenu(param1, sCategory, back);
			}
		}
		case MenuAction_End:
			delete menu;
	}
}

public int Native_OpenShopItemMenu(Handle plugin, int numParams)
{
	if (!g_Convar_Status.BoolValue)
		return ThrowNativeError(SP_ERROR_NATIVE, "Plugin is currently disabled.");
	
	int client = GetNativeCell(1);
	int size;

	GetNativeStringLength(2, size); size++;
	char[] sCategory = new char[size];
	GetNativeString(2, sCategory, size);

	GetNativeStringLength(3, size); size++;
	char[] sItem = new char[size];
	GetNativeString(3, sItem, size);

	return OpenShopItemMenu(client, sCategory, sItem, false);
}

bool GetItemType(const char[] category, const char[] item, char[] type, int size)
{
	if (!g_Convar_Status.BoolValue)
		return false;
	
	StringMap itemsdata;
	if (!g_ItemsData.GetValue(category, itemsdata) || itemsdata == null)
		return false;

	StringMap itemdata;
	if (!itemsdata.GetValue(item, itemdata) || itemdata == null)
		return false;
	
	return itemdata.GetString("type", type, size);
}

public int Native_GetItemType(Handle plugin, int numParams)
{
	if (!g_Convar_Status.BoolValue)
		return ThrowNativeError(SP_ERROR_NATIVE, "Plugin is currently disabled.");
	
	int size;

	GetNativeStringLength(1, size); size++;
	char[] sCategory = new char[size];
	GetNativeString(1, sCategory, size);

	GetNativeStringLength(2, size); size++;
	char[] sItem = new char[size];
	GetNativeString(2, sItem, size);

	char sType[MAX_TYPE_NAME_LENGTH];
	bool successful = GetItemType(sCategory, sItem, sType, sizeof(sType));

	if (successful)
		SetNativeString(3, sType, GetNativeCell(4));

	return successful;
}

ArrayList GetItemsList(const char[] category)
{
	if (!g_Convar_Status.BoolValue)
		return null;
	
	StringMap itemsdata;
	if (!g_ItemsData.GetValue(category, itemsdata) || itemsdata == null)
		return null;
	
	char sCategoryList[MAX_CATEGORY_NAME_LENGTH + 12];
	FormatEx(sCategoryList, sizeof(sCategoryList), "%s_list", category);
	
	ArrayList itemslist;
	if (!g_ItemsData.GetValue(sCategoryList, itemslist) || itemslist == null)
		return null;
	
	return itemslist;
}

public int Native_GetItemsList(Handle plugin, int numParams)
{
	if (!g_Convar_Status.BoolValue)
		return ThrowNativeError(SP_ERROR_NATIVE, "Plugin is currently disabled.");
	
	int size;

	GetNativeStringLength(1, size); size++;
	char[] sCategory = new char[size];
	GetNativeString(1, sCategory, size);

	return view_as<int>(GetItemsList(sCategory));
}

StringMap GetItemsData(const char[] category)
{
	if (!g_Convar_Status.BoolValue)
		return null;
	
	StringMap itemsdata;
	if (!g_ItemsData.GetValue(category, itemsdata) || itemsdata == null)
		return null;
	
	return itemsdata;
}

public int Native_GetItemsData(Handle plugin, int numParams)
{
	if (!g_Convar_Status.BoolValue)
		return ThrowNativeError(SP_ERROR_NATIVE, "Plugin is currently disabled.");
	
	int size;

	GetNativeStringLength(1, size); size++;
	char[] sCategory = new char[size];
	GetNativeString(1, sCategory, size);

	return view_as<int>(GetItemsData(sCategory));
}

StringMap GetItemData(const char[] category, const char[] item)
{
	if (!g_Convar_Status.BoolValue)
		return null;
	
	StringMap itemsdata;
	if (!g_ItemsData.GetValue(category, itemsdata) || itemsdata == null)
		return null;

	StringMap itemdata;
	if (!itemsdata.GetValue(item, itemdata) || itemdata == null)
		return null;
	
	return itemdata;
}

public int Native_GetItemData(Handle plugin, int numParams)
{
	if (!g_Convar_Status.BoolValue)
		return ThrowNativeError(SP_ERROR_NATIVE, "Plugin is currently disabled.");
	
	int size;

	GetNativeStringLength(1, size); size++;
	char[] sCategory = new char[size];
	GetNativeString(1, sCategory, size);

	GetNativeStringLength(2, size); size++;
	char[] sItem = new char[size];
	GetNativeString(2, sItem, size);

	return view_as<int>(GetItemData(sCategory, sItem));
}

int GetItemDataValue(const char[] category, const char[] item, const char[] key)
{
	if (!g_Convar_Status.BoolValue)
		return 0;
	
	StringMap itemsdata;
	if (!g_ItemsData.GetValue(category, itemsdata) || itemsdata == null)
		return 0;

	StringMap itemdata;
	if (!itemsdata.GetValue(item, itemdata) || itemdata == null)
		return 0;
	
	int itemvalue;
	if (!itemdata.GetValue(key, itemvalue))
		return 0;
	
	return itemvalue;
}

public int Native_GetItemDataValue(Handle plugin, int numParams)
{
	if (!g_Convar_Status.BoolValue)
		return ThrowNativeError(SP_ERROR_NATIVE, "Plugin is currently disabled.");
	
	int size;

	GetNativeStringLength(1, size); size++;
	char[] sCategory = new char[size];
	GetNativeString(1, sCategory, size);

	GetNativeStringLength(2, size); size++;
	char[] sItem = new char[size];
	GetNativeString(2, sItem, size);

	GetNativeStringLength(3, size); size++;
	char[] sKey = new char[size];
	GetNativeString(3, sKey, size);

	return GetItemDataValue(sCategory, sItem, sKey);
}

float GetItemDataFloat(const char[] category, const char[] item, const char[] key)
{
	if (!g_Convar_Status.BoolValue)
		return 0.0;
	
	StringMap itemsdata;
	if (!g_ItemsData.GetValue(category, itemsdata) || itemsdata == null)
		return 0.0;

	StringMap itemdata;
	if (!itemsdata.GetValue(item, itemdata) || itemdata == null)
		return 0.0;
	
	float itemfloat;
	if (!itemdata.GetValue(key, itemfloat))
		return 0.0;
	
	return itemfloat;
}

public int Native_GetItemDataFloat(Handle plugin, int numParams)
{
	if (!g_Convar_Status.BoolValue)
		return ThrowNativeError(SP_ERROR_NATIVE, "Plugin is currently disabled.");
	
	int size;

	GetNativeStringLength(1, size); size++;
	char[] sCategory = new char[size];
	GetNativeString(1, sCategory, size);

	GetNativeStringLength(2, size); size++;
	char[] sItem = new char[size];
	GetNativeString(2, sItem, size);

	GetNativeStringLength(3, size); size++;
	char[] sKey = new char[size];
	GetNativeString(3, sKey, size);

	return view_as<any>(GetItemDataFloat(sCategory, sItem, sKey));
}

bool GetItemDataString(const char[] category, const char[] item, const char[] key, char[] buffer, int size)
{
	if (!g_Convar_Status.BoolValue)
		return false;
	
	StringMap itemsdata;
	if (!g_ItemsData.GetValue(category, itemsdata) || itemsdata == null)
		return false;

	StringMap itemdata;
	if (!itemsdata.GetValue(item, itemdata) || itemdata == null)
		return false;
	
	return itemdata.GetString(key, buffer, size);
}

public int Native_GetItemDataString(Handle plugin, int numParams)
{
	if (!g_Convar_Status.BoolValue)
		return ThrowNativeError(SP_ERROR_NATIVE, "Plugin is currently disabled.");
	
	int size;

	GetNativeStringLength(1, size); size++;
	char[] sCategory = new char[size];
	GetNativeString(1, sCategory, size);

	GetNativeStringLength(2, size); size++;
	char[] sItem = new char[size];
	GetNativeString(2, sItem, size);

	GetNativeStringLength(3, size); size++;
	char[] sKey = new char[size];
	GetNativeString(3, sKey, size);

	size = GetNativeCell(5);
	char[] sBuffer = new char[size];
	bool found = GetItemDataString(sCategory, sItem, sKey, sBuffer, size);

	if (found)
		SetNativeString(4, sBuffer, size);

	return found;
}

bool GetItemDataBool(const char[] category, const char[] item, const char[] key)
{
	if (!g_Convar_Status.BoolValue)
		return false;
	
	StringMap itemsdata;
	if (!g_ItemsData.GetValue(category, itemsdata) || itemsdata == null)
		return false;

	StringMap itemdata;
	if (!itemsdata.GetValue(item, itemdata) || itemdata == null)
		return false;
	
	bool itembool;
	if (!itemdata.GetValue(key, itembool))
		return false;
	
	return itembool;
}

public int Native_GetItemDataBool(Handle plugin, int numParams)
{
	if (!g_Convar_Status.BoolValue)
		return ThrowNativeError(SP_ERROR_NATIVE, "Plugin is currently disabled.");
	
	int size;

	GetNativeStringLength(1, size); size++;
	char[] sCategory = new char[size];
	GetNativeString(1, sCategory, size);

	GetNativeStringLength(2, size); size++;
	char[] sItem = new char[size];
	GetNativeString(2, sItem, size);

	GetNativeStringLength(3, size); size++;
	char[] sKey = new char[size];
	GetNativeString(3, sKey, size);

	return view_as<any>(GetItemDataBool(sCategory, sItem, sKey));
}