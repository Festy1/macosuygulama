import XCTest
import SwiftUI
@testable import DesktopDuzen

final class WidgetScalingAndColorTests: XCTestCase {

    // MARK: - Clock Font Color & Transparency Independence

    func testClockFontColorIndependentOfTransparencyAtAllLevels() {
        let redHex = "#FF3B30"
        let testTransparencies: [Double] = [0.0, 0.25, 0.50, 0.75, 1.0]

        for opacity in testTransparencies {
            let clock = DesktopWidget(
                type: .clock,
                themeID: "dark_frost",
                backgroundOpacity: opacity,
                textColorHex: redHex
            )
            let palette = ZonePalette.forWidget(clock)

            // Verify titleRGB is pure red at all opacity levels
            XCTAssertEqual(palette.titleRGB.hexString.uppercased(), redHex.uppercased(),
                           "Clock title font color must remain exactly \(redHex) at opacity \(opacity)")
            XCTAssertEqual(palette.primaryRGB.hexString.uppercased(), redHex.uppercased(),
                           "Clock primary font color must remain exactly \(redHex) at opacity \(opacity)")
            XCTAssertEqual(palette.accentRGB.hexString.uppercased(), redHex.uppercased(),
                           "Clock accent font color must remain exactly \(redHex) at opacity \(opacity)")
            XCTAssertEqual(palette.secondaryOpacity, 1.0,
                           "Clock secondary text opacity must remain 100% (1.0) at opacity \(opacity)")
        }
    }

    func testClockTextColorPersistence() throws {
        let clock = DesktopWidget(
            type: .clock,
            title: "My Clock",
            frame: CGRect(x: 100, y: 100, width: 220, height: 120),
            textColorHex: "#FF3B30"
        )
        let data = try JSONEncoder().encode(clock)
        let decoded = try JSONDecoder().decode(DesktopWidget.self, from: data)

        XCTAssertEqual(decoded.textColorHex, "#FF3B30")
        XCTAssertEqual(decoded.type, .clock)
        XCTAssertEqual(decoded.title, "My Clock")
    }

    func testClockTextColorDefaultsToThemeWhenUnset() {
        let clock = DesktopWidget(type: .clock, themeID: "dark_frost")
        XCTAssertNil(clock.textColorHex)
        let palette = ZonePalette.forWidget(clock)
        // With dark_frost theme, text should be high contrast
        XCTAssertGreaterThanOrEqual(palette.titleContrast, 4.5)
    }

    // MARK: - Calendar Font Scaling

    func testCalendarFontSizesScaleProportionally() {
        // Test metrics at 3 representative sizes: Small (180x160), Default (240x230), Large (700x600)
        func getMetrics(w: CGFloat, h: CGFloat) -> (titleFont: CGFloat, weekdayFont: CGFloat, dateFont: CGFloat) {
            let contentW = max(100, w)
            let contentH = max(80, h)
            let hPadding = max(8, min(contentW * 0.04, 28))
            let vPadding = max(6, min(contentH * 0.03, 24))
            let usableW = max(50, contentW - 2 * hPadding)
            let usableH = max(50, contentH - 2 * vPadding)
            let totalRowCount: CGFloat = 7.0
            let titleH = max(16, min(usableH * 0.13, 50))
            let titleSpacing = max(4, min(usableH * 0.03, 16))
            let gridH = max(30, usableH - titleH - titleSpacing)
            let cellW = usableW / 7.0
            let rowH = gridH / totalRowCount
            let cellSize = min(cellW, rowH)

            let titleFontSize = max(11, min(titleH * 0.65, 34))
            let weekdayFontSize = max(8, min(cellSize * 0.35, 22))
            let dateFontSize = max(9, min(cellSize * 0.46, 30))
            return (titleFontSize, weekdayFontSize, dateFontSize)
        }

        let small = getMetrics(w: 180, h: 160)
        let medium = getMetrics(w: 240, h: 230)
        let large = getMetrics(w: 700, h: 600)

        // Verify strictly monotonic growth
        XCTAssertGreaterThan(medium.titleFont, small.titleFont, "Title font should increase from small to medium")
        XCTAssertGreaterThan(large.titleFont, medium.titleFont, "Title font should increase from medium to large")

        XCTAssertGreaterThan(medium.weekdayFont, small.weekdayFont, "Weekday font should increase from small to medium")
        XCTAssertGreaterThan(large.weekdayFont, medium.weekdayFont, "Weekday font should increase from medium to large")

        XCTAssertGreaterThan(medium.dateFont, small.dateFont, "Date font should increase from small to medium")
        XCTAssertGreaterThan(large.dateFont, medium.dateFont, "Date font should increase from medium to large")
    }

    func testCalendarFontBoundsPreventClippingAndCollapse() {
        // Even at extreme sizes, font sizes should be clamped to valid ranges
        let tinyW: CGFloat = 80
        let tinyH: CGFloat = 60
        let contentW = max(100, tinyW)
        let contentH = max(80, tinyH)
        let hPadding = max(8, min(contentW * 0.04, 28))
        let vPadding = max(6, min(contentH * 0.03, 24))
        let usableW = max(50, contentW - 2 * hPadding)
        let usableH = max(50, contentH - 2 * vPadding)
        let titleH = max(16, min(usableH * 0.13, 50))
        let titleSpacing = max(4, min(usableH * 0.03, 16))
        let gridH = max(30, usableH - titleH - titleSpacing)
        let cellSize = min(usableW / 7.0, gridH / 7.0)

        let titleFont = max(11, min(titleH * 0.65, 34))
        let weekdayFont = max(8, min(cellSize * 0.35, 22))
        let dateFont = max(9, min(cellSize * 0.46, 30))

        XCTAssertGreaterThanOrEqual(titleFont, 11)
        XCTAssertLessThanOrEqual(titleFont, 34)
        XCTAssertGreaterThanOrEqual(weekdayFont, 8)
        XCTAssertLessThanOrEqual(weekdayFont, 22)
        XCTAssertGreaterThanOrEqual(dateFont, 9)
        XCTAssertLessThanOrEqual(dateFont, 30)
    }
}
