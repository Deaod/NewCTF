# NewCTF
Enhanced CTF Gamemode for UnrealTournament. It adds the following features compared to the default CTF gamemode:

- Custom spawn system
- Announcer for flag events (Taken/Dropped/Returned/Captured), plus a few other events
- Advantage system to allow flags in play at the end of a match to be resolved, within a limited amount of time
- Option to not play overtime and instead have draws

## Installation

1. Copy NewCTF.u and SpawnControl.u into System folder
1. Add to `ServerPackage`s
1. Set Gamemode to NewCTF.NewCTF

## Options

### INI

- Spawn System can be adjusted in UnrealTournament.ini
- Default AdvantageDuration can be configured there as well
- Default for bAllowOvertime can be set the same way.

### Command Line
- `?AdvantageDuration=X` changes AdvantageDuration to X
- `?AllowOvertime=(true/false)` sets whether Overtime is allowed for a given configuration or not

## Spawn System

NewCTF comes with a new spawn system, replacing the default one. For the purposes of this document, spawn point and PlayerStart refer to the same thing.

NewCTF has a list of spawn points for each team, which is created at the start of each map and shuffled once.

Every time a player tries to respawn during the game, the spawn system goes through the list of that player's team and tries to find a spawn point that can be **used**. If it finds a spawn point that can be used, that spawn point is moved to the end of the list. If no suitable spawn point can be found, the system lets the default spawn system find a spawn point.

A spawn point can be **used** if:
1. The number of players on the server is greater than `SpawnSystemThreshold`,
2. No enemy is within `SpawnEnemyBlockRange` of the spawn point,
3. No enemy is within `SpawnEnemyVisionBlockRange` and has vision of the spawn point (tracing EyeHeight of player to Location of spawn point),
4. No teammate is within `SpawnFriendlyBlockRange` of the spawn point,
5. No teammate is within `SpawnFriendlyVisionBlockRange` and has vision of the spawn point,
6. No flag is within `SpawnFlagBlockRange` of the spawn point and
7. At least `SpawnMinCycleDistance` other spawn points have been used since the last time this one was used

### Settings

#### SpawnSystemThreshold
Specifies the maximum number of players on a map that will not use the new spawn system. Set to 0 to always use it, or to a very high value to never use it.

#### SpawnEnemyBlockRange
Specifies the range within which an enemy will block a spawn from being used, no matter the visibility.

#### SpawnEnemyVisionBlockRange
Specifies the range within which an enemy with vision of the spawn point will block it from being used.

#### SpawnFriendlyBlockRange
Specifies the range within which a teammate will block a spawn from being used, regardless of visibility.

#### SpawnFriendlyVisionBlockRange
Specifies the range within which a teammate with vision of the spawn point will block it from being used.

#### SpawnFlagBlockRange
Specifies the range within which a Flag will block a spawn from being used, regardless of visibility.

#### SpawnMinCycleDistance
Specifies the number of other spawn points that have to have been used before a given spawn point can be used again. Setting it to 0 disables this restriction.

### SpawnControl
SpawnControl is a tiny add-on for map makers that allows them to provide alternate spawn system settings for a single map.

For this purpose SpawnControl contains two placeable actors, `SpawnControlInfo` and `SpawnControlPlayerStart`.

In order to use it, place the file SpawnControl.u in your System folder and add `EditPackages=SpawnControl` to section `[Editor.EditorEngine]` in UnrealTournament.ini.

#### SpawnControlInfo
Can be placed anywhere on the map, is invisible and contains alternate settings for the entire map.

#### SpawnControlPlayerStart
This is a replacement for the default PlayerStart. It behaves like it in every way, but provides a way to override Range settings of the spawn system for a single spawn point.
