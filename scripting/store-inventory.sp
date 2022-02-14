//Pragma
#pragma semicolon 1
#pragma newdecls required

//Module Info
#define MODULE_DESCRIPTION "The inventory module for the modular store system."
#define MODULE_VERSION "1.0.0"

//Sourcemod Includes
#include <sourcemod>
#include <sourcemod-misc>
#include <colorvariables>

//Our Includes
#include <modularstore/modularstore-globals>
#include <modularstore/modularstore-inventory>

#undef REQUIRE_PLUGIN
#include <modularstore/modularstore-database>
#include <modularstore/modularstore-items>
#include <modularstore/modularstore-menu>
#include <modularstore/modularstore-shop>
#define REQUIRE_PLUGIN

//ConVars
ConVar g_Convar_Status;
ConVar g_Convar_ItemCap;

//Forwards
Handle g_Forward_OnGiveItemPost;
Handle g_Forward_OnRemoveItemPost;
Handle g_Forward_OnEquipItemPost;
Handle g_Forward_OnUnequipItemPost;

//Globals
bool g_Late;

ArrayList g_InventoryCategories[MAXPLAYERS + 1];
StringMap g_InventoryItems[MAXPLAYERS + 1];

StringMap g_EquippedItems[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "[Modular Store] :: Inventory", 
	author = "Keith Warren (Shaders Allen)", 
	description = MODULE_DESCRIPTION, 
	version = MODULE_VERSION, 
	url = "https://github.com/ShadersAllen"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("modularstore-inventory");

	CreateNative("ModularStore_OpenInventoryMenu", Native_OpenInventoryMenu);
	CreateNative("ModularStore_OpenInventoryCategoryMenu", Native_OpenInventoryCategoryMenu);
	CreateNative("ModularStore_OpenInventoryItemMenu", Native_OpenInventoryItemMenu);
	CreateNative("ModularStore_IsItemOwned", Native_IsItemOwned);
	CreateNative("ModularStore_GetItemCount", Native_GetItemCount);
	CreateNative("ModularStore_GiveItem", Native_GiveItem);
	CreateNative("ModularStore_RemoveItem", Native_RemoveItem);
	CreateNative("ModularStore_IsItemEquipped", Native_IsItemEquipped);
	CreateNative("ModularStore_EquipItem", Native_EquipItem);
	CreateNative("ModularStore_UnequipItem", Native_UnequipItem);
	CreateNative("ModularStore_GetEquippedItem", Native_GetEquippedItem);

	g_Forward_OnGiveItemPost = CreateGlobalForward("ModularStore_OnGiveItemPost", ET_Ignore, Param_Cell, Param_String, Param_String, Param_Cell);
	g_Forward_OnRemoveItemPost = CreateGlobalForward("ModularStore_OnRemoveItemPost", ET_Ignore, Param_Cell, Param_String, Param_String, Param_Cell);
	g_Forward_OnEquipItemPost = CreateGlobalForward("ModularStore_OnEquipItemPost", ET_Ignore, Param_Cell, Param_String, Param_String, Param_Cell);
	g_Forward_OnUnequipItemPost = CreateGlobalForward("ModularStore_OnUnequipItemPost", ET_Ignore, Param_Cell, Param_String, Param_String, Param_Cell);

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("modularstore-globals.phrases");
	LoadTranslations("modularstore-inventory.phrases");
	
	CreateConVar("sm_modularstore_inventory_version", MODULE_VERSION, MODULE_DESCRIPTION, FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_SPONLY | FCVAR_DONTRECORD);
	g_Convar_Status = CreateConVar("sm_modularstore_inventory_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_Convar_ItemCap = CreateConVar("sm_modularstore_inventory_itemcap", "100", "Maximum number of allowed items per item.", FCVAR_NOTIFY, true, 1.0);
	//AutoExecConfig(true, "store-inventory", "modularstore");

	RegConsoleCmd("sm_inventory", Command_Inventory);
	RegConsoleCmd("sm_inv", Command_Inventory);

	RegAdminCmd("sm_saveitems", Command_SaveItems, ADMFLAG_ROOT);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
			OnClientPutInServer(i);
	}
}

public void OnConfigsExecuted()
{
	if (g_Late)
	{
		g_Late = false;

		if (ModularStore_IsConnected())
			CreateTable();
	}
}

public void ModularStore_OnConnectPost(const char[] entry, Database db)
{
	CreateTable();
}

void CreateTable()
{
	ModularStore_FastQuery("CREATE TABLE IF NOT EXISTS `store_player_items` ( `id` INT NOT NULL AUTO_INCREMENT , `name` VARCHAR(64) NOT NULL DEFAULT '' , `accountid` INT NOT NULL , `category` VARCHAR(64) NOT NULL , `item` VARCHAR(64) NOT NULL , `charges` INT NOT NULL DEFAULT '-1' , `expiration` INT NOT NULL DEFAULT '-1' , `deleted` TINYINT NOT NULL DEFAULT '0' , `first_created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP , `last_updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP , PRIMARY KEY (`id`)) ENGINE = InnoDB;");
	ModularStore_FastQuery("CREATE TABLE IF NOT EXISTS `store_player_equipped` ( `id` INT NOT NULL AUTO_INCREMENT , `name` VARCHAR(64) NOT NULL DEFAULT '' , `accountid` INT NOT NULL , `category` VARCHAR(64) NOT NULL , `equipped` VARCHAR(64) NOT NULL , `first_created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP , `last_updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP , PRIMARY KEY (`id`), UNIQUE KEY (`accountid`, `category`)) ENGINE = InnoDB;");
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
	
	ModularStore_RegisterStoreItem("inv", "Access your Inventory", OnPress);
}

public void OnPress(int client)
{
	if (!g_Convar_Status.BoolValue)
		return;
	
	OpenInventoryMenu(client, true);
}

public Action Command_Inventory(int client, int args)
{
	if (!g_Convar_Status.BoolValue)
		return Plugin_Handled;
	
	OpenInventoryMenu(client);
	return Plugin_Handled;
}

bool OpenInventoryMenu(int client, bool back = false)
{
	if (!g_Convar_Status.BoolValue)
		return false;
	
	Menu menu = new Menu(MenuHandler_Inventory);
	menu.SetTitle("Pick a category:");

	char sCategory[MAX_CATEGORY_NAME_LENGTH];
	for (int i = 0; i < g_InventoryCategories[client].Length; i++)
	{
		g_InventoryCategories[client].GetString(i, sCategory, sizeof(sCategory));
		menu.AddItem(sCategory, sCategory);
	}

	if (menu.ItemCount == 0)
		menu.AddItem("", " -- No Categories Available --", ITEMDRAW_DISABLED);
	
	PushMenuBool(menu, "back", back);

	menu.ExitBackButton = back;
	menu.Display(client, MENU_TIME_FOREVER);

	return true;
}

public int MenuHandler_Inventory(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sCategory[MAX_CATEGORY_NAME_LENGTH];
			menu.GetItem(param2, sCategory, sizeof(sCategory));

			bool back = GetMenuBool(menu, "back");

			OpenCategoryItemMenu(param1, sCategory, true, back);
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

public int Native_OpenInventoryMenu(Handle plugin, int numParams)
{
	if (!g_Convar_Status.BoolValue)
		return ThrowNativeError(SP_ERROR_NATIVE, "Plugin is currently disabled.");
	
	int client = GetNativeCell(1);

	return OpenInventoryMenu(client);
}

bool OpenCategoryItemMenu(int client, const char[] category, bool show_amount = true, bool back = false)
{
	if (!g_Convar_Status.BoolValue)
		return false;
	
	Menu menu = new Menu(MenuHandler_ItemCategory);
	menu.SetTitle("Pick an item from the %s category:", category);

	ArrayList itemsdata;
	g_InventoryItems[client].GetValue(category, itemsdata);

	if (itemsdata == null)
		itemsdata = new ArrayList(ByteCountToCells(MAX_ITEM_NAME_LENGTH));
	
	StringMap g_Amounts;
	ArrayList g_Posted;
	int amount;
	
	char sStatus[MAX_STATUS_NAME_LENGTH];
	if (show_amount)
	{
		g_Amounts = new StringMap();
		g_Posted = new ArrayList(ByteCountToCells(MAX_ITEM_NAME_LENGTH));
		
		char sItem[MAX_ITEM_NAME_LENGTH];
		for (int i = 0; i < itemsdata.Length; i++)
		{
			itemsdata.GetString(i, sItem, sizeof(sItem));
			
			if (ModularStore_GetItemDataString(category, sItem, "status", sStatus, sizeof(sStatus)) && StrEqual(sStatus, "invisible", false))
				continue;
			
			amount = 0;
			g_Amounts.GetValue(sItem, amount);
			amount++;
			g_Amounts.SetValue(sItem, amount);
		}
	}

	char sItem[MAX_ITEM_NAME_LENGTH]; char sDisplay[MAX_DISPLAY_NAME_LENGTH]; char sAmount[12]; int draw = ITEMDRAW_DEFAULT;
	for (int i = 0; i < itemsdata.Length; i++)
	{
		itemsdata.GetString(i, sItem, sizeof(sItem));

		if (ModularStore_GetItemDataString(category, sItem, "status", sStatus, sizeof(sStatus)) && StrEqual(sStatus, "invisible", false))
			draw = ITEMDRAW_RAWLINE;
		else
		{
			if (g_Posted != null)
			{
				if (g_Posted.FindString(sItem) != -1)
					continue;
				
				g_Posted.PushString(sItem);
			}

			if (g_Amounts != null && g_Amounts.GetValue(sItem, amount))
				FormatEx(sAmount, sizeof(sAmount), " (%i)", amount);

			FormatEx(sDisplay, sizeof(sDisplay), "%s%s", sItem, amount ? sAmount : "");
		}

		menu.AddItem(sItem, sDisplay, draw);
	}

	delete g_Amounts;
	delete g_Posted;

	if (menu.ItemCount == 0)
		menu.AddItem("", " -- No Items Available --", ITEMDRAW_DISABLED);

	PushMenuString(menu, "category", category);
	PushMenuBool(menu, "back", back);
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);

	return true;
}

public int MenuHandler_ItemCategory(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sItem[MAX_ITEM_NAME_LENGTH];
			menu.GetItem(param2, sItem, sizeof(sItem));

			char sItemCategory[MAX_CATEGORY_NAME_LENGTH];
			GetMenuString(menu, "category", sItemCategory, sizeof(sItemCategory));

			bool back = GetMenuBool(menu, "back");

			OpenInventoryItemMenu(param1, sItemCategory, sItem, back);
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				bool back = GetMenuBool(menu, "back");

				OpenInventoryMenu(param1, back);
			}
		}
		case MenuAction_End:
			delete menu;
	}
}

public int Native_OpenInventoryCategoryMenu(Handle plugin, int numParams)
{
	if (!g_Convar_Status.BoolValue)
		return ThrowNativeError(SP_ERROR_NATIVE, "Plugin is currently disabled.");
	
	int client = GetNativeCell(1);

	int size;
	GetNativeStringLength(2, size); size++;

	char[] sCategory = new char[size];
	GetNativeString(2, sCategory, size);

	bool show_amount = GetNativeCell(3);

	return OpenCategoryItemMenu(client, sCategory, show_amount);
}

bool OpenInventoryItemMenu(int client, const char[] category, const char[] item, bool back = false)
{
	if (!g_Convar_Status.BoolValue)
		return false;
	
	StringMap itemsdata = ModularStore_GetItemsData(category);
	if (itemsdata == null)
	{
		PrintToChat(client, "Item %s not available.", item);
		OpenInventoryMenu(client);
		return false;
	}

	StringMap itemdata;
	if (!itemsdata.GetValue(item, itemdata) || itemdata == null)
	{
		PrintToChat(client, "Item %s not available.", item);
		OpenInventoryMenu(client);
		return false;
	}
	
	char sItemDescription[MAX_DESCRIPTION_LENGTH];
	itemdata.GetString("description", sItemDescription, sizeof(sItemDescription));

	char sItemType[MAX_TYPE_NAME_LENGTH];
	itemdata.GetString("type", sItemType, sizeof(sItemType));

	char sItemDisplay[MAX_DISPLAY_NAME_LENGTH];
	ModularStore_GetItemTypeDisplay(sItemType, sItemDisplay, sizeof(sItemDisplay));

	int amount = ModularStore_GetItemCount(client, category, item);
	
	char sDescription[64];
	FormatEx(sDescription, sizeof(sDescription), "Description: %s\n", sItemDescription);

	char sAmount[12];
	FormatEx(sAmount, sizeof(sAmount), "Owned: %i\n ", amount);

	Menu menu = new Menu(MenuHandler_Item);
	menu.SetTitle("Item Information for %s:\n%s\nType: %s\n%s", item, strlen(sItemDescription) > 0 ? sDescription : "\n", sItemDisplay, sAmount);

	char sItemActions[MAX_ACTIONS_LENGTH];
	itemdata.GetString("actions", sItemActions, sizeof(sItemActions));

	bool equipped = ModularStore_IsItemEquipped(client, category, item);

	if (StrEqual(sItemActions, STORE_ITEMACTION_ALL, false))
	{
		if (!equipped)
			menu.AddItem(STORE_ITEMACTION_EQUIP, "Equip Item", amount > 0 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		else
			menu.AddItem(STORE_ITEMACTION_UNEQUIP, "Unequip Item");
		
		menu.AddItem(STORE_ITEMACTION_PREVIEW, "Preview Item");
		menu.AddItem(STORE_ITEMACTION_GIFT, "Gift Item");
		menu.AddItem(STORE_ITEMACTION_TRADE, "Trade Item");
		menu.AddItem(STORE_ITEMACTION_AUCTION, "Auction Item");
		menu.AddItem(STORE_ITEMACTION_GIVEAWAY, "Giveaway Item");
	}
	else
	{
		if (!equipped && StrContains(sItemActions, STORE_ITEMACTION_EQUIP, false) != -1)
			menu.AddItem(STORE_ITEMACTION_EQUIP, "Equip Item", amount > 0 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		else if (StrContains(sItemActions, STORE_ITEMACTION_UNEQUIP, false) != -1)
			menu.AddItem(STORE_ITEMACTION_UNEQUIP, "Unequip Item");
			
		if (StrContains(sItemActions, STORE_ITEMACTION_PREVIEW, false) != -1)
			menu.AddItem(STORE_ITEMACTION_PREVIEW, "Preview Item");
		
		if (StrContains(sItemActions, STORE_ITEMACTION_GIFT, false) != -1)
			menu.AddItem(STORE_ITEMACTION_GIFT, "Gift Item");
			
		if (StrContains(sItemActions, STORE_ITEMACTION_TRADE, false) != -1)
			menu.AddItem(STORE_ITEMACTION_TRADE, "Trade Item");
		
		if (StrContains(sItemActions, STORE_ITEMACTION_AUCTION, false) != -1)
			menu.AddItem(STORE_ITEMACTION_AUCTION, "Auction Item");
		
		if (StrContains(sItemActions, STORE_ITEMACTION_GIVEAWAY, false) != -1)
			menu.AddItem(STORE_ITEMACTION_GIVEAWAY, "Giveaway Item");
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
				OpenInventoryItemMenu(param1, sCategory, sItemName, back);
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				char sCategory[MAX_CATEGORY_NAME_LENGTH];
				GetMenuString(menu, "category", sCategory, sizeof(sCategory));

				bool back = GetMenuBool(menu, "back");
				
				OpenCategoryItemMenu(param1, sCategory, true, back);
			}
		}
		case MenuAction_End:
			delete menu;
	}
}

public int Native_OpenInventoryItemMenu(Handle plugin, int numParams)
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

	return OpenInventoryItemMenu(client, sCategory, sItem);
}

bool IsItemOwned(int client, const char[] category, const char[] item)
{
	if (!g_Convar_Status.BoolValue)
		return false;
	
	ArrayList itemsdata;
	g_InventoryItems[client].GetValue(category, itemsdata);

	if (itemsdata == null)
		itemsdata = new ArrayList(ByteCountToCells(MAX_ITEM_NAME_LENGTH));

	return itemsdata.FindString(item) != -1;
}

public int Native_IsItemOwned(Handle plugin, int numParams)
{
	if (!g_Convar_Status.BoolValue)
		return ThrowNativeError(SP_ERROR_NATIVE, "Plugin is currently disabled.");
	
	int client = GetNativeCell(1);
	int size;

	GetNativeStringLength(2, size); size++;
	char[] category = new char[size];
	GetNativeString(2, category, size);

	GetNativeStringLength(3, size); size++;
	char[] item = new char[size];
	GetNativeString(3, item, size);

	return IsItemOwned(client, category, item);
}

int GetItemCount(int client, const char[] category, const char[] item)
{
	if (!g_Convar_Status.BoolValue)
		return 0;
	
	ArrayList itemsdata;
	g_InventoryItems[client].GetValue(category, itemsdata);

	if (itemsdata == null)
		itemsdata = new ArrayList(ByteCountToCells(MAX_ITEM_NAME_LENGTH));

	char sItem[MAX_ITEM_NAME_LENGTH]; int amount;
	for (int i = 0; i < itemsdata.Length; i++)
	{
		itemsdata.GetString(i, sItem, sizeof(sItem));

		if (StrEqual(sItem, item))
			amount++;
	}

	return amount;
}

public int Native_GetItemCount(Handle plugin, int numParams)
{
	if (!g_Convar_Status.BoolValue)
		return ThrowNativeError(SP_ERROR_NATIVE, "Plugin is currently disabled.");
	
	int client = GetNativeCell(1);
	int size;

	GetNativeStringLength(2, size); size++;
	char[] category = new char[size];
	GetNativeString(2, category, size);

	GetNativeStringLength(3, size); size++;
	char[] item = new char[size];
	GetNativeString(3, item, size);

	return GetItemCount(client, category, item);
}

bool GiveItem(int client, const char[] category, const char[] item, bool message, int amount = 1, int id = 0)
{
	if (!g_Convar_Status.BoolValue)
		return false;
	
	if (g_InventoryCategories[client].FindString(category) == -1)
		g_InventoryCategories[client].PushString(category);

	ArrayList itemsdata;
	g_InventoryItems[client].GetValue(category, itemsdata);

	if (itemsdata == null)
		itemsdata = new ArrayList(ByteCountToCells(MAX_ITEM_NAME_LENGTH));

	if (GetItemCount(client, category, item) + amount > g_Convar_ItemCap.IntValue)
		return false;
	
	Transaction txn = new Transaction();
	char sQuery[512];

	char sName[MAX_NAME_LENGTH];
	GetClientName(client, sName, sizeof(sName));

	int size = 2 * strlen(sName) + 1;
	char[] sEscapedName = new char[size];
	ModularStore_Escape(sName, sEscapedName, size);

	int accountid = GetSteamAccountID(client);

	char category_itemindexes[MAX_CATEGORY_NAME_LENGTH + 12];
	FormatEx(category_itemindexes, sizeof(category_itemindexes), "%s_indexes", category);
	
	StringMap itemids;
	g_InventoryItems[client].GetValue(category_itemindexes, itemids);

	if (itemids == null)
		itemids = new StringMap();

	int index = -1; char sIndex[12];
	for (int i = 0; i < amount; i++)
	{
		index = itemsdata.PushString(item);
		
		if (id == 0)
		{
			FormatEx(sQuery, sizeof(sQuery), "INSERT INTO `store_player_items` (`name`, `accountid`, `category`, `item`) VALUES ('%s', '%i', '%s', '%s');", sEscapedName, accountid, category, item);
			txn.AddQuery(sQuery, index);
		}
		else
		{
			IntToString(index, sIndex, sizeof(sIndex));
			itemids.SetValue(sIndex, id);
		}
	}

	if (id == 0)
	{
		DataPack pack = new DataPack();
		pack.WriteCell(GetClientUserId(client));
		pack.WriteString(category);
		pack.WriteString(item);
		
		ModularStore_Transaction(txn, OnGiveItem_Success, OnGiveItem_Failure, pack);
	}
	else
		delete txn;

	g_InventoryItems[client].SetValue(category, itemsdata);
	g_InventoryItems[client].SetValue(category_itemindexes, itemids);

	if (message)
		CPrintToChat(client, "Item Received: %s (%i)", item, amount);
	
	Call_StartForward(g_Forward_OnGiveItemPost);
	Call_PushCell(client);
	Call_PushString(category);
	Call_PushString(item);
	Call_PushCell(amount);
	Call_Finish();

	return true;
}

public void OnGiveItem_Success(DataPack data, int numQueries, DBResultSet[] results, any[] queryData)
{
	data.Reset();

	int client = GetClientOfUserId(data.ReadCell());
	
	char category[MAX_CATEGORY_NAME_LENGTH];
	data.ReadString(category, sizeof(category));

	char item[MAX_ITEM_NAME_LENGTH];
	data.ReadString(item, sizeof(item));
	
	delete data;

	char category_itemindexes[MAX_CATEGORY_NAME_LENGTH + 12];
	FormatEx(category_itemindexes, sizeof(category_itemindexes), "%s_indexes", category);
	
	StringMap itemids;
	g_InventoryItems[client].GetValue(category_itemindexes, itemids);

	if (itemids == null)
		itemids = new StringMap();

	int index; char sIndex[12]; int id;
	for (int i = 0; i < numQueries; i++)
	{
		index = queryData[i];
		IntToString(index, sIndex, sizeof(sIndex));

		id = SQL_GetInsertId(results[i]);
		itemids.SetValue(sIndex, id);

		//PrintToServer("client: %N - id: %i - index: %i", client, id, index);
	}

	g_InventoryItems[client].SetValue(category_itemindexes, itemids);
}

public void OnGiveItem_Failure(DataPack data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	delete data;
	LogError("Error while saving player data: %s", error);
}

public int Native_GiveItem(Handle plugin, int numParams)
{
	if (!g_Convar_Status.BoolValue)
		return ThrowNativeError(SP_ERROR_NATIVE, "Plugin is currently disabled.");
	
	int client = GetNativeCell(1);
	int size;

	GetNativeStringLength(2, size); size++;
	char[] category = new char[size];
	GetNativeString(2, category, size);

	GetNativeStringLength(3, size); size++;
	char[] item = new char[size];
	GetNativeString(3, item, size);

	bool message = GetNativeCell(4);

	return GiveItem(client, category, item, message);
}

bool RemoveItem(int client, const char[] category, const char[] item, bool message, int amount = 1)
{
	if (!g_Convar_Status.BoolValue)
		return false;
	
	int index = -1;
	if ((index = g_InventoryCategories[client].FindString(category)) == -1)
		return false;

	ArrayList itemsdata;
	g_InventoryItems[client].GetValue(category, itemsdata);

	if (itemsdata == null)
		itemsdata = new ArrayList(ByteCountToCells(MAX_ITEM_NAME_LENGTH));

	char category_itemindexes[MAX_CATEGORY_NAME_LENGTH + 12];
	FormatEx(category_itemindexes, sizeof(category_itemindexes), "%s_indexes", category);
	
	StringMap itemids;
	g_InventoryItems[client].GetValue(category_itemindexes, itemids);

	if (itemids == null)
		itemids = new StringMap();
	
	Transaction txn = new Transaction();

	int item_index; char sIndex[12]; int id; char sQuery[128];
	for (int i = 0; i < amount; i++)
	{
		item_index = itemsdata.FindString(item);

		if (item_index == -1)
			continue;
		
		itemsdata.Erase(item_index);

		IntToString(item_index, sIndex, sizeof(sIndex));
		itemids.GetValue(sIndex, id);

		if (id > 0)
		{
			FormatEx(sQuery, sizeof(sQuery), "UPDATE `store_player_items` SET deleted = '1' WHERE id = '%i';", id);
			txn.AddQuery(sQuery);
		}

		itemids.Remove(sIndex);

		if (itemsdata.Length > 0)
			continue;
		
		g_InventoryCategories[client].Erase(index);

		delete itemsdata;
		g_InventoryItems[client].Remove(category);

		if (message)
			CPrintToChat(client, "The item %s has been removed, you have no more of them.", item);

		if (IsItemEquipped(client, category, item))
			UnequipItem(client, category, item);
		
		ModularStore_Transaction(txn);

		return true;
	}

	ModularStore_Transaction(txn);

	g_InventoryItems[client].SetValue(category, itemsdata);

	if (message)
		CPrintToChat(client, "The item %s has been removed.", item);

	Call_StartForward(g_Forward_OnRemoveItemPost);
	Call_PushCell(client);
	Call_PushString(category);
	Call_PushString(item);
	Call_PushCell(amount);
	Call_Finish();

	return true;
}

public int Native_RemoveItem(Handle plugin, int numParams)
{
	if (!g_Convar_Status.BoolValue)
		return ThrowNativeError(SP_ERROR_NATIVE, "Plugin is currently disabled.");
	
	int client = GetNativeCell(1);
	int size;

	GetNativeStringLength(2, size); size++;
	char[] category = new char[size];
	GetNativeString(2, category, size);

	GetNativeStringLength(3, size); size++;
	char[] item = new char[size];
	GetNativeString(3, item, size);

	bool message = GetNativeCell(4);

	return RemoveItem(client, category, item, message);
}

bool IsItemEquipped(int client, const char[] category, const char[] item)
{
	if (!g_Convar_Status.BoolValue)
		return false;
	
	char sEquipped[MAX_ITEM_NAME_LENGTH];
	if (!g_EquippedItems[client].GetString(category, sEquipped, sizeof(sEquipped)) || strlen(sEquipped) == 0)
		return false;

	return StrEqual(item, sEquipped);
}

public int Native_IsItemEquipped(Handle plugin, int numParams)
{
	if (!g_Convar_Status.BoolValue)
		return ThrowNativeError(SP_ERROR_NATIVE, "Plugin is currently disabled.");
	
	int client = GetNativeCell(1);
	int size;

	GetNativeStringLength(2, size); size++;
	char[] category = new char[size];
	GetNativeString(2, category, size);

	GetNativeStringLength(3, size); size++;
	char[] item = new char[size];
	GetNativeString(3, item, size);

	return IsItemEquipped(client, category, item);
}

bool EquipItem(int client, const char[] category, const char[] item, bool call_action = false, bool save = true)
{
	if (!g_Convar_Status.BoolValue)
		return false;
	
	char sEquipped[MAX_ITEM_NAME_LENGTH];
	g_EquippedItems[client].GetString(category, sEquipped, sizeof(sEquipped));

	bool equipped = !StrEqual(item, sEquipped) && g_EquippedItems[client].SetString(category, item);

	if (call_action && equipped)
		ModularStore_ExecuteItemAction(client, category, item, STORE_ITEMACTION_EQUIP);
	
	if (save)
	{
		char sName[MAX_NAME_LENGTH];
		GetClientName(client, sName, sizeof(sName));

		int size = 2 * strlen(sName) + 1;
		char[] sEscapedName = new char[size];
		ModularStore_Escape(sName, sEscapedName, size);

		int accountid = GetSteamAccountID(client);

		char sQuery[512];
		FormatEx(sQuery, sizeof(sQuery), "INSERT INTO `store_player_equipped` (name, accountid, category, equipped) VALUES ('%s', '%i', '%s', '%s') ON DUPLICATE KEY UPDATE equipped = '%s', last_updated = NOW();", sEscapedName, accountid, category, item, item);
		ModularStore_FastQuery(sQuery);
	}

	Call_StartForward(g_Forward_OnEquipItemPost);
	Call_PushCell(client);
	Call_PushString(category);
	Call_PushString(item);
	Call_PushCell(equipped);
	Call_Finish();

	return equipped;
}

public int Native_EquipItem(Handle plugin, int numParams)
{
	if (!g_Convar_Status.BoolValue)
		return ThrowNativeError(SP_ERROR_NATIVE, "Plugin is currently disabled.");
	
	int client = GetNativeCell(1);
	int size;

	GetNativeStringLength(2, size); size++;
	char[] category = new char[size];
	GetNativeString(2, category, size);

	GetNativeStringLength(3, size); size++;
	char[] item = new char[size];
	GetNativeString(3, item, size);

	return EquipItem(client, category, item);
}

bool UnequipItem(int client, const char[] category, const char[] item, bool call_action = false, bool save = true)
{
	if (!g_Convar_Status.BoolValue)
		return false;
	
	char sEquipped[MAX_ITEM_NAME_LENGTH];
	g_EquippedItems[client].GetString(category, sEquipped, sizeof(sEquipped));

	bool unequipped = StrEqual(item, sEquipped) && g_EquippedItems[client].Remove(category);

	if (call_action && unequipped)
		ModularStore_ExecuteItemAction(client, category, item, STORE_ITEMACTION_UNEQUIP);

	if (save)
	{
		char sName[MAX_NAME_LENGTH];
		GetClientName(client, sName, sizeof(sName));

		int size = 2 * strlen(sName) + 1;
		char[] sEscapedName = new char[size];
		ModularStore_Escape(sName, sEscapedName, size);

		int accountid = GetSteamAccountID(client);

		char sQuery[512];
		FormatEx(sQuery, sizeof(sQuery), "INSERT INTO `store_player_equipped` (name, accountid, category, equipped) VALUES ('%s', '%i', '%s', '') ON DUPLICATE KEY UPDATE equipped = '', last_updated = NOW();", sEscapedName, accountid, category);
		ModularStore_FastQuery(sQuery);
	}

	Call_StartForward(g_Forward_OnUnequipItemPost);
	Call_PushCell(client);
	Call_PushString(category);
	Call_PushString(item);
	Call_PushCell(unequipped);
	Call_Finish();

	return unequipped;
}

public int Native_UnequipItem(Handle plugin, int numParams)
{
	if (!g_Convar_Status.BoolValue)
		return ThrowNativeError(SP_ERROR_NATIVE, "Plugin is currently disabled.");
	
	int client = GetNativeCell(1);
	int size;

	GetNativeStringLength(2, size); size++;
	char[] category = new char[size];
	GetNativeString(2, category, size);

	GetNativeStringLength(3, size); size++;
	char[] item = new char[size];
	GetNativeString(3, item, size);

	return UnequipItem(client, category, item);
}

bool GetEquippedItem(int client, const char[] category, char[] buffer, int size)
{
	if (!g_Convar_Status.BoolValue)
		return false;
	
	return g_EquippedItems[client].GetString(category, buffer, size);
}

public int Native_GetEquippedItem(Handle plugin, int numParams)
{
	if (!g_Convar_Status.BoolValue)
		return ThrowNativeError(SP_ERROR_NATIVE, "Plugin is currently disabled.");
	
	int client = GetNativeCell(1);
	int size;

	GetNativeStringLength(2, size); size++;
	char[] category = new char[size];
	GetNativeString(2, category, size);

	char sItem[MAX_ITEM_NAME_LENGTH];
	bool found = GetEquippedItem(client, category, sItem, sizeof(sItem));

	if (found)
		SetNativeString(3, sItem, GetNativeCell(4));
	
	return found;
}

public void OnClientPutInServer(int client)
{
	if (!g_Convar_Status.BoolValue)
		return;
	
	delete g_InventoryCategories[client];
	g_InventoryCategories[client] = new ArrayList(ByteCountToCells(MAX_CATEGORY_NAME_LENGTH));

	delete g_InventoryItems[client];
	g_InventoryItems[client] = new StringMap();

	delete g_EquippedItems[client];
	g_EquippedItems[client] = new StringMap();

	char sQuery[128];
	FormatEx(sQuery, sizeof(sQuery), "SELECT id, category, item FROM `store_player_items` WHERE accountid = '%i' AND deleted = '0';", GetSteamAccountID(client));
	ModularStore_Query(OnParseItems, sQuery, GetClientUserId(client), DBPrio_Low);

	FormatEx(sQuery, sizeof(sQuery), "SELECT category, equipped FROM `store_player_equipped` WHERE accountid = '%i';", GetSteamAccountID(client));
	ModularStore_Query(OnParseEquipped, sQuery, GetClientUserId(client), DBPrio_Low);
}

public void OnParseItems(DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		LogError("Error while retrieving client items: %s", error);
		return;
	}
	
	int client = -1;
	if ((client = GetClientOfUserId(data)) < 1)
		return;
	
	while (results.FetchRow())
	{
		int id = results.FetchInt(0);

		char sCategory[MAX_CATEGORY_NAME_LENGTH];
		results.FetchString(1, sCategory, sizeof(sCategory));

		char sItem[MAX_ITEM_NAME_LENGTH];
		results.FetchString(2, sItem, sizeof(sItem));

		GiveItem(client, sCategory, sItem, false, 1, id);
	}
}

public void OnParseEquipped(DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		LogError("Error while retrieving client equipped states: %s", error);
		return;
	}
	
	int client = -1;
	if ((client = GetClientOfUserId(data)) < 1)
		return;
	
	while (results.FetchRow())
	{
		char sCategory[MAX_CATEGORY_NAME_LENGTH];
		results.FetchString(0, sCategory, sizeof(sCategory));

		char sEquipped[MAX_ITEM_NAME_LENGTH];
		results.FetchString(1, sEquipped, sizeof(sEquipped));

		EquipItem(client, sCategory, sEquipped, true, false);
	}
}

public void OnClientDisconnect(int client)
{
	if (IsFakeClient(client))
		return;
	
	SaveAllItems(client);
}

public Action Command_SaveItems(int client, int args)
{
	if (!g_Convar_Status.BoolValue || client == 0)
		return Plugin_Handled;
	
	SaveAllItems(client, true);
	return Plugin_Handled;
}

void SaveAllItems(int client, bool announce = false)
{
	if (!g_Convar_Status.BoolValue || IsFakeClient(client))
		return;
	
	if (announce)
		CPrintToChat(client, "All items have been saved.");
}

public void OnClientDisconnect_Post(int client)
{
	delete g_InventoryCategories[client];
	delete g_InventoryItems[client];
	delete g_EquippedItems[client];
}

public void ModularStore_OnItemActionPost(int client, const char[] category, const char[] item, const char[] action)
{
	if (!g_Convar_Status.BoolValue)
		return;
	
	if (StrEqual(action, STORE_ITEMACTION_EQUIP, false))
	{
		EquipItem(client, category, item);
	}
	else if (StrEqual(action, STORE_ITEMACTION_UNEQUIP, false))
	{
		UnequipItem(client, category, item);
	}
}