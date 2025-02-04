# Cursor Grid Teleport

_A blazingly fast keyboard cursor positioning plugin that uses a fixed and predictable grid making it easy to develop muscle memory._

## Overview

**Cursor Grid Teleport** is an AwesomeWM plugin that allows users to quickly reposition the mouse cursor using a predefined, fixed grid layout on the screen. By activating a dedicated "Cursor Mode", users can press keys corresponding to specific screen sections to instantly move the cursor there. The plugin integrates a transparent grid overlay, providing clear visual feedback of the current grid layout.

This predictable grid layout helps in building muscle memory, enabling fast and efficient cursor repositioning without the need to visually locate target areas on the screen.

<https://github.com/user-attachments/assets/5a85f07f-f2bc-4139-a8fd-7ca40b02fd55>

## Features

- **Cursor Mode for Instant Cursor Positioning:**  
  A single key teleports your mouse cursor to a specific grid section.

- **Transparent Grid Overlay:**  
  Displays a semi-transparent grid with labels while in Cursor Mode to guide cursor movement.

- **Precise Click Mode for Fine Control:**  
  In addition to the basic mode, a two-step precise click mode refines cursor positioning for enhanced accuracy. The first key press teleports the cursor to an approximate target area using the main grid, then a secondary scaled grid—centered on the cursor’s current position—is displayed. Pressing a second key allows for fine adjustment before a mouse click is executed.

- **Muscle Memory Friendly:**  
  Fixed grid layout makes it easier to develop muscle memory for fast cursor navigation.

- **Easy Activation/Deactivation:**  
  Toggle the Cursor Mode using a single key combination.

## Roadmap

- **Basic Configuration:**  
  Allow user to define their preferred shortcut and teleport keys.

- **Precise Click Mode Enhancements:**  
  Further improvements to refine the precise click mode and integrate with various screen configurations.

- **Theming and Style Customization via AwesomeWM `beautiful`:**  
  Integrate styling options with AwesomeWM’s theming system, allowing customization of colors, fonts, and transparency via a simple configuration Lua table.

- **Dynamic Grid Geometry for Multi-monitor Setups:**  
  Implement dynamic updates to the grid geometry to accommodate multi-monitor configurations and resolution changes.

- **Expanded Functionality and Custom Shortcuts:**  
  Add support for additional keyboard shortcuts, customizable grid layouts, and extended actions for specific grid cells.

## Usage

1. **Activate the Cursor Mode:**  
   Press `Mod4 + Shift + u` to display a transparent grid overlay showing the available teleport keys. Press a teleport key to instantly move the cursor to the center of the selected cell.

2. **Activate the Precise Click Mode:**  
   Press `Mod4 + Shift + i` to start the two-step precise click process:

   - **Step 1:** The first key press moves the cursor to an approximate location using the main grid and then hides it.
   - **Step 2:** A secondary, scaled grid overlay is displayed, centered around the current cursor position. Press another key to fine-tune the cursor position before a mouse click is executed.

3. **Deactivate Modes:**  
   Both modes automatically deactivate after moving the cursor or clicking, or if you press the `Escape` key.

## Installation

1. Clone or download the repository into your AwesomeWM configuration directory. For example:

   ```bash
   git clone https://github.com/yourusername/cursor-grid-teleport.git ~/.config/awesome/cursor-grid-teleport
   ```

2. Ensure all required dependencies are installed (`awful`, `gears`, `naughty`, `wibox`, `lgi`, etc.). These are typically included with AwesomeWM or can be installed via your package manager.

3. Add or update your AwesomeWM configuration to include the plugin. In your `rc.lua` or equivalent configuration file, require the plugin:

   ```lua
   require("cursor-grid-teleport")
   ```

4. Reload AwesomeWM to apply changes.

## Configuration

You can customize various aspects of the plugin directly in the `init.lua` file:

### Grid Appearance

Adjust `bg` in the `grid_wibox` definition for background color/transparency.

```lua
local grid_wibox = wibox({
  ...
 bg = "#0000b0" .. "44",
})
```

### Grid Labels Appearance

Change `cr:set_source_rgba()` and `cr:set_font_size()` values in the drawing function to modify line/text colors, font size, and now outline styling for labels. For instance, the drawing code now creates a text path, strokes the outline (e.g., in black), and then fills the text:

```lua
-- Grid Labels
cr:select_font_face("Sans", cairo_lgi.FontSlant.NORMAL, cairo_lgi.FontWeight.BOLD)
cr:set_font_size(60)
-- Fill color: R, G, B, Alpha (0-1)
local fill_r, fill_g, fill_b, fill_a = 1, 1, 0, 0.5
-- Outline color: R, G, B, Alpha (0-1)
local outline_r, outline_g, outline_b, outline_a = 0, 0, 0, 1

```

### Keybindings

```lua
-- Global bindings
local globalkeys = gears.table.join(
  awful.key(
    { "Mod4", "Shift" },
    "u",
    toggle_cursor_mode,
    { description = "Activate Cursor Mode", group = "custom" }
  ),
  awful.key(
    { "Mod4", "Shift" },
    "i",
    toggle_cursor_mode_with_click,
    { description = "Activate Precise Click Mode", group = "custom" }
  )
)
```

### Grid Size and Teleport Keys

The grid layout is defined in the `teleport_keys` table. Modify this table to change the keys or grid structure.

```lua
local teleport_keys = {
  { "q", "w", "e", "r", "t", "y", "u", "i", "o", "p" },
  { "a", "s", "d", "f", "g", "h", "j", "k", "l", "~" },
  { "z", "x", "c", "v", "b", "n", "m", ",", ".", "/" },
}
```

### Special Keys Handling

```lua
-- Special keys handling
if key == "dead_tilde" or key == "asciitilde" then
  key = "~"
end
```

## Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](https://github.com/lpanebr/awesomewm-cursor-teleport/issues) if you want to contribute.

1. Fork the repository.
2. Create a new branch (`git checkout -b feature/YourFeature`).
3. Commit your changes (`git commit -am 'Add new feature'`).
4. Push the branch (`git push origin feature/YourFeature`).
5. Open a pull request.

## License

Distributed under the MIT License. See `LICENSE` for more information.
