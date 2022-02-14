#if defined _modularstore_menu_included
  #endinput
#endif
#define _modularstore_menu_included

//Typedefs
typedef RegisterStoreItem_OnPress = function void (int client);

//Natives
native bool ModularStore_ReloadStoreItems();
native bool ModularStore_RegisterStoreItem(const char[] name, const char[] display, RegisterStoreItem_OnPress onpress);
native bool ModularStore_IsAcceptingItemRegistrations();
native void ModularStore_OpenStoreMenu(int client);

//Forwards
forward void ModularStore_OnRegisterItemsPost();

#if !defined REQUIRE_PLUGIN
public void __pl_modularstore_menu_SetNTVOptional()
{
	MarkNativeAsOptional("ModularStore_ReloadStoreItems");
	MarkNativeAsOptional("ModularStore_RegisterStoreItem");
	MarkNativeAsOptional("ModularStore_IsAcceptingItemRegistrations");
	MarkNativeAsOptional("ModularStore_OpenStoreMenu");
}
#endif

public SharedPlugin __pl_modularstore_menu =
{
	name = "modularstore-menu",
	file = "store-menu.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};
