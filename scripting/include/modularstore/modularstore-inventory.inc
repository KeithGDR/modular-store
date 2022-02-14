#if defined _modularstore_inventory_included
  #endinput
#endif
#define _modularstore_inventory_included

//Natives
native bool ModularStore_OpenInventoryMenu(int client);
native bool ModularStore_OpenInventoryCategoryMenu(int client, const char[] category, bool show_amount = true);
native bool ModularStore_OpenInventoryItemMenu(int client, const char[] category);
native bool ModularStore_IsItemOwned(int client, const char[] category, const char[] item);
native int ModularStore_GetItemCount(int client, const char[] category, const char[] item);
native bool ModularStore_GiveItem(int client, const char[] category, const char[] item, bool message = false);
native bool ModularStore_RemoveItem(int client, const char[] category, const char[] item, bool message = false);
native bool ModularStore_IsItemEquipped(int client, const char[] category, const char[] item);
native bool ModularStore_EquipItem(int client, const char[] category, const char[] item);
native bool ModularStore_UnequipItem(int client, const char[] category, const char[] item);
native bool ModularStore_GetEquippedItem(int client, const char[] category, char[] buffer, int size);

//Forwards
forward void ModularStore_OnGiveItemPost(int client, const char[] category, const char[] item, int amount);
forward void ModularStore_OnRemoveItemPost(int client, const char[] category, const char[] item, int amount);
forward void ModularStore_OnEquipItemPost(int client, const char[] category, const char[] item, bool equipped);
forward void ModularStore_OnUnequipItemPost(int client, const char[] category, const char[] item, bool unequipped);

#if !defined REQUIRE_PLUGIN
public void __pl_modularstore_inventory_SetNTVOptional()
{
	MarkNativeAsOptional("ModularStore_OpenInventoryMenu");
	MarkNativeAsOptional("ModularStore_OpenInventoryCategoryMenu");
	MarkNativeAsOptional("ModularStore_OpenInventoryItemMenu");
	MarkNativeAsOptional("ModularStore_IsItemOwned");
	MarkNativeAsOptional("ModularStore_GetItemCount");
	MarkNativeAsOptional("ModularStore_GiveItem");
	MarkNativeAsOptional("ModularStore_RemoveItem");
	MarkNativeAsOptional("ModularStore_IsItemEquipped");
	MarkNativeAsOptional("ModularStore_EquipItem");
	MarkNativeAsOptional("ModularStore_UnequipItem");
	MarkNativeAsOptional("ModularStore_GetEquippedItem");
}
#endif

public SharedPlugin __pl_modularstore_inventory =
{
	name = "modularstore-currency",
	file = "store-currency.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};
