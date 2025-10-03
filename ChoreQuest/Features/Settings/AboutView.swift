import SwiftUI

struct AboutView: View {
    private var appName: String {
        if let display = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, !display.isEmpty {
            return display
        }
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "App"
    }
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    Image(systemName: "app.gift.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.tint)
                        .padding(.bottom, 4)
                    Text(appName)
                        .font(.title2.bold())
                    Text("Version \(version)")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }

            Section("Credits") {
                LabeledContent("Design & Development") {
                    Link("RezPoint Inc.", destination: URL(string: "https://rezpoint.xyz/")!)
                }
                LabeledContent("Icons:") {
                    VStack(alignment: .trailing, spacing: 6) {
                        Link("Icons8", destination: URL(string: "https://icons8.com/")!)
                    }
                }
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
#Preview("About") {
    NavigationStack { AboutView() }
}
#endif
