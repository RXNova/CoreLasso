import SwiftUI

// MARK: - MD3 Type Scale

/// Material Design 3 typography scale mapped to SF Pro system fonts.
public enum MD3Typography {

    // MARK: Display

    public static let displayLarge  = Font.system(size: 57, weight: .regular)
    public static let displayMedium = Font.system(size: 45, weight: .regular)
    public static let displaySmall  = Font.system(size: 36, weight: .regular)

    // MARK: Headline

    public static let headlineLarge  = Font.system(size: 32, weight: .regular)
    public static let headlineMedium = Font.system(size: 28, weight: .regular)
    public static let headlineSmall  = Font.system(size: 24, weight: .regular)

    // MARK: Title

    public static let titleLarge  = Font.system(size: 22, weight: .regular)
    public static let titleMedium = Font.system(size: 16, weight: .medium)
    public static let titleSmall  = Font.system(size: 14, weight: .medium)

    // MARK: Body

    public static let bodyLarge  = Font.system(size: 16, weight: .regular)
    public static let bodyMedium = Font.system(size: 14, weight: .regular)
    public static let bodySmall  = Font.system(size: 12, weight: .regular)

    // MARK: Label

    public static let labelLarge  = Font.system(size: 14, weight: .medium)
    public static let labelMedium = Font.system(size: 12, weight: .medium)
    public static let labelSmall  = Font.system(size: 11, weight: .medium)
}
