import SwiftUI

/// Minimal Line v2 icon geometry.
/// All paths are designed on a 24×24 artboard.
/// stroke-width: 1.75, stroke-linecap: round, stroke-linejoin: round, fill: none
enum WeatherIconPaths {

    // MARK: – Sun
    /// Full circle + 8 rays
    static func sunPath(in rect: CGRect) -> Path {
        var path = Path()
        let cx = rect.midX, cy = rect.midY
        let s = rect.width / 24

        // Circle radius 4.5
        path.addArc(center: CGPoint(x: cx, y: cy),
                    radius: 4.5 * s,
                    startAngle: .degrees(0),
                    endAngle: .degrees(360),
                    clockwise: false)

        // 8 rays at 45° increments, inner r=6.5, outer r=9
        for i in 0..<8 {
            let angle = Double(i) * 45.0 * .pi / 180.0
            let inner = CGPoint(x: cx + cos(angle) * 6.5 * s,
                                y: cy + sin(angle) * 6.5 * s)
            let outer = CGPoint(x: cx + cos(angle) * 9.0 * s,
                                y: cy + sin(angle) * 9.0 * s)
            path.move(to: inner)
            path.addLine(to: outer)
        }
        return path
    }

    // MARK: – Cloud base (smooth, restrained)
    static func cloudPath(in rect: CGRect, xOffset: CGFloat = 0, yOffset: CGFloat = 2) -> Path {
        var path = Path()
        let s = rect.width / 24
        let ox = rect.minX + xOffset * s
        let oy = rect.minY + yOffset * s

        // Cloud base: smooth bezier
        // Bottom line: left 5 to right 19
        // Right arc: 19,17 -> 19,13 radius 2
        // Top right bump: 15,11 radius 4 (large arc)
        // Top left small bump: 9,11 radius 3
        // Left side: back to start
        path.move(to: CGPoint(x: ox + 5.5 * s, y: oy + 17 * s))
        path.addArc(center: CGPoint(x: ox + 5.5 * s, y: oy + 14.5 * s),
                    radius: 2.5 * s, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: true)
        path.addArc(center: CGPoint(x: ox + 9.0 * s, y: oy + 11.0 * s),
                    radius: 3.5 * s, startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
        path.addArc(center: CGPoint(x: ox + 14.5 * s, y: oy + 11.5 * s),
                    radius: 4.0 * s, startAngle: .degrees(210), endAngle: .degrees(340), clockwise: false)
        path.addArc(center: CGPoint(x: ox + 17.5 * s, y: oy + 14.5 * s),
                    radius: 2.5 * s, startAngle: .degrees(340), endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: ox + 5.5 * s, y: oy + 17 * s))
        return path
    }

    // MARK: – Rain drops (perfectly vertical)
    static func rainDrops(in rect: CGRect, count: Int, startY: CGFloat = 18.5, spacing: CGFloat = 3.5) -> Path {
        var path = Path()
        let s = rect.width / 24
        let totalWidth = CGFloat(count - 1) * spacing
        let startX = 12.0 - totalWidth / 2.0

        for i in 0..<count {
            let x = startX + Double(i) * Double(spacing)
            let yTop = Double(startY)
            let yBot = yTop + 2.5
            path.move(to: CGPoint(x: rect.minX + x * s, y: rect.minY + yTop * s))
            path.addLine(to: CGPoint(x: rect.minX + x * s, y: rect.minY + yBot * s))
        }
        return path
    }

    // MARK: – Snow dots
    static func snowFlake(in rect: CGRect) -> Path {
        var path = Path()
        let cx = rect.midX, cy = rect.minY + 18 * (rect.width / 24)
        let s = rect.width / 24

        // 6-spoke snowflake
        for i in 0..<6 {
            let angle = Double(i) * 60.0 * .pi / 180.0
            let inner = CGPoint(x: cx, y: cy)
            let outer = CGPoint(x: cx + cos(angle) * 2.5 * s,
                                y: cy + sin(angle) * 2.5 * s)
            path.move(to: inner)
            path.addLine(to: outer)
        }

        // Small crossbar ticks on each spoke
        for i in 0..<6 {
            let angle = Double(i) * 60.0 * .pi / 180.0
            let perpAngle = angle + .pi / 2
            let midDist: CGFloat = 1.4 * s
            let tickLen: CGFloat = 0.6 * s
            let midPt = CGPoint(x: cx + cos(angle) * midDist,
                                y: cy + sin(angle) * midDist)
            path.move(to: CGPoint(x: midPt.x + cos(perpAngle) * tickLen,
                                  y: midPt.y + sin(perpAngle) * tickLen))
            path.addLine(to: CGPoint(x: midPt.x - cos(perpAngle) * tickLen,
                                     y: midPt.y - sin(perpAngle) * tickLen))
        }
        return path
    }
}
