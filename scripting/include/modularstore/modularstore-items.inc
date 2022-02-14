#if defined _modularstore_items_included
  #endinput
#endif
#define _modularstore_items_included

//Enums
enum RegisterStatus
{
	Register_Successful,
	Register_AlreadyRegistered,
	Register_EmptyNameField,
	Register_ActionNotCalled,
	Register_Disabled,
	Register_UnknownError
}

//Typedefs
typedef RegisterItemType_OnAction = function Action (int client, const char[] action, StringMap itemdata);

//Natives
native void ModularStore_CallRegisterItemTypes();
native RegisterStatus ModularStore_RegisterItemType(const char[] name, const char[] display, RegisterItemType_OnAction action);
native Action ModularStore_ExecuteItemAction(int client, const char[] category, const char[] item, const char[] action);
native bool ModularStore_IsItemTypeRegistered(const char[] name);
native bool ModularStore_UnregisterItemType(const char[] name);
native bool ModularStore_UnregisterAllItemTypes();
native bool ModularStore_GetItemTypeDisplay(const char[] name, char[] buffer, int size);

//Forwards
forward Action ModularStore_OnRegisterItemTypes();
forward void ModularStore_OnRegisterItemTypesPost();

#if !defined REQUIRE_PLUGIN
public void __pl_modularstore_items_SetNTVOptional()
{
	MarkNativeAsOptional("ModularStore_CallRegisterItemTypes");
	MarkNativeAsOptional("ModularStore_RegisterItemType");
	MarkNativeAsOptional("ModularStore_ExecuteItemAction");
	MarkNativeAsOptional("ModularStore_IsItemTypeRegistered");
	MarkNativeAsOptional("ModularStore_UnregisterItemType");
	MarkNativeAsOptional("ModularStore_UnregisterAllItemTypes");
	MarkNativeAsOptional("ModularStore_GetItemTypeDisplay");
}
#endif

public SharedPlugin __pl_modularstore_items =
{
	name = "modularstore-items",
	file = "store-items.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};
