#if defined _modularstore_shop_included
  #endinput
#endif
#define _modularstore_shop_included

//Natives
native bool ModularStore_OpenShopMenu(int client);
native bool ModularStore_OpenCategoriesMenu(int client, const char[] category);
native bool ModularStore_OpenShopItemMenu(int client, const char[] category, const char[] item);
native bool ModularStore_GetItemType(const char[] category, const char[] item, char[] sBuffer, int iSize);
native ArrayList ModularStore_GetItemsList(const char[] category);
native StringMap ModularStore_GetItemsData(const char[] category);
native StringMap ModularStore_GetItemData(const char[] category, const char[] item);
native int ModularStore_GetItemDataValue(const char[] category, const char[] item, const char[] key);
native float ModularStore_GetItemDataFloat(const char[] category, const char[] item, const char[] key);
native bool ModularStore_GetItemDataString(const char[] category, const char[] item, const char[] key, char[] buffer, int size);
native bool ModularStore_GetItemDataBool(const char[] category, const char[] item, const char[] key);

//Forwards
forward Action ModularStore_OnShopOpen(int client);
forward void ModularStore_OnShopOpenPost(int client);
forward Action ModularStore_OnItemAction(int client, char[] category, char[] item, char[] action);
forward void ModularStore_OnItemActionPost(int client, const char[] category, const char[] item, const char[] action);

#if !defined REQUIRE_PLUGIN
public void __pl_modularstore_shop_SetNTVOptional()
{
	MarkNativeAsOptional("ModularStore_OpenShopMenu");
	MarkNativeAsOptional("ModularStore_OpenCategoriesMenu");
	MarkNativeAsOptional("ModularStore_OpenShopItemMenu");
	MarkNativeAsOptional("ModularStore_ExecuteItemAction");
	MarkNativeAsOptional("ModularStore_GetItemType");
	MarkNativeAsOptional("ModularStore_GetItemsList");
	MarkNativeAsOptional("ModularStore_GetItemsData");
	MarkNativeAsOptional("ModularStore_GetItemData");
	MarkNativeAsOptional("ModularStore_GetItemDataValue");
	MarkNativeAsOptional("ModularStore_GetItemDataFloat");
	MarkNativeAsOptional("ModularStore_GetItemDataString");
	MarkNativeAsOptional("ModularStore_GetItemDataBool");
}
#endif

public SharedPlugin __pl_modularstore_shop =
{
	name = "modularstore-shop",
	file = "store-shop.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};
