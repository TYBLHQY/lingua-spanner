// Shared font size descriptor
// Provides canonical derived sizes from Plasmoid configuration.
// Usage:
//   FontStyle { id: fs }
//   Text { font.pixelSize: fs.base }
//   Label { font.pixelSize: fs.small }

import QtQuick
import org.kde.plasma.plasmoid

QtObject {
    id: root

    /// Base font size in pixels
    readonly property int base: Plasmoid.configuration.fontSizeBase || 14

    /// Custom font family (empty = system default)
    readonly property string family: Plasmoid.configuration.fontFamily || ""

    /// Derived: base + 1
    readonly property int large: base + 1
    /// Derived: base - 2, clamped to min 6
    readonly property int small: Math.max(6, base - 2)
    /// Derived: base - 1, clamped to min 6
    readonly property int secondary: Math.max(6, base - 1)
}
