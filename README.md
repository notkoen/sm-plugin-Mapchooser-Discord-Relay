
# Mapchooser => Discord Relay

Sends mapchooser information to a discord embed.

> [!WARNING]
> Make sure the plugin has proper write permissions! A file storing the message ID of the embed will be generated automatically, but the plugin will not be able to update the embed if this file cannot be created for anay reason.

> [!NOTE]
> This plugin was written to work with tilgep's [Mapchooser Unlimited](https://github.com/tilgep/Mapchooser-Unlimited) plugin. Some natives and/or includes may differ!

## Requirements

- [DiscordWebhookAPI](https://github.com/Sarrus1/DiscordWebhookAPI)
- [RIPExt extension](https://github.com/ErikMinekus/sm-ripext) *(included with DiscordWebhookAPI)*

## ConVars

ConVar | Default Value | Description
--- | --- | ---
sm_mcurelay_mode | 2 | 1 = Send update on round end, 2 = Send update on round start
sm_mcurelay_webhook | "" | Discord webhook link