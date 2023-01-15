#include <sourcemod>
#undef REQUIRE_PLUGIN
#include <l4d2center>

int iPrevButtons[MAXPLAYERS + 1];
int iPrevMouse[MAXPLAYERS + 1][2];
int iLastActivity[MAXPLAYERS + 1];

bool bL4D2CenterAvailable;

public void OnPluginStart() {
	AddCommandListener(OnCommandExecute, "spec_mode");
	AddCommandListener(OnCommandExecute, "spec_next");
	AddCommandListener(OnCommandExecute, "spec_prev");
	AddCommandListener(OnCommandExecute, "say");
	AddCommandListener(OnCommandExecute, "say_team");
	AddCommandListener(OnCommandExecute, "callvote");
	RegConsoleCmd("sm_afks", Cmd_AFKs);
	CreateTimer(10.0, KickTimer_Callback, 0, TIMER_REPEAT);
}

public void OnAllPluginsLoaded() {
    bL4D2CenterAvailable = LibraryExists("l4d2center");
}

public void OnLibraryRemoved(const char[] name) {
    if (StrEqual(name, "l4d2center")) bL4D2CenterAvailable = false;
}

public void OnLibraryAdded(const char[] name) {
    if (StrEqual(name, "l4d2center")) bL4D2CenterAvailable = true;
}

public Action Cmd_AFKs(client, args) {
	int iTime = GetTime();
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i)) {
			ReplyToCommand(client, "%N : last activity %d seconds ago", i, iTime - iLastActivity[i]);
		}
	}
	return Plugin_Handled;
}

Action KickTimer_Callback(Handle timer, Handle hndl) {
	if (bL4D2CenterAvailable && L4D2C_GetServerReservation() == 1) {
		return Plugin_Continue;
	}
	int iTime = GetTime();
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i) && iLastActivity[i] != 0) {
			if (iLastActivity[i] + 300 <= iTime) { //5 minutes
				PrintToChatAll("Player %N has been kicked from the server for being AFK for more than 5 minutes", i);
				KickClient(i, "You have been kicked from the server for being AFK for more than 5 minutes");
			} else if (iLastActivity[i] + 240 <= iTime) { //4 minutes
				PrintToChat(i, "[AFK Manager] If you don't show that you are alive, you will be kicked in %d seconds", (iLastActivity[i] + 300) - iTime);
				PrintToChat(i, "[AFK Manager] Move your mouse or type a message in chat");
			}
		}
	}
	return Plugin_Continue;
}

Action OnCommandExecute(int client, const char[] command, int argc) {
	if (client > 0 && IsClientInGame(client) && !IsFakeClient(client)) {
		iLastActivity[client] = GetTime();
	}
	return Plugin_Continue;
}

public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2]) {
	if (client > 0 && client <= MaxClients && (iPrevButtons[client] != buttons || iPrevMouse[client][0] != mouse[0] || iPrevMouse[client][1] != mouse[1]) && IsClientInGame(client) && !IsFakeClient(client)) {
		iPrevButtons[client] = buttons;
		iPrevMouse[client][0] = mouse[0];
		iPrevMouse[client][1] = mouse[1];
		iLastActivity[client] = GetTime();
	}
}

public void OnClientConnected(int client) {
	iLastActivity[client] = 0;
}

public void OnClientDisconnect_Post(int client) {
	iLastActivity[client] = 0;
}

public void OnClientPutInServer(int client) {
	if (client > 0 && IsClientInGame(client) && !IsFakeClient(client)) {
		iLastActivity[client] = GetTime();
	}
}