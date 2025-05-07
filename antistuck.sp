#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <pause>

float Ground_Velocity[3] = {0.0, 0.0, 0.0};
float fDownToFloor[3] = {90.0, 0.0, 0.0};
float fAbleToMove[MAXPLAYERS + 1];
float fNextTeleport[MAXPLAYERS + 1];
float fNow;
bool bGlobalAllowedTeleporting = true;

bool bPauseAvailable;

public void OnPluginStart() {
	CreateTimer(0.1, Teleport_Callback, 0, TIMER_REPEAT);
	HookEvent("ability_use", Event_AbilityUse);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("round_start", Event_RoundStart);
}

public void OnAllPluginsLoaded() {
    bPauseAvailable = LibraryExists("pause");
}

public void OnLibraryRemoved(const char[] sPluginName) {
	if (strcmp(sPluginName, "pause") == 0) {
		bPauseAvailable = false;
	}
}

public void OnLibraryAdded(const char[] sPluginName) {
	if (strcmp(sPluginName, "pause") == 0) {
		bPauseAvailable = true;
	}
}

public void Event_RoundEnd(Handle event, const char[] name, bool dontBroadcast) {
	bGlobalAllowedTeleporting = false;
}

public void Event_RoundStart(Handle event, const char[] name, bool dontBroadcast) {
	CreateTimer(5.0, RoundStart_Timer);
}

public Action RoundStart_Timer(Handle timer) {
	bGlobalAllowedTeleporting = true;
	return Plugin_Handled;
}

public void Event_AbilityUse(Handle event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client > 0 && IsClientInGame(client) && GetClientTeam(client) > 0) {
		char sAbility[128];
		GetEventString(event, "ability", sAbility, sizeof(sAbility));
		if (StrEqual(sAbility, "ability_vomit")) {
			fAbleToMove[client] = GetEngineTime() + 1.5;
		} else if (StrEqual(sAbility, "ability_throw")) {
			fAbleToMove[client] = GetEngineTime() + 3.5;
		} else if (StrEqual(sAbility, "ability_toungue")) {
			fAbleToMove[client] = GetEngineTime() + 1.0;
		} else if (StrEqual(sAbility, "ability_spit")) {
			fAbleToMove[client] = GetEngineTime() + 1.5;
		}
	}
}

public Action Teleport_Callback(Handle timer, any sheo) {
	if (bGlobalAllowedTeleporting && !(bPauseAvailable && IsInPause())) {
		for (int i = 1; i <= MaxClients; i++) {
			if (IsClientInGame(i)) {
				int iTeam = GetClientTeam(i);
				int iStuckEngine = GetPlayerStuckEngine(i);
				if ((iTeam == 2 && iStuckEngine > 0) || (iTeam == 3 && iStuckEngine > 500)) {
					int iMask = iTeam == 2 ? MASK_PLAYERSOLID : MASK_NPCSOLID;
					if (IsEntityStuck(i, iMask)) {
						if (IsSafeToTeleport(i)) {
							float fDistance = FixPlayerPosition(i);
							if (fDistance >= 0.0) {
								PrintToChatAll("Player %N found stuck, teleported him to a valid position (%d)", i, RoundToNearest(fDistance));
							} else {
								PrintToChatAll("Player %N found stuck, couldn't teleport him to a valid position", i);
								fNextTeleport[i] = GetEngineTime() + 10.0; //don't try too often
							}
						}
					}
				}
			}
		}
	}
	return Plugin_Handled;
}



float FixPlayerPosition(int iClient) {
	float fMaxTeleportRadius = 100.0;
	int iMask = GetClientTeam(iClient) == 2 ? MASK_PLAYERSOLID : MASK_NPCSOLID;
	for (float fRadius = 0.0; fRadius <= fMaxTeleportRadius; fRadius = fRadius + 2.0) {
		if (TryFixPosition(iClient, iMask, fRadius)) {
			return fRadius;
		}
	}
	return -1.0;
}

bool TryFixPosition(int iClient, int iMask, float Radius) {
	float vecPosition[3];
	float vecOrigin[3];
	float vecAngle[3];
	GetClientAbsOrigin(iClient, vecOrigin);
	GetClientEyeAngles(iClient, vecAngle);
	float PitchAngle = -90.0;
	while (PitchAngle <= 90.0) {
		float YawAngle = -180.0;
		while (YawAngle < 180.0) {
			vecPosition[0] = vecOrigin[0] + Radius * Cosine(DegreeToRadian(YawAngle)) * Cosine(DegreeToRadian(PitchAngle));
			vecPosition[1] = vecOrigin[1] + Radius * Sine(DegreeToRadian(YawAngle)) * Cosine(DegreeToRadian(PitchAngle));
			vecPosition[2] = vecOrigin[2] + Radius * Sine(DegreeToRadian(PitchAngle));
			
			TeleportEntity(iClient, vecPosition, vecAngle, Ground_Velocity);
			if (!IsEntityStuck(iClient, iMask) && GetDistanceToFloor(iClient, iMask) <= 100.0) {
				return true;
			}
			YawAngle += 10.0;
		}
		PitchAngle += 10.0;
	}
	TeleportEntity(iClient, vecOrigin, vecAngle, Ground_Velocity);
	return false;
}

float DegreeToRadian(float angle) {
	return angle * FLOAT_PI / 180.0;
}

bool IsEntityStuck(int iEnt, int iMask) {
	float vecMin[3], vecMax[3], vecOrigin[3];
	GetEntPropVector(iEnt, Prop_Send, "m_vecMins", vecMin);
	GetEntPropVector(iEnt, Prop_Send, "m_vecMaxs", vecMax);
	GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", vecOrigin);
	Handle hTrace = TR_TraceHullFilterEx(vecOrigin, vecOrigin, vecMin, vecMax, iMask, TraceEntityFilterSolid);
	bool bTrue = TR_DidHit(hTrace);
	CloseHandle(hTrace);
	return bTrue;
}

int GetPlayerStuckEngine(int client) {
	return GetEntProp(client, Prop_Data, "m_StuckLast");
}

float GetDistanceToFloor(int client, int iMask) {
	float vOrigin[3];
	GetClientEyePosition(client, vOrigin);
	Handle hTrace = TR_TraceRayFilterEx(vOrigin, fDownToFloor, iMask, RayType_Infinite, TraceEntityFilterSolid);
	if (TR_DidHit(hTrace)) {
		float vFloorPoint[3];
		TR_GetEndPosition(vFloorPoint, hTrace);
		CloseHandle(hTrace);
		return (vOrigin[2] - vFloorPoint[2]);
	}
	CloseHandle(hTrace);
	return 999999.0;
}

public bool TraceEntityFilterSolid(int entity, int contentsMask) {
	if (entity > 0 && entity <= MaxClients) {
		return false;
	}
	int iCollisionType;
	if (entity >= 0 && IsValidEdict(entity) && IsValidEntity(entity)) {
		iCollisionType = GetEntProp(entity, Prop_Send, "m_CollisionGroup");
	}
	if (iCollisionType == 1 || iCollisionType == 11 || iCollisionType == 5) {
		return false;
	}
	return true;
}

bool IsSafeToTeleport(int client) {
	fNow = GetEngineTime();
	if (!IsPlayerAlive(client)) {
		return false;
	} else if (GetEntityMoveType(client) == MOVETYPE_LADDER) {
		return false;
	} else if (GetEntProp(client, Prop_Send, "m_jockeyAttacker") > 0) {
		return false;
	} else if (GetEntProp(client, Prop_Send, "m_jockeyVictim") > 0) {
		return false;
	} else if (GetEntProp(client, Prop_Send, "m_pounceAttacker") > 0) {
		return false;
	} else if (GetEntProp(client, Prop_Send, "m_pounceVictim") > 0) {
		return false;
	} else if (GetEntProp(client, Prop_Send, "m_carryAttacker") > 0) {
		return false;
	} else if (GetEntProp(client, Prop_Send, "m_carryVictim") > 0) {
		return false;
	} else if (GetEntProp(client, Prop_Send, "m_pummelAttacker") > 0) {
		return false;
	} else if (GetEntProp(client, Prop_Send, "m_pummelVictim") > 0) {
		return false;
	} else if (GetEntProp(client, Prop_Send, "m_isHangingFromLedge") == 1) {
		return false;
	} else if (GetEntProp(client, Prop_Send, "m_isIncapacitated") == 1) {
		return false;
	} else if (fAbleToMove[client] != 0.0 && fNow < fAbleToMove[client]) {
		return false;
	} else if (fNextTeleport[client] != 0.0 && fNow < fNextTeleport[client]) {
		return false;
	} else {
		return true;
	}
}
