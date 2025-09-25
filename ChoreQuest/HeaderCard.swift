import SwiftUI

// MARK: Header
struct HeaderCard: View {
    @State private var bellWiggle = false

    var body: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(Color(red: 0.0/255.0, green: 153.0/255.0, blue: 255.0/255.0)) // #0099FF
                .frame(height: 320)
                .frame(maxWidth: .infinity)
                .ignoresSafeArea(edges: .top)
                .shadow(color: Color.black.opacity(0.15), radius: 20, y: 10)

            VStack(alignment: .leading, spacing: 20) {
                // Top icons row
                HStack {
                    Spacer()

                    HStack(spacing: 14) {
                        Button(action: {}) {
                            Image(systemName: "bell")
                                .symbolEffect(.bounce, value: bellWiggle)
                                .foregroundStyle(.white)
                                .padding(10)
                                .background(.white.opacity(0.15), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            // playful attention draw on appear
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                bellWiggle.toggle()
                            }
                        }

                        Button(action: {}) {
                            Image(systemName: "gearshape")
                                .foregroundStyle(.white)
                                .padding(10)
                                .background(.white.opacity(0.15), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Welcome Back, KD")
                        .font(.system(.largeTitle, design: .rounded)).bold()
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())

                    Text("Managing 3 children")
                        .foregroundStyle(.white.opacity(0.9))
                }

                NotificationBanner()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 64)
            .safeAreaPadding(.top)
        }
    }
}

struct NotificationBanner: View {
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "megaphone.fill")
                .imageScale(.medium)
                .foregroundStyle(.white)
            Text("You have 2 new notifications")
                .foregroundStyle(.white)
                .font(.headline)
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .foregroundStyle(.white)
                .symbolEffect(.pulse, value: pulse)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.18))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
        )
        .compositingGroup()
        .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
        .onAppear { pulse = true }
        #if os(iOS)
        .hoverEffect(.highlight)
        #endif
    }
}
