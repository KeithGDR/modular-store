#if defined _modularstore_currency_included
  #endinput
#endif
#define _modularstore_currency_included

//Natives
native int ModularStore_GetCurrency(int client, const char[] currency = NULL_STRING);
native bool ModularStore_SetCurrency(int client, int value, const char[] currency = NULL_STRING);
native bool ModularStore_AddCurrency(int client, int value, const char[] currency = NULL_STRING);
native bool ModularStore_RemoveCurrency(int client, int value, const char[] currency = NULL_STRING);

//Forwards

#if !defined REQUIRE_PLUGIN
public void __pl_modularstore_currency_SetNTVOptional()
{
	MarkNativeAsOptional("ModularStore_GetCurrency");
	MarkNativeAsOptional("ModularStore_SetCurrency");
	MarkNativeAsOptional("ModularStore_AddCurrency");
	MarkNativeAsOptional("ModularStore_RemoveCurrency");
}
#endif

public SharedPlugin __pl_modularstore_currency =
{
	name = "modularstore-currency",
	file = "store-currency.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};
