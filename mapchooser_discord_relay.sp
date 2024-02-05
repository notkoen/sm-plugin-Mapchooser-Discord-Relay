#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <mapchooser_unlimited>
#include <discordWebhookAPI>

// Define team variables
#define CS_TEAM_CT 3
#define CS_TEAM_T 2
#define CS_TEAM_SPECTATOR 1
#define CS_TEAM_NONE 0

// Plugin functionality settings
ConVar g_cvMode;

// Embed/Message settings
ConVar g_cvWebhook;

// Global Variables
char g_sNextmap[PLATFORM_MAX_PATH];
int iStartTime;

int g_iMode;
char g_sWebhook[PLATFORM_MAX_PATH];
char g_sMessageId[PLATFORM_MAX_PATH];

public Plugin myinfo =
{
	name = "Mapchooser => Discord Relay",
	author = "koen, tilgep",
	description = "Send Mapchooser information to a Discord embed",
	version = "",
	url = "https://github.com/notkoen"
};

public void OnPluginStart()
{
	// Convars
	g_cvMode = CreateConVar("sm_mcurelay_mode", "2", "Specify when map stats are updated (1 = End of Round, 2 = Start of Round)", _, true, 1.0, true, 2.0);
	g_cvWebhook = CreateConVar("sm_mcurelay_webhook", "", "Discord webhook link", FCVAR_PROTECTED);
	AutoExecConfig(true);

	// Hook convar changes
	HookConVarChange(g_cvMode, OnConvarChange);
	HookConVarChange(g_cvWebhook, OnConvarChange);

	// Hook Events
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);

	// Test Command
	RegAdminCmd("sm_mcurelay", Command_MCURelay, ADMFLAG_UNBAN, "Send MCU-Relay update message to discord");

	// Find message ID
	char msgidfile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, msgidfile, sizeof(msgidfile), "configs/mapchooser_unlimited");
	if (!DirExists(msgidfile))
	{
		CreateDirectory(msgidfile, FPERM_O_READ|FPERM_O_EXEC|FPERM_G_READ|FPERM_G_EXEC|FPERM_U_READ|FPERM_U_WRITE|FPERM_U_EXEC);
	}
	Format(msgidfile, sizeof(msgidfile), "%s/relaymessageid.txt", msgidfile);
	File f = OpenFile(msgidfile, "r");
	if (f != null)
	{
		f.ReadLine(g_sMessageId, PLATFORM_MAX_PATH);
		LogMessage("Retrieved webhook message ID (%s)", g_sMessageId);
		delete f;
	}
}

public void OnPluginEnd()
{
	// Store message id
	char msgidfile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, msgidfile, sizeof(msgidfile), "configs/mapchooser_unlimited");
	if (!DirExists(msgidfile))
	{
		CreateDirectory(msgidfile, FPERM_O_READ|FPERM_O_EXEC|FPERM_G_READ|FPERM_G_EXEC|FPERM_U_READ|FPERM_U_WRITE|FPERM_U_EXEC);
	}
	Format(msgidfile, sizeof(msgidfile), "%s/relaymessageid.txt", msgidfile);
	File f = OpenFile(msgidfile, "w");
	if (f != null && !StrEqual(g_sMessageId, ""))
	{
		f.WriteLine(g_sMessageId);
		LogMessage("Stored webhook message ID (%s)", g_sMessageId);
	}
	delete f;
}

public void OnConfigsExecuted()
{
	g_iMode = g_cvMode.IntValue;
	GetConVarString(g_cvWebhook, g_sWebhook, sizeof(g_sWebhook));
}

public void OnConvarChange(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	if (cvar == g_cvMode)
		g_iMode = g_cvMode.IntValue;
	else if (cvar == g_cvWebhook)
		g_sWebhook = g_cvWebhook.StringValue;
}

public void OnMapStart()
{
	iStartTime = GetTime();
	g_sNextmap = "";
}

public void Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	if (g_iMode == 2)
	{
		UpdateStats();
	}
}

public void Event_RoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
	if (g_iMode == 1)
	{
		UpdateStats();
	}
}

public void OnMapVoteEnd(const char[] map)
{
	FormatEx(g_sNextmap, sizeof(g_sNextmap), "%s", map);
	UpdateStats();
}

void UpdateStats()
{
	char buffer[PLATFORM_MAX_PATH];

	Webhook hook = new Webhook("**Update**");
	hook.SetUsername("Mapchooser Info");

	Embed embed = new Embed("Map Information");
	embed.SetColor(65280); // #00ff00 converted to decimal

	// Format the timestamp
	FormatTime(buffer, sizeof(buffer), "%FT\%T.000Z", GetTime() - (8 * 3600));
	embed.SetTimeStamp(buffer);

	/* ==========[ Get Information ]========== */
	// Get map name
	GetCurrentMap(buffer, sizeof(buffer));

	// Get this while mapname is stored
	int extendsLimit = GetMapMaxExtends(buffer);
	
	// Add current map field
	EmbedField mapField = new EmbedField("Current Map:", buffer);
	embed.AddField(mapField);

	// Add the thumbnail image
	Format(buffer, sizeof(buffer), "https://vauff.com/mapimgs/%s.jpg", buffer);
	EmbedThumbnail thumb = new EmbedThumbnail(buffer);
	embed.SetThumbnail(thumb);
	delete thumb;

	// Get timeleft
	Format(buffer, sizeof(buffer), "%s", GetTimeleft());
	EmbedField timeField = new EmbedField("Timeleft:", buffer);
	embed.AddField(timeField);

	// Get extends used
	int extendsUsed = GetExtendsUsed();
	int extendsLeft = extendsLimit - extendsUsed;
	Format(buffer, sizeof(buffer), "%d / %d (%d left)", extendsUsed, extendsLimit, extendsLeft);

	EmbedField extendField = new EmbedField("Extends Used:", buffer);
	embed.AddField(extendField);

	// Check next map
	if (StrEqual(g_sNextmap, "EXTEND") || StrEqual(g_sNextmap, "DONTCHANGE") || StrEqual(g_sNextmap, ""))
		Format(buffer, sizeof(buffer), "Pending Vote");
	else Format(buffer, sizeof(buffer), "%s", g_sNextmap);

	EmbedField nextmapField = new EmbedField("Nextmap:", buffer);
	embed.AddField(nextmapField);
	
	// Get elapsed time
	int iCurrentTime = GetTime();
	int iElapsedTime = iCurrentTime - iStartTime;
	int minutes = iElapsedTime / 60;
	int seconds = iElapsedTime % 60;
	Format(buffer, sizeof(buffer), "%d:%s%d", minutes, seconds < 10 ? "0" : "", seconds);
	EmbedField playedField = new EmbedField("Time Played:", buffer);
	embed.AddField(playedField);

	// Get player count
	int iPlayerCount = GetClientCount(true);
	int iConnectingCount = GetClientCount(false) - iPlayerCount;
	Format(buffer, sizeof(buffer), "%d / 64 (%d)", iPlayerCount, iConnectingCount);
	EmbedField playerField = new EmbedField("Players:", buffer);
	embed.AddField(playerField);

	// Get Score
	Format(buffer, sizeof(buffer), "%d (H): %d (ZM)", GetTeamScore(CS_TEAM_CT), GetTeamScore(CS_TEAM_T));
	EmbedField scoreField = new EmbedField("Score:", buffer);
	embed.AddField(scoreField);

	hook.AddEmbed(embed);

	g_cvWebhook.GetString(buffer, sizeof(buffer));
	LogMessage("Attempting webhook to url \"%s\"", buffer);
	char jsonmsg[1024];
	hook.ToString(jsonmsg, 1024);
	LogMessage("JSON message content: \"%s\"", jsonmsg);
	// Check if we should edit
	if (StrEqual(g_sMessageId, ""))
	{
		hook.Execute(buffer, OnWebHookExecuted);
	}
	else
	{
		hook.Edit(buffer, g_sMessageId, OnWebHookEdited);
	}
	delete hook;
}

public void OnWebHookExecuted(HTTPResponse response, any data)
{
	if (response.Status != HTTPStatus_OK)
	{
		LogError("An error has occured while sending the webhook. Status error code: %d", response.Status);
		return;
	}

	// Retrieve the message's id.
	JSONObject resData = view_as<JSONObject>(response.Data);
	resData.GetString("id", g_sMessageId, sizeof(g_sMessageId));
	LogMessage("Webhook sent, message id is now \"%s\"", g_sMessageId);
}

void OnWebHookEdited(HTTPResponse response, any data)
{
	if (response.Status != HTTPStatus_OK)
	{
		LogError("An error has occured while editing the webhook. Status error code: %d", response.Status);
		return;
	}
	LogMessage("Webhook edited.");
}

char[] GetTimeleft()
{
	// Code Taken from basetriggers.sp from AlliedModders
	char finalOutput[1024];
	int timeleft, mins, secs;

	GetMapTimeLeft(timeleft);
	mins = timeleft / 60;
	secs = timeleft % 60;

	if (mins < 0 || secs < 0)
	{
		FormatEx(finalOutput,sizeof(finalOutput), "Last Round");
	}
	else
	{
		FormatEx(finalOutput, sizeof(finalOutput), "%d:%s%d", mins, secs < 10 ? "0" : "", secs);
	}
	return finalOutput;
}

public Action Command_MCURelay(int client, int args)
{
	UpdateStats();
	PrintToChat(client, "[MCU-Relay] Sent update message to discord!");
	return Plugin_Handled;
}