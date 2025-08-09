import SwiftUI
import UIKit

struct MessagesView: View {
    @StateObject private var viewModel = AICoachViewModel()
    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool
    @State private var textEditorHeight: CGFloat = 36
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0.0) {
                // Chat messages list with performance optimizations
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.messages) { message in
                                ChatBubble(message: message)
                                    .id(message.id)
                                    .transition(.asymmetric(
                                        insertion: .scale.combined(with: .opacity),
                                        removal: .opacity
                                    ))
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .onChange(of: viewModel.messages) { oldValue, newValue in
                        if let lastMessage = newValue.last {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                    .onTapGesture {
                        // Dismiss keyboard when tapping on the chat area
                        isInputFocused = false
                    }
                }
                .background(AppTheme.background.ignoresSafeArea())
                
                // Message input with performance optimizations
                VStack(spacing: 0) {
                    Divider()
                    HStack(alignment: .bottom, spacing: 8) {
                        ZStack(alignment: .leading) {
                            AutoGrowingTextEditor(text: $messageText, dynamicHeight: $textEditorHeight, minHeight: 36, maxHeight: 120)
                                .frame(height: textEditorHeight)
                                .padding(.horizontal, 12)
                                .background(AppTheme.surface)
                                .foregroundColor(AppTheme.text)
                                .clipShape(
                                    textEditorHeight <= 44
                                    ? AnyShape(Capsule())
                                    : AnyShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                )
                                .focused($isInputFocused)
                            
                            if messageText.isEmpty {
                                Text("Ask your coach anything...")
                                    .foregroundColor(AppTheme.text.opacity(0.4))
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .allowsHitTesting(false)
                                    .onTapGesture {
                                        isInputFocused = true
                                    }
                            }
                        }
                        
                        // Send button with loading state
                        Button(action: sendMessage) {
                            ZStack {
                                if viewModel.isProcessing {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.text.opacity(0.3)))
                                } else {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 28))
                                }
                            }
                            .foregroundColor(viewModel.isProcessing ? AppTheme.text.opacity(0.3) : AppTheme.primary)
                        }
                        .disabled(messageText.isEmpty || viewModel.isProcessing)
                        .padding(.trailing, 8)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(AppTheme.background)
                }
            }
            .navigationTitle("AI Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showMemoryStats() }) {
                            Label("Memory Stats", systemImage: "brain")
                        }
                        
                        Button(action: { clearMemory() }) {
                            Label("Clear Memory", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(AppTheme.primary)
                    }
                }
                
                // Add keyboard dismiss button
                ToolbarItem(placement: .keyboard) {
                    Button("Done") {
                        isInputFocused = false
                    }
                    .foregroundColor(AppTheme.primary)
                }
            }
            .onAppear {
                // Configure navigation bar appearance for better readability
                let appearance = UINavigationBarAppearance()
                appearance.configureWithOpaqueBackground()
                appearance.backgroundColor = UIColor(AppTheme.background)
                appearance.titleTextAttributes = [
                    .foregroundColor: UIColor(AppTheme.text),
                    .font: UIFont.systemFont(ofSize: 18, weight: .semibold)
                ]
                appearance.largeTitleTextAttributes = [
                    .foregroundColor: UIColor(AppTheme.text),
                    .font: UIFont.systemFont(ofSize: 24, weight: .bold)
                ]
                
                UINavigationBar.appearance().standardAppearance = appearance
                UINavigationBar.appearance().scrollEdgeAppearance = appearance
                UINavigationBar.appearance().compactAppearance = appearance
            }
            .onTapGesture {
                // Dismiss keyboard when tapping anywhere on the view
                isInputFocused = false
            }
        }
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        let text = messageText
        messageText = ""
        textEditorHeight = 36
        viewModel.sendMessage(text)
    }
    
    private func showMemoryStats() {
        let stats = viewModel.getMemoryStats()
        print("Memory Stats: \(stats)")
        // TODO: Show memory stats in a sheet or alert
    }
    
    private func clearMemory() {
        viewModel.clearMemory()
        // TODO: Show confirmation
    }
}

struct ChatBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.system(size: 16))
                    .foregroundColor(message.isUser ? .white : AppTheme.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(message.isUser ? AppTheme.primary : AppTheme.surface)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                
                // Show timestamp for all messages
                Text(formatTimestamp(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(AppTheme.text.opacity(0.6))
                    .padding(.horizontal, 4)
                
                if message.type == .typing {
                    TypingIndicator()
                }
            }
            
            if !message.isUser {
                Spacer()
            }
        }
        .padding(.horizontal, 4)
        .animation(.easeInOut(duration: 0.2), value: message.text)
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            // Today: show time only (e.g., "8:14 PM")
            formatter.timeStyle = .short
            formatter.dateStyle = .none
        } else if calendar.isDateInYesterday(date) {
            // Yesterday: show "Yesterday" and time
            return "Yesterday \(formatter.string(from: date))"
        } else if calendar.dateInterval(of: .weekOfYear, for: Date())?.contains(date) == true {
            // This week: show day name and time
            formatter.dateFormat = "EEEE h:mm a"
        } else {
            // Older: show date and time
            formatter.dateFormat = "MMM d, h:mm a"
        }
        
        return formatter.string(from: date)
    }
}

struct TypingIndicator: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(AppTheme.text.opacity(0.3))
                    .frame(width: 6, height: 6)
                    .offset(y: animationOffset)
                    .animation(
                        Animation.easeInOut(duration: 0.5)
                            .repeatForever()
                            .delay(0.2 * Double(index)),
                        value: animationOffset
                    )
            }
        }
        .onAppear {
            animationOffset = -5
        }
    }
}

struct PencilShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let pointLength: CGFloat = 10
        
        path.move(to: CGPoint(x: rect.minX + pointLength, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - pointLength, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX - pointLength, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + pointLength, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        
        return path
    }
}

struct AutoGrowingTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var dynamicHeight: CGFloat
    var minHeight: CGFloat = 36
    var maxHeight: CGFloat = 120
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.delegate = context.coordinator
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        AutoGrowingTextEditor.recalculateHeight(view: uiView, result: context.coordinator)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, height: $dynamicHeight, minHeight: minHeight, maxHeight: maxHeight)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var text: Binding<String>
        var height: Binding<CGFloat>
        let minHeight: CGFloat
        let maxHeight: CGFloat
        
        init(text: Binding<String>, height: Binding<CGFloat>, minHeight: CGFloat, maxHeight: CGFloat) {
            self.text = text
            self.height = height
            self.minHeight = minHeight
            self.maxHeight = maxHeight
        }
        
        func textViewDidChange(_ textView: UITextView) {
            text.wrappedValue = textView.text
            AutoGrowingTextEditor.recalculateHeight(view: textView, result: self)
        }
    }
    
    static func recalculateHeight(view: UITextView, result: Coordinator) {
        let size = view.sizeThatFits(CGSize(width: view.bounds.width, height: CGFloat.greatestFiniteMagnitude))
        let newHeight = min(max(size.height, result.minHeight), result.maxHeight)
        if result.height.wrappedValue != newHeight {
            DispatchQueue.main.async {
                result.height.wrappedValue = newHeight
            }
        }
    }
}

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

struct DynamicInputShape: ViewModifier {
    let isSingleLine: Bool
    func body(content: Content) -> some View {
        if isSingleLine {
            content.clipShape(Capsule())
        } else {
            content.cornerRadius(18)
        }
    }
}

struct AnyShape: Shape, @unchecked Sendable {
    private let path: (CGRect) -> Path
    
    init<S: Shape>(_ shape: S) {
        self.path = shape.path(in:)
    }
    
    func path(in rect: CGRect) -> Path {
        path(rect)
    }
}

#Preview {
    MessagesView()
        .onAppear {
            // Add sample messages for testing
            let previewViewModel = AICoachViewModel()
            let now = Date()
            let calendar = Calendar.current
            
            previewViewModel.messages = [
                ChatMessage(id: UUID(), text: "👋 What's up? Ready to crush some goals?", isUser: false, type: .greeting, timestamp: calendar.date(byAdding: .minute, value: -5, to: now) ?? now),
                ChatMessage(id: UUID(), text: "I want to build muscle", isUser: true, timestamp: calendar.date(byAdding: .minute, value: -4, to: now) ?? now),
                ChatMessage(id: UUID(), text: "Let's get it! 💪 What's your current routine?", isUser: false, type: .response, timestamp: calendar.date(byAdding: .minute, value: -3, to: now) ?? now),
                ChatMessage(id: UUID(), text: "I do push-ups and squats", isUser: true, timestamp: calendar.date(byAdding: .minute, value: -2, to: now) ?? now),
                ChatMessage(id: UUID(), text: "Solid foundation! Add pull-ups and deadlifts. You'll see gains in 4 weeks.", isUser: false, type: .response, timestamp: calendar.date(byAdding: .minute, value: -1, to: now) ?? now)
            ]
        }
}

// Preview-friendly text input for testing
struct PreviewTextInput: View {
    @State private var text = ""
    @State private var height: CGFloat = 36
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Test Text Input")
                .font(.headline)
                .foregroundColor(AppTheme.text)
            
            HStack(alignment: .bottom, spacing: 8) {
                ZStack(alignment: .leading) {
                    TextField("Type here to test...", text: $text, axis: .vertical)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppTheme.surface)
                        .foregroundColor(AppTheme.text)
                        .clipShape(
                            height <= 44
                            ? AnyShape(Capsule())
                            : AnyShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        )
                        .lineLimit(1...5)
                    
                    if text.isEmpty {
                        Text("Type here to test...")
                            .foregroundColor(AppTheme.text.opacity(0.4))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }
                
                Button(action: {
                    print("Send: \(text)")
                    text = ""
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(text.isEmpty ? AppTheme.text.opacity(0.3) : AppTheme.primary)
                }
                .disabled(text.isEmpty)
            }
            .padding(.horizontal, 12)
            
            Text("Preview Text Input - This works in previews!")
                .font(.caption)
                .foregroundColor(AppTheme.text.opacity(0.6))
        }
        .padding()
        .background(AppTheme.background)
    }
}

#Preview("Text Input Test") {
    PreviewTextInput()
} 
