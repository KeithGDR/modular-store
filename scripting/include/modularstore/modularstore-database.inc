#if defined _modularstore_database_included
  #endinput
#endif
#define _modularstore_database_included

//Typedefs
typedef ModularStore_OnQuery = function void (DBResultSet results, const char[] error, any data);
typedef ModularStore_OnTrans_Success = function void (any data, int numQueries, DBResultSet[] results, any[] queryData);
typedef ModularStore_OnTrans_Failure = function void (any data, int numQueries, const char[] error, int failIndex, any[] queryData);

//Natives
native bool ModularStore_IsConnected();
native Database ModularStore_CopyDatabase();
native bool ModularStore_Query(ModularStore_OnQuery callback, const char[] query, any data = 0, DBPriority prio = DBPrio_Normal);
native bool ModularStore_FastQuery(const char[] query, DBPriority prio = DBPrio_Normal);
native bool ModularStore_Transaction(Transaction txn, ModularStore_OnTrans_Success onSuccess = INVALID_FUNCTION, ModularStore_OnTrans_Failure onError = INVALID_FUNCTION, any data = 0, DBPriority priority = DBPrio_Normal);
native bool ModularStore_Escape(const char[] string, char[] buffer, int maxlength, int& written = 0);
native bool ModularStore_IsSameConnection(Database other);

//Forwards
forward Action ModularStore_OnConnect(char[] entry);
forward void ModularStore_OnConnectPost(const char[] entry, Database db);

#if !defined REQUIRE_PLUGIN
public void __pl_modularstore_database_SetNTVOptional()
{
	MarkNativeAsOptional("ModularStore_IsConnected");
	MarkNativeAsOptional("ModularStore_CopyDatabase");
	MarkNativeAsOptional("ModularStore_Query");
	MarkNativeAsOptional("ModularStore_FastQuery");
	MarkNativeAsOptional("ModularStore_Transaction");
	MarkNativeAsOptional("ModularStore_Escape");
	MarkNativeAsOptional("ModularStore_IsSameConnection");
}
#endif

public SharedPlugin __pl_modularstore_database =
{
	name = "modularstore-database",
	file = "store-database.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};
