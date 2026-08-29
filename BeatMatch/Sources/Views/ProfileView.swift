import SwiftUI

struct ProfileView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("About Pitchwire") {
                    Text("Slice 0 build — local-only, sample journalist data. See ARCHITECTURE.md for what's next.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Profile")
        }
    }
}
