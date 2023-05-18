#pragma semicolon 1
#include <sourcemod>
#include <tf2_stocks>
#include <tf2attributes>
#include <sm_logger>
#include <berobot_constants>
#include <berobot>

#define PLUGIN_VERSION "1.0"
#define ROBOT_NAME	"Mecha Face"
#define ROBOT_CLASS "Scout"
#define ROBOT_ROLE "Damage"
#define ROBOT_SUBCLASS "Hitscan"
#define ROBOT_DESCRIPTION "Baby Face's Blaster"
#define ROBOT_TIPS "Move speed increases from kills\nFaster fire rate"
#define ROBOT_ON_DEATH "Mecha Face's speed increases on kill\nCounter him with sentries"

#define GSCOUT		"models/bots/scout_boss/bot_scout_boss.mdl"
#define SPAWN	"#mvm/giant_heavy/giant_heavy_entrance.wav"
#define DEATH	"mvm/sentrybuster/mvm_sentrybuster_explode.wav"
#define LOOP	"mvm/giant_scout/giant_scout_loop.wav"

#define LEFTFOOT        ")mvm/giant_scout/giant_scout_step_01.wav"
#define LEFTFOOT1       ")mvm/giant_scout/giant_scout_step_03.wav"
#define RIGHTFOOT       ")mvm/giant_scout/giant_scout_step_02.wav"
#define RIGHTFOOT1      ")mvm/giant_scout/giant_scout_step_04.wav"



public Plugin:myinfo = 
{
	name = "[TF2] Be the Giant Mecha Scout",
	author = "Erofix using the code from: Pelipoika, PC Gamer, Jaster and StormishJustice",
	description = "Play as the Giant Scout",
	version = PLUGIN_VERSION,
	url = "www.sourcemod.com"
}

char LOG_TAGS[][] = {"VERBOSE", "INFO", "ERROR"};
enum(<<= 1)
{
    SML_VERBOSE = 1,
    SML_INFO,
    SML_ERROR,
}

public OnPluginStart()
{
	SMLoggerInit(LOG_TAGS, sizeof(LOG_TAGS), SML_ERROR, SML_FILE);

	LoadTranslations("common.phrases");
	HookEvent("player_death", Event_Death, EventHookMode_Post);
	AddNormalSoundHook(BossScout);


	RobotDefinition robot;
	robot.name = ROBOT_NAME;
	robot.role = ROBOT_ROLE;
	robot.class = ROBOT_CLASS;
	robot.subclass = ROBOT_SUBCLASS;
	robot.shortDescription = ROBOT_DESCRIPTION;
	robot.sounds.spawn = SPAWN;
	robot.sounds.loop = LOOP;
	robot.sounds.death = DEATH;
	AddRobot(robot, MakeGiantscout, PLUGIN_VERSION, null, 2);
}

public void OnPluginEnd()
{
	RemoveRobot(ROBOT_NAME);
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
//	CreateNative("BeGiantPyro_MakeGiantscout", Native_SetGiantPyro);
//	CreateNative("BeGiantPyro_IsGiantPyro", Native_IsGiantPyro);
	return APLRes_Success;
}

public OnMapStart()
{
	




	
	//PrecacheSound(SOUND_GUNFIRE);
	//PrecacheSound(SOUND_WINDUP);
	
}

public Action:SetModel(client, const String:model[])
{
	if (IsValidClient(client) && IsPlayerAlive(client))
	{
		SetVariantString(model);
		AcceptEntityInput(client, "SetCustomModel");

		SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);
	}
}

public Action:BossScout(clients[64], &numClients, String:sample[PLATFORM_MAX_PATH], &entity, &channel, &Float:volume, &level, &pitch, &flags)
{
	if (!IsValidClient(entity)) return Plugin_Continue;
	if (!IsRobot(entity, ROBOT_NAME)) return Plugin_Continue;

	if (strncmp(sample, "player/footsteps/", 17, false) == 0)
	{
	if (StrContains(sample, "1.wav", false) != -1)
	{
	Format(sample, sizeof(sample), "mvm/giant_scout/giant_scout_step_01.wav");
	EmitSoundToAll(sample, entity);
	}
	else if (StrContains(sample, "3.wav", false) != -1)
	{
	Format(sample, sizeof(sample), "mvm/giant_scout/giant_scout_step_03.wav");
	EmitSoundToAll(sample, entity);
	}
	else if (StrContains(sample, "2.wav", false) != -1)
	{
	Format(sample, sizeof(sample), "mvm/giant_scout/giant_scout_step_02.wav");
	EmitSoundToAll(sample, entity);
	}
	else if (StrContains(sample, "4.wav", false) != -1)
	{
	Format(sample, sizeof(sample), "mvm/giant_scout/giant_scout_step_04.wav");
	EmitSoundToAll(sample, entity);
	}
	return Plugin_Changed;
	}
	if (volume == 0.0 || volume == 0.9997) return Plugin_Continue;

	return Plugin_Continue;
	}

#define TheFederalCasemaker 30119
#define TheTicketBoy 30376
#define BrooklynBooties 30540

MakeGiantscout(client)
{
	SMLogTag(SML_VERBOSE, "Createing ScoutName");
	TF2_SetPlayerClass(client, TFClass_Scout);
	TF2_RegeneratePlayer(client);

	new ragdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
	if (ragdoll > MaxClients && IsValidEntity(ragdoll)) AcceptEntityInput(ragdoll, "Kill");
	decl String:weaponname[32];
	GetClientWeapon(client, weaponname, sizeof(weaponname));
	if (strcmp(weaponname, "tf_weapon_", false) == 0) 
	{
		SetEntProp(GetPlayerWeaponSlot(client, 0), Prop_Send, "m_iWeaponState", 0);
		TF2_RemoveCondition(client, TFCond_Slowed);
	}
	CreateTimer(0.0, Timer_Switch, client);
	SetModel(client, GSCOUT);
	
	int iHealth = 1250;
		
	int MaxHealth = 125;
	//PrintToChatAll("MaxHealth %i", MaxHealth);
	
	int iAdditiveHP = iHealth - MaxHealth;
	
	TF2_SetHealth(client, iHealth);
	// PrintToChatAll("iHealth %i", iHealth);
	
	// PrintToChatAll("iAdditiveHP %i", iAdditiveHP);
	
	
	SetEntPropFloat(client, Prop_Send, "m_flModelScale", 1.75);
	SetEntProp(client, Prop_Send, "m_bIsMiniBoss", true);
	TF2Attrib_SetByName(client, "max health additive bonus", float(iAdditiveHP));
	TF2Attrib_SetByName(client, "ammo regen", 100.0);
	// TF2Attrib_SetByName(client, "move speed penalty", 0.7);
	TF2Attrib_SetByName(client, "damage force reduction", 1.5);
	TF2Attrib_SetByName(client, "airblast vulnerability multiplier", 1.5);
	TF2Attrib_SetByName(client, "airblast vertical vulnerability multiplier", 1.0);
	float HealthPackPickUpRate =  float(MaxHealth) / float(iHealth);
	TF2Attrib_SetByName(client, "health from packs decreased", HealthPackPickUpRate);
	TF2Attrib_SetByName(client, "cancel falling damage", 1.0);
	TF2Attrib_SetByName(client, "patient overheal penalty", 0.15);
	
	
	TF2Attrib_SetByName(client, "increased jump height", 1.25);
	TF2Attrib_SetByName(client, "rage giving scale", 0.85);
	TF2Attrib_SetByName(client, "self dmg push force increased", 3.0);
	
	UpdatePlayerHitbox(client, 1.75);
	
	TF2_RemoveCondition(client, TFCond_CritOnFirstBlood);
	TF2_AddCondition(client, TFCond_SpeedBuffAlly, 0.1);
	
	PrintHintText(client, ROBOT_TIPS);
	// SetEntProp(client, Prop_Send, "m_bForcedSkin", 1);
	// SetEntProp(client, Prop_Send, "m_nForcedSkin", 0);

}

stock TF2_SetHealth(client, NewHealth)
{
	SetEntProp(client, Prop_Send, "m_iHealth", NewHealth, 1);
	SetEntProp(client, Prop_Data, "m_iHealth", NewHealth, 1);
	SetEntProp(client, Prop_Data, "m_iMaxHealth", NewHealth, 1);
}

public Action:Timer_Switch(Handle:timer, any:client)
{
	if (IsValidClient(client))
		GiveGiantPyro(client);
}

stock GiveGiantPyro(client)
{
	if (IsValidClient(client))
	{
		RoboRemoveAllWearables(client);

		TF2_RemoveWeaponSlot(client, 0);
		TF2_RemoveWeaponSlot(client, 1);
		TF2_RemoveWeaponSlot(client, 2);
                
		TFTeam iTeam = view_as<TFTeam>(GetEntProp(client, Prop_Send, "m_iTeamNum"));
		float TeamPaint = 0.0;
		
		if (iTeam == TFTeam_Blue){
				TeamPaint = 3686984.0;
				
		}
		if (iTeam == TFTeam_Red){
				
				TeamPaint = 4732984.0;
		}

		CreateRoboWeapon(client, "tf_weapon_pep_brawler_blaster", 772, 6, 1, 1, 0);
                
		CreateRoboHat(client, TheFederalCasemaker, 10, 6, TeamPaint, 0.85, -1.0);
		CreateRoboHat(client, TheTicketBoy, 10, 6, 1315860.0, 1.0, -1.0);
		CreateRoboHat(client, BrooklynBooties, 10, 6, 1315860.0, 1.0, -1.0);

		int Weapon1 = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);

		if(IsValidEntity(Weapon1))
		{
			TF2Attrib_RemoveAll(Weapon1);
                        
			// TF2Attrib_SetByName(Weapon1, "weapon spread bonus", 0.35);
			TF2Attrib_SetByName(Weapon1, "dmg penalty vs buildings", 0.35);
			TF2Attrib_SetByName(Weapon1, "fire rate penalty", 0.75);
			TF2Attrib_SetByName(Weapon1, "killstreak tier", 1.0);
			// TF2Attrib_SetByName(Weapon1, "Reload time increased", 1.1);
			TF2Attrib_SetByName(Weapon1, "hype resets on jump", 0.0);
			TF2Attrib_SetByName(Weapon1, "lose hype on take damage", 0.0);
			TF2Attrib_SetByName(Weapon1, "boost on damage", 0.0);
			
			
			TF2Attrib_SetByName(Weapon1, "dmg penalty vs players", 1.25);
                        
		}
	}
}
 
public Native_SetGiantPyro(Handle:plugin, args)
	MakeGiantscout(GetNativeCell(1));

public Event_Death(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));

	if (!IsAnyRobot(victim) && IsRobot(attacker, ROBOT_NAME))
	{
		int Weapon1 = GetPlayerWeaponSlot(attacker, TFWeaponSlot_Primary);

		if(Weapon1 != -1)
		{
			float Hypemeter = GetEntPropFloat(attacker, Prop_Send, "m_flHypeMeter");
			SetEntPropFloat(attacker, Prop_Send, "m_flHypeMeter", Hypemeter+10.0);

			float Speed = GetEntPropFloat(attacker, Prop_Send, "m_flMaxspeed");
			if (Speed*1.05 >= 520.0){

				SetEntPropFloat(attacker, Prop_Send, "m_flMaxspeed", 520.0);
			}else
			{
				SetEntPropFloat(attacker, Prop_Send, "m_flMaxspeed", Speed+26.8);
			}
			
			// PrintToChatAll("Speed set to %f", Speed+26.8);
		}
	}

}
