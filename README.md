# OrionBot
![Commit](https://img.shields.io/github/last-commit/Raffy27/OrionBot)
![Release](https://img.shields.io/github/v/release/Raffy27/OrionBot)
![Issues](https://img.shields.io/github/issues/Raffy27/OrionBot)
![Toxicity](https://img.shields.io/badge/toxicity-2.550-red)
![Donate](https://img.shields.io/badge/btc-16XsRodnoCKzAWHCELxsfQRUpfviqiWbyR-blueviolet)

OrionBot is the deployed binary of a centralized and versatile remote administration tool, making use of the Tor network to communicate with its respective server.

## [Setup Guide](https://github.com/Raffy27/OrionServer/blob/master/SetupGuide.md)

## Features
### Static
* Customizable icon and install name
* Startup options: Automatic, Task, Registry, Startup folder
* Persistence
* Reinfection
* Base creation (hidden)
* Tracking of Spreading Vectors
* Anti-Virtualization
* Anti-Debugging
* Execution Delay
* Disabling Windows Defender
* Elevation
* Melting
* Torified or Standard traffic
* Encrypted and dynamic Resources
* Polymorphism
### Runtime
* Basic (bot-specific) information
* Information gathering
    * System information
    * Software information
    * Passwords (LaZagne parser)
    * Discord Token grabbing
    * Files: Download, Upload, List, Open remotely
* Power: Shutdown, Reboot, Lock, Sleep, Wake
* Execution: Local File, Remote File, Command
* Elevation: Simple, Disguised, Silent
* Toggle Windows Defender protection
* Crypto mining
* Spreading
* MessageBox
* Abort command

## Getting started
This section covers the recommended software and dependencies needed to compile and debug the project. 

### Prerequisites
Delphi environment:
* RAD Studio 10.3+

### Dependencies
* <a href="https://github.com/TurboPack/LockBox3" target="_blank">LockBox 3.7</a> for the encryption routines
* <a href="https://github.com/z505/TProcess-Delphi" target="_blank">DProcess</a> for high-level process management (included)
* <a href="https://github.com/AlessandroZ/LaZagne" target="_blank">LaZagne</a> for password recovery (runtime)
* <a href="https://github.com/nanopool/nanominer" target="_blank">Nanominer</a> for crypto mining (runtime)

### Installing
Clone the repository using
```shell
git clone https://github.com/Raffy27/OrionBot
```
Open Bot.dproj or the source file (Bot.lpr) in your IDE.

### Debugging
If you're using RAD Studio, switch to the **Debug** Build Configuration and build the project.

Make sure the **DEBUG directive** is defined and the **Dbg** procedure in **Basics.pas** is working as intended.

To debug in-place (do not create a base, etc.) add a **Config.ini** to the current directory of OrionBot, essentially simulating a post-install second start. You can get a valid configuration file by building a new binary with **OrionPanel** and then extracting it from the Resources.

You can use <a href="http://www.angusj.com/resourcehacker/" target="_blank">ResourceHacker</a> to edit/extract binary Resources.

You can use <a href="https://docs.microsoft.com/en-us/sysinternals/downloads/debugview" target="_blank">DebugView</a> to see debug messages logged by OrionBot. A useful filter file can be found <a href="https://gist.github.com/Raffy27/51708a718eb9b17c96027e7af8ef1633" target="_blank">**here**</a>.

## Releases
For active releases and pre-compiled binaries, see <a href="https://github.com/Raffy27/OrionBot/releases" target="_blank">Releases</a>.
For usage with the entire project, see the instructions provided in **OrionServer**.

## License
This project is licensed under the MIT License -  see the <a href="https://github.com/Raffy27/OrionBot/blob/master/LICENSE" target="_blank">LICENSE</a> file for details. For the dependencies, all rights belong to their respective owners. These should be used according to their respective licenses.
