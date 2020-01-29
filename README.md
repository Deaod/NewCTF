# NewCTF
Enhanced CTF Gamemode for UnrealTournament. It adds the following features compared to the default CTF gamemode:

- Custom spawn system
- Announcer for flag events (Taken/Dropped/Returned/Captured), plus a few other events
- Advantage system to allow flags in play at the end of a match to be resolved, within a limited amount of time
- Option to not play overtime and instead have draws

## Installation

1. Copy NewCTF.u into System folder
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
