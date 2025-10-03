import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct SplashView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 48) {
                AppIconView(size: 128)
                ProgressView()
                    .progressViewStyle(.circular)
            }
            .padding()
        }
    }
}

private struct AppIconView: View {
    var size: CGFloat = 120

    var body: some View {
        Group {
            #if canImport(UIKit)
            if let icon = AppIconProvider.iconImage() {
                Image(uiImage: icon)
                    .resizable()
                    .scaledToFit()
            } else {
                fallbackIcon
            }
            #else
            fallbackIcon
            #endif
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 8)
    }

    private var fallbackIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.secondary.opacity(0.12))
            Image(systemName: "app.fill")
                .resizable()
                .scaledToFit()
                .padding(28)
                .symbolRenderingMode(.hierarchical)
                
        }
    }
}

private enum AppIconProvider {
    #if canImport(UIKit)
    static func iconImage() -> UIImage? {
        guard let iconsDict = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
              let primaryIcon = iconsDict["CFBundlePrimaryIcon"] as? [String: Any],
              let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
              let iconName = iconFiles.last else {
            return nil
        }
        return UIImage(named: iconName)
    }
    #else
    static func iconImage() -> Any? { nil }
    #endif
}

#if DEBUG
#Preview("SplashView") {
    SplashView()
}
#endif
