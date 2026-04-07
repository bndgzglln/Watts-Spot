import Foundation

public struct ApplianceShortcut: Identifiable, Codable, Hashable {
    public let id: UUID
    public var name: String
    public var taskType: TaskType
    public var durationMinutes: Int
    
    public enum TaskType: Codable, Hashable, Identifiable {
        case predefined(PredefinedType)
        case custom(String)
        
        public enum PredefinedType: String, Codable, CaseIterable, Identifiable {
            case shortCycle = "short"
            case hotCycle = "hot"
            case refreshCycle = "refresh"
            case normal = "normal"
            case intensive = "intensive"
            
            public var id: String { rawValue }
            
            public var titleKey: String {
                switch self {
                case .shortCycle: return "scheduler.task_type_short"
                case .hotCycle: return "scheduler.task_type_hot"
                case .refreshCycle: return "scheduler.task_type_refresh"
                case .normal: return "scheduler.task_type_normal"
                case .intensive: return "scheduler.task_type_intensive"
                }
            }
        }
        
        public static var allCases: [TaskType] {
            PredefinedType.allCases.map { .predefined($0) }
        }
        
        public static var customCases: [TaskType] {
            [.predefined(.shortCycle), .predefined(.hotCycle), .predefined(.refreshCycle), .predefined(.normal), .predefined(.intensive), .custom("")]
        }
        
        public var id: String {
            switch self {
            case .predefined(let type): return type.id
            case .custom(let text): return "custom_\(text)"
            }
        }
        
        public var titleKey: String {
            switch self {
            case .predefined(let type): return type.titleKey
            case .custom: return "scheduler.task_type_custom"
            }
        }
        
        public var displayText: String {
            switch self {
            case .predefined(let type):
                return L10n.text(type.titleKey)
            case .custom(let text):
                return text
            }
        }
        
        public var isCustom: Bool {
            if case .custom = self { return true }
            return false
        }
    }
    
    public init(id: UUID = UUID(), name: String, taskType: TaskType, durationMinutes: Int) {
        self.id = id
        self.name = name
        self.taskType = taskType
        self.durationMinutes = durationMinutes
    }
    
    public var durationFormatted: String {
        if durationMinutes < 60 {
            return "\(durationMinutes) min"
        } else {
            let hours = durationMinutes / 60
            let minutes = durationMinutes % 60
            if minutes == 0 {
                return "\(hours) h"
            }
            return "\(hours) h \(minutes) min"
        }
    }
}

public struct CheapestWindow: Identifiable {
    public let id = UUID()
    public let startTime: Date
    public let endTime: Date
    public let entries: [SpotPrice]
    
    public init(startTime: Date, endTime: Date, entries: [SpotPrice]) {
        self.startTime = startTime
        self.endTime = endTime
        self.entries = entries
    }
    
    public var durationMinutes: Int {
        Int(endTime.timeIntervalSince(startTime) / 60)
    }
    
    public var averagePricePerKWh: Double {
        guard !entries.isEmpty else { return 0 }
        return entries.map(\.pricePerKWh).reduce(0, +) / Double(entries.count)
    }
    
    public var minPricePerKWh: Double {
        entries.map(\.pricePerKWh).min() ?? 0
    }
    
    public var maxPricePerKWh: Double {
        entries.map(\.pricePerKWh).max() ?? 0
    }
    
    public var averagePriceText: String {
        (averagePricePerKWh * 100).formatted(.number.precision(.fractionLength(2)))
    }
    
    public var minPriceText: String {
        (minPricePerKWh * 100).formatted(.number.precision(.fractionLength(2)))
    }
    
    public var maxPriceText: String {
        (maxPricePerKWh * 100).formatted(.number.precision(.fractionLength(2)))
    }
    
    public var startTimeFormatted: String {
        startTime.formatted(.dateTime.hour().minute())
    }
    
    public var endTimeFormatted: String {
        endTime.formatted(.dateTime.hour().minute())
    }
    
    public var timeRangeText: String {
        "\(startTimeFormatted) - \(endTimeFormatted)"
    }
}
