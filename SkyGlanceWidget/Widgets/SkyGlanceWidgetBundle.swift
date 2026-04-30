import WidgetKit
import SwiftUI

@main
struct SkyGlanceWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Lock Screen
        GlanceInlineWidget()
        GlanceCircularWidget()
        GlanceLockScreenWidget()

        // Home Screen
        GlanceHomeSmallWidget()
        GlanceHomeMediumWidget()
    }
}
