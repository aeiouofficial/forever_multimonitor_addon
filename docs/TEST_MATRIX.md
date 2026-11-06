# In-client Test Matrix

Target: WoW Forever launch client **1.60.1.70790**, interface **16001**.

## Required before release

| Area | Test | Pass criteria |
|---|---|---|
| Loading | Cold launch with addon enabled | No Lua errors; addon appears in AddOns |
| Compatibility | `/fmm status` | Runtime version/build/interface match client |
| Loading | `/reload` | No Lua errors; settings preserved |
| Recovery | Enter world / zone transition | Enabled layout reapplies once after UI settles |
| Recovery | Change UI scale / window size | Geometry recalculates without anchor drift |
| Detection | `/fmm status` | Reports logical canvas and active profile |
| Viewport | Mainhand left | 3D world is confined to left region |
| Viewport | Mainhand right | 3D world is confined to right region |
| Viewport | Disable / reset | Original viewport anchors restored |
| Combat | Apply while in combat | No protected-action error; operation deferred |
| Combat | Leave combat | Pending layout applies once |
| Map | Open / close / reopen World Map | Map is positioned in Offhand and remains usable |
| Character | Open / close Character panel | Panel routes and restores correctly |
| Bags | Open each supported bag mode | No duplicate, hidden, or stuck bag frames |
| Persistence | Logout / relog / cold restart | Account options remain stable and layout recovers |
| Topology | Different monitor sizes / vertical offsets | Documented manual geometry remains usable |
| Regression | Disable addon | Native panels and viewport return to baseline |

## Environment capture

Record the following with each live test:
- `/dump GetBuildInfo()`
- `/dump WOW_PROJECT_ID, WOW_PROJECT_CAMELOT`
- `/fmm status`
- Display arrangement, resolution and Windows scaling per display
- Other addons that replace bags, map or character UI

## Release gate

Do not claim full support or Offhand feature parity until every required row is passed on the current live Forever build and panel compatibility has been tested with the default UI.
