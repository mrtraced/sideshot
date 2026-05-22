import SwiftUI

/// Lightweight hover tooltip with a configurable short delay.
/// macOS `.help()` uses the system delay (~2s) which is too long when the
/// tooltip is the primary way to read a truncated path. This modifier shows
/// a small floating label after ~0.4s of hover.
struct QuickHelp: ViewModifier {
    let text: String
    let delay: Double

    @State private var isHovering = false
    @State private var shouldShow = false
    @State private var task: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                task?.cancel()
                if hovering {
                    isHovering = true
                    task = Task {
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        if !Task.isCancelled {
                            await MainActor.run { shouldShow = true }
                        }
                    }
                } else {
                    isHovering = false
                    shouldShow = false
                }
            }
            .overlay(alignment: .bottom) {
                if shouldShow {
                    Text(text)
                        .font(.system(size: 11))
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color(nsColor: .controlBackgroundColor))
                                .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(Color.black.opacity(0.08))
                        )
                        .offset(y: 22)
                        .fixedSize(horizontal: true, vertical: false)
                        .zIndex(999)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.12), value: shouldShow)
    }
}

extension View {
    /// Hover tooltip with a short delay. Use for cases where `.help()` (system
    /// delay) is too slow — e.g., paths truncated in dense grids.
    func quickHelp(_ text: String, delay: Double = 0.4) -> some View {
        modifier(QuickHelp(text: text, delay: delay))
    }
}
