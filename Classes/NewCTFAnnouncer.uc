class NewCTFAnnouncer extends Object;

#exec AUDIO IMPORT FILE="Sounds\Red_Flag_Dropped.wav" NAME="RedFlagDropped"
#exec AUDIO IMPORT FILE="Sounds\Red_Flag_Returned.wav" NAME="RedFlagReturned"
#exec AUDIO IMPORT FILE="Sounds\Red_Flag_Taken.wav" NAME="RedFlagTaken"
#exec AUDIO IMPORT FILE="Sounds\Red_Team_Scores.wav" NAME="RedTeamScores"
#exec AUDIO IMPORT FILE="Sounds\Red_Team_on_Offence.wav" NAME="RedTeamAdvantage"
#exec AUDIO IMPORT FILE="Sounds\red_team_is_the_winner.wav" NAME="RedTeamWins"

#exec AUDIO IMPORT FILE="Sounds\Blue_Flag_Dropped.wav" NAME="BlueFlagDropped"
#exec AUDIO IMPORT FILE="Sounds\Blue_Flag_Returned.wav" NAME="BlueFlagReturned"
#exec AUDIO IMPORT FILE="Sounds\Blue_Flag_Taken.wav" NAME="BlueFlagTaken"
#exec AUDIO IMPORT FILE="Sounds\Blue_Team_Scores.wav" NAME="BlueTeamScores"
#exec AUDIO IMPORT FILE="Sounds\Blue_Team_on_Offence.wav" NAME="BlueTeamAdvantage"
#exec AUDIO IMPORT FILE="Sounds\blue_team_is_the_winner.wav" NAME="BlueTeamWins"

#exec AUDIO IMPORT FILE="Sounds\overtime.wav" NAME="Overtime"
#exec AUDIO IMPORT FILE="Sounds\Draw_Game.wav" NAME="Draw"
#exec AUDIO IMPORT FILE="Sounds\gotflag.wav" NAME="GotFlag"

var sound FlagDropped[4];
var sound FlagReturned[4];
var sound FlagTaken[4];
var sound FlagScored[4];
var sound Overtime;
var sound Advantage[4];
var sound Draw;
var sound Win[4];
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

    Advantage(0)=sound'NewCTF.RedTeamAdvantage'
    Advantage(1)=sound'NewCTF.BlueTeamAdvantage'
    Advantage(2)=none
    Advantage(3)=none

    Draw=sound'NewCTF.Draw'

    Win(0)=sound'NewCTF.RedTeamWins'
    Win(1)=sound'NewCTF.BlueTeamWins'
    Win(2)=none
    Win(3)=none

    GotFlag=sound'NewCTF.GotFlag'
}