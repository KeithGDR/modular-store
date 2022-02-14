//Pragma
#pragma semicolon 1
#pragma newdecls required

//Module Info
#define MODULE_DESCRIPTION "The items module for the modular store system."
#define MODULE_VERSION "1.0.0"

//Sourcemod Includes
#include <sourcemod>
#include <sourcemod-misc>

//Our Includes
#include <modularstore/modularstore-globals>
#include <modularstore/modularstore-items>

#undef REQUIRE_PLUGIN
#include <modularstore/modularstore-shop>
#define REQUIRE_PLUGIN

//ConVars
ConVar g_Convar_Status;

//Forwards
Handle g_Forward_OnRegisterItemTypes;
Handle g_Forward_OnRegisterItemTypesPost;
Handle g_Forward_OnItemAction;
Handle g_Forward_OnItemActionPost;

//Globals
ArrayList g_TypesList;
StringMap g_TypePlugin;	//Handle Heaven
StringMap g_TypeDisplay;
StringMap g_TypeActionCalls;	//Handle Hell

public Plugin myinfo = 
{
	name = "[Modular Store] :: Items", 
	author = "Keith Warren (Shaders Allen)", 
	description = MODULE_DESCRIPTION, 
	version = MODULE_VERSION, 
	url = "https://github.com/ShadersAllen"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("modularstore-items");

	CreateNative("ModularStore_CallRegisterItemTypes", Native_CallRegisterItemTypes);
	CreateNative("ModularStore_RegisterItemType", Native_RegisterItemType);
	CreateNative("ModularStore_ExecuteItemAction", Native_ExecuteItemAction);
	CreateNative("ModularStore_IsItemTypeRegistered", Native_IsItemTypeRegistered);
	CreateNative("ModularStore_UnregisterItemType", Native_UnregisterItemType);
	CreateNative("ModularStore_UnregisterAllItemTypes", Native_UnregisterAllItemTypes);
	CreateNative("ModularStore_GetItemTypeDisplay", Native_GetItemTypeDisplay);
	
	g_Forward_OnRegisterItemTypes = CreateGlobalForward("ModularStore_OnRegisterItemTypes", ET_Event);
	g_Forward_OnRegisterItemTypesPost = CreateGlobalForward("ModularStore_OnRegisterItemTypesPost", ET_Ignore);
	g_Forward_OnItemAction = CreateGlobalForward("ModularStore_OnItemAction", ET_Event, Param_Cell, Param_String, Param_String, Param_String);
	g_Forward_OnItemActionPost = CreateGlobalForward("ModularStore_OnItemActionPost", ET_Ignore, Param_Cell, Param_String, Param_String, Param_String);

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("modularstore-globals.phrases");
	LoadTranslations("modularstore-items.phrases");
	
	CreateConVar("sm_modularstore_items_version", MODULE_VERSION, MODULE_DESCRIPTION, FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_SPONLY | FCVAR_DONTRECORD);
	g_Convar_Status = CreateConVar("sm_modularstore_items_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	//AutoExecConfig(true, "store-items", "modularstore");

	g_TypesList = new ArrayList(ByteCountToCells(MAX_TYPE_NAME_LENGTH));
	g_TypePlugin = new StringMap();
	g_TypeDisplay = new StringMap();
	g_TypeActionCalls = new StringMap();
}

public void OnConfigsExecuted()
{
	if (!g_Convar_Status.BoolValue)
		return;
}

public void OnAllPluginsLoaded()
{
	if (!g_Convar_Status.BoolValue)
		return;
	
	CallRegisterItemTypes();
}

bool CallRegisterItemTypes()
{
	if (!g_Convar_Status.BoolValue)
		return false;
	
	Call_StartForward(g_Forward_OnRegisterItemTypes);
	Action result = Plugin_Continue; Call_Finish(result);

	if (result == Plugin_Changed)
		UnregisterAllItemTypes();

	if (result > Plugin_Changed)
		return false;

	Call_StartForward(g_Forward_OnRegisterItemTypesPost);
	Call_Finish();

	return true;
}

public int Native_CallRegisterItemTypes(Handle plugin, int numParams)
{
	if (!g_Convar_Status.BoolValue)
		return ThrowNativeError(SP_ERROR_NATIVE, "Plugin is currently disabled.");
	
	return CallRegisterItemTypes();
}

public void ModularStore_OnItemActionPost(int client, const char[] category, const char[] item, const char[] action)
{
	if (!g_Convar_Status.BoolValue)
		return;
	
	char sType[MAX_TYPE_NAME_LENGTH];
	ModularStore_GetItemType(category, item, sType, sizeof(sType));
	
	StringMap itemdata = ModularStore_GetItemData(category, item);
	
	ExecuteAction(client, sType, action, itemdata);
}

bool ExecuteAction(int client, const char[] type, const char[] action, StringMap itemdata)
{
	if (!g_Convar_Status.BoolValue)
		return false;

	Handle action_callback;
	if (!g_TypeActionCalls.GetValue(type, action_callback))
		return false;

	if (action_callback != null && GetForwardFunctionCount(action_callback) > 0)
	{
		Call_StartForward(action_callback);
		Call_PushCell(client);
		Call_PushString(action);
		Call_PushCell(itemdata);
		Call_Finish();

		return true;
	}

	return false;
}

RegisterStatus RegisterItemType(Handle plugin, const char[] name, const char[] display, Function action)
{
	if (!g_Convar_Status.BoolValue)
		return Register_Disabled;
	
	if (strlen(name) == 0)
		return Register_EmptyNameField;
	
	if (g_TypesList.FindString(name) != -1)
		return Register_AlreadyRegistered;
	
	if (action == INVALID_FUNCTION)
		return Register_ActionNotCalled;

	Handle action_callback = CreateForward(ET_Ignore, Param_Cell, Param_String, Param_Cell);

	if (action_callback == null)
		return Register_UnknownError;

	AddToForward(action_callback, plugin, action);

	g_TypesList.PushString(name);
	g_TypePlugin.SetValue(name, plugin);
	g_TypeDisplay.SetString(name, display);
	g_TypeActionCalls.SetValue(name, action_callback);

	return Register_Successful;
}

public int Native_RegisterItemType(Handle plugin, int numParams)
{
	if (!g_Convar_Status.BoolValue)
		return ThrowNativeError(SP_ERROR_NATIVE, "Plugin is currently disabled.");
	
	int size;

	GetNativeStringLength(1, size); size++;
	char[] sItemType = new char[size];
	GetNativeString(1, sItemType, size + 1);

	GetNativeStringLength(2, size); size++;
	char[] sItemDisplay = new char[size];
	GetNativeString(2, sItemDisplay, size + 1);

	Function action = GetNativeFunction(3);

	return view_as<int>(RegisterItemType(plugin, sItemType, sItemDisplay, action));
}

Action ExecuteItemAction(int client, char[] category, char[] item, char[] action)
{
	if (!g_Convar_Status.BoolValue)
		return Plugin_Continue;
	
	Call_StartForward(g_Forward_OnItemAction);
	Call_PushCell(client);
	Call_PushStringEx(category, MAX_CATEGORY_NAME_LENGTH, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushStringEx(item, MAX_ITEM_NAME_LENGTH, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushStringEx(action, MAX_ACTION_NAME_LENGTH, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Action results = Plugin_Continue; Call_Finish(results);

	if (results > Plugin_Changed)
		return results;

	Call_StartForward(g_Forward_OnItemActionPost);
	Call_PushCell(client);
	Call_PushString(category);
	Call_PushString(item);
	Call_PushString(action);
	Call_Finish();

	return results;
}

public int Native_ExecuteItemAction(Handle plugin, int numParams)
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

	GetNativeStringLength(4, size); size++;
	char[] sAction = new char[size];
	GetNativeString(4, sAction, size);

	return view_as<any>(ExecuteItemAction(client, sCategory, sItem, sAction));
}

bool IsItemTypeRegistered(const char[] name)
{
	if (!g_Convar_Status.BoolValue)
		return false;
	
	return g_TypesList.FindString(name) != -1;
}

public int Native_IsItemTypeRegistered(Handle plugin, int numParams)
{
	if (!g_Convar_Status.BoolValue)
		return ThrowNativeError(SP_ERROR_NATIVE, "Plugin is currently disabled.");
	
	int size;
	GetNativeStringLength(1, size); size++;

	char[] name = new char[size];
	GetNativeString(1, name, size);

	return IsItemTypeRegistered(name);
}

bool UnregisterItemType(const char[] name)
{
	if (!g_Convar_Status.BoolValue)
		return false;
	
	int index = g_TypesList.FindString(name);

	if (index == -1)
		return false;
	
	g_TypesList.Erase(index);

	g_TypePlugin.Remove(name);
	g_TypeDisplay.Remove(name);

	Handle action_callback;
	g_TypeActionCalls.GetValue(name, action_callback);
	delete action_callback;

	g_TypeActionCalls.Remove(name);

	return true;
}

public int Native_UnregisterItemType(Handle plugin, int numParams)
{
	if (!g_Convar_Status.BoolValue)
		return ThrowNativeError(SP_ERROR_NATIVE, "Plugin is currently disabled.");
	
	int size;
	GetNativeStringLength(1, size); size++;

	char[] name = new char[size];
	GetNativeString(1, name, size);

	return UnregisterItemType(name);
}

bool UnregisterAllItemTypes()
{
	if (!g_Convar_Status.BoolValue)
		return false;
	
	if (g_TypesList.Length == 0)
		return false;
	
	g_TypesList.Clear();
	g_TypePlugin.Clear();
	g_TypeDisplay.Clear();
	g_TypeActionCalls.Clear();

	return true;
}

public int Native_UnregisterAllItemTypes(Handle plugin, int numParams)
{
	if (!g_Convar_Status.BoolValue)
		return ThrowNativeError(SP_ERROR_NATIVE, "Plugin is currently disabled.");
	
	return UnregisterAllItemTypes();
}

bool GetItemTypeDisplay(const char[] type, char[] display, int size)
{
	if (!g_Convar_Status.BoolValue)
		return false;
	
	return g_TypeDisplay.GetString(type, display, size);
}

public int Native_GetItemTypeDisplay(Handle plugin, int numParams)
{
	if (!g_Convar_Status.BoolValue)
		return ThrowNativeError(SP_ERROR_NATIVE, "Plugin is currently disabled.");
	
	int size;
	GetNativeStringLength(1, size); size++;

	char[] sItemType = new char[size];
	GetNativeString(1, sItemType, size);

	char sItemDisplay[MAX_DISPLAY_NAME_LENGTH];
	bool successful = GetItemTypeDisplay(sItemType, sItemDisplay, sizeof(sItemDisplay));
	
	if (successful)
		SetNativeString(2, sItemDisplay, GetNativeCell(3));

	return successful;
}