# ![icon](easy-move-resize/Images.xcassets/AppIcon.appiconset/icon_32x32.png) Easy Move+Resize

Adds easy `modifier key + mouse drag` move and resize to OSX

## Usage
**Easy Move+Resize** is based on behavior found in many X11/Linux window managers

* `Cmd + Ctrl + Left Mouse` anywhere inside a window, then drag to ***move***.
* `Cmd + Ctrl + Right Mouse` anywhere inside a window, then drag to ***resize***,
    * The resize direction is determined by which region of the window is clicked.  *i.e.* a right-click in roughly the top-left corner of a window will act as if you grabbed the top left corner, whereas a right-click in roughly the top-center of a window will act as if you grabbed the top of the window.
    * The choice for using middle mouse button as resize modifier can be selected in the menu.
* The choice of modifier keys to hold down to activate dragging or resizing can be customized by toggling the appropriate modifier key name in the application icon menu.
    * Click the menu item to toggle it.
    * All keys toggled to selected must be held down for activation.
* Behavior can be disabled by toggling the `Disabled` item in the application icon menu.
* If you are dragging or resizing a window in the background and want it to rise to the top, select the `Bring Window to Front` menu item.
* To restore application settings select the `Reset to Defaults` menu item.

## Installation

### brew

```
brew cask install easy-move-plus-resize
```

### manually

* Grab the latest version from the [Releases page](https://github.com/dmarcotte/easy-move-resize/releases)
* Unzip and run!
* Select **Exit** from the application icon to quit

    ![Icon](asset-sources/doc-img/running-icon.png)

    ![Icon Exit](asset-sources/doc-img/running-icon-exit.png)

## Contributing

[Contributions](contributing.md) welcome!
