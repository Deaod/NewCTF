# NewCTF
Enhanced CTF Gamemode for UnrealTournament. It adds the following features compared to the default CTF gamemode:

* Custom spawn system
* Announcer for flag events (Taken/Dropped/Returned/Captured), plus a few other events
* Advantage system to allow flags in play at the end of a match to be resolved, within a limited amount of time
* Option to not play overtime and instead have draws
* Option to increase respawn delay during overtime, to force the game to end
* Option to remove the light-glow around flag-carriers
* Adjustable flag timeout when dropped

## Installation

1. Copy NewCTFv13.u and NewCTFInterface.u into System folder
2. Set Gamemode to NewCTFv13.NewCTF (replacing Botpack.CTFGame)

## Client Settings

The settings for clients/players can be found in NewCTF.ini in your System folder, the contents of which will be similar to this:
```ini
[ClientSettings]
AnnouncerVolume=1.5
CTFAnnouncerClass=NewCTFv13.DefaultAnnouncer
Debug=False
_Version=1
```

### AnnouncerVolume
Controls the volume of announcements. Valid settings range from `0.0` to `6.0`.

### CTFAnnouncerClass
Which announcements to use. NewCTF comes with two announcers: NewCTFv13.DefaultAnnouncer and NewCTFv13.NewCTFAnnouncer.

Announcers can have custom sounds for the following CTF events:
* FlagDropped - When a flag was dropped by a player
* FlagReturned - When a player returned a flag
* FlagTaken - When a player took a flag off its FlagBase
* FlagScored - When a player captured the enemy flag
* GotFlag - When you picked up the flag yourself
* Overtime - When the game goes into Overtime
* Advantage - When the game goes into Advantage
* Draw - When the game finishes as a draw

Note that all announcements play in addition to the games internal sounds

#### NewCTFv13.DefaultAnnouncer
Only provides custom sounds for Overtime, Advantage, and Draw, which would not have sounds otherwise.

#### NewCTFv13.NewCTFAnnouncer
Provides sounds for all events.

#### Interface
If you want to create your own Announcer package for NewCTF, create a new package containing a class that extends `INewCTFAnnouncer` from the [NewCTFInterface](https://github.com/Deaod/NewCTFInterface) package. Then set `CTFAnnouncerClass` to the name of your new package followed by a dot, followed by the name of the class.

### Debug
Setting this to true causes NewCTF to log all incoming announcement notifications.

### \_Version
This is an version number for your settings, used to automatically upgrade your settings with new versions of NewCTF.

## Server Settings
The settings for servers can be found in UnrealTournament.ini in your System folder, the contents of which will be similar to this:

```ini
[NewCTFv13.NewCTF]
SpawnSystemThreshold=4
SpawnEnemyBlockRange=650.0
SpawnEnemyVisionBlockRange=2000.0
SpawnFriendlyBlockRange=150.0
SpawnFriendlyVisionBlockRange=150.0
SpawnFlagBlockRange=750.0
SpawnMinCycleDistance=1
bAllowOvertime=False
OvertimeRespawnDelay=1.0
OvertimeRespawnDelayCoefficient=120.0
OvertimeRespawnDelayStartTime=300
AdvantageDuration=120
MercyScore=0
bFlagGlow=True
FlagTimeout=25.0
FlagAdvantageTimeout=25.0
FlagOvertimeTimeout=25.0
```

### Spawn*
These settings will be explained in the [Spawn System](#spawn-system) section.

### bAllowOvertime
Whether to allow a match to go into overtime, or to end the game in a draw.  
Can also be set through the URL using `?bAllowOvertime=(true/false)`.  
See also [Interaction with Overtime](#interaction-with-overtime).

### OvertimeRespawnDelay
After [OvertimeRespawnDelayStartTime](#overtimerespawndelaystarttime) seconds of overtime respawning is delayed by this many seconds (at least 1 second).

### OvertimeRespawnDelayCoefficient
Only applies if greater than `0.0`.  
Every this many seconds of overtime past [OvertimeRespawnDelayStartTime](#overtimerespawndelaystarttime) respawning is delayed by one additional second.

### OvertimeRespawnDelayStartTime
After this many seconds of overtime, respawning could be delayed by more than normal, depending on [OvertimeRespawnDelay](#overtimerespawndelay) and [OvertimeRespawnDelayCoefficient](#overtimerespawndelaycoefficient).

### AdvantageDuration
How much time (in seconds) to add on top of the regular time to allow flags in play at the end to be resolved. Note that due to implementation details AdvantageDuration can not be set to 60 seconds. NewCTF will write a warning about this to the log and set AdvantageDuration to 59 automatically.  
Can also be set through the URL using `?AdvantageDuration=X`.  
See section [Advantage](#advantage).

### MercyScore
If MercyScore is greater than 0, and one team is at least one more than
MercyScore ahead of their closest opponent, the game ends immediately.  
Can also be set through the URL using `?MercyScore=X`.

### bFlagGlow
Controls whether flags glow when being carried by players.  
Can also be set through the URL using `bFlagGlow=(True/False)`.

### FlagTimeout
Controls how long a flag stays on the ground before being returned automatically. This variable controls the Timeout during normal play.

### FlagTimeoutAdvantage
Controls how long a flag stays on the ground before being returned automatically during advantage.

### FlagTimeoutOvertime
Controls how long a flag stays on the ground before being returned automatically during overtime.

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

### Interface
NewCTFInterface contains an add-on for map makers that allows them to provide alternate spawn system settings for a single map.

For this purpose NewCTFInterface contains two placeable actors, `SpawnControlInfo` and `SpawnControlPlayerStart`.

In order to use it, place the file NewCTFInterface.u in your System folder and add `EditPackages=NewCTFInterface` to section `[Editor.EditorEngine]` in UnrealTournament.ini.

#### SpawnControlInfo
Can be placed anywhere on the map, is invisible and contains alternate settings for the entire map.

#### SpawnControlPlayerStart
This is a replacement for the default PlayerStart. It behaves like it in every way, but provides a way to override Range settings of the spawn system for a single spawn point.

## Advantage
NewCTF introduces an advantage system which delays the end of a match if at least one flag is not on its FlagBase at the end of the regular time. Advantage will end once all flags are on their FlagBases, either by being returned or by being captured, or alternatively it will end when the additional time granted by the [AdvantageDuration](#advantageduration) setting runs out.

### Interaction with Overtime
Advantage applies even if overtime is allowed.  
The game might first go into Advantage, then into Overtime if the resolution of Advantage resulted in a drawn game.

## Building
1. Open a command line window, go to your UnrealTournament installation folder and clone this repository using `git clone https://github.com/Deaod/NewCTF.git NewCTFv13`
2. Use build.bat to build a new NewCTFv13.u, which will also be copied to the System folder of this repository