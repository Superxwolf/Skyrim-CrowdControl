# Crowd Control for Skyrim

This mods for Skyrim Special Edition that connects to Warp World's Crowd Control and contains commands so that players can affect your game through Twitch.

- Requires SKSE64

# Breakdown of projects

## CC_Pack

This is the C# pack used by Crowd Control to have a list of effects and know what TCP port to connects to the SKSE Plugin.

## SKSE_Plugin

This is the C++ code that creates the required TCP connection and maintains it. There's a few asynchrous threads created in order to keep in check both
the TCP connection and timing out commands properly if the Papyrus Script does not execute them after a certain amount of time.

The best way to work with this is to add the project to the actual SKSE64 development solution.

## Papyrus_Script

This is the script that connects to the SKSE plugin to receive and execute the commands.
