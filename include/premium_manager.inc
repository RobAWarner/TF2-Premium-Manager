#define PREMIUM_PREFIX "\x01[\x07CCFE44Premium\x01]"

public SharedPlugin:__pl_premium_manager = 
{
    name = "premium_manager",
    file = "premium_manager.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

public __pl_premium_manager_SetNTVOptional()
{
    MarkNativeAsOptional("Premium_RegisterEffect");
    MarkNativeAsOptional("Premium_UnRegisterEffect");
    MarkNativeAsOptional("Premium_IsClientPremium");
    MarkNativeAsOptional("Premium_ShowMenu");
    MarkNativeAsOptional("Premium_IsEffectEnabled");
    MarkNativeAsOptional("Premium_SetEffectState");
    MarkNativeAsOptional("Premium_AddConfigOption");
}

functag PremiumECE public(client);
functag PremiumECD public(client);

/**
 * Registers an effect
 *
 * @param name               A name to be used to reference to this effect, will be used as its command.
 * @param displayName        A name to display to players for this effect.
 * @param enableCallback     A function to use as a callback for when an effect should be enabled
 * @param disabledCallback   A function to use as a callback for when an effect should be disabled
 * @param menuItem           Optional: Add a entry into premium menu for this effect.
 * @noreturn
 */

native Premium_RegisterEffect(const String:name[], const String:displayName[], PremiumECE:enableCallback, PremiumECD:disabledCallback, bool:menuItem = true);

/**
 * UnRegisters an effect
 *
 * @param name   The name used to register the effect.
 * @noreturn
 */
native Premium_UnRegisterEffect(const String:name[]);

/**
 * Returns whether or not a player has premium status
 *
 * @param client   Client to check.
 * @return         True if premium, false otherwise.
 */

native bool:Premium_IsClientPremium(client);

/**
 * Display the premium menu to a client if they have premium status
 *
 * @param client   Client to check.
 * @return         True if premium, false otherwise.
 */

native bool:Premium_ShowMenu(client);

/**
 * Gets the current on/off status of an effect
 *
 * @param client   Client to get cookie for.
 * @param name     Effect name to check.
 * @return         True if enabled, false otherwise.
 */

native bool:Premium_IsEffectEnabled(client, const String:name[]);

/**
 * Sets the current on/off status of an effect
 *
 * @param client    Client to change cookie for.
 * @param effect    Effect name to set.
 * @param enabled   Bool to enabled/disable effect.
 * @noreturn
 */

native bool:Premium_SetEffectState(client, const String:name[], bool:enabled);

/**
 * Adds a 'configure' option to an effects menu item
 *
 * @param effect     Effect name to add menu to.
 * @param callback   Function to call when user select the configure option.
 * @noreturn
 */

native bool:Premium_AddConfigOption(const String:name[], bool:enabled);