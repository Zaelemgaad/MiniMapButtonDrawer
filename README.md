# MiniMapButtonDrawer

For **World of Warcraft 3.3.5a (Wrath, Interface 30300)**.

Moves addon minimap buttons into a neat drawer attached to the edge of your screen.
Hover to pull it out. Move away to tuck it back in. Drag the tab to any screen edge.

Right-click the tab or type `/mbd` (`/mbf` also works) for button size, separate
drawer/button transparency, RGB tab color, rounded inner corners, and 1-24 px tab thickness.
Flip orientation changes the drawer layout without moving or rotating its tab.

Detects Minimap Button Frame, DragonUI and MBB. Choose to host a compatible
container, disable either addon, or leave things alone. The prompt can be dismissed
permanently and reopened from settings. Protected or separately anchored button
groups cannot be hosted safely; their names and the reason are shown.

## Install

Download **MiniMapButtonDrawer.zip** from [Releases](https://github.com/Zaelemgaad/MiniMapButtonDrawer/releases/latest).
Extract it into `Interface/AddOns`, then restart the game.
No other addons required.

Replacing MinimapButtonFrame? Exit first, remove the old addon folder, and rename
each account's `WTF/Account/<account>/SavedVariables/MinimapButtonFrame.lua` to
`MiniMapButtonDrawer.lua` to retain settings. Don't overwrite an existing new file.

Original Minimap Button Frame by Bachlott; drawer rewrite by AddonsEX.
