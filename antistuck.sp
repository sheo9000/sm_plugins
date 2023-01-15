#include <sourcemod>
#include <sdktools>
#include <pause>

new Float:Ground_Velocity[3] = {0.0, 0.0, 0.0};
new Float:fDownToFloor[3] = {90.0, 0.0, 0.0};
new Float:fAbleToMove[MAXPLAYERS + 1];
new Float:fNow;
new Float:fMaxTeleportRadius = 200.0;
new bool:bGlobalAllowedTeleporting;
new Float:fTickrate;
new Float:fMoveCheck;

public OnPluginStart()
{
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

public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	bGlobalAllowedTeleporting = false;
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	CreateTimer(5.0, RoundStart_Timer);
}

public Action:RoundStart_Timer(Handle:timer)
{
	bGlobalAllowedTeleporting = true;
}

public Event_AbilityUse(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client > 0 && IsClientInGame(client) && GetClientTeam(client) > 0)
	{
		decl String:sAbility[128];
		GetEventString(event, "ability", sAbility, sizeof(sAbility));
		if (StrEqual(sAbility, "ability_vomit"))
		{
			fAbleToMove[client] = GetEngineTime() + 1.5;
		}
		else if (StrEqual(sAbility, "ability_throw"))
		{
			fAbleToMove[client] = GetEngineTime() + 3.5;
		}
		else if (StrEqual(sAbility, "ability_toungue"))
		{
			fAbleToMove[client] = GetEngineTime() + 1.0;
		}
		else if (StrEqual(sAbility, "ability_spit"))
		{
			fAbleToMove[client] = GetEngineTime() + 1.5;
		}
	}
}

public Action:Teleport_Callback(Handle:timer, any:sheo)
{
	if (bGlobalAllowedTeleporting && !IsInPause())
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && GetClientTeam(i) > 1 && IsSafeToTeleport(i))
			{
				if (IsEntityStuck(i))
				{
					CheckIfPlayerCanMove(i, 0, fMoveCheck, 0.0, 0.0);
				}
			}
		}
	}
	return Plugin_Handled;
}

CheckIfPlayerCanMove(iClient, testID, Float:X=0.0, Float:Y=0.0, Float:Z=0.0)
{
	decl Float:vecVelo[3];
	decl Float:vecOrigin[3];
	GetClientAbsOrigin(iClient, vecOrigin);
	GetEntPropVector(iClient, Prop_Data, "m_vecBaseVelocity", vecVelo);
	vecVelo[0] = vecVelo[0] + X;
	vecVelo[1] = vecVelo[1] + Y;
	vecVelo[2] = vecVelo[2] + Z;
	SetEntPropVector(iClient, Prop_Data, "m_vecBaseVelocity", vecVelo);
	new Handle:hData = CreateDataPack();
	CreateTimer(0.1, TimerWait, hData);
	WritePackCell(hData, GetClientUserId(iClient));
	WritePackCell(hData, testID);
	WritePackFloat(hData, vecOrigin[0]);
	WritePackFloat(hData, vecOrigin[1]);
	WritePackFloat(hData, vecOrigin[2]);
}

public Action:TimerWait(Handle:timer, any:hData)
{
	decl Float:vecOrigin[3];
	decl Float:vecOriginAfter[3];
	ResetPack(hData, false);
	new iClient = GetClientOfUserId(ReadPackCell(hData));
	if (bGlobalAllowedTeleporting && !IsInPause() && iClient > 0 && IsClientInGame(iClient) && GetClientTeam(iClient) > 0 && IsSafeToTeleport(iClient))
	{
		new testID = ReadPackCell(hData);
		vecOrigin[0] = ReadPackFloat(hData);
		vecOrigin[1] = ReadPackFloat(hData);
		vecOrigin[2] = ReadPackFloat(hData);
		GetClientAbsOrigin(iClient, vecOriginAfter);
		if (GetVectorDistance(vecOrigin, vecOriginAfter, false) == 0.0)
		{
			if(testID == 0)
			{
				CheckIfPlayerCanMove(iClient, 1, 0.0, 0.0, -1.0 * fMoveCheck);
			}
			else if(testID == 1)
			{
				CheckIfPlayerCanMove(iClient, 2, -1.0 * fMoveCheck, 0.0, 0.0);
			}
			else if(testID == 2)
			{
				CheckIfPlayerCanMove(iClient, 3, 0.0, fMoveCheck, 0.0);
			}
			else if(testID == 3)
			{
				CheckIfPlayerCanMove(iClient, 4, 0.0, -1.0 * fMoveCheck, 0.0);
			}
			else if(testID == 4)
			{
				CheckIfPlayerCanMove(iClient, 5, 0.0, 0.0, fMoveCheck);
			}
			else
			{
				FixPlayerPosition(iClient);
			}
		}
	}
	CloseHandle(hData);
	return Plugin_Continue;
}

FixPlayerPosition(iClient)
{
	new Float:pos_Z = -50.0;
	new Float:fRadius = 0.0;
	while (pos_Z <= fMaxTeleportRadius && !TryFixPosition(iClient, fRadius, pos_Z))
	{
		fRadius = fRadius + 2.0;
		pos_Z = pos_Z + 2.0;
	}
}

bool:TryFixPosition(iClient, Float:Radius, Float:pos_Z)
{
	decl Float:DegreeAngle;
	decl Float:vecPosition[3];
	decl Float:vecOrigin[3];
	decl Float:vecAngle[3];
	GetClientAbsOrigin(iClient, vecOrigin);
	GetClientEyeAngles(iClient, vecAngle);
	vecPosition[2] = vecOrigin[2] + pos_Z;
	DegreeAngle = -180.0;
	while (DegreeAngle < 180.0)
	{
		vecPosition[0] = vecOrigin[0] + Radius * Cosine(DegreeAngle * FLOAT_PI / 180.0);
		vecPosition[1] = vecOrigin[1] + Radius * Sine(DegreeAngle * FLOAT_PI / 180.0);
		
		TeleportEntity(iClient, vecPosition, vecAngle, Ground_Velocity);
		if (!IsEntityStuck(iClient) && GetDistanceToFloor(iClient) <= 240.0)
		{
			return true;
		}
		DegreeAngle += 10.0;
	}
	TeleportEntity(iClient, vecOrigin, vecAngle, Ground_Velocity);
	return false;
}

bool:IsEntityStuck(iEnt)
{
	decl Float:vecMin[3], Float:vecMax[3], Float:vecOrigin[3];
	GetEntPropVector(iEnt, Prop_Send, "m_vecMins", vecMin);
	GetEntPropVector(iEnt, Prop_Send, "m_vecMaxs", vecMax);
	GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", vecOrigin);
	new Handle:hTrace = TR_TraceHullFilterEx(vecOrigin, vecOrigin, vecMin, vecMax, MASK_PLAYERSOLID, TraceEntityFilterSolid);
	new bool:bTrue = TR_DidHit(hTrace);
	CloseHandle(hTrace);
	return bTrue;
}

Float:GetDistanceToFloor(client)
{
	decl Float:vOrigin[3];
	GetClientEyePosition(client, vOrigin);
	new Handle:hTrace = TR_TraceRayFilterEx(vOrigin, fDownToFloor, MASK_PLAYERSOLID, RayType_Infinite, TraceEntityFilterSolid);
	if (TR_DidHit(hTrace))
	{
		decl Float:vFloorPoint[3];
		TR_GetEndPosition(vFloorPoint, hTrace);
		CloseHandle(hTrace);
		return (vOrigin[2] - vFloorPoint[2]);
	}
	CloseHandle(hTrace);
	return 999999.0;
}

public bool:TraceEntityFilterSolid(entity, contentsMask)
{
	if (entity > 0 && entity <= MaxClients)
	{
		return false;
	}
	new iCollisionType;
	if (entity >= 0 && IsValidEdict(entity) && IsValidEntity(entity))
	{
		iCollisionType = GetEntProp(entity, Prop_Send, "m_CollisionGroup");
	}
	if (iCollisionType == 1 || iCollisionType == 11 || iCollisionType == 5)
	{
		return false;
	}
	return true;
}

bool:IsSafeToTeleport(client)
{
	fNow = GetEngineTime();
	if (!IsPlayerAlive(client))
	{
		return false;
	}
	else if (GetEntityMoveType(client) == MOVETYPE_LADDER)
	{
		return false;
	}
	else if (GetEntProp(client, Prop_Send, "m_jockeyAttacker") > 0)
	{
		return false;
	}
	else if (GetEntProp(client, Prop_Send, "m_jockeyVictim") > 0)
	{
		return false;
	}
	else if (GetEntProp(client, Prop_Send, "m_pounceAttacker") > 0)
	{
		return false;
	}
	else if (GetEntProp(client, Prop_Send, "m_pounceVictim") > 0)
	{
		return false;
	}
	else if (GetEntProp(client, Prop_Send, "m_carryAttacker") > 0)
	{
		return false;
	}
	else if (GetEntProp(client, Prop_Send, "m_carryVictim") > 0)
	{
		return false;
	}
	else if (GetEntProp(client, Prop_Send, "m_pummelAttacker") > 0)
	{
		return false;
	}
	else if (GetEntProp(client, Prop_Send, "m_pummelVictim") > 0)
	{
		return false;
	}
	else if (GetEntProp(client, Prop_Send, "m_isHangingFromLedge") == 1)
	{
		return false;
	}
	else if (GetEntProp(client, Prop_Send, "m_isIncapacitated") == 1)
	{
		return false;
	}
	else if (fAbleToMove[client] != 0.0 && fNow < fAbleToMove[client])
	{
		return false;
	}
	else
	{
		return true;
	}
}
