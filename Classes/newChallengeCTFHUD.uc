class newChallengeCTFHUD extends ChallengeTeamHUD;

#exec TEXTURE IMPORT NAME=redmarker FILE=TEXTURES\new\red_mark.pcx GROUP="Icons" FLAGS=2 MIPS=OFF
#exec TEXTURE IMPORT NAME=bluemarker FILE=TEXTURES\new\blue_mark.pcx GROUP="Icons" FLAGS=2 MIPS=OFF
#exec TEXTURE IMPORT NAME=flag FILE=TEXTURES\new\flag.pcx GROUP="Icons" FLAGS=2 MIPS=OFF
#exec TEXTURE IMPORT NAME=flagright FILE=TEXTURES\new\flag_right.pcx GROUP="Icons" FLAGS=2 MIPS=OFF
#exec TEXTURE IMPORT NAME=flagdropped FILE=Textures\new\flag_dropped.pcx GROUP="Icons" FLAGS=2 MIPS=OFF
#exec TEXTURE IMPORT NAME=runningman FILE=Textures\new\runningman.pcx GROUP="Icons" FLAGS=2 MIPS=OFF
#exec TEXTURE IMPORT NAME=runningmanr FILE=Textures\new\runningmanr.pcx GROUP="Icons" FLAGS=2 MIPS=OFF

var CTFFlag MyFlag;
var color Blue, Red, Gold;

simulated function DrawTypingPrompt( canvas Canvas, console Console )
{
    local string TypingPrompt;
    local float XL, YL, YPos, XOffset;
    local float MyOldClipX, OldClipY, OldOrgX, OldOrgY;

    MyOldClipX = Canvas.ClipX;
    OldClipY = Canvas.ClipY;
    OldOrgX = Canvas.OrgX;
    OldOrgY = Canvas.OrgY;

    Canvas.DrawColor = GreenColor;
    TypingPrompt = "(>"@Console.TypedStr$"_";
    Canvas.Font = MyFonts.GetSmallFont( Canvas.ClipX );
    Canvas.StrLen( "TEST", XL, YL );
    YPos = YL*4 + 105;
    if (PawnOwner.PlayerReplicationInfo.bIsSpectator || bHideHUD || bHideFaces)
        XOffset = 0;
    else
        XOffset = FMax(0,FaceAreaOffset + 15*Scale + YPos);
    Canvas.SetOrigin(XOffset, FMax(0,YPos + 7*Scale));
    Canvas.SetClip( 760*Scale, Canvas.ClipY );
    Canvas.SetPos( 0, 0 );
    Canvas.DrawText( TypingPrompt, false );
    Canvas.SetOrigin( OldOrgX, OldOrgY );
    Canvas.SetClip( MyOldClipX, OldClipY );
}

simulated function Message( PlayerReplicationInfo PRI, coerce string Msg, name MsgType )
{
    local int i;
    local Class<LocalMessage> MessageClass;

    switch (MsgType)
    {
        case 'Say':
        case 'TeamSay':
            MessageClass = class'newSayMessagePlus';
            break;
        case 'CriticalEvent':
            MessageClass = class'CriticalStringPlus';
            LocalizedMessage( MessageClass, 0, None, None, None, Msg );
            return;
        case 'DeathMessage':
            MessageClass = class'RedSayMessagePlus';
            break;
        case 'Pickup':
            PickupTime = Level.TimeSeconds;
        default:
            MessageClass = class'StringMessagePlus';
            break;
    }

    if (ClassIsChildOf(MessageClass, class'newSayMessagePlus') ||
        ClassIsChildOf(MessageClass, class'TeamSayMessagePlus') )
    {
        FaceTexture = PRI.TalkTexture;
        if ( FaceTexture != None )
            FaceTime = Level.TimeSeconds + 3;
        if ( Msg == "" )
            return;
    }
    for (i=0; i<4; i++)
    {
        if ( ShortMessageQueue[i].Message == None )
        {
            // Add the message here.
            ShortMessageQueue[i].Message = MessageClass;
            ShortMessageQueue[i].Switch = 0;
            ShortMessageQueue[i].RelatedPRI = PRI;
            ShortMessageQueue[i].OptionalObject = None;
            ShortMessageQueue[i].EndOfLife = MessageClass.Default.Lifetime + Level.TimeSeconds;
            if ( MessageClass.Default.bComplexString )
                ShortMessageQueue[i].StringMessage = Msg;
            else
                ShortMessageQueue[i].StringMessage = MessageClass.Static.AssembleString(self,0,PRI,Msg);
            return;
        }
    }

    // No empty slots.  Force a message out.
    for (i=0; i<3; i++)
        CopyMessage(ShortMessageQueue[i], ShortMessageQueue[i+1]);

    ShortMessageQueue[3].Message = MessageClass;
    ShortMessageQueue[3].Switch = 0;
    ShortMessageQueue[3].RelatedPRI = PRI;
    ShortMessageQueue[3].OptionalObject = None;
    ShortMessageQueue[3].EndOfLife = MessageClass.Default.Lifetime + Level.TimeSeconds;
    if ( MessageClass.Default.bComplexString )
        ShortMessageQueue[3].StringMessage = Msg;
    else
        ShortMessageQueue[3].StringMessage = MessageClass.Static.AssembleString(self,0,PRI,Msg);
}

simulated function PostRender( canvas Canvas )
{
    local int X, Y, i, j, k, M, bFlagX, bFlagY, rFlagX, rFlagY, textX, textY;
    local int takenX, takenY;
    local CTFFlag Flag;
    local bool bAlt, bWideScreen;
    local float XL, YL, XPos, YPos, FadeValue, OldOriginX;

    HUDSetup(canvas);
    if ( (PawnOwner == None) || (PlayerOwner.PlayerReplicationInfo == None) )
        return;

    if ( bShowInfo )
    {
        ServerInfo.RenderInfo( Canvas );
        return;
    }


    Canvas.Font = MyFonts.GetSmallFont( Canvas.ClipX );
    OldOriginX = Canvas.OrgX;
    // Master message short queue control loop.
    Canvas.Font = MyFonts.GetSmallFont( Canvas.ClipX );
    Canvas.StrLen("TEST", XL, YL);
    Canvas.SetClip(768*Scale - 10, Canvas.ClipY);
    bDrawFaceArea = false;
    if ( !bHideFaces && !PlayerOwner.bShowScores && !bForceScores && !bHideHUD
        && !PawnOwner.PlayerReplicationInfo.bIsSpectator && (scale >= 0.4) )
    {
        DrawSpeechArea(Canvas, XL, YL);
        bDrawFaceArea = (FaceTexture != None) && (FaceTime > Level.TimeSeconds);
        if ( bDrawFaceArea )
        {
            if ( !bHideHUD && ((PawnOwner.PlayerReplicationInfo == None) || !PawnOwner.PlayerReplicationInfo.bIsSpectator) )
                Canvas.SetOrigin( FMax(YL*4 + 8, 70*Scale) + 7*Scale + 6 + FaceAreaOffset, Canvas.OrgY );
        }
    }

    for (i=0; i<4; i++)
    {
        if ( ShortMessageQueue[i].Message != None )
        {
            j++;

            if ( bResChanged || (ShortMessageQueue[i].XL == 0) )
            {
                if ( ShortMessageQueue[i].Message.Default.bComplexString )
                    Canvas.StrLen(
                        ShortMessageQueue[i].Message.Static.AssembleString(
                            self,
                            ShortMessageQueue[i].Switch,
                            ShortMessageQueue[i].RelatedPRI,
                            ShortMessageQueue[i].StringMessage
                        ),
                        ShortMessageQueue[i].XL,
                        ShortMessageQueue[i].YL
                    );
                else
                    Canvas.StrLen(ShortMessageQueue[i].StringMessage, ShortMessageQueue[i].XL, ShortMessageQueue[i].YL);
                Canvas.StrLen("TEST", XL, YL);
                ShortMessageQueue[i].numLines = 1;
                if ( ShortMessageQueue[i].YL > YL )
                {
                    ShortMessageQueue[i].numLines++;
                    for (k=2; k<4-i; k++)
                    {
                        if (ShortMessageQueue[i].YL > YL*k)
                            ShortMessageQueue[i].numLines++;
                    }
                }
            }

            // Keep track of the amount of lines a message overflows, to offset the next message with.
            Canvas.SetPos(6, 2 + YL * YPos);
            YPos += ShortMessageQueue[i].numLines;
            if ( YPos > 4 )
                break;

            if ( ShortMessageQueue[i].Message.Default.bComplexString )
            {
                // Use this for string messages with multiple colors.
                ShortMessageQueue[i].Message.static.RenderComplexMessage(
                    Canvas,
                    ShortMessageQueue[i].XL,
                    YL,
                    ShortMessageQueue[i].StringMessage,
                    ShortMessageQueue[i].Switch,
                    ShortMessageQueue[i].RelatedPRI,
                    None,
                    ShortMessageQueue[i].OptionalObject
                );
            }
            else
            {
                Canvas.DrawColor = ShortMessageQueue[i].Message.Default.DrawColor;
                Canvas.SetPos(Canvas.CurX, Canvas.CurY + 170);
                Canvas.DrawText(ShortMessageQueue[i].StringMessage, False);
            }
        }
    }

    Canvas.DrawColor = WhiteColor;
    Canvas.SetClip(OldClipX, Canvas.ClipY);
    Canvas.SetOrigin(OldOriginX, Canvas.OrgY);

    if ( PlayerOwner.bShowScores || bForceScores )
    {
        if ( (PlayerOwner.Scoring == None) && (PlayerOwner.ScoringType != None) )
            PlayerOwner.Scoring = Spawn(PlayerOwner.ScoringType, PlayerOwner);
        if ( PlayerOwner.Scoring != None )
        {
            PlayerOwner.Scoring.OwnerHUD = self;
            PlayerOwner.Scoring.ShowScores(Canvas);
            if ( PlayerOwner.Player.Console.bTyping )
                DrawTypingPrompt(Canvas, PlayerOwner.Player.Console);
            return;
        }
    }

    YPos = FMax(YL*4 + 8, 70*Scale);
    if ( bDrawFaceArea )
        DrawTalkFace( Canvas,0, YPos );
    if (j > 0)
    {
        bDrawMessageArea = True;
        MessageFadeCount = 2;
    }
    else
        bDrawMessageArea = False;

    if ( !bHideCenterMessages )
    {
        // Master localized message control loop.
        for (i=0; i<10; i++)
        {
            if (LocalMessages[i].Message != None)
            {
                if (LocalMessages[i].Message.Default.bFadeMessage && Level.bHighDetailMode)
                {
                    Canvas.Style = ERenderStyle.STY_Translucent;
                    FadeValue = (LocalMessages[i].EndOfLife - Level.TimeSeconds);
                    if (FadeValue > 0.0)
                    {
                        if ( bResChanged || (LocalMessages[i].XL == 0) )
                        {
                            if ( LocalMessages[i].Message.Static.GetFontSize(LocalMessages[i].Switch) == 1 )
                                LocalMessages[i].StringFont = MyFonts.GetBigFont( Canvas.ClipX );
                            else // ==2
                                LocalMessages[i].StringFont = MyFonts.GetHugeFont( Canvas.ClipX );
                            Canvas.Font = LocalMessages[i].StringFont;
                            Canvas.StrLen(LocalMessages[i].StringMessage, LocalMessages[i].XL, LocalMessages[i].YL);
                            LocalMessages[i].YPos = LocalMessages[i].Message.Static.GetOffset(LocalMessages[i].Switch, LocalMessages[i].YL, Canvas.ClipY);
                        }
                        Canvas.Font = LocalMessages[i].StringFont;
                        Canvas.DrawColor = LocalMessages[i].DrawColor * (FadeValue/LocalMessages[i].LifeTime);
                        Canvas.SetPos( 0.5 * (Canvas.ClipX - LocalMessages[i].XL), LocalMessages[i].YPos );
                        Canvas.DrawText( LocalMessages[i].StringMessage, False );
                    }
                }
                else
                {
                    if ( bResChanged || (LocalMessages[i].XL == 0) )
                    {
                        if ( LocalMessages[i].Message.Static.GetFontSize(LocalMessages[i].Switch) == 1 )
                            LocalMessages[i].StringFont = MyFonts.GetBigFont( Canvas.ClipX );
                        else // == 2
                            LocalMessages[i].StringFont = MyFonts.GetHugeFont( Canvas.ClipX );
                        Canvas.Font = LocalMessages[i].StringFont;
                        Canvas.StrLen(LocalMessages[i].StringMessage, LocalMessages[i].XL, LocalMessages[i].YL);
                        LocalMessages[i].YPos = LocalMessages[i].Message.Static.GetOffset(LocalMessages[i].Switch, LocalMessages[i].YL, Canvas.ClipY);
                    }
                    Canvas.Font = LocalMessages[i].StringFont;
                    Canvas.Style = ERenderStyle.STY_Normal;
                    Canvas.DrawColor = LocalMessages[i].DrawColor;
                    Canvas.SetPos( 0.5 * (Canvas.ClipX - LocalMessages[i].XL), LocalMessages[i].YPos );
                    Canvas.DrawText( LocalMessages[i].StringMessage, False );
                }
            }
        }
    }
    Canvas.Style = ERenderStyle.STY_Normal;

    if ( !PlayerOwner.bBehindView && (PawnOwner.Weapon != None) && (Level.LevelAction == LEVACT_None) )
    {
        Canvas.DrawColor = WhiteColor;
        PawnOwner.Weapon.PostRender(Canvas);
        if ( !PawnOwner.Weapon.bOwnsCrossHair )
            DrawCrossHair(Canvas, 0,0 );
    }

    if ( (PawnOwner != Owner) && PawnOwner.bIsPlayer )
    {
        Canvas.Font = MyFonts.GetSmallFont( Canvas.ClipX );
        Canvas.bCenter = true;
        Canvas.Style = ERenderStyle.STY_Normal;
        Canvas.DrawColor = CyanColor * TutIconBlink;
        Canvas.SetPos(4, Canvas.ClipY - 96 * Scale);
        Canvas.DrawText( LiveFeed$PawnOwner.PlayerReplicationInfo.PlayerName, true );
        Canvas.bCenter = false;
        Canvas.DrawColor = WhiteColor;
        Canvas.Style = Style;
    }

    if ( bStartUpMessage && (Level.TimeSeconds < 5) )
    {
        bStartUpMessage = false;
        PlayerOwner.SetProgressTime(7);
    }
    if ( (PlayerOwner.ProgressTimeOut > Level.TimeSeconds) && !bHideCenterMessages )
        DisplayProgressMessage(Canvas);

    // Display MOTD
    if ( MOTDFadeOutTime > 0.0 )
        DrawMOTD(Canvas);

    if( !bHideHUD )
    {
        if ( !PawnOwner.PlayerReplicationInfo.bIsSpectator )
        {
            Canvas.Style = Style;

            // Draw Ammo
            if ( !bHideAmmo )
                DrawAmmo(Canvas);

            // Draw Health/Armor status
            DrawStatus(Canvas);

            // Display Weapons
            if ( !bHideAllWeapons )
                DrawWeapons(Canvas);
            else if ( Level.bHighDetailMode
                    && (PawnOwner == PlayerOwner) && (PlayerOwner.Handedness == 2) )
            {
                // if weapon bar hidden and weapon hidden, draw weapon name when it changes
                if ( PawnOwner.PendingWeapon != None )
                {
                    WeaponNameFade = 1.0;
                    Canvas.Font = MyFonts.GetBigFont( Canvas.ClipX );
                    Canvas.DrawColor = PawnOwner.PendingWeapon.NameColor;
                    Canvas.SetPos(Canvas.ClipX - 360 * Scale, Canvas.ClipY - 64 * Scale);
                    Canvas.DrawText(PawnOwner.PendingWeapon.ItemName, False);
                }
                else if ( (Level.NetMode == NM_Client)
                        && PawnOwner.IsA('TournamentPlayer') && (TournamentPlayer(PawnOwner).ClientPending != None) )
                {
                    WeaponNameFade = 1.0;
                    Canvas.Font = MyFonts.GetBigFont( Canvas.ClipX );
                    Canvas.DrawColor = TournamentPlayer(PawnOwner).ClientPending.NameColor;
                    Canvas.SetPos(Canvas.ClipX - 360 * Scale, Canvas.ClipY - 64 * Scale);
                    Canvas.DrawText(TournamentPlayer(PawnOwner).ClientPending.ItemName, False);
                }
                else if ( (WeaponNameFade > 0) && (PawnOwner.Weapon != None) )
                {
                    Canvas.Font = MyFonts.GetBigFont( Canvas.ClipX );
                    Canvas.DrawColor = PawnOwner.Weapon.NameColor;
                    if ( WeaponNameFade < 1 )
                        Canvas.DrawColor = Canvas.DrawColor * WeaponNameFade;
                    Canvas.SetPos(Canvas.ClipX - 360 * Scale, Canvas.ClipY - 64 * Scale);
                    Canvas.DrawText(PawnOwner.Weapon.ItemName, False);
                }
            }
            // Display Frag count
            if ( !bAlwaysHideFrags && !bHideFrags )
                DrawFragCount(Canvas);
        }
        // Team Game Synopsis
        if ( !bHideTeamInfo )
            DrawGameSynopsis(Canvas);

        // Display Identification Info
        if ( PawnOwner == PlayerOwner )
            DrawIdentifyInfo(Canvas);

        if ( HUDMutator != None )
            HUDMutator.PostRender(Canvas);

        if ( (PlayerOwner.GameReplicationInfo != None) && (PlayerPawn(Owner).GameReplicationInfo.RemainingTime > 0) )
        {
            if ( TimeMessageClass == None )
                TimeMessageClass = class<CriticalEventPlus>(DynamicLoadObject("Botpack.TimeMessage", class'Class'));

            if ( (PlayerOwner.GameReplicationInfo.RemainingTime <= 300)
              && (PlayerOwner.GameReplicationInfo.RemainingTime != LastReportedTime) )
            {
                LastReportedTime = PlayerOwner.GameReplicationInfo.RemainingTime;
                if ( PlayerOwner.GameReplicationInfo.RemainingTime <= 30 )
                {
                    bTimeValid = ( bTimeValid || (PlayerOwner.GameReplicationInfo.RemainingTime > 0) );
                    if ( PlayerOwner.GameReplicationInfo.RemainingTime == 30 )
                        TellTime(5);
                    else if ( bTimeValid && PlayerOwner.GameReplicationInfo.RemainingTime <= 10 )
                        TellTime(16 - PlayerOwner.GameReplicationInfo.RemainingTime);
                }
                else if ( PlayerOwner.GameReplicationInfo.RemainingTime % 60 == 0 )
                {
                    M = PlayerOwner.GameReplicationInfo.RemainingTime/60;
                    TellTime(5 - M);
                }
            }
        }
    }
    if ( PlayerOwner.Player.Console.bTyping )
        DrawTypingPrompt(Canvas, PlayerOwner.Player.Console);

    if ( PlayerOwner.bBadConnectionAlert && (PlayerOwner.Level.TimeSeconds > 5) )
    {
        Canvas.Style = ERenderStyle.STY_Normal;
        Canvas.DrawColor = WhiteColor;
        Canvas.SetPos(Canvas.ClipX - (64*Scale), Canvas.ClipY / 2);
        Canvas.DrawIcon(texture'DisconnectWarn', Scale);
    }


    // Disable the face box so it doesn't overlap with the new HUD
    bHideFaces = True;
    bDrawFaceArea = false;

    // Set the correct Scale size (nasty hack!! i'm lazy)
    if (HUDScale < 0.8 || HUDScale > 0.8)
        HUDScale = 0.8;


    if ( (PlayerOwner == None) || (PawnOwner == None) || (PlayerOwner.GameReplicationInfo == None)
        || (PawnOwner.PlayerReplicationInfo == None)
        || ((PlayerOwner.bShowMenu || PlayerOwner.bShowScores) && (Canvas.ClipX < 640)) )
        return;


    // Draw top HUD

    // Markers
        // Red
    Canvas.Style = Style;
    X = (Canvas.ClipX - Canvas.ClipX) + (Canvas.ClipX / 2) - 290 * Scale;
    Y = (Canvas.ClipY - Canvas.ClipY) - 40 * Scale;
    Canvas.DrawColor = Red;
    Canvas.SetPos(X, Y);
    Canvas.DrawIcon(texture'redmarker', Scale * 1.5);
    // Blue
    X = (Canvas.ClipX - Canvas.ClipX) + 900 * Scale;
    Y = (Canvas.ClipY - Canvas.ClipY) - 40 * Scale;
    Canvas.DrawColor = Blue;
    Canvas.SetPos(X, Y);
    Canvas.DrawIcon(texture'bluemarker', Scale * 1.5);
    //Canvas.SetPos((Canvas.ClipX - Canvas.ClipX) + (Canvas.ClipX / 2), (Canvas.ClipY - Canvas.ClipY));
    //Canvas.DrawText("I am here!", False);


    if( !bHideHUD && !bHideTeamInfo )
    {

        for ( i=0; i<4; i++ ) {
            Flag = CTFReplicationInfo(PlayerOwner.GameReplicationInfo).FlagList[i];
            if ( Flag != None ) {
                if (Flag.Team == PawnOwner.PlayerReplicationInfo.Team)
                    MyFlag = Flag;

                if (Flag.bHome) {
                    // Flags
                    // Red Flag
                    rFlagX = (Canvas.ClipX - Canvas.ClipX) + (Canvas.ClipX / 2) - 340 * scale;
                    rFlagY = (Canvas.ClipY - Canvas.ClipY) - 25;
                    Canvas.DrawColor = Red;
                    Canvas.SetPos(rFlagX, rFlagY);
                    Canvas.Style = ERenderStyle.STY_Translucent;
                    Canvas.DrawIcon(texture'flag', scale * 1.5);
                    Canvas.Style = Style;
                    // Blue Flag
                    bFlagX = (Canvas.ClipX - Canvas.ClipX) + 952 * scale;
                    bFlagY = (Canvas.ClipY - Canvas.ClipY) - 25;
                    Canvas.DrawColor = Blue;
                    Canvas.SetPos(bFlagX, bFlagY);
                    Canvas.Style = ERenderStyle.STY_Translucent;
                    Canvas.DrawIcon(texture'flagright', scale * 1.5);
                    Canvas.Style = Style;
                } else if ( Flag.bHeld ) {
                    if (Flag.Team == 0) {
                        // Red Flag
                        rFlagX = (Canvas.ClipX - Canvas.ClipX) + (Canvas.ClipX / 2) - 340 * scale;
                        rFlagY = (Canvas.ClipY - Canvas.ClipY) - 25;
                        Canvas.DrawColor = Red;
                        Canvas.SetPos(rFlagX, rFlagY);
                        Canvas.Style = ERenderStyle.STY_Translucent;
                        Canvas.DrawIcon(texture'flag', scale * 1.5);
                        Canvas.Style = Style;

                        X = (Canvas.ClipX - Canvas.ClipX) + (Canvas.ClipX / 2) - 340 * Scale;
                        Y = (Canvas.ClipY - Canvas.ClipY) - 10;
                        //Canvas.Style = ERenderStyle.STY_Translucent;
                        Canvas.SetPos(X, Y);
                        Canvas.DrawColor = Gold;
                        Canvas.DrawIcon(texture'runningman', Scale * 1.5);
                        Canvas.Style = Style;
                    } else if (Flag.Team == 1) {
                        // Blue Flag
                        bFlagX = (Canvas.ClipX - Canvas.ClipX) + 952 * scale;
                        bFlagY = (Canvas.ClipY - Canvas.ClipY) - 25;
                        Canvas.DrawColor = Blue;
                        Canvas.SetPos(bFlagX, bFlagY);
                        Canvas.Style = ERenderStyle.STY_Translucent;
                        Canvas.DrawIcon(texture'flagright', scale * 1.5);
                        Canvas.Style = Style;

                        X = (Canvas.ClipX - Canvas.ClipX) + 952 * scale;
                        Y = (Canvas.ClipY - Canvas.ClipY) - 10;
                        //Canvas.Style = ERenderStyle.STY_Translucent;
                        Canvas.SetPos(X, Y);
                        Canvas.DrawColor = Gold;
                        Canvas.DrawIcon(texture'runningmanr', scale * 1.5);
                        Canvas.Style = Style;
                    }
                } else {
                    if (Flag.Team == 0) {
                        // Red Flag
                        rFlagX = (Canvas.ClipX - Canvas.ClipX) + (Canvas.ClipX / 2) - 340 * scale;
                        rFlagY = (Canvas.ClipY - Canvas.ClipY) - 25;
                        Canvas.DrawColor = Red;
                        Canvas.SetPos(rFlagX, rFlagY);
                        Canvas.Style = ERenderStyle.STY_Translucent;
                        Canvas.DrawIcon(texture'flag', scale * 1.5);
                        Canvas.Style = Style;

                        X = (Canvas.ClipX - Canvas.ClipX) + (Canvas.ClipX / 2) - 340 * scale;
                        Y = (Canvas.ClipY - Canvas.ClipY) - 10;
                        //Canvas.Style = ERenderStyle.STY_Translucent;
                        Canvas.SetPos(X, Y);
                        Canvas.DrawColor = Gold;
                        Canvas.DrawIcon(texture'flagdropped', scale * 1.5);
                        Canvas.Style = Style;
                    } else if (Flag.Team == 1) {
                        // Blue Flag
                        bFlagX = (Canvas.ClipX - Canvas.ClipX) + 952 * scale;
                        bFlagY = (Canvas.ClipY - Canvas.ClipY) - 25;
                        Canvas.DrawColor = Blue;
                        Canvas.SetPos(bFlagX, bFlagY);
                        Canvas.Style = ERenderStyle.STY_Translucent;
                        Canvas.DrawIcon(texture'flagright', Scale * 1.5);
                        Canvas.Style = Style;

                        X = (Canvas.ClipX - Canvas.ClipX) + 952 * scale;
                        Y = (Canvas.ClipY - Canvas.ClipY) - 10;
                        Canvas.SetPos(X, Y);
                        Canvas.DrawColor = Gold;
                        Canvas.DrawIcon(texture'flagdropped', Scale * 1.5);
                        Canvas.Style = Style;
                    }
                }
            }
            //Y -= 150 * Scale;
        }
    }
}

simulated function DrawPlayerTeam(Canvas Canvas)
{
    local Pawn P;
    local int X, Y, rTextX;
    P = PlayerPawn(Owner);

    if ( (PawnOwner.PlayerReplicationInfo == None)
        || PawnOwner.PlayerReplicationInfo.bIsSpectator
        || (PlayerCount == 1) )
        return;

    X = (Canvas.ClipX - Canvas.ClipX) + (Canvas.ClipX / 2) - 54 * scale;
    Y = (Canvas.ClipY - Canvas.ClipY) + 75;

    Canvas.Font = MyFonts.GetSmallFont( Canvas.ClipX );
    Canvas.DrawColor = WhiteColor;

    Canvas.SetPos(X, Y);
    Canvas.DrawText("You are on", False);
    Canvas.SetPos(X + 78, Y);
    if (P.PlayerReplicationInfo.Team == 0) {
       // You are on Red
       Canvas.DrawColor = RedColor;
       Canvas.DrawText("Red", False);
    } else {
        // You are on Blue
        Canvas.DrawColor = BlueColor;
        Canvas.DrawText("Blue", False);
    }
}

simulated function DrawTeam(Canvas Canvas, TeamInfo TI)
{
    local float XL, YL;

    if ( (TI != None) && (TI.Size > 0) )
    {
        Canvas.DrawColor = TeamColor[TI.TeamIndex];
        if (TI.TeamIndex == 1) {
            if (Canvas.ClipX >= 1920)
                DrawBigNum(Canvas, int(TI.Score), (Canvas.ClipX - Canvas.ClipX) + 900 * Scale, (Canvas.ClipY - Canvas.ClipY) + 50, 1);
            else
                DrawBigNum(Canvas, int(TI.Score), (Canvas.ClipX - Canvas.ClipX) + 900 * Scale, (Canvas.ClipY - Canvas.ClipY) + 25, 1);
            DrawPlayerTeam(Canvas);
        }
        else if (TI.TeamIndex == 0)
            if (Canvas.ClipX >= 1920)
                DrawBigNum(Canvas, int(TI.Score), (Canvas.ClipX - Canvas.ClipX) + 630 * Scale, (Canvas.ClipY - Canvas.ClipY) + 50, 1);
            else
                DrawBigNum(Canvas, int(TI.Score), (Canvas.ClipX - Canvas.ClipX) + 630 * Scale, (Canvas.ClipY - Canvas.ClipY) + 25, 1);
        DrawPlayerTeam(Canvas);
    }
}


defaultproperties
{
    ServerInfoClass=class'Botpack.ServerInfoCTF'
    Gold=(R=255,G=255,B=0)
    Red=(R=255,G=0,B=0)
    Blue=(R=0,G=0,B=255)
}