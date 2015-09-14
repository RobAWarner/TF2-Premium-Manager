#define PREMIUM_PREFIX "\x01[\x07CCFE44Premium\x01]"
#define PREMIUM_PREFIX_NOCOLOR "[Premium]"
#define PREMIUM_MENU_TIME 120

#define PREMIUM_COOLDOWN_ENABLE 1
#define PREMIUM_COOLDOWN_DISABLE 2
#define PREMIUM_COOLDOWN_BOTH 3

#define PREMIUM_RETURN_HIDEMENU 10
#define PREMIUM_CALL_STOP 11

public SharedPlugin:__pl_premium_manager = {
    name = "premium_manager",
    file = "premium_manager.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

public __pl_premium_manager_SetNTVOptional() {
    MarkNativeAsOptional("Premium_RegEffect");
    MarkNativeAsOptional("Premium_RegBasicEffect");
    MarkNativeAsOptional("Premium_UnRegEffect");
    MarkNativeAsOptional("Premium_AddEffectCooldown");
    MarkNativeAsOptional("Premium_IsClientPremium");
    MarkNativeAsOptional("Premium_ShowMenu");
    MarkNativeAsOptional("Premium_ShowLastMenu");
    MarkNativeAsOptional("Premium_IsEffectEnabled");
    MarkNativeAsOptional("Premium_SetEffectState");
    MarkNativeAsOptional("Premium_AddMenuOption");
    MarkNativeAsOptional("Premium_ActivateClientCooldown");
    MarkNativeAsOptional("Premium_ResetClientCooldown");
}

functag PremiumECE public(client);
functag PremiumECD public(client);
functag PremiumECF public(client);
functag PremiumMC public(client);

forward Premium_ManagerLoaded();
forward Premium_ManagerUnLoaded();

/**
 * Registers a togglable effect
 *
 * @param effect             A name to be used to reference to this effect, will be used as its command.
 * @param displayName        A name to display to players for this effect.
 * @param enableCallback     A function to use as a callback for when an effect should be enabled
 * @param disabledCallback   A function to use as a callback for when an effect should be disabled
 * @param menuItem           Add a entry into premium menu for this effect.
 * @return                   True is effect registered, false if it already exists
 */

native bool:Premium_RegEffect(const String:effect[], const String:displayName[], PremiumECE:enableCallback, PremiumECD:disabledCallback, bool:menuItem = true);

/**
 * Registers a basic effect with just a fire callback
 *
 * @param effect             A name to be used to reference to this effect, will be used as its command.
 * @param displayName        A name to display to players for this effect.
 * @param fireCallback       A function to use as a callback for when a user runs the command
 * @param menuItem           Add a entry into premium menu for this effect.
 * @return                   True is effect registered, false if it already exists
 */

native bool:Premium_RegBasicEffect(const String:effect[], const String:displayName[], PremiumECF:fireCallback, bool:menuItem = true);

/**
 * UnRegisters an effect
 *
 * @param effect   The name used to register the effect.
 * @noreturn
 */
native bool:Premium_UnRegEffect(const String:effect[]);

/**
 * Adds a cooldown to the registered effect
 *
 * @param effect   The name used to register the effect.
 * @param time     Cooldown time (in seconds).
 * @param flag     Flag to specify when to apply cooldown (PREMIUM_COOLDOWN_ENABLE, PREMIUM_COOLDOWN_DISABLE OR PREMIUM_COOLDOWN_BOTH).
 * @noreturn
 */
native bool:Premium_AddEffectCooldown(const String:effect[], time, flag=0);

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
 * @param client   Client to show to.
 * @noreturn
 */

native bool:Premium_ShowMenu(client);

/**
 * Displays the previous premium menu the client viewed
 *
 * @param client   Client to show to.
 * @noreturn
 */

native bool:Premium_ShowLastMenu(client);

/**
 * Gets the current on/off status of an effect
 *
 * @param client   Client to get cookie for.
 * @param effect   Effect name to check.
 * @return         True if enabled, false otherwise.
 */

native bool:Premium_IsEffectEnabled(client, const String:effect[]);

/**
 * Sets the current on/off status of an effect
 *
 * @param client    Client to change cookie for.
 * @param effect    Effect name to set.
 * @param enabled   Bool to enabled/disable effect.
 * @noreturn
 */

native bool:Premium_SetEffectState(client, const String:effect[], bool:enabled);

/**
 * Adds an option to an effects menu
 *
 * @param effect     Effect name to add menu to.
 * @param title      Title to use for menu option.
 * @param callback   Function to call when user select the menu option.
 * @noreturn
 */

native bool:Premium_AddMenuOption(const String:effect[], const String:title[], PremiumMC:callback);

/**
 * Activates the effect cooldown on a client
 *
 * @param client     Client to activate for.
 * @param effect     Effect name.
 * @param isEnable   Set true if adding cooldown for enabling effect, false for disabling effect.
 * @return           True on success, false otherwise
 */

native bool:Premium_ActivateClientCooldown(client, const String:effect[], bool:isEnable);

/**
 * Resets the effect cooldown on a client
 *
 * @param client     Client to reset.
 * @param effect     Effect name.
 * @param isEnable   Set true if resetting enable cooldown, false for disable cooldown.
 * @return           True on success, false otherwise
 */

native bool:Premium_ResetClientCooldown(client, const String:effect[], bool:isEnable);