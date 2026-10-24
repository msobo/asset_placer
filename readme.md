
# Godot Asset Placer V2

![v2](icon.png)

This is Godot Editor plugin that allows for quick asset placement and management when working with large 3D Scenes.
Heavily modified for modular-asset collections placement and management.
Based on: https://github.com/levinzonr/godot-asset-placer


## Installation

1. Copy the `addons/asset_placerV2` folder into your Godot project under the `addons` directory.
2. Enable the plugin in the Godot Editor by going to `Project` -> `Project Settings` -> `Plugins` and enabling the `Asset PlacerV2` plugin.


### Placing Assets

Godot Asset Placer provides various placement modes. All methods rely on RayCasting to determine where to place the asset.

Placement Modes can be cycled using `Q` Shortcut

#### Surface Collisions (Default)

This mode requires your scene to have Collision Objects (StaticBody3D, CollisionShape3D, etc.) in order to place assets on surfaces. This mode is useful when your scene already has some kind of physical floor and you want your assets placed directly onto it.

#### Plane Collisions

This mode allows you to place assets on an infinite plane at a specified height. This is useful for quickly placing assets in an empty scene or when you want to place assets at a specific height without relying on existing geometry. This plane has a configurable Normal and Point Of origin.
You can quickly enter this mode by pressing `Q` while in placement mode.

If you want to configure Plane Options (Normal and Origin) you can do so within Options Sub View or with `W` Translate Mode
This will allow to move the plane origin using Mouse Wheel along selected Axis

Plane height steps are anchored to the world origin. Horizontal planes therefore always reach `y = 0`, regardless of the configured step size. If changing the step size leaves the plane between valid levels, it snaps to the next level in the current movement direction. This also works along the X and Z axes and with angled plane normals.

#### Grid Brush

The Grid Brush makes it quick to build levels from modular props in Plane Placement Mode. Press `B` to toggle the brush; enabling it automatically activates Plane Placement Mode and grid snapping. The shortcut is configurable in Settings.

- `Left Mouse Button` drag: Paint freehand across grid cells
- `Shift` + `Left Mouse Button` drag: Paint a straight, continuous grid line
- `Ctrl` + `Left Mouse Button` drag: Paint a filled rectangular area

Each grid cell contains at most one object placed by Asset Placer. Painting into an occupied cell replaces that object. The same replacement behavior applies to regular single placements in Plane Placement Mode. Unrelated nodes and Asset Placer objects on other height levels remain untouched.

An entire drag is recorded as a single Undo/Redo action. The preview's rotation and scale at the start of the drag are applied consistently to the complete stroke. A brush preview and viewport overlay hints show the active brush behavior.

Set the square **Grid Step** in Asset Placement Options to any value from `0.01` to `1000` world units. The visible plane grid scales with this value. If the setting changes during a brush stroke, the current stroke keeps the grid size with which it started.

#### AutoGrid from Collection Filters

AutoGrid automatically enables Grid Snapping and applies a configured U/V grid step when the Assets tab has **exactly one** matching collection filter selected. Configure the feature and its grid steps in **Settings → Auto Grid from Collection Filter**.

The default steps are:

- Wall: 2 × 2
- Floor: 4 × 4
- Ceiling: 4 × 4

For AutoGrid to recognize a collection, its name must begin with one of these type names, followed by the end of the name or a separator:

- Wall: wall, walls, walls_pack
- Floor: floor, floors, floor-pack
- Ceiling: ceiling, ceilings, ceilings modular

Matching is case-insensitive. Names such as stone_walls and wallsXYZ do not activate AutoGrid because the type is not the leading collection name or is missing a separator.

When you select no collection, multiple collections, or a collection without one of these prefixes, the previous manual Grid Snapping state is restored. Manually changing Grid Snapping or its U/V value temporarily disables AutoGrid for the current filter; switching the filter enables automatic matching again.


#### Random Asset Placement

You can enable random asset placement in the Asset Placement Options. When enabled, after each placement, a new asset will be randomly selected from the currently filtered list of assets in the Assets Panel. This is useful for quickly populating scenes with varied assets.

#### Auto-Grouping by Collection

When enabled in the Asset Placement Options, placed assets will automatically be grouped under Node3D nodes named after their **primary collection**. This keeps your scene tree organized without manual effort.

For example, if you have assets assigned to "Trees" and "Rocks" collections:

```
- Parent (your selected parent node)
 - Trees (auto-created group)
  - Tree(1)
  - Tree(2)
 - Rocks (auto-created group)
  - Rock(1)
  - Rock(2)
```

Assets without a primary collection will be placed directly under the parent node. See [Primary Collections](#primary-collections) for how to set the primary collection for your assets.

#### Transforming Assets Before Placement

You can modify the preview of the asset before placement. This includes options for rotation and scaling, allowing users to visualize how the asset will appear in the scene prior to placement, do quick and precise adjustment modifications.
Specific transformation mode can be enabled by pressing button while in placement mode (Asset is selected). By default, transformations are applied by Mouse Wheel:

- `Mouse Wheel Up`: "Positive" transformation
- `Mouse Wheel Down`: "Negative" transformation

Following transformations are supported:

- `E` to rotate (Default axis is Y)
- `R` to scale (Uniform Scale by default, All axis at once)
- `W` to translate (Default axis is Y) - Activates `Plane Placement Mode`

This also requires an ability to select active Axis for the transformation. This can be done by pressing following keys:

- `X` to select X axis
- `Y` to select Y axis
- `Z` to select Z axis

### Organizing Assets

You can organize your assets into Collections. Collections is a simple way to "group" assets together by some criteria. For example, you can create a collection for all the trees in your scene, or all the rocks, etc.
To create a collection navigate to the Collections tab, choose a name and color. Then you can assign assets into one or more collections, either by using a options menu or dragging and dropping assets into the window while Collection Filter is active.

#### Collection Management

The Collection Management dialog provides a streamlined way to assign and remove collections from multiple assets at once.

**Features:**

- **Batch Selection** - Select multiple assets using Shift+Click (range) or Ctrl/Cmd+Click (multi-select)
- **Quick Assignment** - Add or remove collections from all selected assets with one click
- **Visual Feedback** - See which collections are fully assigned, partially assigned, or available
- **Unavailable Asset Cleanup** - Sort unavailable assets to the top and permanently remove selected entries from the Asset Library without deleting project files

To open the Collection Management dialog:

- Click "Manage Collections" button in the Collections tab
- Right-click an asset and select "Manage Collections"

### Settings Panel

#### General Settings

- **Preview Material** - Choose your own Material3D resource or disable preview materials entirely
- **Plane Material** - Customize the appearance of the plane used in Plane Placement Mode (Project-level setting)
- **Transform Step** - Configure the amount of rotation/scale applied per Mouse Wheel step
  - Rotation Step (default: 5 degrees)
  - Scale/Translate Step (default: 0.1 units)
- **Thumbnail UI Scale** - Adjust the size of thumbnails in the Assets Panel (default: 1.0)
- **Regenerate Thumbnails** - Rebuild generated asset previews from Settings when needed
- **Asset Palette Item Scale** - Adjust the size of palette buttons in both the Palette tab and viewport overlay (default: 1.0)
- **Auto Grid from Collection Filter** - Enable automatic Grid Snapping for a single filtered wall, floor, or ceiling collection; configure independent U/V steps for each type (defaults: Wall 2 × 2, Floor/Ceiling 4 × 4). Collection names must start with wall/walls, floor/floors, or ceiling/ceilings and use a separator when further text follows, e.g. walls_pack.
- **Plane Mode Toggle** - Configure plane placement mode behavior
- **Grid Step** - Set the square Plane Placement grid size from 0.01 to 1000 world units
- **Asset Library Path** - Set a custom location for the `asset_library.json` file, useful for version control and team sharing

#### Key Bindings

Customize shortcuts for all Asset Placer actions:

- Rotate (Default: `E`)
- Scale (Default: `R`)
- Translate (Default: `W`)
- Cycle Placement Modes (Default: `Q`)
- Toggle Snapping (Default: `S`)
- Toggle Grid Brush (Default: `B`)
- Toggle X, Y, Z Axis (Default: `X`, `Y`, `Z`)
- Transform Apply (Default: Mouse Wheel Up/Down; optional rotation drag: `Alt+LMB`)
- In Place Transform Mode (Default: `Shift+E`)
- Palette Next (Default: `Tab`)
- Palette Previous (Default: `Shift+Tab`)
- Toggle Asset Placer (Default: `Shift+A`)

Key bindings support Mouse Button and Modifier Combinations (Ctrl, Shift, Alt), allowing you to avoid conflicts with existing Godot shortcuts. The Settings Panel includes conflict detection that will highlight conflicting keys in red.

All settings are persisted across Godot sessions within EditorSettings and apply to all your projects.

The Settings Panel also provides **Drag to Rotate (Alt+LMB)** and **Drag Sensitivity**. Drag rotation affects both asset previews and In Place Transform Mode; it replaces Mouse Wheel only for rotation, while scale and translation keep their configured positive/negative transform bindings.

## Known Issues

- Some generated thumbnails may still look imperfect depending on asset complexity, materials, and scene setup

## Changelog
