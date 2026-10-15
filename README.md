# FS22_DriveThroughWash

A Farming Simulator 22 mod that turns **every wash station into an automatic drive-through car wash**. Drive in, wait a few seconds, drive out clean. No getting out, no pressure washer.

## Features

- Drive into a wash station and your vehicle is cleaned automatically in about 3 seconds
- Everything attached to your vehicle (trailers, implements) is washed too
- Shows "Washing vehicle..." while washing and "Vehicle washed" when it's done
- No key to press and nothing to set up
- Works in multiplayer (the server does the washing)

## Which buildings work as a wash station

| Building | Works |
|---|---|
| Base game high pressure washer | Yes |
| Wash bay / washer mods that use the game's high pressure washer | Yes |
| Any placeable with "wash" in its file name (car wash, wash bay mods) | Yes |

The wash zone is a circle of **10 m** around the centre of the building.

## Installation

1. Download `FS22_DriveThroughWash.zip` from the [Releases](../../releases) page.
2. Put the zip in `Documents\My Games\FarmingSimulator2022\mods`. Don't unzip it.
3. Turn on **Drive-Through Wash** when you load your savegame.

## Usage

1. Buy and place a wash station (for example the high pressure washer from the shop), or use one that's already on the map.
2. Drive your vehicle into or next to it.
3. Wait until you see **Vehicle washed**, then drive on.

## Settings

The settings are at the top of `scripts/DriveThroughWash.lua`:

| Setting | Default | What it does |
|---|---|---|
| `WASH_RADIUS` | `10` | Size of the wash zone in meters |
| `WASH_HEIGHT` | `8` | Max height difference between vehicle and station |
| `WASH_DURATION` | `3000` | Time in ms to fully clean a very dirty vehicle |
| `DEBUG` | `false` | Draws the wash zones in the world and logs how many stations were found |

## Reporting problems

If something doesn't work, open `Documents\My Games\FarmingSimulator2022\log.txt`, search for `[DriveThroughWash]`, and open an issue with those lines and the wash station you were using.

## Files

- `modDesc.xml`: mod description and texts
- `scripts/DriveThroughWash.lua`: finds wash stations and washes vehicles in their zone

## Credits

Made by Timo.
