import SwiftUI

enum AppLayout {
    static let headerHeight: CGFloat = 200
    static let headerTopOffset: CGFloat = 40
    static let maxContentWidth: CGFloat = 640
}

enum AppSpacing {
    static let section: CGFloat = 16
    static let screenPadding: CGFloat = 20
    static let bottomPadding: CGFloat = 32
    static let cardInnerPadding: CGFloat = 20
    static let cardCornerRadius: CGFloat = 28
    static let rowHorizontalPadding: CGFloat = 14
    static let rowVerticalPadding: CGFloat = 10
    static let rowCornerRadius: CGFloat = 16
}

enum AppColors {
    static let background = Color(.systemGroupedBackground)
    static let cardBackground = Color(.systemBackground)
    static let cardBorder = Color.black.opacity(0.05)
    static let cardShadow = Color.black.opacity(0.06)
    static var rowAccent: Color { Color.blue.opacity(0.08) }
}

struct AppGlassBackground: View {
    var body: some View {
        Group {
            if #available(iOS 18.0, macOS 15.0, *) {
                Color.clear.glassEffect()
            } else {
                Color.clear
            }
        }
    }
}

struct AppSectionHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.title3.bold())
            Spacer()
        }
        .padding(.bottom, 4)
    }
}

struct AppCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppSpacing.cardInnerPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius, style: .continuous)
                    .fill(AppColors.cardBackground)
                    .shadow(color: AppColors.cardShadow, radius: 18, y: 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSpacing.cardCornerRadius, style: .continuous)
                            .stroke(AppColors.cardBorder, lineWidth: 0.5)
                    )
            )
            .background(AppGlassBackground())
    }
}

extension View {
    func appCardStyle() -> some View {
        modifier(AppCardStyle())
    }

    func appRowBackground(color: Color = AppColors.rowAccent) -> some View {
        modifier(AppRowBackground(color: color))
    }
}

private struct AppRowBackground: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, AppSpacing.rowHorizontalPadding)
            .padding(.vertical, AppSpacing.rowVerticalPadding)
            .background(
                RoundedRectangle(cornerRadius: AppSpacing.rowCornerRadius, style: .continuous)
                    .fill(color)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.rowCornerRadius, style: .continuous)
                    .stroke(AppColors.cardBorder, lineWidth: 0.5)
            )
    }
}

struct AppScreen<Content: View, Overlay: View>: View {
    private let headerHeight: CGFloat
    private let headerTopOffset: CGFloat
    private let maxContentWidth: CGFloat
    private let contentSpacing: CGFloat
    private let allowsScroll: Bool
    private let showsScrollIndicators: Bool
    private let header: HeaderCard
    private let overlay: () -> Overlay
    private let content: () -> Content

    init(
        headerHeight: CGFloat = AppLayout.headerHeight,
        headerTopOffset: CGFloat = AppLayout.headerTopOffset,
        maxContentWidth: CGFloat = AppLayout.maxContentWidth,
        contentSpacing: CGFloat = AppSpacing.section,
        allowsScroll: Bool = true,
        showsScrollIndicators: Bool = false,
        header: HeaderCard = HeaderCard(),
        @ViewBuilder overlay: @escaping () -> Overlay,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.headerHeight = headerHeight
        self.headerTopOffset = headerTopOffset
        self.maxContentWidth = maxContentWidth
        self.contentSpacing = contentSpacing
        self.allowsScroll = allowsScroll
        self.showsScrollIndicators = showsScrollIndicators
        self.header = header
        self.overlay = overlay
        self.content = content
    }

    var body: some View {
        ZStack(alignment: .top) {
            header
                .ignoresSafeArea(edges: .top)
                .frame(height: headerHeight)
                .zIndex(1000)

            Group {
                if allowsScroll {
                    ScrollView {
                        contentStack
                    }
                    .scrollIndicators(showsScrollIndicators ? .visible : .hidden)
                } else {
                    contentStack
                }
            }
        }
        .overlay(alignment: .top) { overlay() }
        .background(AppColors.background.ignoresSafeArea())
    }

    private var contentStack: some View {
        VStack(spacing: contentSpacing) {
            Color.clear
                .frame(height: max(headerHeight - headerTopOffset, 0))
            content()
        }
        .frame(maxWidth: maxContentWidth)
        .padding(.horizontal, AppSpacing.screenPadding)
        .padding(.bottom, AppSpacing.bottomPadding)
    }
}

extension AppScreen where Overlay == EmptyView {
    init(
        headerHeight: CGFloat = AppLayout.headerHeight,
        headerTopOffset: CGFloat = AppLayout.headerTopOffset,
        maxContentWidth: CGFloat = AppLayout.maxContentWidth,
        contentSpacing: CGFloat = AppSpacing.section,
        allowsScroll: Bool = true,
        showsScrollIndicators: Bool = false,
        header: HeaderCard = HeaderCard(),
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            headerHeight: headerHeight,
            headerTopOffset: headerTopOffset,
            maxContentWidth: maxContentWidth,
            contentSpacing: contentSpacing,
            allowsScroll: allowsScroll,
            showsScrollIndicators: showsScrollIndicators,
            header: header,
            overlay: { EmptyView() },
            content: content
        )
    }
}
