#include <tf2>
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <sm_logger>
#include <morecolors_newsyntax>
#include <berobot_constants>
#include <berobot>
#include <tf2_isPlayerInSpawn>


char LOG_TAGS[][] = {"VERBOSE", "INFO", "ERROR"};
enum (<<= 1)
{
    SML_VERBOSE = 1,
    SML_INFO,
    SML_ERROR
}
#include <berobot_core>
#pragma newdecls required
#pragma semicolon 1


public Plugin myinfo =
{
	name = "berobot_volunteer",
	author = "icebear",
	description = "",
	version = "0.1",
	url = "https://github.com/higps/robogithub"
};

methodmap VolunteerState < StringMap
{
    public VolunteerState() {
        return view_as<VolunteerState>(new StringMap());
    }

    property int ClientId {
        public get(){ 
            int value;
            this.GetValue("ClientId", value);
            return value;
        }
        public set(int value){
            this.SetValue("ClientId", value);
        }
    }

    property int QueuePoints {
        public get(){ 
            int value;
            this.GetValue("QueuePoints", value);
            return value;
        }
        public set(int value){
            this.SetValue("QueuePoints", value);
        }
    }

    property bool Admin {
        public get(){ 
            bool value;
            this.GetValue("Admin", value);
            return value;
        }
        public set(bool value){
            this.SetValue("Admin", value);
        }
    }

    property bool Vip {
        public get(){ 
            bool value;
            this.GetValue("Vip", value);
            return value;
        }
        public set(bool value){
            this.SetValue("Vip", value);
        }
    }

    property bool Volunteered {
        public get(){ 
            bool value;
            this.GetValue("Volunteered", value);
            return value;
        }
        public set(bool value){
            this.SetValue("Volunteered", value);
        }
    }

    public void GetClientIdString(char steamId[10]){ 
        this.GetString("ClientIdString", steamId, sizeof(steamId));
    }
    public void SetClientIdString(char value[10]){
        this.SetString("ClientIdString", value);
    }

    public void GetSteamId(char steamId[64]){ 
        this.GetString("SteamId", steamId, sizeof(steamId));
    }
    public void SetSteamId(char value[64]){
        this.SetString("SteamId", value);
    }
}

ConVar _autoVolunteerTimeoutConVar;
int _autoVolunteerTimeout;
ConVar _autoVolunteerPriaoritizeAdminFlagConVar;
int _autoVolunteerAdminFlag;
ConVar _robocapTeamConVar;
int _robocapTeam;

StringMap _vipSteamIds;
bool _automaticVolunteerVoteIsInProgress;
Handle _countdownTimer;
int _countdownTarget;
Handle _autoVolunteerTimer;
bool _pickedOption[MAXPLAYERS + 1];
bool _volunteered[MAXPLAYERS + 1];
StringMap _queuePoints;

public void OnPluginStart()
{
    SMLoggerInit(LOG_TAGS, sizeof(LOG_TAGS), SML_ERROR, SML_FILE);
    SMLogTag(SML_INFO, "berobot_volunteer started at %i", GetTime());

    _autoVolunteerTimeoutConVar = CreateConVar("sm_auto_volunteer_timeout", "20", "duration the automatic volunteer-menu will be shown (in seconds) ('0' to disable)");
    _autoVolunteerTimeoutConVar.AddChangeHook(AutoVolunteerTimeoutCvarChangeHook);
    _autoVolunteerTimeout = GetConVarInt(_autoVolunteerTimeoutConVar);

    int defautlAdminFlag = ADMFLAG_ROOT;
    char defautlAdminFlagString[10];
    IntToString(defautlAdminFlag, defautlAdminFlagString, sizeof(defautlAdminFlagString));
    _autoVolunteerPriaoritizeAdminFlagConVar = CreateConVar("sm_auto_volunteer_prioitize_admin_flag", 
                                                            defautlAdminFlagString, 
                                                            "Users with this admin-flag get prioritized when picking volunteers. set to -1 to disable");
    _autoVolunteerPriaoritizeAdminFlagConVar.AddChangeHook(AutoVolunteerAdminFlagCvarChangeHook);
    _autoVolunteerAdminFlag = GetConVarInt(_autoVolunteerPriaoritizeAdminFlagConVar);

    RegAdminCmd("sm_setvolunteer", Command_SetVolunteer, ADMFLAG_SLAY, "sets the volunteer status to true/enabled");
    RegAdminCmd("sm_unsetvolunteer", Command_UnsetVolunteer, ADMFLAG_SLAY, "sets the volunteer status to false/disabled");
    RegAdminCmd("sm_reload_vip_volunteers", Command_ReloadVipVolunteers, ADMFLAG_SLAY, "reloads VIP-SteamIds from file");
    RegAdminCmd("sm_reload_queuepoints_volunteers", Command_ReloadQueuepointsVolunteers, ADMFLAG_SLAY, "reloads queuepoints from file");

    RegConsoleCmd("sm_volunteer", Command_Volunteer, "Volunters you to be a giant robot");
    RegConsoleCmd("sm_vlntr", Command_Volunteer, "Volunters you to be a giant robot");
    RegConsoleCmd("sm_join", Command_Volunteer, "Volunters you to be a giant robot");

    LoadVipSteamIds();    
    LoadQueuePointsFromFile();    

    Reset();
}

public void OnConfigsExecuted()
{
    _robocapTeamConVar = FindConVar(CONVAR_ROBOCAP_TEAM);
    _robocapTeamConVar.AddChangeHook(RobocapTeamCvarChangeHook);
    _robocapTeam = GetConVarInt(_robocapTeamConVar);
}

public void MM_OnClientResetting(int clientId)
{
    SMLogTag(SML_VERBOSE, "resetting volunteer status for client %i", clientId);

    _pickedOption[clientId] = false;
    _volunteered[clientId] = false;
}

public void AutoVolunteerAdminFlagCvarChangeHook(ConVar convar, const char[] sOldValue, const char[] sNewValue)
{
    _autoVolunteerAdminFlag = StringToInt(sNewValue);
}

public void AutoVolunteerTimeoutCvarChangeHook(ConVar convar, const char[] sOldValue, const char[] sNewValue)
{
    _autoVolunteerTimeout = StringToInt(sNewValue);
}

public void RobocapTeamCvarChangeHook(ConVar convar, const char[] sOldValue, const char[] sNewValue)
{
    _robocapTeam = StringToInt(sNewValue);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("StartAutomaticVolunteerVote", Native_StartAutomaticVolunteerVote);
    CreateNative("AutomaticVolunteerVoteIsInProgress", Native_AutomaticVolunteerVoteIsInProgress);
    CreateNative("GetRandomVolunteer", Native_GetRandomVolunteer);
    return APLRes_Success;
}

public void OnMapStart()
{
    Reset();
}

void Reset()
{
    _automaticVolunteerVoteIsInProgress = false;
    for(int i = 0; i <= MAXPLAYERS; i++)
    {
        _volunteered[i] = false;
        _pickedOption[i] = false;
    }
}

void LoadVipSteamIds()
{
    if (_vipSteamIds)
        delete _vipSteamIds;

    _vipSteamIds = new StringMap();
    File file = OpenFile("mm_volunteer_vip.txt", "r");
    if (file == null)
    {
        SMLogTag(SML_INFO, "VIPs could not be loaded, because file 'mm_volunteer_vip.txt' was not found", _vipSteamIds.Size);
        return;
    }

    while(!file.EndOfFile())
    {
        char steamId[64];
        file.ReadLine(steamId, sizeof(steamId));
        _vipSteamIds.SetValue(steamId, true);
    }
    CloseHandle(file);

    SMLogTag(SML_INFO, "%i VIPs loaded", _vipSteamIds.Size);
}

public Action Command_ReloadVipVolunteers(int client, int args)
{
    LoadVipSteamIds();
}

public Action Command_ReloadQueuepointsVolunteers(int client, int args)
{
    LoadQueuePointsFromFile();
}

public Action Command_SetVolunteer(int client, int args)
{
    if (!IsEnabled())
    {
        MM_PrintToChat(client, "Unable to volunteer, robot-mode is not enabled");
        SMLogTag(SML_VERBOSE, "Command_SetVolunteer cancled for %L, because robot-mode is not enabled", client);
        return Plugin_Handled;
    }

    if (IsYTEnabled())
    {
        MM_PrintToChat(client, "Unable to volunteer, robot-mode is not enabled");
        SMLogTag(SML_VERBOSE, "Command_SetVolunteer cancled for %L, because robot-mode is not enabled", client);
        return Plugin_Handled;
    }

    char target[32];
    if(args < 1)
    {
        target = "";
    }
    else
        GetCmdArg(1, target, sizeof(target));

    VolunteerTargets(client, target, true);

    return Plugin_Handled;
}

public Action Command_UnsetVolunteer(int client, int args)
{
    if (!IsEnabled())
    {
        MM_PrintToChat(client, "Unable to volunteer, robot-mode is not enabled");
        SMLogTag(SML_VERBOSE, "Command_UnsetVolunteer cancled for %L, because robot-mode is not enabled", client);
        return Plugin_Handled;
    }

    char target[32];
    if(args < 1)
    {
        target = "";
    }
    else
        GetCmdArg(1, target, sizeof(target));

    VolunteerTargets(client, target, false);

    return Plugin_Handled;
}

public Action Command_Volunteer(int client, int args)
{
    SMLogTag(SML_VERBOSE, "Command_Volunteer called for %L", client);

    if (!IsEnabled())
    {
        MM_PrintToChat(client, "Unable to volunteer, robot-mode is not enabled");
        SMLogTag(SML_VERBOSE, "Command_Volunteer cancled for %L, because robot-mode is not enabled", client);
        return Plugin_Handled;
    }
    //     if (IsYTEnabled())
    // {
    //     MM_PrintToChat(client, "Unable to volunteer, because Youtube mode is active");
    //     SMLogTag(SML_VERBOSE, "Command_Volunteer cancled for %L, because robot-mode is in youtube mode", client);
    //     return Plugin_Handled;
    // }

    // if (AutomaticVolunteerVoteIsInProgress()) 
    // {
    //     MM_PrintToChat(client, "Unable to volunteer, a vote for volunteers is in progress");
    //     return Plugin_Handled;
    // }

    char target[32];
    if(args < 1)
    {
        target = "";
    }
    else
        GetCmdArg(1, target, sizeof(target));


    if (!TF2Spawn_IsClientInSpawn(client) && IsPlayerAlive(client))
    {
        MM_PrintToChat(client, "You can only volunteer when in spawn or dead.");
        
    }else
    {
        VolunteerTargets(client, target, !_volunteered[client]);
    }

    return Plugin_Handled;
}

public void VolunteerTargets(int client, char target[32], bool volunteering)
{
    int targetFilter = 0;
    if(target[0] == '\0')
    {
        target = "@me";
        targetFilter = COMMAND_FILTER_NO_IMMUNITY;
    }

    char target_name[MAX_TARGET_LENGTH];
    int target_list[MAXPLAYERS], target_count;
    bool tn_is_ml;

    if((target_count = ProcessTargetString(
          target,
          client,
          target_list,
          MAXPLAYERS,
          targetFilter,
          target_name,
          sizeof(target_name),
          tn_is_ml)) <= 0)
    {
        ReplyToTargetError(client, target_count);
        return;
    }

    for(int i = 0; i < target_count; i++)
    {
        int targetClientId = target_list[i];
        Volunteer(targetClientId, volunteering);
    }
}

public void Volunteer(int client, bool volunteering)
{
    _volunteered[client] = volunteering;
    _pickedOption[client] = true;


    if (volunteering)
        MM_PrintToChat(client, "You volunteered to be a robot.");
    else
    {
        MM_PrintToChat(client, "You no longer volunteer to be a robot.");
        UnmakeRobot(client);
    }

    EnsureRobotCount();
}

int Native_AutomaticVolunteerVoteIsInProgress(Handle plugin, int numParams)
{
    return _automaticVolunteerVoteIsInProgress;
}

int Native_GetRandomVolunteer(Handle plugin, int numParams)
{
    int length = GetNativeCell(2);
    int[] ignoredClientIds = new int[length];
    GetNativeArray(1, ignoredClientIds, length);
    SMLogTag(SML_VERBOSE, "Native_GetRandomVolunteer read %i ignroedClientIds", length);

    ArrayList pickedVolunteers = PickVolunteers(1, ignoredClientIds, length, false);    
    if (pickedVolunteers.Length <= 0)
    {
        delete pickedVolunteers;
        return -1;
    }

    int clientId = pickedVolunteers.Get(0);
    SMLogTag(SML_VERBOSE, "Native_GetRandomVolunteer picked %L", clientId);

    delete pickedVolunteers;

    return clientId;
}

int Native_StartAutomaticVolunteerVote(Handle plugin, int numParams)
{
    _automaticVolunteerVoteIsInProgress = true;
    for(int i = 1; i <= MaxClients; i++)
    {
        if (!IsValidClient(i) || !IsClientInGame(i))
            continue;
        if (_pickedOption[i])
        {            
            if (_volunteered[i])
                MM_PrintToChat(i, "You already volunteered to be a robot. type '!volunteer' to cancle your volunteer-state.");
            else
                MM_PrintToChat(i, "You already decided not volunteering to be a robot. type '!volunteer' to volunteer again.");
            continue;
        }
        
        Menu_AutomaticVolunteer(i);
    }

    _countdownTarget = GetTime() + _autoVolunteerTimeout;
    _autoVolunteerTimer = CreateTimer(float(_autoVolunteerTimeout), Timer_VolunteerAutomaticVolunteers);
    _countdownTimer = CreateTimer(1.0, Timer_Countdown, _, TIMER_REPEAT);
    TriggerTimer(_countdownTimer, true);
}

Action Timer_Countdown(Handle timer)
{
    int remainingSeconds = _countdownTarget - GetTime();
    if (remainingSeconds < 0)
        return Plugin_Stop;
        
    int volunteerCount = CountVolunteers();
    char verb[5];
    if (volunteerCount == 1)
        verb = "has";
    else
        verb = "have";
    PrintCenterTextAll("%i seconds left to vote. %i/%i %s volunteered so far. Random volunteers are picked to be robots.", remainingSeconds, volunteerCount, _robocapTeam, verb);
    
    return Plugin_Continue;
}

Action Timer_VolunteerAutomaticVolunteers(Handle timer)
{
    if (_countdownTimer != null)
    {
        KillTimer(_countdownTimer);
        _countdownTimer = null;
    }
    VolunteerAutomaticVolunteers();
}

int CountVolunteers()
{
    int count = 0;
    for(int i = 0; i <= MaxClients; i++)
    {
        if (!_volunteered[i])
            continue;
        
        count++;
    }

    return count;
}

void VolunteerAutomaticVolunteers()
{
    int[] ignoredClientIds = new int[1];
    ArrayList pickedVolunteers = PickVolunteers(_robocapTeam, ignoredClientIds, 0);

    int[] volunteerArray = new int[pickedVolunteers.Length];
    for(int i = 0; i < pickedVolunteers.Length; i++)
    {
        VolunteerState state = pickedVolunteers.Get(i);
        volunteerArray[i] = state.ClientId;
        SMLogTag(SML_VERBOSE, "setting %L as volunteered", volunteerArray[i]);
    }
    SetVolunteers(volunteerArray, pickedVolunteers.Length);

    delete pickedVolunteers;

    SMLogTag(SML_VERBOSE, "setting _automaticVolunteerVoteIsInProgress to false");
    _automaticVolunteerVoteIsInProgress = false;
}

/**
 * picks volunteers, based on admin-/vip-/volunteer-status 
 * 
 * @param neededVolunteers           amount of needed volunteers
 * @param ignoredClientIds           array of clientIds that should be ignored (can't ever get picked)
 * @param ignoredClientIdsLength     length of the ignoredClientIds-array
 * @param pickNonvolunteers          indicates if nonvolunteers should be picked, if not enough people volunteered (default: true)
 * @return                           returns a ArrayList of VolunteerStates
 */
ArrayList PickVolunteers(int neededVolunteers, int[] ignoredClientIds, int ignoredClientIdsLength, bool pickNonvolunteers = true)
{
    StringMap ignoredClientIdLookup = new StringMap();
    for(int i = 0; i < ignoredClientIdsLength; i++)
    {
        int ignoredClientId = ignoredClientIds[i];
        char str[10];
        IntToString(ignoredClientId, str, 10);

        SMLogTag(SML_VERBOSE, "adding %s for %i to ignored volunteers", str, ignoredClientId);
        ignoredClientIdLookup.SetValue(str, true);
    }

    ArrayList volunteers = new ArrayList();
    
    for(int i = 0; i <= MaxClients; i++)
    {
        if (!IsValidClient(i))
            continue;
        if (!IsClientInGame(i))
            continue;

        char str[10];
        IntToString(i, str, 10);
        bool value;
        if (ignoredClientIdLookup.GetValue(str, value))
        {
            SMLogTag(SML_VERBOSE, "ignoring %L for picking volunteers", i);
            continue;
        }

        VolunteerState state = new VolunteerState();
        state.ClientId = i;

        char steamId[64];
        if (!GetClientAuthId(i, AuthId_Steam2, steamId, sizeof(steamId)))
        {
            SMLogTag(SML_ERROR, "could not read steamid for %L. ignoring queue points", i);
            continue;
        }
        SMLogTag(SML_VERBOSE, "read steamid for %L: %s", i, steamId);

        state.SetSteamId(steamId);
        state.SetClientIdString(str);
        int queuePoints;
        _queuePoints.GetValue(steamId, queuePoints);
        state.QueuePoints = queuePoints;
        SMLogTag(SML_VERBOSE, "%L with steamid %s has %i Queuepoints", i, steamId, queuePoints);
        // PrintToChatAll("%L has %i Queuepoints", i, queuePoints);
        // // PrintCenterText(i, "You have %i points", queuePoints);
        // PrintToConsoleAll("%L has %i Queuepoints", i, queuePoints);

        if (!_volunteered[i])
        {
            SMLogTag(SML_VERBOSE, "%L has not volunteered", i);
            if (pickNonvolunteers)
                volunteers.Push(state);
            continue;
        }

        state.Volunteered = true;
        volunteers.Push(state);

        if (_autoVolunteerAdminFlag >= 0)
        {
            int userflags = GetUserFlagBits(i);
            if (userflags & _autoVolunteerAdminFlag)
            {
                SMLogTag(SML_VERBOSE, "%L has volunteered and gets prioritized, because they have admin-flag %i", i, _autoVolunteerAdminFlag);
                state.Admin = true;
                continue;
            }
        }

        if (_vipSteamIds.GetValue(steamId, value))
        {
            SMLogTag(SML_VERBOSE, "%L has volunteered and gets prioritized, because they are a vip", i);
            state.Vip = true;
            continue;
        }

        SMLogTag(SML_VERBOSE, "%L has volunteered", i);
    }

    delete ignoredClientIdLookup;
    
    if (volunteers.Length > neededVolunteers)
    {
        volunteers.SortCustom(VolunteerStateComparision);

        UpdateQueuePoints(volunteers, neededVolunteers);

        volunteers.Resize(neededVolunteers);
    }
    else
    {
        UpdateQueuePoints(volunteers, neededVolunteers);
    }

    for(int volunteerIndex = 0; volunteerIndex < volunteers.Length; volunteerIndex++)
    {
        VolunteerState state = volunteers.Get(volunteerIndex);
        SMLogTag(SML_VERBOSE, "%L was picked with %i queuepoints (Admin: %i; Vip: %i; Volunteered: %i)", state.ClientId, state.QueuePoints, state.Admin, state.Vip, state.Volunteered);
    }
    
    return volunteers;
}

void UpdateQueuePoints(ArrayList volunteers, int neededVolunteers)
{
    for(int volunteerIndex = 0; volunteerIndex < volunteers.Length; volunteerIndex++)
    {
        VolunteerState state = view_as<VolunteerState>(volunteers.Get(volunteerIndex));

        char steamId[64];
        state.GetSteamId(steamId);

        int newQueuepoints;
        if (volunteerIndex < neededVolunteers)
        {
            newQueuepoints = 0;
            SMLogTag(SML_VERBOSE, "resetting Queuepoints for %L with steamid %s", state.ClientId, steamId);
        }
        else
        {
            newQueuepoints = state.QueuePoints + 1;
            SMLogTag(SML_VERBOSE, "increasing Queuepoints for %L with steamid %s to %i", state.ClientId, steamId, newQueuepoints);
        }
        
        _queuePoints.SetValue(steamId, newQueuepoints);
    }
    SaveQueuePointsToFile();
}

int VolunteerStateComparision(int index1, int index2, Handle array, Handle hndl)
{
    ArrayList list = view_as<ArrayList>(array); 
    VolunteerState a = view_as<VolunteerState>(list.Get(index1));
    VolunteerState b = view_as<VolunteerState>(list.Get(index2));
    
    if (a.Admin && !b.Admin)
        return -1;
    if (!a.Admin && b.Admin)
        return 1;
    
    if (a.Vip && !b.Vip)
        return -1;
    if (!a.Vip && b.Vip)
        return 1;
    
    if (a.Volunteered && !b.Volunteered)
        return -1;
    if (!a.Volunteered && b.Volunteered)
        return 1;

    if (a.QueuePoints < b.QueuePoints)
        return 1;
    if (a.QueuePoints > b.QueuePoints)
        return -1;
    return 0;
}

void SaveQueuePointsToFile()
{
    File file = OpenFile("mm_volunteer_queuepoints.txt", "w+");
    if (file == null)
    {
        SMLogTag(SML_ERROR, "Queuepoints could not be saved, because file 'mm_volunteer_queuepoints.txt' could not be opend for writing.");
        return;
    }

    StringMapSnapshot snapshot = _queuePoints.Snapshot();
    for(int i = 0; i < snapshot.Length; i++)
    {
        char key[64];
        snapshot.GetKey(i, key, sizeof(key));
        int queuePoints;
        _queuePoints.GetValue(key, queuePoints);
        
        bool success = file.WriteLine("%s", key);
        if (!success)
        {
            SMLogTag(SML_ERROR, "could not write steamid line for '%s,%i'", key, queuePoints);
            
            delete snapshot;
            CloseHandle(file);

            return;
        }
        success = file.WriteLine("%i", queuePoints);
        if (!success)
        {
            SMLogTag(SML_ERROR, "could not write queuepoints line for '%s,%i'", key, queuePoints);
            
            delete snapshot;
            CloseHandle(file);

            return;
        }

        file.WriteLine("");
    }
    delete snapshot;

    file.Flush();
    CloseHandle(file);

    SMLogTag(SML_VERBOSE, "%i Queuepoints saved to file 'mm_volunteer_queuepoints.txt'", _queuePoints.Size);
}

void LoadQueuePointsFromFile()
{
    _queuePoints = new StringMap();

    File file = OpenFile("mm_volunteer_queuepoints.txt", "r");
    if (file == null)
    {
        SMLogTag(SML_INFO, "Queuepoints could not be loaded, because file 'mm_volunteer_queuepoints.txt' could not be opend for reading.");
        return;
    }

    int lineNumber = 0;
    while(!file.EndOfFile())
    {
        lineNumber++;

        char steamId[64];
        bool success = file.ReadLine(steamId, sizeof(steamId));
        if (!success)
        {
            SMLogTag(SML_VERBOSE, "could not read steamId line: %i", lineNumber);
            break;
        }
        CutAtNewLine(steamId, sizeof(steamId));
        SMLogTag(SML_VERBOSE, "read steamId %s", steamId);

        lineNumber++;
        char queuepointsString[10];
        success = file.ReadLine(queuepointsString, sizeof(queuepointsString));
        if (!success)
        {
            SMLogTag(SML_ERROR, "could not read queuepoints line: %i", lineNumber);
            break;
        }
        CutAtNewLine(queuepointsString, sizeof(queuepointsString));
        SMLogTag(SML_VERBOSE, "read queuepoints %s", queuepointsString);
        
        lineNumber++;
        char emptyLine[2];
        file.ReadLine(emptyLine, sizeof(emptyLine));
        CutAtNewLine(emptyLine, sizeof(emptyLine));
        SMLogTag(SML_VERBOSE, "read separator %s", emptyLine);
        SMLogTag(SML_VERBOSE, "read steamId %s; queuepoints %s", steamId, queuepointsString);

        int queuepoints = StringToInt(queuepointsString);        
        _queuePoints.SetValue(steamId, queuepoints);
    }

    CloseHandle(file);

    SMLogTag(SML_INFO, "%i Queuepoints loaded from file 'mm_volunteer_queuepoints.txt'", _queuePoints.Size);
}

void CutAtNewLine(char[] str, int length)
{
    for(int i = 0; i < length; i++)
    {
        if (str[i] == '\n')
        {
            str[i] = '\0';
            return;
        }
    }
}

bool EveryClientAnsweredVote()
{
    for(int i = 1; i <= MaxClients; i++)
    {        
        if (!IsValidClient(i) || !IsClientInGame(i))
            continue;
        if (!_pickedOption[i])
            return false;
    }

    return true;
}

Action Menu_AutomaticVolunteer(int client)
{
    Menu menu = new Menu(MenuHandler);

    menu.SetTitle("Do you want to play as a robot?");
    menu.ExitButton = false;

    menu.AddItem(MENU_ANSWER_YES, "Yes");
    menu.AddItem(MENU_ANSWER_NO, "No");

    int timeout = _autoVolunteerTimeout;
    menu.Display(client, timeout);
    SMLogTag(SML_VERBOSE, "AutomaticVolunteer-menu displayed to %L for %i seconds", client, timeout);

    return Plugin_Handled;
}

public int MenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    /* If an option was selected, tell the client about the item. */
    if(action == MenuAction_Select)
    {
        char answer[32];
        bool found = menu.GetItem(param2, answer, sizeof(answer));
        PrintToConsole(param1, "You selected item: %d (found? %d answer: %s)", param2, found, answer);

        _volunteered[param1] = StrEqual(answer, MENU_ANSWER_YES);
        _pickedOption[param1] = true;
        if (EveryClientAnsweredVote())
        {
            KillTimer(_autoVolunteerTimer);
            if (_countdownTimer != null)
            {
                KillTimer(_countdownTimer);
                _countdownTimer = null;
            }
            VolunteerAutomaticVolunteers();
        }
    }
    /* If the menu was cancelled, print a message to the server about it. */
    else if(action == MenuAction_Cancel)
    {
        _volunteered[param1] = false;
    }

    /* If the menu has ended, destroy it */
    else if(action == MenuAction_End)
    {
        delete menu;
    }
}