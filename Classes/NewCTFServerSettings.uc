class NewCTFServerSettings extends Object
    config perobjectconfig;

// Number of player up until which the old spawn system is used
var(SpawnSystem) config int   SpawnSystemThreshold;
// Range within which any enemy, visible or not will block a spawn
var(SpawnSystem) config float SpawnEnemyBlockRange;
// Range within which any enemy with vision on the spawn will block it
var(SpawnSystem) config float SpawnEnemyVisionBlockRange;
// Range within which any friend, visible or not will block a spawn
var(SpawnSystem) config float SpawnFriendlyBlockRange;
// Range within which any friend with vision will block a spawn
var(SpawnSystem) config float SpawnFriendlyVisionBlockRange;
// Range within which any flag will block a spawn
var(SpawnSystem) config float SpawnFlagBlockRange;
// Minimum number of spawn points to cycle through before reusing one
var(SpawnSystem) config int SpawnMinCycleDistance;

// True results in default behavior, False activates an advantage system
var(Overtime)    config bool bAllowOvertime;
// Extra time if a flag is in play when the game ends, 0 for no limit
// Never use the value 60, if you like the end-of-match countdown.
var(Advantage)   config int  AdvantageDuration;


defaultproperties
{
    SpawnSystemThreshold=4
    SpawnEnemyBlockRange=500.0
    SpawnEnemyVisionBlockRange=2000.0
    SpawnFriendlyBlockRange=150.0
    SpawnFriendlyVisionBlockRange=150.0
    SpawnFlagBlockRange=500.0
    SpawnMinCycleDistance=1

    bAllowOvertime=False
    AdvantageDuration=120
}