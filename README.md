# Lambda AMXX Plugins
<p align="center">
    <a href="https://github.com/d3m37r4/lambda-amxx/blob/main/LICENSE">
        <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="License">
    </a>
</p>

## What is this?
Basic set of the AMXX layer for the exchange of information between the game server and the web part of <a href="https://github.com/d3m37r4/lambda-web/">Lambda-Web</a>.

## Requirements
<a href="https://github.com/alliedmodders/amxmodx/">
    <img src="https://img.shields.io/badge/AMXModX-v1.9.0-blue?style=flat-square"> 
</a>
<br>
<a href="https://github.com/In-line/grip">
    <img src="https://img.shields.io/badge/GoldSrcRestInPawn-v0.1.5-blue?style=flat-square" alt="License"> 
</a>
<br>
Or higher versions of the specified package.

## Installation
* Compile `*.sma` files
* Move compiled files `*.amxx` to `amxmodx/plugins/lambda`
* Copy the file `configs/lambda/lambda-core.json` and `configs/plugins-lambda.ini` to the appropriate directory.

## Configuration
Fill in the fields in the configuration file `configs/lambda/lambda-core.json`
```json
{
    "request-url": "http://127.0.0.1",
    "server-ip": "127.0.0.1",
    "server-port": 27015,
    "server-auth-token": ""
}
```
## Goals of the project
* Develop a flexible system for administration of Counter Strike 1.6 game server (in the long term, add support for other games on goldsrc and source).
* Expanded granting of groups of players and accesses.
* Extended API for plugins that allows you to scale the system.

## Contribution and support
If you have any thoughts or suggestions to improve the product, contact me at one of the following places:

<a href="https://github.com/d3m37r4/lambda-amxx/issues/">Github Issues</a><br>
<a href="https://github.com/d3m37r4/lambda-amxx/discussions/">Github Discussions</a><br>
<a href="https://t.me/dmitry_isakow">Telegram</a>
