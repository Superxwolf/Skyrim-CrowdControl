using System;
using System.Collections.Generic;
using CrowdControl.Common;
using JetBrains.Annotations;

namespace CrowdControl.Games.Packs
{
    [UsedImplicitly]
    public class Skyrim : SimpleTCPPack
    {
        public override string Host => "127.0.0.1";

        public override ushort Port => 59420;

        public Skyrim([NotNull] IPlayer player, [NotNull] Func<CrowdControlBlock, bool> responseHandler,
            [NotNull] Action<object> statusUpdateHandler) : base(player, responseHandler, statusUpdateHandler)
        {
        }

        public override Game Game { get; } = new Game(59, "The Elder Scrolls V: Skyrim Special Edition", "Skyrim", "PC", ConnectorType.SimpleTCPConnector);

        public override List<Effect> Effects => new List<Effect>
        {
            #region Give Item (folder)

            new Effect("Give Items", "items", ItemKind.Folder),
            new Effect("Give Apples (5)", "give_apple", "items"),
            //new Effect("Spawn Cheese Wheel", "spawn_applecheese_wheel", "items"),
            new Effect("Give Health Potion", "give_health_potion", "items"),
            new Effect("Give Magika Potion", "give_magika_potion", "items"),
            new Effect("Give Lockpicks (5)", "give_lockpicks", "items"),
            new Effect("Give Gold (10)", "give_gold_10", "items"),
            new Effect("Give Gold (100)", "give_gold_100", "items"),
            new Effect("Give Gold (1000)", "give_gold_1000", "items"),

            #endregion

            #region Take Away Item

            new Effect("Take Away Items", "take_items", ItemKind.Folder),
            new Effect("Take Lockpick (1)", "take_lockpick", "take_items"),
            new Effect("Take Gold (10)", "take_gold_10", "take_items"),
            new Effect("Take Gold (100)", "take_gold_100", "take_items"),
            new Effect("Take Gold (1000)", "take_gold_1000", "take_items"),

            #endregion

            #region Spawn Companion (folder)

            #endregion

            #region Spawn Enemy (folder)

            new Effect("Enemies", "enemies", ItemKind.Folder),
            new Effect("Spawn Dragon", "spawn_dragon", "enemies"),
            new Effect("Spawn Witch", "spawn_witch", "enemies"),
            //new Effect("Spawn Angry Chicken", "spawn_angry_chicken", "enemies"),
            new Effect("Spawn Draugr", "spawn_draugr", "enemies"),
            new Effect("Spawn Bandit", "spawn_bandit", "enemies"),

            #endregion

            #region Helpful

            new Effect("Helpful", "helpful", ItemKind.Folder),
            new Effect("Full Heal", "full_heal", "helpful"),
            new Effect("Good Random Spell", "good_spell", "helpful"),
            new Effect("Spawn Horse", "spawn_horse", "helpful"),
            new Effect("Increase Speed (30 seconds)", "increase_speed", "helpful"),
            //new Effect("Increase Jump (30 seconds)", "increase_jump", "helpful"),
            new Effect("Increased Damage (30 seconds)", "increase_damage", "helpful"),
            new Effect("Infinite Stamina (30 seconds)", "infinite_stamina", "helpful"),

            #endregion

            #region Detrimental

            new Effect("Detrimental", "detrimental", ItemKind.Folder),
            new Effect("Kill Player", "kill_player", "detrimental"),
            new Effect("10% Health", "to_ten_health", "detrimental"),
            new Effect("Bad Random Spell", "bad_spell", "detrimental"),
            new Effect("Disable Crouch (1 minute)", "disable_crouch", "detrimental"),
            new Effect("Destroy/Unlearn Left Hand", "destroy_left", "detrimental"),
            new Effect("Destroy/Unlearn Right Hand", "destroy_right", "detrimental"),
            new Effect("Decrease Speed (30 seconds)", "decrease_speed", "detrimental"),
            //new Effect("Decrease Jump (30 seconds)", "decrease_jump", "detrimental"),
            new Effect("Decrease Damage (30 seconds)", "decrease_damage", "detrimental"),
            new Effect("Deplete Stamina", "deplete_stamina", "detrimental"),
            new Effect("Disable Fast Travel (30 seconds)", "disable_fast_travel", "detrimental"),

            #endregion

            #region Miscellaneus

            new Effect("Miscellaneous", "miscellaneous", ItemKind.Folder),
            new Effect("Launch Player", "launch_player", "miscellaneous"),

            #endregion

            #region Fast Travel

            new Effect("Fast Travel", "fast_travel", ItemKind.Folder),
            new Effect("Random Fast Travel", "random_fast_travel", "fast_travel"),
            new Effect("Fast Travel to Whiterun", "fast_travel_whiterun", "fast_travel"),
            new Effect("Fast Travel to Riverwood", "fast_travel_riverwood", "fast_travel"),
            new Effect("Fast Travel to Solitude", "fast_travel_solitude", "fast_travel"),
            new Effect("Fast Travel to Windhelm", "fast_travel_windhelm", "fast_travel"),
            new Effect("Fast Travel to Markarth", "fast_travel_markarth", "fast_travel"),

            // Implemented but not working properly
            //new Effect("Fast Travel to Dawnstar", "fast_travel_dawnstar", "fast_travel"),
            //new Effect("Fast Travel to Winterhold", "fast_travel_winterhold", "fast_travel"),
            //new Effect("Fast Travel to Riften", "fast_travel_riften", "fast_travel"),
            //new Effect("Fast Travel to Falkreath", "fast_travel_falkreath", "fast_travel"),
            //new Effect("Fast Travel to High Hrothgar", "fast_travel_high_hrothgar", "fast_travel")

            #endregion

        };
    }
}
