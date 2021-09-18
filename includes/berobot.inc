#if defined _berobot_included
 #endinput
#endif
#define _berobot_included "0.1"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

const int NAMELENGTH = 128;
typedef RobotCallback = function void (int client, char target[32]);


native void AddRobot(char name[NAMELENGTH], char class[9], RobotCallback callback);
native void RemoveRobot(char name[NAMELENGTH]);

native ArrayList GetRobotNames();
native void GetRobotClass(char name[NAMELENGTH], char class[9]);

native void CreateRobot(char[] name, int client, char target[32]);