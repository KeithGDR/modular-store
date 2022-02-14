//Pragma
#pragma semicolon 1
#pragma newdecls required

//Module Info
#define MODULE_DESCRIPTION "The Database module for the modular store system."
#define MODULE_VERSION "1.0.0"

//Sourcemod Includes
#include <sourcemod>
#include <sourcemod-misc>

//Our Includes
#include <modularstore/modularstore-globals>
#include <modularstore/modularstore-database>

//ConVars
ConVar g_Convar_Status;

//Forwards
Handle g_Forward_OnConnect;
Handle g_Forward_OnConnectPost;

//Globals
Database g_Database;

public Plugin myinfo = 
{
	name = "[Modular Store] :: Database", 
	author = "Keith Warren (Shaders Allen)", 
	description = MODULE_DESCRIPTION, 
	version = MODULE_VERSION, 
	url = "https://github.com/ShadersAllen"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("modularstore-database");

	CreateNative("ModularStore_IsConnected", Native_IsConnected);
	CreateNative("ModularStore_CopyDatabase", Native_CopyDatabase);
	CreateNative("ModularStore_Query", Native_Query);
	CreateNative("ModularStore_FastQuery", Native_FastQuery);
	CreateNative("ModularStore_Transaction", Native_Transaction);
	CreateNative("ModularStore_Escape", Native_Escape);
	CreateNative("ModularStore_IsSameConnection", Native_IsSameConnection);

	g_Forward_OnConnect = CreateGlobalForward("ModularStore_OnConnect", ET_Event, Param_String);
	g_Forward_OnConnectPost = CreateGlobalForward("ModularStore_OnConnectPost", ET_Ignore, Param_String, Param_Cell);

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("modularstore-globals.phrases");
	LoadTranslations("modularstore-database.phrases");
	
	CreateConVar("sm_modularstore_database_version", MODULE_VERSION, MODULE_DESCRIPTION, FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_SPONLY | FCVAR_DONTRECORD);
	g_Convar_Status = CreateConVar("sm_modularstore_database_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	//AutoExecConfig(true, "store-database", "modularstore");
}

public void OnConfigsExecuted()
{
	if (!g_Convar_Status.BoolValue)
		return;
	
	if (g_Database == null)
	{
		char sStore[64];
		strcopy(sStore, sizeof(sStore), "store");

		Call_StartForward(g_Forward_OnConnect);
		Call_PushStringEx(sStore, sizeof(sStore), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
		Action results = Plugin_Continue; Call_Finish(results);

		if (results == Plugin_Continue)
			strcopy(sStore, sizeof(sStore), "store");

		Database.Connect(OnSQLConnect, "store");
	}
}

public void OnSQLConnect(Database db, const char[] error, any data)
{
	if (!g_Convar_Status.BoolValue)
	{
		delete db;
		return;
	}
	
	if (db == null)
	{
		LogError("Error while connecting to database: %s", error);
		return;
	}

	if (g_Database != null)
	{
		delete db;
		return;
	}

	g_Database = db;
	LogMessage("Connected to database successfully.");

	char sStore[64];
	strcopy(sStore, sizeof(sStore), "store");

	Call_StartForward(g_Forward_OnConnectPost);
	Call_PushString(sStore);
	Call_PushCell(g_Database);
	Call_Finish();
}

bool IsConnected()
{
	if (!g_Convar_Status.BoolValue)
		return false;
	
	return g_Database != null;
}

public int Native_IsConnected(Handle plugin, int numParams)
{
	if (!g_Convar_Status.BoolValue)
		return ThrowNativeError(SP_ERROR_NATIVE, "Plugin is currently disabled.");
	
	return IsConnected();
}

Database CopyDatabase()
{
	if (!g_Convar_Status.BoolValue)
		return null;

	return view_as<Database>(CloneHandle(g_Database));
}

public int Native_CopyDatabase(Handle plugin, int numParams)
{
	if (!g_Convar_Status.BoolValue)
		return ThrowNativeError(SP_ERROR_NATIVE, "Plugin is currently disabled.");
	
	return view_as<any>(CopyDatabase());
}

bool CreateQuery(Handle plugin, SQLQueryCallback callback, const char[] query, any data, DBPriority prio)
{
	if (!g_Convar_Status.BoolValue)
		return false;
	
	if (g_Database == null)
		return false;

	DataPack pack = new DataPack();
	pack.WriteCell(plugin);
	pack.WriteFunction(callback);
	pack.WriteCell(data);
	
	g_Database.Query(OnNativeQuery, query, pack, prio);
	return true;
}

public void OnNativeQuery(Database db, DBResultSet results, const char[] error, DataPack data)
{
	data.Reset();
	Handle plugin = data.ReadCell();
	Function callback = data.ReadFunction();
	any data2 = data.ReadCell();
	delete data;

	Call_StartFunction(plugin, callback);
	Call_PushCell(results);
	Call_PushString(error);
	Call_PushCell(data2);
	Call_Finish();
}

public int Native_Query(Handle plugin, int numParams)
{
	if (!g_Convar_Status.BoolValue)
		return ThrowNativeError(SP_ERROR_NATIVE, "Plugin is currently disabled.");
	
	SQLQueryCallback callback = GetNativeCell(1);

	int size;
	GetNativeStringLength(2, size); size++;

	char[] query = new char[size];
	GetNativeString(2, query, size);

	any data = GetNativeCell(3);
	DBPriority prio = GetNativeCell(4);

	return CreateQuery(plugin, callback, query, data, prio);
}

bool CreateFastQuery(const char[] query, DBPriority prio)
{
	if (!g_Convar_Status.BoolValue)
		return false;
	
	if (g_Database == null)
		return false;
	
	g_Database.Query(OnFastQuery, query, _, prio);
	return true;
}

public void OnFastQuery(Database db, DBResultSet results, const char[] error, any data)
{
	if (!g_Convar_Status.BoolValue)
		return;
	
	if (results == null)
		LogError("Error while processing results: %s", error);
}

public int Native_FastQuery(Handle plugin, int numParams)
{
	if (!g_Convar_Status.BoolValue)
		return ThrowNativeError(SP_ERROR_NATIVE, "Plugin is currently disabled.");
	
	int size;
	GetNativeStringLength(1, size); size++;

	char[] query = new char[size];
	GetNativeString(1, query, size);

	DBPriority prio = GetNativeCell(2);

	return CreateFastQuery(query, prio);
}

bool CreateTransaction(Handle plugin, Transaction txn, Function onSuccess, Function onError, any data, DBPriority priority)
{
	if (!g_Convar_Status.BoolValue)
		return false;
	
	if (g_Database == null)
		return false;
	
	DataPack pack = new DataPack();
	pack.WriteCell(plugin);
	pack.WriteFunction(onSuccess);
	pack.WriteFunction(onError);
	pack.WriteCell(data);
	
	g_Database.Execute(txn, onNativeSuccess, onNativeError, pack, priority);
	return true;
}

public void onNativeSuccess(Database db, DataPack data, int numQueries, DBResultSet[] results, any[] queryData)
{
	data.Reset();

	Handle plugin = data.ReadCell();
	Function onSuccess = data.ReadFunction();
	data.ReadFunction();
	any data2 = data.ReadCell();

	delete data;
	
	if (plugin != null && onSuccess != INVALID_FUNCTION)
	{
		Call_StartFunction(plugin, onSuccess);
		Call_PushCell(data2);
		Call_PushCell(numQueries);
		Call_PushArray(results, numQueries);
		Call_PushArray(queryData, numQueries);
		Call_Finish();
	}
}

public void onNativeError(Database db, DataPack data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	data.Reset();

	Handle plugin = data.ReadCell();
	data.ReadFunction();
	Function onError = data.ReadFunction();
	any data2 = data.ReadCell();

	delete data;
	
	if (plugin != null && onError != INVALID_FUNCTION)
	{
		Call_StartFunction(plugin, onError);
		Call_PushCell(data2);
		Call_PushCell(numQueries);
		Call_PushString(error);
		Call_PushCell(failIndex);
		Call_PushArray(queryData, numQueries);
		Call_Finish();
	}
}

public int Native_Transaction(Handle plugin, int numParams)
{
	if (!g_Convar_Status.BoolValue)
		return ThrowNativeError(SP_ERROR_NATIVE, "Plugin is currently disabled.");
	
	Transaction txn = GetNativeCell(1);
	Function onSuccess = GetNativeCell(2);
	Function onError = GetNativeCell(3);
	any data = GetNativeCell(4);
	DBPriority prio = GetNativeCell(5);

	return CreateTransaction(plugin, txn, onSuccess, onError, data, prio);
}

bool EscapeBuffer(const char[] string, char[] buffer, int maxlength, int& written)
{
	if (!g_Convar_Status.BoolValue)
		return false;
	
	if (g_Database == null)
		return false;
	
	g_Database.Escape(string, buffer, maxlength, written);
	return true;
}

public int Native_Escape(Handle plugin, int numParams)
{
	if (!g_Convar_Status.BoolValue)
		return ThrowNativeError(SP_ERROR_NATIVE, "Plugin is currently disabled.");
	
	int size;
	GetNativeStringLength(1, size); size++;

	char[] string = new char[size];
	GetNativeString(1, string, size);

	int maxlength = GetNativeCell(3);

	char[] buffer = new char[maxlength]; int written;
	bool success = EscapeBuffer(string, buffer, maxlength, written);

	SetNativeString(2, buffer, maxlength);
	SetNativeCellRef(4, written);

	return success;
}

bool CheckSameConnection(Database other)
{
	if (!g_Convar_Status.BoolValue)
		return false;
	
	return g_Database.IsSameConnection(other);
}

public int Native_IsSameConnection(Handle plugin, int numParams)
{
	if (!g_Convar_Status.BoolValue)
		return ThrowNativeError(SP_ERROR_NATIVE, "Plugin is currently disabled.");
	
	Database other = GetNativeCell(1);

	return CheckSameConnection(other);
}