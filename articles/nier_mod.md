## Install FAR Mod and HD Texture Pack for NieR: Automata on Linux
### Environment

- OS: Arch Linux
- Kernel: 5.12.11-zen
- CPU: AMD Ryzen 3600
- RAM: 32GB (2x16GB)
- GPU: NVIDIA GTX1650 4GB
- NVIDIA Driver: 465.31


### Prerequisite

+ You need ```protontricks``` package installed.  

__For Arch Linux users,__
```bash
pacman -S protontricks
```

+ Any recent Proton package, I would prefer [Proton-GE](https://github.com/GloriousEggroll/proton-ge-custom) by GloriousEggrol for optimal performance and game compatibilities
  I tested with the latest version of [Proton-6.10-GE-1](https://github.com/GloriousEggroll/proton-ge-custom/releases/tag/6.10-GE-1).  
   1. Download the Proton-6.10-GE-1.tar.gz (the one end with .tar.gz).  
   2. Create a directory ```compatibilitytools.d``` in your Steam install location, default in ```~/.local/share/Steam```, or if you cannot find it, the install location can be refer to the ```~/.steam/root``` symlink.   
   3. Extract all the content of the archive to ```compatibilitytools.d``` directory  
   ```bash
   tar xvf ~/Downloads/Proton-6.10-GE-1.tar.gz # Use your Download location
   ```  
   4. Once completed, restart the Steam client and configure the game to use your selected custom Proton package.  
  The detailed steps can refer to [this article](https://parasurv.neocities.org/how-to-force-linux-games-to-use-steam-proton.html) by parasurv.  
  You should be able to start the game at least once to allow Steam setup the game prefix.  
+ Download the [FAR Mod](https://github.com/Kaldaien/FAR) by Kaldaien.  
As I tested, version above 0.7.0.14 is not stable and may crash at game startup.  
You may use the [0.7.0.14](https://github.com/Kaldaien/FAR/releases/download/far_070/FAR_0_7_0_14.7z) version.  
+ Download the [HD texture Pack](https://www.nexusmods.com/nierautomata/mods/5).  
You may pick any edition you like. However, the site requires login in order to download the files. *(I use texture pack for 1080p or lower since higher resolution required more VRAM.)*

### Setup the wineprefix

FAR Mod required Both x86 and x64 edition of Visual C++ 2017 Redistributable.  
As I tested, the `vcrun2017` verb in winetricks are currently broken. You may manually install the VC2017 by using the vc_redist.\<arch\>.exe from Microsoft.  

- x86: [vc_redist.x86.exe](https://aka.ms/vs/16/release/vc_redist.x86.exe)  
- x64: [vc_redist.x64.xe](https://aka.ms/vs/16/release/vc_redist.x64.exe)  


1. Run this command to start the shell
```bash
protontricks 524220 shell
```
2. In the shell, run the following commands and follow the instruction of the install wizard.
```bash
wine ~/Downloads/vc_redist.x86.exe # Use your Download location
wine ~/Downloads/vc_redist.x64.exe # Use your Download location
```
3. Exit the shell. Then install the `dinput8` verb by, *(If you use Proton-GE, this setup is not needed)*  
```bash
protontricks 524220 dinput8
```

**[NOTE]** If the installation failed due to error ```... dinput8.dll: Persion Denied```, you may delete that ```dinput8.dll``` stated in the path, which should be a symlink.

4. Once install, run this command to open `winecfg`,
```bash
protontricks 524220 winecfg
```
5. Proceed to the `Libraries` tab, add a new override for library named `dinput8` with `native, builtin` setting.

### Install the FAR Mod

The installation of the mod is straightforward.  
1. Find the game directory of Nier: Automata. You may open you game page in the `Library` tab, open the game properties and then proceed to `Local Files`, press `Browse` to open the game directory.  
You should see `NieRAutomata.exe` in the root of the game directory.  
2. Extract all the content of the FAR Mod archive to the game directory. Then, you may start the game to test whether the installation succeeds.  
3. You may press `Ctrl + Shift + Backspace` to open the in-game GUI.  
Two file `dinput8.ini` and `FAR.ini` should be generated in the game directory.

**[NOTE]** These files are encoded in UTF-16. If you are using Kate editor, you may see whole page of block and random characters, just set back the correct encoding is fine.

**[NOTE]** According to [MiyacoGBF](https://gist.github.com/MiyacoGBF/6fd49ae4a73a9a7f4d13c488bff2da77), open `dinput8.ini`  and change `Silent=false` in `Steam.Log` section to `Silent=false` maybe a workaround for fixing GUI crash. However, I cannot show the OSD without crash while the GUI work fine without special configuration. 

**[WARNING]**  Don't enable the OSD or press `Ctrl + Shift + O` in game as it will crash your game.

The OSD configuration file is in `pfx/drive_c/users/steamuser/My Documents/My Mods/SpecialK/Global` in the game wineprefix, which should be in`<game directory>/../../compatdata/524220` .
If you find accidently enable the OSD and the game keep crashing at statup, you press open the `osd.ini` and edit `Show=true` in `SpecialK.OSD` section to `Show=false` to manualy disable the OSD.

### Setting FAR Mod
Here is my configuration  
|||
|------|-----|
|Global Illumination|Low|
|Bloom|Native Resolution|
|AO|Native Resolution|
**Global Illumination** significantly degrade the graphical performance but at least **low** profile is needed.  

### Install the HD Texture Pack

1. Open the game directory of Nier: Automata
2. Extract all the content of the HD Texture Pack archive.  
The game directory should now have a new subdirectory `FAR_Res`  
3. Open `dinput8.ini` and change `Inject=false` in `Textures.D3D11` section to `Inject=true` to enable the texture.

### Reference

[Tweaks & FAR](https://steamcommunity.com/groups/SpecialK_Mods/discussions/3/1334600128973500691/)  
[How to Install FAR, HD Texture Pack, and ReShade (GShade) for NieR:Automata on Linux](https://gist.github.com/MiyacoGBF/6fd49ae4a73a9a7f4d13c488bff2da77)  
[FAR Mod](https://github.com/Kaldaien/FAR)
<br/>

*Last updated on 2 July, 2021*
[&#91;Back to main page&#93;](/)