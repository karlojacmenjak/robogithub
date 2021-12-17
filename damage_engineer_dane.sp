#pragma semicolon 1
#include <sourcemod>
#include <tf2_stocks>
#include <tf2attributes>
#include <sdkhooks>
#include <berobot_constants>
#include <berobot>
//#include <sendproxy>
#include <tfobjects>
#include <dhooks>
#include <sdktools>
//#include <collisionhook>
#include <tf_custom_attributes>

#pragma semicolon 1
//#pragma newdecls required

#define PLUGIN_VERSION "1.0"
#define ROBOT_NAME	"Uncle Dane"
#define ROBOT_ROLE "Damage"
#define ROBOT_DESCRIPTION " Widowmaker, Jag"

#define ChangeDane             "models/bots/engineer/bot_engineer.mdl"
#define SPAWN   "#mvm/giant_heavy/giant_heavy_entrance.wav"
#define DEATH   "mvm/sentrybuster/mvm_sentrybuster_explode.wav"
#define LOOP    "mvm/giant_heavy/giant_heavy_loop.wav"


#define ENGIE_SPAWN_SOUND		"vo/announcer_mvm_engbot_arrive02.mp3"
#define ENGIE_SPAWN_SOUND2		"vo/announcer_mvm_engbot_arrive03.mp3"

#define TELEPORTER_ACTIVATE1	"vo/announcer_mvm_eng_tele_activated01.mp3"
#define TELEPORTER_ACTIVATE2	"vo/announcer_mvm_eng_tele_activated02.mp3"
#define TELEPORTER_ACTIVATE3	"vo/announcer_mvm_eng_tele_activated03.mp3"
#define TELEPORTER_ACTIVATE4	"vo/announcer_mvm_eng_tele_activated04.mp3"
#define TELEPORTER_ACTIVATE5	"vo/announcer_mvm_eng_tele_activated05.mp3"

#define TELEPORTER_SPAWN		"mvm/mvm_tele_deliver.wav"

#define TF_OBJECT_TELEPORTER	1
#define TF_TELEPORTER_ENTR	0

//new g_offsCollisionGroup;

bool engibotactive;
bool teleportercheck;
bool AnnouncerQuiet;



int EngieTeam = 2;
int engieid = -1;
int g_iMaxEntities;
int BossTeleporter;

float vecSpawns[2][3];

static int g_iPadType[2048];
static int g_iObjectParticle[2048];

static char g_szOffsetStartProp[64];
static int g_iOffsetMatchingTeleporter = -1;

bool g_ReadyToTeamPort[MAXPLAYERS + 1] = false;

enum //Teleporter states
{
	TELEPORTER_STATE_BUILDING = 0,				// Building, not active yet
	TELEPORTER_STATE_IDLE,						// Does not have a matching teleporter yet
	TELEPORTER_STATE_READY,						// Found match, charged and ready
	TELEPORTER_STATE_SENDING,					// Teleporting a player away
	TELEPORTER_STATE_RECEIVING,					
	TELEPORTER_STATE_RECEIVING_RELEASE,
	TELEPORTER_STATE_RECHARGING,				// Waiting for recharge
	TELEPORTER_STATE_UPGRADING					// Upgrading
}

enum //Custom ObjectType
{
	PadType_None = 0,
	PadType_Boss,
}

public Plugin:myinfo =
{
	name = "[TF2] Be Big Robot Uncle Dane",
	author = "Erofix using the code from: Pelipoika, PC Gamer, Jaster and StormishJustice",
	description = "Play as the Giant Uncle Dane Bot from MvM",
	version = PLUGIN_VERSION,
	url = "www.sourcemod.com"
}

public OnPluginStart()
{
    LoadTranslations("common.phrases");

    //g_offsCollisionGroup = FindSendPropInfo("DT_BaseEntity", "m_CollisionGroup");
    HookEvent("player_builtobject", ObjectBuilt, EventHookMode_Post);
	HookEvent("player_carryobject", ObjectCarry, EventHookMode_Post);
//	HookEvent("player_upgradedobject", ObjectCarry, EventHookMode_Post);

	Handle hGameConf = LoadGameConfigFile("tf2.teleporters");
	if (hGameConf == INVALID_HANDLE)
	{
		SetFailState("[EngiPads] Unable to load gamedata file 'tf2.teleporters.txt'");
	}
	
	bool bFoundProp = GameConfGetKeyValue(hGameConf, "StartProp", g_szOffsetStartProp, sizeof(g_szOffsetStartProp));
	g_iOffsetMatchingTeleporter = GameConfGetOffset(hGameConf, "m_hMatchingTeleporter");
	
	if (!bFoundProp || g_iOffsetMatchingTeleporter < 0)
	{
		SetFailState("[EngiPads] Unable to get m_hMatchingTeleporter offset from 'tf2.teleporters.txt'. Check gamedata!");
	}
	
	CloseHandle(hGameConf);

	//AddCommandListener(CommandListener_Build, "build");
	//HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_Post);

	//RegConsoleCmd("sm_dane", Dane, "become dane");

    RobotDefinition robot;
    robot.name = ROBOT_NAME;
    robot.role = ROBOT_ROLE;
    robot.class = "Engineer";
    robot.shortDescription = ROBOT_DESCRIPTION;
    robot.sounds.spawn = SPAWN;
    robot.sounds.loop = LOOP;
    robot.sounds.death = DEATH;
    AddRobot(robot, MakeUncleDane, PLUGIN_VERSION);
	
	PrecacheSound(ENGIE_SPAWN_SOUND, true);
	PrecacheSound(ENGIE_SPAWN_SOUND2, true);
	PrecacheSound(TELEPORTER_ACTIVATE1, true);
	PrecacheSound(TELEPORTER_ACTIVATE2, true);
	PrecacheSound(TELEPORTER_ACTIVATE3, true);
	PrecacheSound(TELEPORTER_ACTIVATE4, true);
	PrecacheSound(TELEPORTER_ACTIVATE5, true);
	PrecacheSound(TELEPORTER_SPAWN, true);



    // for(int client = 1 ; client <= MaxClients ; client++)
    // {
    //     if(IsClientInGame(client))
    //     {
    //         //SDKHook(client, SDKHook_TraceAttack, OnTraceAttack);
	// 		//PrintToChatAll("Hooking %N", client);
    //        // SDKHook(client, SDKHook_Touch, OnTouch);
    //     }
    // }

}

public void OnPluginEnd()
{
	RemoveRobot(ROBOT_NAME);
}
/* public OnEntityCreated(entity, const String:classname[])
{
    if(StrContains(classname[1], "item_ammopack", false) != -1 || StrContains(classname[1], "item_healthkit", false) != -1)
    {
        SDKHook(entity,    SDKHook_StartTouch,     StartTouch);
        SDKHook(entity,    SDKHook_Touch,             OnTouch);
    }
} */

/* public Action OnTouch(int client, int ent)
{
	char entname[MAX_NAME_LENGTH];
	GetEntityClassname(ent, entname, sizeof(entname));
	
	if (!StrContains(entname, "item_ammo") || !StrContains(entname, "item_health")){
		PrintToChatAll("Ent: %s", entname);
    	if(GetEntProp(ent, Prop_Data, "m_bDisabled") == 1)
        return;
	}

	
} */

// public Action OnTouch(int client)
// {
// 	PrintToChatAll("TOUCHING! %N", client);
// }

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	//	CreateNative("BeSuperHeavyweightChamp_MakeUncleDane", Native_SetSuperHeavyweightChamp);
	//	CreateNative("BeSuperHeavyweightChamp_IsSuperHeavyweightChamp", Native_IsSuperHeavyweightChamp);
	return APLRes_Success;
}

public OnMapStart()
{
	PrecacheModel(ChangeDane);
	PrecacheSound(SPAWN);
	PrecacheSound(DEATH);
	PrecacheSound(LOOP);

	

}




/* public bool ShouldCollide(entity, collisiongroup, contentmask, bool result)
{	
	PrintToChatAll("Returning false");
	return false;
}
 */
//trigger the event
// public void PlayerUpgradedobject(Event evnet, const char[] name, bool dontBroadcast)
// {
// PrintToChatAll("Upgrade complete");
// }

public void ObjectBuilt(Event event, const char[] name, bool dontBroadcast)
{
	// if (view_as<TFObjectType>(event.GetInt("object")) != TFObject_Teleporter)
	// return;
	
	
	int iBuilder = GetClientOfUserId(event.GetInt("userid"));
	int iObj = event.GetInt("index");
	//int entRef = EntIndexToEntRef(iObj);
	//PrintToChatAll("iObj %i", iObj);
	
	if (IsValidClient(iBuilder) && IsRobot(iBuilder, ROBOT_NAME)){
		// SetEntProp(iObj, Prop_Send, "m_iHighestUpgradeLevel", 3);
		// SetEntProp(iObj, Prop_Send, "m_iUpgradeLevel", 3);
		if (view_as<TFObjectType>(event.GetInt("object")) != TFObject_Teleporter){
		SetEntPropFloat(iObj, Prop_Send, "m_flModelScale", 1.65);
		SetEntPropFloat(iObj, Prop_Send, "m_flPercentageConstructed", 1.0);
		DispatchKeyValue(iObj, "defaultupgrade", "2"); 
	
		}

	}
}

// int CreatePadParticle(int iPad, char[] szParticleName)
// {
// 	//TFTeam iPadTeam = view_as<TFTeam>(GetEntProp(iPad, Prop_Send, "m_iTeamNum"));
// 	//char szParticleName[128];
// 	// switch (g_iPadType[iPad])
// 	// {
// 	// 	case PadType_Boost:	strcopy(szParticleName, sizeof(szParticleName), "powerup_icon_haste");
// 	// 	case PadType_Jump:	strcopy(szParticleName, sizeof(szParticleName), "powerup_icon_agility");
// 	// }
// 	// switch (iPadTeam)
// 	// {
// 	// 	case TFTeam_Red:	StrCat(szParticleName, sizeof(szParticleName), "_red");
// 	// 	case TFTeam_Blue:	StrCat(szParticleName, sizeof(szParticleName), "_blue");
// 	// }
// 	int iParticle = SpawnParticle(szParticleName);
	
// 	float vPos[3];
// 	GetEntPropVector(iPad, Prop_Data, "m_vecAbsOrigin", vPos);
// 	//vPos[2] += 40.0;
// 	TeleportEntity(iParticle, vPos, NULL_VECTOR, NULL_VECTOR);
	
// 	SetParent(iPad, iParticle);
	
// 	return iParticle;
// }

stock int SpawnParticle(char[] szParticleType)
{
	int iParti = CreateEntityByName("info_particle_system");
	if (IsValidEntity(iParti))
	{
		DispatchKeyValue(iParti, "effect_name", szParticleType);
		DispatchSpawn(iParti);
		ActivateEntity(iParti);
	}
	return iParti;
}

stock void SetParent(int iParent, int iChild, char[] szAttachPoint = "")
{
	SetVariantString("!activator");
	AcceptEntityInput(iChild, "SetParent", iParent, iChild);
	
	if (szAttachPoint[0] != '\0')
	{
		if (IsValidClient(iParent) && IsPlayerAlive(iParent))
		{
			SetVariantString(szAttachPoint);
			AcceptEntityInput(iChild, "SetParentAttachmentMaintainOffset", iChild, iChild, 0);
		}
	}
}

stock void TF2_SetMatchingTeleporter(int iTele, int iMatch)	//Set the matching teleporter entity of a given Teleporter
{

	if (IsValidEntity(iTele) && HasEntProp(iTele, Prop_Send, g_szOffsetStartProp))
	{
		//PrintToChatAll("Matching telepoters");
		int iOffs = FindSendPropInfo("CObjectTeleporter", g_szOffsetStartProp) + g_iOffsetMatchingTeleporter;
		SetEntDataEnt2(iTele, iOffs, iMatch, true);
	}
	
}

public void ObjectCarry(Event event, const char[] name, bool dontBroadcast)
{
	// if (view_as<TFObjectType>(event.GetInt("object")) != TFObject_Teleporter)
	// return;
	
	
	int iBuilder = GetClientOfUserId(event.GetInt("userid"));
	int iObj = event.GetInt("index");
	//int entRef = EntIndexToEntRef(iObj);
	//PrintToChatAll("iObj %i", iObj);
	
	if (IsValidClient(iBuilder) && IsRobot(iBuilder, ROBOT_NAME)){
		// SetEntProp(iObj, Prop_Send, "m_iHighestUpgradeLevel", 3);
		// SetEntProp(iObj, Prop_Send, "m_iUpgradeLevel", 3);
		if (view_as<TFObjectType>(event.GetInt("object")) != TFObject_Teleporter)SetEntPropFloat(iObj, Prop_Send, "m_flModelScale", 1.0);
		
	//	SetEntPropFloat(iObj, Prop_Send, "m_flPercentageConstructed", 1.0);
		//SetEntProp(iObj, Prop_Send, "m_CollisionGroup", 2); 
		//SetEntPropFloat(iObj, Prop_Send, "m_bDisposableBuilding", 1.0);	
//		DispatchKeyValue(iObj, "defaultupgrade", "2"); 
		//SetEntPropFloat(iObj, Prop_Send, "m_iUpgradeMetalRequired ", 0.1);
		//SDKHook(iObj, SDKHook_ShouldCollide, ShouldCollide );
		//CH_PassFilter(iBuilder, iObj, false);
		//SetEntData(iObj, g_offsCollisionGroup, 2, 4, false);
	
	}
}

/* public Action:CH_PassFilter( ent1, ent2, &bool:result )
{
	PrintToChatAll("Should stop");
			result = false;
			return Plugin_Stop;

}  */

/* public bool:ShouldCollide( entity, collisiongroup, contentsmask, bool:result )
{
	PrintToChatAll("Should not collide");
    return false;
}  */

public Action:SetModel(client, const String:model[])
{
	if (IsValidClient(client) && IsPlayerAlive(client))
	{
		SetVariantString(model);
		AcceptEntityInput(client, "SetCustomModel");

		SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);
		
		
	}
}
// public Action Dane(int client, int args)
// {
// 	// TF2_SetPlayerClass(client, TFClass_Engineer);
//     // TF2_RegeneratePlayer(client);
// 	MakeUncleDane(client);
// }

MakeUncleDane(client)
{
	
	TF2_SetPlayerClass(client, TFClass_Engineer);
	TF2_RegeneratePlayer(client);

	EngieTeam = GetClientTeam(client);

	new ragdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
	if (ragdoll > MaxClients && IsValidEntity(ragdoll)) AcceptEntityInput(ragdoll, "Kill");
	decl String:weaponname[32];
	GetClientWeapon(client, weaponname, sizeof(weaponname));
	if (strcmp(weaponname, "tf_weapon_", false) == 2)
	{
		SetEntProp(GetPlayerWeaponSlot(client, 2), Prop_Send, "m_iWeaponState", 2);
		TF2_RemoveCondition(client, TFCond_Slowed);
	}
	CreateTimer(0.0, Timer_Switch, client);
	SetModel(client, ChangeDane);

	int iHealth = 1250;
	int MaxHealth = 125;
	int iAdditiveHP = iHealth - MaxHealth;
	float OverHealRate = 1.5;

	float OverHeal = float(MaxHealth) * OverHealRate;
	float TotalHealthOverHeal = iHealth * OverHealRate;
	float OverHealPenaltyRate = OverHeal / TotalHealthOverHeal;
	
	TF2_SetHealth(client, iHealth);
	TF2Attrib_SetByName(client, "patient overheal penalty", OverHealPenaltyRate);

	SetEntPropFloat(client, Prop_Send, "m_flModelScale", 1.65);
	SetEntProp(client, Prop_Send, "m_bIsMiniBoss", _:true);
	
	TF2Attrib_SetByName(client, "move speed penalty", 0.6);
	TF2Attrib_SetByName(client, "damage force reduction", 0.3);
	TF2Attrib_SetByName(client, "airblast vulnerability multiplier", 0.3);
float HealthPackPickUpRate =  float(MaxHealth) / float(iHealth);
TF2Attrib_SetByName(client, "health from packs decreased", HealthPackPickUpRate);
	TF2Attrib_SetByName(client, "max health additive bonus", float(iAdditiveHP));
	TF2Attrib_SetByName(client, "cancel falling damage", 1.0);
	TF2Attrib_SetByName(client, "override footstep sound set", 2.0);
	TF2Attrib_SetByName(client, "maxammo metal increased", 2.5);
	TF2Attrib_SetByName(client, "metal regen", 150.0);
	TF2Attrib_SetByName(client, "building cost reduction", 2.5);
	TF2Attrib_SetByName(client, "mod teleporter cost", 4.0);
	TF2Attrib_SetByName(client, "major increased jump height", 1.25);
	TF2Attrib_SetByName(client, "rage giving scale", 0.85);

	UpdatePlayerHitbox(client, 1.65);
	
	TF2_RemoveCondition(client, TFCond_CritOnFirstBlood);
	TF2_AddCondition(client, TFCond_SpeedBuffAlly, 0.1);
	
	PrintHintText(client, "Widowmaker deals 250 precent damage to your sentry's target\nYou build lvl 3 in one swing\nYou have teamporters");
	PrintCenterText(client, "Use !stuck if you get stuck in buildings");
	
	SetEntProp(client, Prop_Send, "m_iAmmo", 500, _, 3);

//	EmitGameSoundToAll("Announcer.MVM_Engineer_Teleporter_Activated");
//Doesn't work for whatever reason
	///EmitGameSoundToAll("Announcer.MVM_First_Engineer_Teleport_Spawned");


	int soundswitch = GetRandomInt(1, 2);
	switch(soundswitch)
	{
		case 1:
		{
			EmitSoundToAll(ENGIE_SPAWN_SOUND);
		}
		case 2:
		{
			EmitSoundToAll(ENGIE_SPAWN_SOUND2);
		}
	}


	
}

stock TF2_SetHealth(client, NewHealth)
{
	SetEntProp(client, Prop_Send, "m_iHealth", NewHealth, 1);
	SetEntProp(client, Prop_Data, "m_iHealth", NewHealth, 1);
}

public Action:Timer_Switch(Handle:timer, any:client)
{
	if (IsValidClient(client))
	GiveBigRoboDane(client);
}

// public Action:Timer_Resize(Handle:timer, any:hat)
// {
	// if (IsValidClient(client))
	// GiveBigRoboDane(client);
// }

#define THEDANGER 30420
#define GOLDDIGGER 30172
#define INSULATOR 30539

stock GiveBigRoboDane(client)
{
	if (IsValidClient(client))
	{
		RoboRemoveAllWearables(client);

		TF2_RemoveWeaponSlot(client, 0);
		TF2_RemoveWeaponSlot(client, 1);
		TF2_RemoveWeaponSlot(client, 2);

		CreateRoboWeapon(client, "tf_weapon_shotgun_primary", 527, 6, 1, 2, 0);
		CreateRoboWeapon(client, "tf_weapon_wrench", 329, 6, 1, 2, 0);


		CreateRoboHat(client, THEDANGER, 10, 6, 15132390.0, 1.0, -1.0);
		CreateRoboHat(client, GOLDDIGGER, 10, 6, 15132390.0, 1.0, -1.0);
		CreateRoboHat(client, INSULATOR, 10, 6, 15132390.0, 1.0, -1.0);

		int Weapon1 = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
		int Weapon3 = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);

		if(IsValidEntity(Weapon1))
		{
			TF2Attrib_RemoveAll(Weapon1);
			TF2Attrib_SetByName(Weapon1, "fire rate bonus", 0.7);
			TF2Attrib_SetByName(Weapon1, "damage bonus", 1.0);
			TF2Attrib_SetByName(Weapon1, "killstreak tier", 1.0);
			TF2Attrib_SetByName(Weapon1, "mod ammo per shot", 30.0);
			TF2Attrib_SetByName(Weapon1, "engineer building teleporting pickup", 10.0);
			TF2Attrib_SetByName(Weapon1, "damage bonus bullet vs sentry target", 2.5);
			
		}
		if(IsValidEntity(Weapon3))
		{
			TF2Attrib_RemoveAll(Weapon3);
			TF2Attrib_SetByName(Weapon3, "fire rate bonus", 0.85);
			TF2Attrib_SetByName(Weapon3, "damage bonus", 2.0);
			TF2Attrib_SetByName(Weapon3, "Construction rate increased", 10.0);
			TF2Attrib_SetByName(Weapon3, "killstreak tier", 1.0);
			TF2Attrib_SetByName(Weapon3, "melee range multiplier", 1.65);
			TF2Attrib_SetByName(Weapon3, "Repair rate increased", 4.0);
			TF2Attrib_SetByName(Weapon3, "dmg penalty vs buildings", 0.75);
			TF2Attrib_SetByName(Weapon3, "engineer building teleporting pickup", 10.0);
			TF2Attrib_SetByName(Weapon3, "engy building health bonus", 2.32);
			TF2Attrib_SetByName(Weapon3, "engy dispenser radius increased", 6.0);
			TF2CustAttr_SetString(Weapon3, "mod building health", "teleporter=500");
		}
		
	}
}


//TELEPORTER CODE// VERSION 1

//ConVar bEnabled, cvUber;

//float vecSpawns[2][3];	// 0 for red, 1 for blue

// public void OnPluginStart()
// {
// 	bEnabled = CreateConVar("sm_teamporter_enable", "1", "Enable the TF2 Teamporter plugin?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
// 	cvUber = CreateConVar("sm_teamporter_uber", "3.0", "Seconds to add ubercharge after teleportation. 0 to disable", FCVAR_NOTIFY, true, 0.0);
// 	CreateConVar("sm_teamporter_version", PLUGIN_VERSION, "TF2 Teamporter plugin version", FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_SPONLY | FCVAR_DONTRECORD);


	// HookEvent("teamplay_round_start", OnNeedReset);
	// HookEvent("teamplay_point_captured", OnNeedReset);
// }

// public void OnNeedReset(Event event, const char[] name, bool dontBroadcast)
// {
// 	int spawnteam, ent = -1;
// 	ArrayList redspawn = new ArrayList();
// 	ArrayList bluspawn = new ArrayList();

// 	while ((ent = FindEntityByClassname(ent, "info_player_teamspawn")) != -1)
// 	{
// 		if (GetEntProp(ent, Prop_Data, "m_bDisabled"))
// 			continue;

// 		spawnteam = GetEntProp(ent, Prop_Send, "m_iTeamNum");
// 		if (spawnteam == 2)	// Push ents to according team arraylist
// 			redspawn.Push(ent);
// 		else if (spawnteam == 3)
// 			bluspawn.Push(ent);
// 	}

// 	ent = redspawn.Get( GetRandomInt(0, redspawn.Length-1) );	// This may be an issue on custom maps with wacky spawn locations, so random one will do
// 	GetEntPropVector(ent, Prop_Send, "m_vecOrigin", vecSpawns[0]);
// 	ent = bluspawn.Get( GetRandomInt(0, bluspawn.Length-1) );
// 	GetEntPropVector(ent, Prop_Send, "m_vecOrigin", vecSpawns[1]);

// 	delete redspawn;
// 	delete bluspawn;
// }

// public Action OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
// {

// 	int client = GetClientOfUserId(event.GetInt("userid"));
// 	//PrintToChatAll("%N spawned", client);
// 	if (!IsAnyRobot(client))
// 	{
// 		return Plugin_Continue;
// 		//PrintToChatAll("%N spawned and was not a robot", client);
// 	}
	
// 	int team = GetClientTeam(client);

// 	// if (team != EngieTeam)
// 	// 	return Plugin_Continue;

// 	int ent = -1;
// 	int i = (team == 2 ? 1 : 0);
// 	float vecSpawn[3];
// 	float vecIsActuallyGoingToSpawn[3] = {-99999.0, -99999.0, -99999.0};
// 	float dist, otherdist = GetVectorDistance(vecIsActuallyGoingToSpawn, vecSpawns[i]);
// 	float vecRotation[3];

// 	while ((ent = FindEntityByClassname(ent, "obj_teleporter")) != -1)
// 	{
// 		if (GetEntProp(ent, Prop_Send, "m_iTeamNum") != team)
// 			continue;
// 		if (GetEntProp(ent, Prop_Send, "m_bBuilding"))	// If being built
// 			continue;
// 		if (GetEntProp(ent, Prop_Send, "m_bCarried"))	// If being carried
// 			continue;
// 		if (GetEntProp(ent, Prop_Send, "m_iObjectMode") != 1)	// If not exit
// 			continue;
// 		if (GetEntProp(ent, Prop_Send, "m_bHasSapper"))//has sapper
// 			continue;
// 		if (!IsValidEntity(GetEntDataEnt2(ent, FindSendPropInfo("CObjectTeleporter", "m_bMatchBuilding")+4)))	// Props to Pelipoika
// 			continue;

// 		GetEntPropVector(ent, Prop_Send, "m_vecOrigin", vecSpawn);
// 		dist = GetVectorDistance(vecSpawn, vecSpawns[i]);
// 		if (dist < otherdist)
// 		{
// 			otherdist = dist;
// 			vecIsActuallyGoingToSpawn = vecSpawn;
// 			GetEntPropVector(ent, Prop_Send, "m_angRotation", vecRotation);	// Force players to look in the direction of teleporter on spawn
// 		}
// 	}
// 	// If no teleporters found
// 	if (GetVectorDistance(vecIsActuallyGoingToSpawn, vecSpawns[i]) >= 70000){
// 		return Plugin_Continue;
// 	}	
		

// 	vecIsActuallyGoingToSpawn[2] += 15.0;	// Don't get stuck inside of teleporter
// 	//PrintToChatAll("%N was teleported", client);
// 	TeleportEntity(client, vecIsActuallyGoingToSpawn, vecRotation, NULL_VECTOR);
// 	EmitSoundToAll(TELEPORTER_SPAWN, client);

// 	float oober = 3.0;
// 	if (oober != 0.0)
// 		TF2_AddCondition(client, TFCond_Ubercharged, oober);
// 	return Plugin_Continue;
// }

// public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
// {
// 	if(IsValidClient(client) && IsRobot(client, ROBOT_NAME) && buttons & IN_DUCK) 
// 	{
// 		g_ReadyToTeamPort[client] = true;
// 		PrintToChatAll("Setting teamporter true for %N", client);
// 	}else
// 	{
// 		g_ReadyToTeamPort[client] = false;
// 		//PrintToChatAll("Setting teamporter false for %N", client);
// 	}
// }

//TELEPORTER CODE// VERSION 2
/* public Action Particle_Teleporter(Handle Timer)
{
	
	int client; 
	for(int i = 1; i <= MaxClients; i++)
    {
		if(IsRobot(i, ROBOT_NAME))
		{
		client = i;
		EngieTeam = GetClientTeam(i);
		//PrintToChatAll("%N is dane bot", i);
		}
	}

	if(IsRobot(client, ROBOT_NAME))
	{
		CreateTimer(3.0, Particle_Teleporter);
		int TeleporterExit = -1;	
		if((TeleporterExit = FindEntityByClassname(TeleporterExit,"obj_teleporter")) != -1)
		{
			if(GetEntProp(TeleporterExit, Prop_Send, "m_iTeamNum") == EngieTeam && GetEntPropEnt(TeleporterExit, Prop_Send, "m_hBuilder") == engieid)
			{
				char modelname[128];
				GetEntPropString(TeleporterExit, Prop_Data, "m_ModelName", modelname, 128);
				if(StrContains(modelname, "light") != -1)
				{
					float position[3];
					GetEntPropVector(TeleporterExit,Prop_Send, "m_vecOrigin",position);
					int attach = CreateEntityByName("trigger_push");
					CreateTimer(3.0, DeleteTrigger, attach);
					TeleportEntity(attach, position, NULL_VECTOR, NULL_VECTOR);
					AttachParticle(attach,"teleporter_mvm_bot_persist");
					if (EngieTeam == 3)
					{
						AttachParticle(attach,"teleporter_blue_floorglow");
						AttachParticle(attach,"teleporter_blue_entrance_disc");
						AttachParticle(attach,"teleporter_blue_exit_level3");
						AttachParticle(attach,"teleporter_blue_charged_wisps");
						AttachParticle(attach,"teleporter_blue_charged");
					}
					else if (EngieTeam == 2)
					{
						AttachParticle(attach,"teleporter_red_floorglow");
						AttachParticle(attach,"teleporter_red_entrance_disc");
						AttachParticle(attach,"teleporter_red_exit_level3");
						AttachParticle(attach,"teleporter_red_charged_wisps");
						AttachParticle(attach,"teleporter_red_charged");
					}
					if(!AnnouncerQuiet)
					{
						int soundswitch = GetRandomInt(1, 5);
						switch(soundswitch)
						{
							case 1:
							{
								EmitSoundToAll(TELEPORTER_ACTIVATE1);
							}
							case 2:
							{
								EmitSoundToAll(TELEPORTER_ACTIVATE2);
							}
							case 3:
							{
								EmitSoundToAll(TELEPORTER_ACTIVATE3);
							}
							case 4:
							{
								EmitSoundToAll(TELEPORTER_ACTIVATE4);
							}
							case 5:
							{
								EmitSoundToAll(TELEPORTER_ACTIVATE5);
							}
						}
						AnnouncerQuiet = true;
					}
				}
			}
		}
	}
} */

/* stock AttachParticle(entity, char[] particleType, float offset[]={0.0,0.0,0.0}, bool attach=true)
{
	int particle = CreateEntityByName("info_particle_system");

	char targetName[128];
	float position[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", position);
	position[0]+=offset[0];
	position[1]+=offset[1];
	position[2]+=offset[2];
	TeleportEntity(particle, position, NULL_VECTOR, NULL_VECTOR);

	Format(targetName, sizeof(targetName), "target%i", entity);
	DispatchKeyValue(entity, "targetname", targetName);

	DispatchKeyValue(particle, "targetname", "tf2particle");
	DispatchKeyValue(particle, "parentname", targetName);
	DispatchKeyValue(particle, "effect_name", particleType);
	DispatchSpawn(particle);
	SetVariantString(targetName);
	if(attach)
	{
		AcceptEntityInput(particle, "SetParent", particle, particle, 0);
		SetEntPropEnt(particle, Prop_Send, "m_hOwnerEntity", entity);
	}
	ActivateEntity(particle);
	AcceptEntityInput(particle, "start");
	CreateTimer(3.0, DeleteParticle, particle);
	return particle;
} */
/* public Action DeleteParticle(Handle timer, any Ent)
{
	if (!IsValidEntity(Ent)) return;
	char cls[25];
	GetEdictClassname(Ent, cls, sizeof(cls));
	if (StrEqual(cls, "info_particle_system", false)) AcceptEntityInput(Ent, "Kill");
	return;
} */

stock TE_Particle(char[] Name, float origin[3] = NULL_VECTOR, float start[3] = NULL_VECTOR, float angles[3] = NULL_VECTOR, entindex=-1, attachtype=-1, attachpoint=-1, bool resetParticles=true, customcolors = 0, float color1[3] = NULL_VECTOR, float color2[3] = NULL_VECTOR, controlpoint = -1, controlpointattachment = -1, float controlpointoffset[3] = NULL_VECTOR)
{
    // find string table
    int tblidx = FindStringTable("ParticleEffectNames");
    if (tblidx == INVALID_STRING_TABLE) 
    {
        LogError("Could not find string table: ParticleEffectNames");
        return;
    }
    float delay = 3.0;
    // find particle index
    char tmp[256];
    int count = GetStringTableNumStrings(tblidx);
    int stridx = INVALID_STRING_INDEX;
    
    for (int i = 0; i < count; i++)
    {
        ReadStringTable(tblidx, i, tmp, sizeof(tmp));
        if (StrEqual(tmp, Name, false))
        {
            stridx = i;
            break;
        }
    }
    if (stridx == INVALID_STRING_INDEX)
    {
        LogError("Could not find particle: %s", Name);
        return;
    }

    TE_Start("TFParticleEffect");
    TE_WriteFloat("m_vecOrigin[0]", origin[0]);
    TE_WriteFloat("m_vecOrigin[1]", origin[1]);
    TE_WriteFloat("m_vecOrigin[2]", origin[2]);
    TE_WriteFloat("m_vecStart[0]", start[0]);
    TE_WriteFloat("m_vecStart[1]", start[1]);
    TE_WriteFloat("m_vecStart[2]", start[2]);
    TE_WriteVector("m_vecAngles", angles);
    TE_WriteNum("m_iParticleSystemIndex", stridx);
    if (entindex !=- 1)
    {
        TE_WriteNum("entindex", entindex);
    }
    if (attachtype != -1)
    {
        TE_WriteNum("m_iAttachType", attachtype);
    }
    if (attachpoint != -1)
    {
        TE_WriteNum("m_iAttachmentPointIndex", attachpoint);
    }
    TE_WriteNum("m_bResetParticles", resetParticles ? 1 : 0);    
    
    if(customcolors)
    {
        TE_WriteNum("m_bCustomColors", customcolors);
        TE_WriteVector("m_CustomColors.m_vecColor1", color1);
        if(customcolors == 2)
        {
            TE_WriteVector("m_CustomColors.m_vecColor2", color2);
        }
    }
    if(controlpoint != -1)
    {
        TE_WriteNum("m_bControlPoint1", controlpoint);
        if(controlpointattachment != -1)
        {
            TE_WriteNum("m_ControlPoint1.m_eParticleAttachment", controlpointattachment);
            TE_WriteFloat("m_ControlPoint1.m_vecOffset[0]", controlpointoffset[0]);
            TE_WriteFloat("m_ControlPoint1.m_vecOffset[1]", controlpointoffset[1]);
            TE_WriteFloat("m_ControlPoint1.m_vecOffset[2]", controlpointoffset[2]);
        }
    }    
    TE_SendToAll(delay);
}

stock DestroyBuildings(int client)
{
	decl String:strObjects[3][] = {"obj_sentrygun","obj_dispenser","obj_teleporter"};
	
	int owner = -1; 
	
	for(int o = 0; o < sizeof(strObjects); o++)
	{
		int iEnt = -1;
		while((iEnt = FindEntityByClassname(iEnt, strObjects[o])) != -1)
			if(IsValidEntity(iEnt) && GetEntProp( iEnt, Prop_Send, "m_iTeamNum" ) == EngieTeam)
			{
				//owner = GetEntPropEnt(iEnt, Prop_Send, "m_hOwnerEntity");
				owner = GetEntPropEnt(iEnt, Prop_Send, "m_hBuilder");				
				
				if (client == -1 || owner == client)
				{	
					//PrintToServer("[REX] Destroyed object %i, owner - %N", iEnt, owner);
					SetEntityHealth(iEnt, 100);
					SetVariantInt(1488);
					AcceptEntityInput(iEnt, "RemoveHealth");
				}
			}
	}
}
public Action DeleteTrigger(Handle timer, any Ent)
{
	if (!IsValidEntity(Ent)) return;
	char cls[25];
	GetEdictClassname(Ent, cls, sizeof(cls));
	if (StrEqual(cls, "trigger_push", false)) AcceptEntityInput(Ent, "Kill");
	return;
}

// public Action CommandListener_Build(client, const char[] command, argc)
// {
// 	char sObjectMode[256], sObjectType[256];
// 	GetCmdArg(1, sObjectType, sizeof(sObjectType));
// 	GetCmdArg(2, sObjectMode, sizeof(sObjectMode));
// 	int iObjectMode = StringToInt(sObjectMode);
// 	int iObjectType = StringToInt(sObjectType);
// 	//char sClassName[32];
// 	// PrintToChat(client,"Object type: %i", iObjectType);
// 	// PrintToChat(client,"Object mode: %i", iObjectMode);
// 	// for(int i = MaxClients + 1; i < g_iMaxEntities; i++)
// 	// {
// 	// 	PrintToChatAll("Client: %i", i);
// 	// 	if(!IsValidEntity(i)) continue;
		
// 	// 	GetEntityNetClass(i, sClassName, sizeof(sClassName));
// 		if(IsRobot(client, ROBOT_NAME) && iObjectType == TF_OBJECT_TELEPORTER && iObjectMode == TF_TELEPORTER_ENTR)
// 		{
// 			PrintCenterText(client,"You can't build enterance, you can only build a exit teleporter!");
// 			PrintToChat(client,"You can't build enterance , you can only build a exit teleporter!");
// 			return Plugin_Handled;
// 		}
// 	// }
// 	return Plugin_Continue;
// }

stock void ResetSkin(int iEnt)
{
	if (IsValidEntity(iEnt) && HasEntProp(iEnt, Prop_Send, "m_nSkin"))
	{
		int iTeam = GetEntProp(iEnt, Prop_Data, "m_iTeamNum");
		SetEntProp(iEnt, Prop_Send, "m_nSkin", iTeam - 2);
	}
}

public void OnGameFrame()
{
	// if (cvarPads[PadsEnabled].IntValue == EngiPads_Disabled)
	// 	return;
	//PrintToChatAll("THINKING1!");
	int i = -1;
	while ((i = FindEntityByClassname2(i, "obj_teleporter")) != -1)
	{
		if (IsValidEntity(i))
		{
			if (g_iPadType[i] == PadType_Boss){
				//PrintToChatAll("THINKING!");
				OnPadThink(i);
			}
				
		}
	}
}

void OnPadThink(int iPad)
{
	float flConstructed = GetEntPropFloat(iPad, Prop_Send, "m_flPercentageConstructed");
	bool bBuilding = view_as<bool>(GetEntProp(iPad, Prop_Send, "m_bBuilding"));
	bool bCarried = view_as<bool>(GetEntProp(iPad, Prop_Send, "m_bCarried"));
	bool bPlacing = view_as<bool>(GetEntProp(iPad, Prop_Send, "m_bPlacing"));
	bool bDisabled = view_as<bool>(GetEntProp(iPad, Prop_Send, "m_bDisabled"));
	bool bSapped = view_as<bool>(GetEntProp(iPad, Prop_Send, "m_bHasSapper"));
	
	//PrintToChatAll("Teleporter state: %i", TF2_GetBuildingState(iPad));

	if (bCarried || bPlacing || bDisabled)
	{
	if (bBuilding && flConstructed < 1.0)
	{
		if (TF2_GetBuildingState(iPad) != TELEPORTER_STATE_BUILDING)
			TF2_SetBuildingState(iPad, TELEPORTER_STATE_BUILDING);
		if (GetEntProp(iPad, Prop_Send, "m_iUpgradeLevel") != 3 && !bSapped)
		{
			SetEntProp(iPad, Prop_Send, "m_iHighestUpgradeLevel", 3);
			SetEntProp(iPad, Prop_Send, "m_iUpgradeLevel", 3);
		}
		return;
	}
	}
	//int iObjParti = EntRefToEntIndex(g_iObjectParticle[iPad]);
	
	if (bSapped)
	{
		if (GetEntProp(iPad, Prop_Send, "m_iUpgradeLevel") > 1)
		{
			SetEntProp(iPad, Prop_Send, "m_iUpgradeLevel", 1);	//Prevents the Red-Tape Recorder having to downgrade Pads before deconstructing.
			SetEntProp(iPad, Prop_Send, "m_iHighestUpgradeLevel", 1);
			TF2_SetBuildingState(iPad, TELEPORTER_STATE_IDLE);
			
		}
		//	PrintToChatAll("Sapped");
		return;
	}
	
		

	if (TF2_GetBuildingState(iPad) > TELEPORTER_STATE_BUILDING && TF2_GetBuildingState(iPad) < TELEPORTER_STATE_UPGRADING)
	{
		if (TF2_GetBuildingState(iPad) != TELEPORTER_STATE_READY)/*  && GetEntPropFloat(iPad, Prop_Send, "m_flRechargeTime") <= GetGameTime() */
		{
			//AcceptEntityInput(iPad, "Start");
			TF2_SetBuildingState(iPad, TELEPORTER_STATE_READY);	//Make sure the Pad always re-activates when it's supposed to.
			
		//	AcceptEntityInput(iObjParti, "Start");
			// #if defined DEBUG
			// PrintToChatAll("%i Ready!", iPad);
			// #endif
		}
		// if (TF2_GetBuildingState(iPad) == TELEPORTER_STATE_READY && IsValidEntity(iObjParti) && !bSapped)
		// {
		// 	AcceptEntityInput(iObjParti, "Start");
		// }
			
	}
	SetEntPropFloat(iPad, Prop_Send, "m_flCurrentRechargeDuration", 1.0);
	SetEntPropFloat(iPad, Prop_Send, "m_flYawToExit", GetEntPropFloat(iPad, Prop_Send, "m_flYawToExit") + 10.0);	//Make the arrow spin for fun, and to indicate its not a Teleporter (but mostly for fun)
	if (GetEntPropFloat(iPad, Prop_Send, "m_flYawToExit") > 360.0){
		SetEntPropFloat(iPad, Prop_Send, "m_flYawToExit", 0.0);
	}

		
}
stock int FindEntityByClassname2(int startEnt, char[] classname)
{
	/* If startEnt isn't valid shifting it back to the nearest valid one */
	while (startEnt > -1 && !IsValidEntity(startEnt)) startEnt--;
	return FindEntityByClassname(startEnt, classname);
}

stock int TF2_GetBuildingState(int iBuilding)
{
	int iState = -1;
	
	if (IsValidEntity(iBuilding))
	{
		iState = GetEntProp(iBuilding, Prop_Send, "m_iState");
	}
	
	return iState;
}

stock void TF2_SetBuildingState(int iBuilding, int iState = 0)
{	
	if (IsValidEntity(iBuilding))
	{
		SetEntProp(iBuilding, Prop_Send, "m_iState", iState);
	//	PrintToChatAll("Setting state to %i", iState);
	}
}

// stock void TF2_DisableObject(int iObj)
// {
// 	if (IsValidEntity(iObj))
// 	{
// 		AcceptEntityInput(iObj, "Disable");
// 	}
// }

// stock void TF2_EnableObject(int iObj)
// {
// 	if (IsValidEntity(iObj))
// 	{
// 		AcceptEntityInput(iObj, "Enable");
// 	}
// }