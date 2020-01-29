class NewCTFAnnouncer extends Object;

#exec AUDIO IMPORT FILE="Sounds\Red_Flag_Dropped.wav" NAME="RedFlagDropped"
#exec AUDIO IMPORT FILE="Sounds\Red_Flag_Returned.wav" NAME="RedFlagReturned"
#exec AUDIO IMPORT FILE="Sounds\Red_Flag_Taken.wav" NAME="RedFlagTaken"
#exec AUDIO IMPORT FILE="Sounds\Red_Team_Scores.wav" NAME="RedTeamScores"

#exec AUDIO IMPORT FILE="Sounds\Blue_Flag_Dropped.wav" NAME="BlueFlagDropped"
#exec AUDIO IMPORT FILE="Sounds\Blue_Flag_Returned.wav" NAME="BlueFlagReturned"
#exec AUDIO IMPORT FILE="Sounds\Blue_Flag_Taken.wav" NAME="BlueFlagTaken"
#exec AUDIO IMPORT FILE="Sounds\Blue_Team_Scores.wav" NAME="BlueTeamScores"

#exec AUDIO IMPORT FILE="Sounds\overtime.wav" NAME="Overtime"
#exec AUDIO IMPORT FILE="Sounds\Draw_Game.wav" NAME="Draw"
#exec AUDIO IMPORT FILE="Sounds\gotflag.wav" NAME="GotFlag"
#exec AUDIO IMPORT FILE="Sounds\advantage.wav" NAME="AdvantageGeneric"

var sound FlagDropped[4];
var sound FlagReturned[4];
var sound FlagTaken[4];
var sound FlagScored[4];
var sound Overtime;
var sound AdvantageGeneric;
var sound Draw;
var sound GotFlag;

defaultproperties {
    FlagDropped(0)=sound'NewCTF.RedFlagDropped'
    FlagDropped(1)=sound'NewCTF.BlueFlagDropped'
    FlagDropped(2)=none
    FlagDropped(3)=none

    FlagReturned(0)=sound'NewCTF.RedFlagReturned'
    FlagReturned(1)=sound'NewCTF.BlueFlagReturned'
    FlagReturned(2)=none
    FlagReturned(3)=none

    FlagTaken(0)=sound'NewCTF.RedFlagTaken'
    FlagTaken(1)=sound'NewCTF.BlueFlagTaken'
    FlagTaken(2)=none
    FlagTaken(3)=none

    FlagScored(0)=sound'NewCTF.RedTeamScores'
    FlagScored(1)=sound'NewCTF.BlueTeamScores'
    FlagScored(2)=none
    FlagScored(3)=none

    Overtime=sound'NewCTF.Overtime'
    AdvantageGeneric=sound'NewCTF.AdvantageGeneric'
    Draw=sound'NewCTF.Draw'
    GotFlag=sound'NewCTF.GotFlag'
}