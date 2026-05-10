import SwiftUI

struct OnboardingFlow: View {
    @EnvironmentObject private var session: SessionStore
    @State private var step: Step = .tradition
    @State private var draft: AppUser = .sample

    enum Step { case tradition, permissions }

    var body: some View {
        switch step {
        case .tradition:
            TraditionPickerStep(draft: $draft) { step = .permissions }
        case .permissions:
            PermissionPrimingStep(draft: $draft) {
                session.completeOnboarding(with: draft)
            }
        }
    }
}
