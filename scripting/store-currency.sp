//Pragma
#pragma semicolon 1
#pragma newdecls required

//Module Info
#define MODULE_DESCRIPTION "The currency module for the modular store system."
#define MODULE_VERSION "1.0.0"

//Sourcemod Includes
#include <sourcemod>
#include <sourcemod-misc>
#include <colorvariables>

//Our Includes
#include <modularstore/modularstore-globals>
#include <modularstore/modularstore-currency>

#undef REQUIRE_PLUGIN
#include <modularstore/modularstore-database>
#include <modularstore/modularstore-shop>
#include <modularstore/modularstore-inventory>
#include <modularstore/modularstore-menu>
#define REQUIRE_PLUGIN

//ConVars
ConVar g_Convar_Status;
ConVar g_Convar_DefaultCurrency;

//Forwards

//Globals
bool g_Late;

ArrayList g_AvailableCurrencies;
StringMap g_CurrencyDisplay;
StringMap g_CurrencyFlags;
StringMap g_CurrencySteamIDs;

StringMap g_Currencies[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "[Modular Store] :: Currency", 
	author = "Keith Warren (Shaders Allen)", 
	description = MODULE_DESCRIPTION, 
	version = MODULE_VERSION, 
	url = "https://github.com/ShadersAllen"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("modularstore-currency");

	CreateNative("ModularStore_GetCurrency", Native_GetCurrency);
	CreateNative("ModularStore_SetCurrency", Native_SetCurrency);
	CreateNative("ModularStore_AddCurrency", Native_AddCurrency);
	CreateNative("ModularStore_RemoveCurrency", Native_RemoveCurrency);

	g_Late = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("modularstore-globals.phrases");
	LoadTranslations("modularstore-currency.phrases");
	
	CreateConVar("sm_modularstore_currency_version", MODULE_VERSION, MODULE_DESCRIPTION, FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_SPONLY | FCVAR_DONTRECORD);
	g_Convar_Status = CreateConVar("sm_modularstore_currency_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_Convar_DefaultCurrency = CreateConVar("sm_modularstore_currency_default", "credits", "Name of the primary currency for the plugin to use.", FCVAR_NOTIFY);
	//AutoExecConfig(true, "store-currency", "modularstore");

	g_AvailableCurrencies = new ArrayList(ByteCountToCells(MAX_CURRENCY_NAME_LENGTH));
	g_CurrencyDisplay = new StringMap();
	g_CurrencyFlags = new StringMap();
	g_CurrencySteamIDs = new StringMap();

	RegConsoleCmd("sm_currencies", Command_Currencies);

	RegAdminCmd("sm_savecurrency", Command_SaveCurrency, ADMFLAG_ROOT);

	RegAdminCmd("sm_setcurrency", Command_SetCurrency, ADMFLAG_ROOT);
	RegAdminCmd("sm_addcurrency", Command_AddCurrency, ADMFLAG_ROOT);
	RegAdminCmd("sm_removecurrency", Command_RemoveCurrency, ADMFLAG_ROOT);
}

public void OnConfigsExecuted()
{
	ParseCurrencies();

	if (g_Late)
	{
		g_Late = false;

		if (ModularStore_IsConnected())
			CreateTable();
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
				OnClientPutInServer(i);
		}
	}
}

void ParseCurrencies()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/modularstore/currencies.cfg");
	
	KeyValues kv = new KeyValues("currencies");

	if (kv.ImportFromFile(sPath) && kv.GotoFirstSubKey())
	{
		g_AvailableCurrencies.Clear();
		g_CurrencyDisplay.Clear();
		g_CurrencyFlags.Clear();
		g_CurrencySteamIDs.Clear();

		char sCurrency[MAX_CURRENCY_NAME_LENGTH]; char sDisplay[MAX_DISPLAY_NAME_LENGTH]; char sFlags[MAX_FLAGS_LENGTH]; char sSteamIDs[2048];
		do
		{
			kv.GetSectionName(sCurrency, sizeof(sCurrency));

			if (g_AvailableCurrencies.FindString(sCurrency) == -1)
				g_AvailableCurrencies.PushString(sCurrency);
			
			kv.GetString("display", sDisplay, sizeof(sDisplay));
			g_CurrencyDisplay.SetString(sCurrency, sDisplay);

			kv.GetString("flags", sFlags, sizeof(sFlags));
			g_CurrencyFlags.SetString(sCurrency, sFlags);

			kv.GetString("steamids", sSteamIDs, sizeof(sSteamIDs));
			g_CurrencySteamIDs.SetString(sCurrency, sSteamIDs);
		}
		while (kv.GotoNextKey());
	}

	delete kv;
	LogMessage("Parsed %i currencies.", g_AvailableCurrencies.Length);
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
	
	ModularStore_RegisterStoreItem("currencies", "Access your Wallet", OnPress);
}

public void OnPress(int client)
{
	if (!g_Convar_Status.BoolValue)
		return;
	
	OpenCurrenciesMenu(client, true);
}

public Action Command_Currencies(int client, int args)
{
	if (!g_Convar_Status.BoolValue)
		return Plugin_Handled;
	
	OpenCurrenciesMenu(client, false);
	return Plugin_Handled;
}

void OpenCurrenciesMenu(int client, bool back)
{
	Menu menu = new Menu(MenuHandler_Currencies);
	menu.SetTitle("Your available currencies:");

	char sCurrency[MAX_CURRENCY_NAME_LENGTH]; char sDisplay[MAX_DISPLAY_NAME_LENGTH]; int currency; char sBuffer[255];
	for (int i = 0; i < g_AvailableCurrencies.Length; i++)
	{
		g_AvailableCurrencies.GetString(i, sCurrency, sizeof(sCurrency));
		g_CurrencyDisplay.GetString(sCurrency, sDisplay, sizeof(sDisplay));
		
		if (strlen(sDisplay) > 0)
			strcopy(sBuffer, sizeof(sBuffer), sDisplay);
		else
		{
			strcopy(sBuffer, sizeof(sBuffer), sCurrency);
			sBuffer[0] = CharToUpper(sBuffer[0]);
		}

		g_Currencies[client].GetValue(sCurrency, currency);
		Format(sBuffer, sizeof(sBuffer), "(%i) %s", currency, sBuffer);
		
		menu.AddItem(sCurrency, sBuffer);
	}

	if (menu.ItemCount == 0)
		menu.AddItem("", " -- No Currencies Available --", ITEMDRAW_DISABLED);

	PushMenuBool(menu, "back", back);

	menu.ExitBackButton = back;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Currencies(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_End:
			delete menu;
	}
}

public void ModularStore_OnItemActionPost(int client, const char[] category, const char[] item, const char[] action)
{
	if (!g_Convar_Status.BoolValue)
		return;
	
	if (StrEqual(action, STORE_ITEMACTION_BUY, false))
	{
		StringMap itemdata = ModularStore_GetItemData(category, item);

		char sPrice[12];
		itemdata.GetString("price", sPrice, sizeof(sPrice));
		int price = StringToInt(sPrice);

		char sCurrency[MAX_CURRENCY_NAME_LENGTH];
		itemdata.GetString("currency", sCurrency, sizeof(sCurrency));

		if (strlen(sCurrency) == 0)
			g_Convar_DefaultCurrency.GetString(sCurrency, sizeof(sCurrency));
		
		if (GetCurrency(client, sCurrency) < price)
		{
			PrintToChat(client, "You don't have enough money to purchase this item.");
			return;
		}
		
		ModularStore_GiveItem(client, category, item);
	}
	else if (StrEqual(action, STORE_ITEMACTION_SELL, false))
	{
		StringMap itemdata = ModularStore_GetItemData(category, item);

		char sPrice[12];
		itemdata.GetString("price", sPrice, sizeof(sPrice));
		int price = StringToInt(sPrice);

		if (price < 1)
		{
			PrintToChat(client, "Your item has been refunded for 0 credits.");
			ModularStore_RemoveItem(client, category, item);
			return;
		}

		char sCurrency[MAX_CURRENCY_NAME_LENGTH];
		itemdata.GetString("currency", sCurrency, sizeof(sCurrency));

		if (strlen(sCurrency) == 0)
			g_Convar_DefaultCurrency.GetString(sCurrency, sizeof(sCurrency));
		
		char sRefundPercentage[12];
		itemdata.GetString("refund_percentage", sRefundPercentage, sizeof(sRefundPercentage));
		float refund_percentage = StringToFloat(sRefundPercentage);

		int refund = RoundFloat(price * refund_percentage);
		
		if (AddCurrency(client, refund, sCurrency))
		{
			PrintToChat(client, "Your item has been refunded for %i credits.", refund);
			ModularStore_RemoveItem(client, category, item);
		}
	}
}

public void ModularStore_OnConnectPost(const char[] entry, Database db)
{
	CreateTable();
}

void CreateTable()
{
	ModularStore_FastQuery("CREATE TABLE IF NOT EXISTS `store_player_currencies` ( `id` INT NOT NULL AUTO_INCREMENT , `name` VARCHAR(64) NOT NULL DEFAULT '' , `accountid` INT NOT NULL , `currency` VARCHAR(64) NOT NULL , `value` INT(16) NOT NULL DEFAULT '0' , `first_created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP , `last_updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP , PRIMARY KEY (`id`), UNIQUE (`accountid`, `currency`)) ENGINE = InnoDB;");
}

public void OnClientPutInServer(int client)
{
	if (!g_Convar_Status.BoolValue || IsFakeClient(client))
		return;

	g_Currencies[client] = new StringMap();
	
	char sQuery[128];
	FormatEx(sQuery, sizeof(sQuery), "SELECT currency, value FROM `store_player_currencies` WHERE accountid = '%i';", GetSteamAccountID(client));
	ModularStore_Query(OnParseCredits, sQuery, GetClientUserId(client), DBPrio_Low);
}

public void OnParseCredits(DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		LogError("Error while retrieving client credits: %s", error);
		return;
	}
	
	int client = -1;
	if ((client = GetClientOfUserId(data)) < 1)
		return;
	
	while (results.FetchRow())
	{
		char sCurrency[MAX_CURRENCY_NAME_LENGTH];
		results.FetchString(0, sCurrency, sizeof(sCurrency));

		int value = results.FetchInt(1);

		SetCurrency(client, value, sCurrency);
	}

	char sDefaultCurrency[MAX_CURRENCY_NAME_LENGTH];
	g_Convar_DefaultCurrency.GetString(sDefaultCurrency, sizeof(sDefaultCurrency));
	g_Currencies[client].SetValue(sDefaultCurrency, 1, false);
}

public void OnClientDisconnect(int client)
{
	if (!g_Convar_Status.BoolValue || IsFakeClient(client))
		return;
	
	SaveAllCurrencies(client);
}

public Action Command_SaveCurrency(int client, int args)
{
	if (!g_Convar_Status.BoolValue || client == 0)
		return Plugin_Handled;
	
	SaveAllCurrencies(client, true);
	return Plugin_Handled;
}

void SaveAllCurrencies(int client, bool announce = false)
{
	if (!g_Convar_Status.BoolValue || IsFakeClient(client))
		return;
	
	char sName[MAX_NAME_LENGTH];
	GetClientName(client, sName, sizeof(sName));

	int size = 2 * strlen(sName) + 1;
	char[] sEscapedName = new char[size];
	ModularStore_Escape(sName, sEscapedName, size);

	int accountid = GetSteamAccountID(client);

	Transaction txn = new Transaction();

	char sCurrency[MAX_CURRENCY_NAME_LENGTH]; int value; char sQuery[256];
	for (int i = 0; i < g_AvailableCurrencies.Length; i++)
	{
		g_AvailableCurrencies.GetString(i, sCurrency, sizeof(sCurrency));

		if (!g_Currencies[client].GetValue(sCurrency, value))
			continue;

		FormatEx(sQuery, sizeof(sQuery), "INSERT INTO `store_player_currencies` (name, accountid, currency) VALUES ('%s', '%i', '%s') ON DUPLICATE KEY UPDATE value = '%i', last_updated = NOW();", sEscapedName, accountid, sCurrency, value);
		txn.AddQuery(sQuery);
	}

	ModularStore_Transaction(txn);

	if (announce)
		CPrintToChat(client, "All currencies have been saved.");
}

public void OnClientDisconnect_Post(int client)
{
	delete g_Currencies[client];
}

int GetCurrency(int client, char[] currency)
{
	if (!g_Convar_Status.BoolValue)
		return 0;

	if (strlen(currency) == 0)
		g_Convar_DefaultCurrency.GetString(currency, MAX_CURRENCY_NAME_LENGTH);
	
	int value;
	g_Currencies[client].GetValue(currency, value);

	return value;
}

public int Native_GetCurrency(Handle plugin, int numParams)
{
	if (!g_Convar_Status.BoolValue)
		return ThrowNativeError(SP_ERROR_NATIVE, "Plugin is currently disabled.");
	
	int client = GetNativeCell(1);

	int size;
	GetNativeStringLength(2, size); size++;
	
	char[] sCurrency = new char[size];
	GetNativeString(2, sCurrency, size);

	return GetCurrency(client, sCurrency);
}

bool SetCurrency(int client, int value, char[] currency)
{
	if (!g_Convar_Status.BoolValue)
		return false;

	if (strlen(currency) == 0)
		g_Convar_DefaultCurrency.GetString(currency, MAX_CURRENCY_NAME_LENGTH);

	if (value < 0 || value > 100000)
		return false;
	
	g_Currencies[client].SetValue(currency, value);

	return true;
}

public Action Command_SetCurrency(int client, int args)
{
	if (!g_Convar_Status.BoolValue || IsFakeClient(client))
		return Plugin_Handled;

	if (args < 3)
	{
		char sCommand[MAX_COMMAND_NAME_LENGTH];
		GetCommandName(sCommand, sizeof(sCommand));
		CReplyToCommand(client, "[Usage] %s <target> <currency> <credits>", sCommand);
		return Plugin_Handled;
	}
	
	char sTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, sTarget, sizeof(sTarget));

	char sCurrency[MAX_CURRENCY_NAME_LENGTH];
	GetCmdArg(2, sCurrency, sizeof(sCurrency));

	if (g_AvailableCurrencies.FindString(sCurrency) == -1)
	{
		CReplyToCommand(client, "Error: Currency '%s' not found.", sCurrency);
		return Plugin_Handled;
	}

	int value;
	if ((value = GetCmdArgInt(3)) < 0)
	{
		CReplyToCommand(client, "Error: Value must be more than 0.");
		return Plugin_Handled;
	}

	int[] targets = new int[MaxClients];
	char sTargetName[MAX_TARGET_LENGTH];
	bool tn_is_ml;

	int count;
	if ((count = ProcessTargetString(sTarget, client, targets, MaxClients, COMMAND_FILTER_NO_BOTS, sTargetName, sizeof(sTargetName), tn_is_ml)) < 1)
	{
		ReplyToTargetError(client, count);
		return Plugin_Handled;
	}

	for (int i = 0; i < count; i++)
		SetCurrency(targets[i], value, sCurrency);
	
	CPrintToChatAll("%N has set %s's %s to %i.", client, sTargetName, sCurrency, value);
	
	return Plugin_Handled;
}

public int Native_SetCurrency(Handle plugin, int numParams)
{
	if (!g_Convar_Status.BoolValue)
		return ThrowNativeError(SP_ERROR_NATIVE, "Plugin is currently disabled.");
	
	int client = GetNativeCell(1);
	int value = GetNativeCell(2);

	int size;
	GetNativeStringLength(3, size); size++;
	
	char[] sCurrency = new char[size];
	GetNativeString(3, sCurrency, size);

	return SetCurrency(client, value, sCurrency);
}

bool AddCurrency(int client, int value, char[] currency)
{
	if (!g_Convar_Status.BoolValue)
		return false;

	if (strlen(currency) == 0)
		g_Convar_DefaultCurrency.GetString(currency, MAX_CURRENCY_NAME_LENGTH);

	int current;
	g_Currencies[client].GetValue(currency, current);

	current += value;

	if (current >= 100000)
		return false;
	
	g_Currencies[client].SetValue(currency, current);

	return true;
}

public Action Command_AddCurrency(int client, int args)
{
	if (!g_Convar_Status.BoolValue || IsFakeClient(client))
		return Plugin_Handled;

	if (args < 3)
	{
		char sCommand[MAX_COMMAND_NAME_LENGTH];
		GetCommandName(sCommand, sizeof(sCommand));
		CReplyToCommand(client, "[Usage] %s <target> <currency> <credits>", sCommand);
		return Plugin_Handled;
	}
	
	char sTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, sTarget, sizeof(sTarget));

	char sCurrency[MAX_CURRENCY_NAME_LENGTH];
	GetCmdArg(2, sCurrency, sizeof(sCurrency));

	if (g_AvailableCurrencies.FindString(sCurrency) == -1)
	{
		CReplyToCommand(client, "Error: Currency '%s' not found.", sCurrency);
		return Plugin_Handled;
	}

	int value;
	if ((value = GetCmdArgInt(3)) < 0)
	{
		CReplyToCommand(client, "Error: Value must be more than 0.");
		return Plugin_Handled;
	}

	int[] targets = new int[MaxClients];
	char sTargetName[MAX_TARGET_LENGTH];
	bool tn_is_ml;

	int count;
	if ((count = ProcessTargetString(sTarget, client, targets, MaxClients, COMMAND_FILTER_NO_BOTS, sTargetName, sizeof(sTargetName), tn_is_ml)) < 1)
	{
		ReplyToTargetError(client, count);
		return Plugin_Handled;
	}

	for (int i = 0; i < count; i++)
		AddCurrency(targets[i], value, sCurrency);
	
	CPrintToChatAll("%N has added %s's %s by %i.", client, sTargetName, sCurrency, value);
	
	return Plugin_Handled;
}

public int Native_AddCurrency(Handle plugin, int numParams)
{
	if (!g_Convar_Status.BoolValue)
		return ThrowNativeError(SP_ERROR_NATIVE, "Plugin is currently disabled.");
	
	int client = GetNativeCell(1);
	int value = GetNativeCell(2);

	int size;
	GetNativeStringLength(3, size); size++;
	
	char[] sCurrency = new char[size];
	GetNativeString(3, sCurrency, size);

	return AddCurrency(client, value, sCurrency);
}

bool RemoveCurrency(int client, int value, char[] currency)
{
	if (!g_Convar_Status.BoolValue)
		return false;
	
	if (strlen(currency) == 0)
		g_Convar_DefaultCurrency.GetString(currency, MAX_CURRENCY_NAME_LENGTH);
	
	int current;
	g_Currencies[client].GetValue(currency, current);

	if (current < value)
		return false;

	current -= value;

	if (current < 0)
		current = 0;

	g_Currencies[client].SetValue(currency, current);
	
	return true;
}

public Action Command_RemoveCurrency(int client, int args)
{
	if (!g_Convar_Status.BoolValue || IsFakeClient(client))
		return Plugin_Handled;

	if (args < 3)
	{
		char sCommand[MAX_COMMAND_NAME_LENGTH];
		GetCommandName(sCommand, sizeof(sCommand));
		CReplyToCommand(client, "[Usage] %s <target> <currency> <credits>", sCommand);
		return Plugin_Handled;
	}
	
	char sTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, sTarget, sizeof(sTarget));

	char sCurrency[MAX_CURRENCY_NAME_LENGTH];
	GetCmdArg(2, sCurrency, sizeof(sCurrency));

	if (g_AvailableCurrencies.FindString(sCurrency) == -1)
	{
		CReplyToCommand(client, "Error: Currency '%s' not found.", sCurrency);
		return Plugin_Handled;
	}

	int value;
	if ((value = GetCmdArgInt(3)) < 0)
	{
		CReplyToCommand(client, "Error: Value must be more than 0.");
		return Plugin_Handled;
	}

	int[] targets = new int[MaxClients];
	char sTargetName[MAX_TARGET_LENGTH];
	bool tn_is_ml;

	int count;
	if ((count = ProcessTargetString(sTarget, client, targets, MaxClients, COMMAND_FILTER_NO_BOTS, sTargetName, sizeof(sTargetName), tn_is_ml)) < 1)
	{
		ReplyToTargetError(client, count);
		return Plugin_Handled;
	}

	for (int i = 0; i < count; i++)
		RemoveCurrency(targets[i], value, sCurrency);
	
	CPrintToChatAll("%N has removed %s's %s by %i.", client, sTargetName, sCurrency, value);
	
	return Plugin_Handled;
}

public int Native_RemoveCurrency(Handle plugin, int numParams)
{
	if (!g_Convar_Status.BoolValue)
		return ThrowNativeError(SP_ERROR_NATIVE, "Plugin is currently disabled.");
	
	int client = GetNativeCell(1);
	int value = GetNativeCell(2);

	int size;
	GetNativeStringLength(3, size); size++;
	
	char[] sCurrency = new char[size];
	GetNativeString(3, sCurrency, size);

	return RemoveCurrency(client, value, sCurrency);
}