import SwiftUI

struct HeaderCard: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(height: 238)
                .frame(maxWidth: .infinity)
                .ignoresSafeArea(edges: .top)
                .shadow(color: Color.black.opacity(0.15), radius: 20, y: 10)

            VStack(alignment: .leading, spacing: 6) {
                Text("Welcome Back, KD")
                    .font(.system(.largeTitle, design: .rounded)).bold()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())

                Text("Managing 3 children")
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 110)
            .safeAreaPadding(.top)
        }
    }
}

#Preview {
    ContentView()
}
