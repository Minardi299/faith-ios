import SwiftUI

struct ProfileToolbarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    ProfileView()
                } label: {
                    Image(systemName: "person.crop.circle")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

extension View {
    func profileToolbar() -> some View {
        modifier(ProfileToolbarModifier())
    }
}
