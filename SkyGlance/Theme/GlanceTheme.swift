import SwiftUI

struct GlanceTheme {
    let primaryText: Color
    let secondaryText: Color
    let containerBackground: AnyShapeStyle
    let widgetBackground: AnyShapeStyle
    let glassCardFill: AnyShapeStyle
    let glassHighlight: AnyShapeStyle
    let glassStroke: Color
    let cardShadow: Color

    init(
        primaryText: Color,
        secondaryText: Color,
        containerBackground: some ShapeStyle,
        widgetBackground: some ShapeStyle,
        glassCardFill: some ShapeStyle,
        glassHighlight: some ShapeStyle,
        glassStroke: Color,
        cardShadow: Color
    ) {
        self.primaryText = primaryText
        self.secondaryText = secondaryText
        self.containerBackground = AnyShapeStyle(containerBackground)
        self.widgetBackground = AnyShapeStyle(widgetBackground)
        self.glassCardFill = AnyShapeStyle(glassCardFill)
        self.glassHighlight = AnyShapeStyle(glassHighlight)
        self.glassStroke = glassStroke
        self.cardShadow = cardShadow
    }
}
