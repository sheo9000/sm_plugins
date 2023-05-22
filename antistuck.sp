#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <pause>

float Ground_Velocity[3] = {0.0, 0.0, 0.0};
float fDownToFloor[3] = {90.0, 0.0, 0.0};
float fAbleToMove[MAXPLAYERS + 1];
float fNow;
float fMaxTeleportRadius = 200.0;
bool bGlobalAllowedTeleporting = true;
float fTickrate;
float fMoveCheck;

bool bPauseAvailable;

public void OnPluginStart() {
	CreateTimer(1.0, Teleport_Callback, 0, TIMER_REPEAT);
	HookEvent("ability_use", Event_AbilityUse);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("round_start", Event_RoundStart);
	fTickrate = 1.0 / GetTickInterval();
	if (fTickrate >= 50) {
		fMoveCheck = 15.0;
	} else {
		fMoveCheck = 20.0;
	}
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
			if (IsClientInGame(i) && GetClientTeam(i) > 1 && IsSafeToTeleport(i)) {
				if (IsEntityStuck(i, GetClientTeam(i) == 2 ? MASK_PLAYERSOLID : MASK_NPCSOLID)) {
					CheckIfPlayerCanMove(i, 0, fMoveCheck, 0.0, 0.0);
				}
			}
		}
	}
	return Plugin_Handled;
}

void CheckIfPlayerCanMove(int iClient, int testID, float X, float Y, float Z) {
	float vecVelo[3];
	GetEntPropVector(iClient, Prop_Data, "m_vecBaseVelocity", vecVelo);
	if (vecVelo[0] != 0.0 || vecVelo[1] != 0.0 || vecVelo[2] != 0.0) {
		return;
	}
	float vecOrigin[3];
	GetClientAbsOrigin(iClient, vecOrigin);
	vecVelo[0] = vecVelo[0] + X;
	vecVelo[1] = vecVelo[1] + Y;
	vecVelo[2] = vecVelo[2] + Z;
	SetEntPropVector(iClient, Prop_Data, "m_vecBaseVelocity", vecVelo);
	Handle hData = CreateDataPack();
	CreateTimer(0.1, TimerWait, hData);
	WritePackCell(hData, GetClientUserId(iClient));
	WritePackCell(hData, testID);
	WritePackFloat(hData, vecOrigin[0]);
	WritePackFloat(hData, vecOrigin[1]);
	WritePackFloat(hData, vecOrigin[2]);
}

void PushPlayer(int iClient, float X, float Y, float Z) {
	float vecVelo[3];
	GetEntPropVector(iClient, Prop_Data, "m_vecBaseVelocity", vecVelo);
	vecVelo[0] = vecVelo[0] + X;
	vecVelo[1] = vecVelo[1] + Y;
	vecVelo[2] = vecVelo[2] + Z;
	SetEntPropVector(iClient, Prop_Data, "m_vecBaseVelocity", vecVelo);
}

public Action TimerWait(Handle timer, any hData) {
	float vecOrigin[3];
	float vecOriginAfter[3];
	ResetPack(hData, false);
	int iClient = GetClientOfUserId(ReadPackCell(hData));
	if (bGlobalAllowedTeleporting && !(bPauseAvailable && IsInPause()) && iClient > 0 && IsClientInGame(iClient) && GetClientTeam(iClient) > 0 && IsSafeToTeleport(iClient)) {
		int testID = ReadPackCell(hData);
		vecOrigin[0] = ReadPackFloat(hData);
		vecOrigin[1] = ReadPackFloat(hData);
		vecOrigin[2] = ReadPackFloat(hData);
		GetClientAbsOrigin(iClient, vecOriginAfter);
		if (GetVectorDistance(vecOrigin, vecOriginAfter, false) == 0.0) {
			if (testID == 0) {
				CheckIfPlayerCanMove(iClient, testID + 1, -1.0 * fMoveCheck, 0.0, 0.0);
			} else if (testID == 1) {
				CheckIfPlayerCanMove(iClient, testID + 1, 0.0, fMoveCheck, 0.0);
			} else if (testID == 2) {
				CheckIfPlayerCanMove(iClient, testID + 1, 0.0, -1.0 * fMoveCheck, 0.0);
			} else {
				FixPlayerPosition(iClient);
			}
		} else {
			if (testID == 0) {
				PushPlayer(iClient, -1.0 * fMoveCheck, 0.0, 0.0);
			} else if (testID == 1) {
				PushPlayer(iClient, fMoveCheck, 0.0, 0.0);
			} else if (testID == 2) {
				PushPlayer(iClient, 0.0, -1.0 * fMoveCheck, 0.0);
			} else if (testID == 3) {
				PushPlayer(iClient, 0.0, fMoveCheck, 0.0);
			}
		}
	}
	CloseHandle(hData);
	return Plugin_Continue;
}

void FixPlayerPosition(int iClient) {
	float pos_Z = -50.0;
	float fRadius = 0.0;
	int iMask = GetClientTeam(iClient) == 2 ? MASK_PLAYERSOLID : MASK_NPCSOLID;
	while (pos_Z <= fMaxTeleportRadius && !TryFixPosition(iClient, iMask, fRadius, pos_Z)) {
		fRadius = fRadius + 2.0;
		pos_Z = pos_Z + 2.0;
	}
}

bool TryFixPosition(int iClient, int iMask, float Radius, float pos_Z) {
	float DegreeAngle;
	float vecPosition[3];
	float vecOrigin[3];
	float vecAngle[3];
	GetClientAbsOrigin(iClient, vecOrigin);
	GetClientEyeAngles(iClient, vecAngle);
	vecPosition[2] = vecOrigin[2] + pos_Z;
	DegreeAngle = -180.0;
	while (DegreeAngle < 180.0) {
		vecPosition[0] = vecOrigin[0] + Radius * Cosine(DegreeAngle * FLOAT_PI / 180.0);
		vecPosition[1] = vecOrigin[1] + Radius * Sine(DegreeAngle * FLOAT_PI / 180.0);
		
		TeleportEntity(iClient, vecPosition, vecAngle, Ground_Velocity);
		if (!IsEntityStuck(iClient, iMask) && GetDistanceToFloor(iClient, iMask) <= 240.0) {
			return true;
		}
		DegreeAngle += 10.0;
	}
	TeleportEntity(iClient, vecOrigin, vecAngle, Ground_Velocity);
	return false;
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
	} else {
		return true;
	}
}
