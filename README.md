# NexusSync-Elevator

A simple elevator resource for Qbox, QBCore and ESX Legacy, with a blue 3D interior screen, a camera close-up, target interaction and an in-game creator. All built-in text is in English. No SQL database is required.

## Installation

Keep the resource folder named `NexusSync-Elevator`. Start your framework, interior/MLO and target resource first. Add the following to `server.cfg`:

```cfg
set onesync on
ensure ox_target # Or: ensure qb-target
ensure NexusSync-Elevator
add_ace group.admin ns_elevator.admin allow
# If needed, assign your licence to the admin group:
# add_principal identifier.license:YOUR_LICENSE group.admin
```

After updating the files, run `restart NexusSync-Elevator` in the server console.

## Creator

1. Run `/elevatorcreator` and create or select an elevator.
2. Set the name and floors. Set **Black screen** for that elevator, then save to apply the choice.
3. On each floor, stand at the cabin centre, facing the exit, and select **Arrival position**.
4. Select **Preview tablet**. The screen appears in the world before you confirm its position.
5. Use the controls below to adjust it. Enter confirms the draft position; Esc or Backspace cancels the preview. Open **Advanced settings** to edit screen dimensions, heading, job access and routing bucket.
6. Close the menu, move to the next floor and reopen the command to resume the draft.
7. Save once every floor has an arrival position and a screen.

| Control | Preview action |
| --- | --- |
| Left / right arrows | Move sideways relative to the screen |
| Up / down arrows | Adjust height |
| Page Up / Page Down or mouse wheel | Adjust depth |
| Q / E | Rotate |
| Shift | Fine adjustment |
| WASD and mouse | Move the player and look around |
| Enter | Confirm position in the draft |
| Esc / Backspace | Cancel placement |

Point your target at the screen and choose **Select floor**. The menu closes, the camera returns to gameplay and the resource waits for `Config.TravelDuration` before transitioning. Passengers stay frozen until the destination floor has loaded and their feet can be positioned on it. If loading fails, the trip is cancelled and the player remains at the origin.

## Black-screen option

**Per elevator:** toggle **Black screen** in the creator and save the elevator. Checked enables a fade; unchecked keeps gameplay visible.

**Global default:** edit `config.lua`:

```lua
Config.UseScreenFade = false -- true: black screen; false: visible teleport
Config.FadeDuration = 200 -- Fade out/in duration in milliseconds
Config.TravelDuration = 1500 -- Visible delay after the menu closes
Config.CollisionTimeout = 5000 -- Maximum destination loading time
```

The global default applies to existing elevators without a saved `screenFade` override. New elevators inherit the default when created. An explicit setting saved in the creator takes priority over the global default.

With the fade enabled, the travel delay stays visible. The screen fades out before loading/teleporting and fades back in after safe placement. Cancelled trips and resource shutdown restore any fade started by this resource. With the fade disabled, the resource does not call the screen-fade natives.

## Configuration and behaviour

- Each floor needs only an arrival position and an interior screen. The resource does not operate doors or exterior call buttons, and does not include an MLO or a physically moving cabin.
- The menu and the world screen use the same blue layout. The keypad keeps three columns and at least four rows: floor 1 is at the bottom right, floor 2 is to its left. Missing floors leave empty slots.
- All players on foot within the configured cabin radius travel together. Keep the radius inside the cabin and leave arrival positions clear.
- One trip runs per elevator. The server keeps the elevator reserved until all passengers finish loading, disconnect or reach the recovery timeout.
- Screens show the floor where they are installed. Any floor can be used directly without a prior call.
- An empty job gives public access. The server checks jobs and minimum grades. A passenger without destination access cancels the group trip before departure.
- `Config.Framework`: `auto`, `qbox`, `qbcore`, `esx` or `standalone`. Auto prefers Qbox, then QBCore, then ESX.
- `Config.Target`: `auto`, `ox_target` or `qb-target`. Auto prefers ox_target. One of these resources is required.
- `Config.InteractDistance` controls target range. The target zone radius uses `Config.TargetRadius`, with a minimum of half the screen width/height. ox_target displays an indicator while aiming.
- `Config.RenderDistance` controls how far away screens are rendered. A client keeps at most eight nearby screen textures.
- The creator requires the `ns_elevator.admin` ACE in every framework.
- A new installation starts with no elevators. Create them using `/elevatorcreator`. Data is stored in `data/elevators.json`; the previous version is copied to `data/elevators.backup.json` on save. Updates preserve existing data. Old door/call-button fields are ignored.
- If another administrator saves changes, select the elevator again in the list to reload its latest revision.
- OneSync and a loaded, walkable interior are required at every floor.

## Credits

The included Barlow Condensed font uses the SIL Open Font License in `web/fonts/OFL.txt`.
