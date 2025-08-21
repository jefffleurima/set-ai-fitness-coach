import Foundation

/// Speech priority levels for gym coaching scenarios
enum SpeechPriority: Int, CaseIterable, Comparable {
    /// Immediate interrupt - stops all speech immediately (safety/form corrections)
    case immediateInterrupt = 0
    
    /// Immediate blocking - stops current speech, blocks new low-priority speech
    case immediateBlocking = 1
    
    /// Normal priority - standard coaching feedback
    case normal = 2
    
    /// Low priority - background encouragement, can be interrupted
    case low = 3
    
    static func < (lhs: SpeechPriority, rhs: SpeechPriority) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    var description: String {
        switch self {
        case .immediateInterrupt:
            return "Immediate Interrupt"
        case .immediateBlocking:
            return "Immediate Blocking"
        case .normal:
            return "Normal"
        case .low:
            return "Low Priority"
        }
    }
    
    /// Whether this priority should interrupt currently playing speech
    var shouldInterrupt: Bool {
        switch self {
        case .immediateInterrupt, .immediateBlocking:
            return true
        case .normal, .low:
            return false
        }
    }
    
    /// Whether this priority should block new speech of lower priority
    var shouldBlock: Bool {
        switch self {
        case .immediateInterrupt, .immediateBlocking:
            return true
        case .normal, .low:
            return false
        }
    }
}

/// Speech request with content and metadata
struct SpeechRequest {
    let id: UUID
    let text: String
    let priority: SpeechPriority
    let timestamp: Date
    let timeout: TimeInterval?
    let completion: ((Bool) -> Void)?
    
    init(text: String, 
         priority: SpeechPriority, 
         timeout: TimeInterval? = nil,
         completion: ((Bool) -> Void)? = nil) {
        self.id = UUID()
        self.text = text
        self.priority = priority
        self.timestamp = Date()
        self.timeout = timeout
        self.completion = completion
    }
}
