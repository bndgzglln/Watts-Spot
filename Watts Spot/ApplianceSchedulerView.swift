import SwiftUI
import Combine
import SpotPriceKit

struct ApplianceSchedulerView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var viewModel = ApplianceSchedulerViewModel()
    
    private let priceViewModel: PriceViewModel
    
    init(viewModel: PriceViewModel) {
        self.priceViewModel = viewModel
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        quickStartSection
                        shortcutsSection
                    }
                    .padding(20)
                }
            }
            .navigationTitle(L10n.text("scheduler.navigation_title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.showingShortcutEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingResultSheet) {
                if let window = viewModel.cheapestWindow {
                    ResultSheetView(window: window, relativeTime: relativeTimeString(from: window.startTime))
                }
            }
            .sheet(isPresented: $viewModel.showingShortcutEditor) {
                ShortcutEditorView(shortcut: viewModel.editingShortcut) { shortcut in
                    viewModel.saveShortcut(shortcut)
                }
            }
            .alert(viewModel.errorAlertTitle, isPresented: $viewModel.showingErrorAlert) {
                Button(L10n.text("common.ok"), role: .cancel) {}
            } message: {
                Text(viewModel.errorAlertMessage)
            }
        }
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(red: 0.15, green: 0.15, blue: 0.17), Color(red: 0.12, green: 0.14, blue: 0.18)]
                : [Color(red: 0.96, green: 0.98, blue: 0.95), Color(red: 0.87, green: 0.93, blue: 0.96)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var quickStartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text("scheduler.quick_start"))
                .font(.headline)
            
            VStack(spacing: 16) {
                HStack {
                    Text(L10n.text("scheduler.duration"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Picker("", selection: $viewModel.selectedDurationMinutes) {
                        ForEach(durationOptions, id: \.self) { minutes in
                            Text(formatDurationForPicker(minutes)).tag(minutes)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.text("scheduler.search_time_range"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Picker("", selection: $viewModel.selectedDayFilter) {
                        if priceViewModel.tomorrowEntries.isEmpty {
                            Text(L10n.text("price.today")).tag(DayFilter.today)
                        } else {
                            Text(L10n.text("scheduler.all_days")).tag(DayFilter.all)
                            Text(L10n.text("price.today")).tag(DayFilter.today)
                            Text(L10n.text("price.day_ahead")).tag(DayFilter.tomorrow)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                HStack(spacing: 12) {
                    Picker("", selection: $viewModel.isQuickStartEndFixed) {
                        Text(L10n.text("scheduler.start_at")).tag(false)
                        Text(L10n.text("scheduler.finish_by")).tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: .infinity)
                    
                    DatePicker("", selection: $viewModel.quickStartTime, displayedComponents: [.hourAndMinute])
                        .labelsHidden()
                        .frame(width: 100)
                }
                
                Button {
                    let timeConstraint = viewModel.timeConstraint(for: priceViewModel)
                    guard timeConstraint.isValid else { return }
                    viewModel.findCheapestWindow(
                        entriesProvider: { priceViewModel.entries(for: viewModel.selectedDayFilter) },
                        preferredStartTime: timeConstraint.start,
                        preferredEndTime: timeConstraint.end
                    )
                } label: {
                    Label(L10n.text("scheduler.find_cheapest"), systemImage: "bolt.magnifyingglass")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(viewModel.isSearching)
            }
            .padding(18)
            .background(colorScheme == .dark
                ? Color(uiColor: .secondarySystemBackground)
                : Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.2) : Color.white.opacity(0.55), lineWidth: 1)
            )
        }
    }
    
    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.text("scheduler.shortcuts"))
                .font(.headline)
            
            if viewModel.shortcuts.isEmpty {
                Text(L10n.text("scheduler.no_shortcuts"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                    .background(colorScheme == .dark
                        ? Color(uiColor: .secondarySystemBackground).opacity(0.5)
                        : Color.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.shortcuts) { shortcut in
                        ShortcutRowView(shortcut: shortcut) {
                            viewModel.selectedDurationMinutes = shortcut.durationMinutes
                            let timeConstraint = viewModel.timeConstraint(for: priceViewModel)
                            guard timeConstraint.isValid else { return }
                            viewModel.findCheapestWindow(
                                entriesProvider: { priceViewModel.entries(for: viewModel.selectedDayFilter) },
                                preferredStartTime: timeConstraint.start,
                                preferredEndTime: timeConstraint.end
                            )
                        }
                        .contextMenu {
                            Button {
                                viewModel.editingShortcut = shortcut
                                viewModel.showingShortcutEditor = true
                            } label: {
                                Label(L10n.text("scheduler.edit_shortcut"), systemImage: "pencil")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                viewModel.deleteShortcut(shortcut)
                            } label: {
                                Label(L10n.text("common.delete"), systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var resultSection: some View {
        if let window = viewModel.cheapestWindow {
            let isTomorrow = !Calendar.current.isDateInToday(window.startTime)
            let relativeTime = relativeTimeString(from: window.startTime)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(L10n.text("scheduler.cheapest_window"))
                        .font(.headline)
                    
                    Spacer()
                    
                    if isTomorrow {
                        Text(L10n.text("price.day_ahead"))
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.2))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    }
                    
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                
                if !relativeTime.isEmpty {
                    Text(relativeTime)
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }
                
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(L10n.text("scheduler.start_time"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(window.startTimeFormatted)
                                .font(.title2.weight(.bold))
                            Text(window.startTime.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .center) {
                            Text(L10n.text("scheduler.duration"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(formatDuration(window.durationMinutes))
                                .font(.headline)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text(L10n.text("scheduler.end_time"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(window.endTimeFormatted)
                                .font(.title2.weight(.bold))
                            Text(window.endTime.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text(L10n.text("scheduler.avg_price"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(L10n.format("price.avg_suffix", window.averagePriceText))
                                .font(.headline)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .center) {
                            Text(L10n.text("scheduler.min_price"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(L10n.format("price.low_suffix", window.minPriceText))
                                .font(.headline)
                                .foregroundStyle(.green)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text(L10n.text("scheduler.max_price"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(window.maxPriceText) ct/kWh")
                                .font(.headline)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .padding(18)
                .background(colorScheme == .dark
                    ? Color(uiColor: .secondarySystemBackground)
                    : Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.orange.opacity(0.5), lineWidth: 2)
                )
            }
        }
    }
    
    struct ResultSheetView: View {
        @Environment(\.dismiss) private var dismiss
        @Environment(\.colorScheme) private var colorScheme
        let window: CheapestWindow
        let relativeTime: String
        
        private func formatDuration(_ minutes: Int) -> String {
            if minutes < 60 {
                return "\(minutes) min"
            } else {
                let hours = minutes / 60
                let mins = minutes % 60
                if mins == 0 {
                    return "\(hours) h"
                }
                return "\(hours)h \(mins)m"
            }
        }
        
        var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        let isTomorrow = !Calendar.current.isDateInToday(window.startTime)
                        
                        HStack {
                            Text(L10n.text("scheduler.cheapest_window"))
                                .font(.title2.weight(.bold))
                            
                            Spacer()
                            
                            if isTomorrow {
                                Text(L10n.text("price.day_ahead"))
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.2))
                                    .foregroundStyle(.orange)
                                    .clipShape(Capsule())
                            }
                        }
                        
                        if !relativeTime.isEmpty {
                            Text(relativeTime)
                                .font(.headline)
                                .foregroundStyle(.orange)
                        }
                        
                        VStack(spacing: 16) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(L10n.text("scheduler.start_time"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(window.startTimeFormatted)
                                        .font(.title2.weight(.bold))
                                    Text(window.startTime.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .center) {
                                    Text(L10n.text("scheduler.duration"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(formatDuration(window.durationMinutes))
                                        .font(.headline)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing) {
                                    Text(L10n.text("scheduler.end_time"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(window.endTimeFormatted)
                                        .font(.title2.weight(.bold))
                                    Text(window.endTime.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            Divider()
                            
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(L10n.text("scheduler.avg_price"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(L10n.format("price.avg_suffix", window.averagePriceText))
                                        .font(.headline)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .center) {
                                    Text(L10n.text("scheduler.min_price"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(L10n.format("price.low_suffix", window.minPriceText))
                                        .font(.headline)
                                        .foregroundStyle(.green)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing) {
                                    Text(L10n.text("scheduler.max_price"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("\(window.maxPriceText) ct/kWh")
                                        .font(.headline)
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                        .padding(20)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(20)
                }
                .background(colorScheme == .dark
                    ? Color(red: 0.15, green: 0.15, blue: 0.17)
                    : Color(red: 0.96, green: 0.98, blue: 0.95))
                .navigationTitle(L10n.text("scheduler.cheapest_window"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.text("common.done")) {
                            dismiss()
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(colorScheme == .dark ? Color.black : Color.white)
        }
    }
    
    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                return "\(hours) h"
            }
            return "\(hours)h \(mins)m"
        }
    }
    
    private func relativeTimeString(from date: Date) -> String {
        let now = Date()
        let interval = date.timeIntervalSince(now)
        guard interval > 0 else { return "" }
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours == 0 && minutes == 0 {
            return L10n.text("scheduler.now")
        } else if hours == 0 {
            return L10n.format("scheduler.in_minutes", minutes)
        } else if minutes == 0 {
            return L10n.format("scheduler.in_hours", hours)
        } else {
            return L10n.format("scheduler.in_hours_minutes", hours, minutes)
        }
    }
    
    private func formatDurationForPicker(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours == 0 {
            return String(format: "%02d min", mins)
        } else if mins == 0 {
            return String(format: "%dh", hours)
        } else {
            return String(format: "%dh %02dm", hours, mins)
        }
    }
    
    private var durationOptions: [Int] {
        var options: [Int] = []
        for hours in 0...8 {
            for mins in stride(from: 0, to: 60, by: 15) {
                let total = hours * 60 + mins
                if total > 0 {
                    options.append(total)
                }
            }
        }
        return options
    }
}

enum DayFilter: String, CaseIterable {
    case all
    case today
    case tomorrow
}

struct ShortcutRowView: View {
    let shortcut: ApplianceShortcut
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(shortcut.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(shortcut.taskType.displayText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text(shortcut.durationFormatted)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct ShortcutEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var name: String
    @State private var taskType: ApplianceShortcut.TaskType
    @State private var customTaskText: String
    @State private var durationMinutes: Int
    @State private var notificationEnabled: Bool
    @State private var notificationLeadTimeMinutes: Int
    
    let editingShortcut: ApplianceShortcut?
    let onSave: (ApplianceShortcut) -> Void
    
    init(shortcut: ApplianceShortcut?, onSave: @escaping (ApplianceShortcut) -> Void) {
        self.editingShortcut = shortcut
        self.onSave = onSave
        _name = State(initialValue: shortcut?.name ?? "")
        
        if let type = shortcut?.taskType {
            _taskType = State(initialValue: type.isCustom ? .predefined(.normal) : type)
            _customTaskText = State(initialValue: type.isCustom ? Self.extractCustomText(from: type) : "")
        } else {
            _taskType = State(initialValue: .predefined(.normal))
            _customTaskText = State(initialValue: "")
        }
        _durationMinutes = State(initialValue: shortcut?.durationMinutes ?? 60)
        _notificationEnabled = State(initialValue: shortcut?.notificationEnabled ?? false)
        _notificationLeadTimeMinutes = State(initialValue: shortcut?.notificationLeadTimeMinutes ?? 30)
    }
    
    private static func extractCustomText(from type: ApplianceShortcut.TaskType) -> String {
        if case .custom(let text) = type { return text }
        return ""
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L10n.text("scheduler.name"), text: $name)
                }
                
                Section(L10n.text("scheduler.task_type")) {
                    Picker(L10n.text("scheduler.task_type"), selection: $taskType) {
                        ForEach(ApplianceShortcut.TaskType.allCases) { type in
                            Text(type.displayText).tag(type)
                        }
                        Text(L10n.text("scheduler.task_type_custom")).tag(ApplianceShortcut.TaskType.custom(""))
                    }
                    .pickerStyle(.menu)
                    
                    if taskType.isCustom || !customTaskText.isEmpty {
                        TextField(L10n.text("scheduler.task_type_custom_placeholder"), text: $customTaskText)
                            .textInputAutocapitalization(.words)
                    }
                }
                
                Section(L10n.text("scheduler.duration")) {
                    Picker(L10n.text("scheduler.duration"), selection: $durationMinutes) {
                        ForEach(durationOptions, id: \.self) { minutes in
                            Text(formatDurationForPicker(minutes)).tag(minutes)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section(L10n.text("scheduler.notification_section")) {
                    Toggle(L10n.text("scheduler.notification_enable"), isOn: $notificationEnabled)
                    
                    if notificationEnabled {
                        Picker(L10n.text("scheduler.notification_lead_time"), selection: $notificationLeadTimeMinutes) {
                            ForEach(leadTimeOptions, id: \.self) { minutes in
                                Text(formatLeadTime(minutes)).tag(minutes)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
            }
            .navigationTitle(editingShortcut == nil ? L10n.text("scheduler.add_shortcut") : L10n.text("scheduler.edit_shortcut"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.text("common.cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("common.save")) {
                        let finalTaskType: ApplianceShortcut.TaskType
                        if taskType.isCustom {
                            finalTaskType = .custom(customTaskText.isEmpty ? L10n.text("scheduler.task_type_custom") : customTaskText)
                        } else {
                            finalTaskType = taskType
                        }
                        let shortcut = ApplianceShortcut(
                            id: editingShortcut?.id ?? UUID(),
                            name: name,
                            taskType: finalTaskType,
                            durationMinutes: durationMinutes,
                            notificationEnabled: notificationEnabled,
                            notificationLeadTimeMinutes: notificationLeadTimeMinutes
                        )
                        onSave(shortcut)
                        dismiss()
                    }
                    .disabled(name.isEmpty || durationMinutes == 0)
                }
            }
        }
    }
    
    private func formatDurationForPicker(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours == 0 {
            return String(format: "%02d min", mins)
        } else if mins == 0 {
            return String(format: "%dh", hours)
        } else {
            return String(format: "%dh %02dm", hours, mins)
        }
    }
    
    private var durationOptions: [Int] {
        var options: [Int] = []
        for hours in 0...8 {
            for mins in stride(from: 0, to: 60, by: 15) {
                let total = hours * 60 + mins
                if total > 0 {
                    options.append(total)
                }
            }
        }
        return options
    }
    
    private var leadTimeOptions: [Int] {
        [5, 10, 15, 20, 30, 45, 60, 90, 120]
    }
    
    private func formatLeadTime(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                return "\(hours) h"
            }
            return "\(hours) h \(mins) min"
        }
    }
}

@MainActor
final class ApplianceSchedulerViewModel: ObservableObject {
    @Published var shortcuts: [ApplianceShortcut] = []
    @Published var selectedDurationMinutes: Int = 60
    @Published var selectedDayFilter: DayFilter = .all
    @Published var cheapestWindow: CheapestWindow?
    @Published var isSearching: Bool = false
    @Published var showingShortcutEditor: Bool = false
    @Published var editingShortcut: ApplianceShortcut?
    @Published var showingResultSheet: Bool = false
    @Published var showingErrorAlert: Bool = false
    @Published var errorAlertTitle: String = ""
    @Published var errorAlertMessage: String = ""
    @Published var quickStartTime: Date = Date()
    @Published var isQuickStartEndFixed: Bool = false
    
    private let userDefaults = UserDefaults.standard
    private let shortcutsKey = "applianceShortcuts"
    
    var selectedDuration: Date {
        get {
            let hours = selectedDurationMinutes / 60
            let minutes = selectedDurationMinutes % 60
            var components = DateComponents()
            components.hour = hours
            components.minute = minutes
            return Calendar.current.date(from: components) ?? Date()
        }
        set {
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            selectedDurationMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        }
    }
    
    init() {
        loadShortcuts()
    }
    
    func timeConstraint(for priceViewModel: PriceViewModel) -> (start: Date?, end: Date?, isValid: Bool) {
        let calendar = Calendar.current
        let now = Date()
        let timeComponents = calendar.dateComponents([.hour, .minute], from: quickStartTime)
        
        // Determine the base date based on selected day filter
        let baseDate: Date
        switch selectedDayFilter {
        case .today:
            baseDate = calendar.startOfDay(for: now)
        case .tomorrow:
            baseDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        case .all:
            // For "all days", use today's date as base
            baseDate = calendar.startOfDay(for: now)
        }
        
        // Combine base date with selected time
        var combinedComponents = calendar.dateComponents([.year, .month, .day], from: baseDate)
        combinedComponents.hour = timeComponents.hour
        combinedComponents.minute = timeComponents.minute
        let constrainedTime = calendar.date(from: combinedComponents) ?? quickStartTime
        
        // Helper function to check if a time is in the past (comparing only hour and minute)
        func isTimeInPast(_ time: Date) -> Bool {
            let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
            let nowComponents = calendar.dateComponents([.hour, .minute], from: now)
            
            let timeMinutes = (timeComponents.hour ?? 0) * 60 + (timeComponents.minute ?? 0)
            let nowMinutes = (nowComponents.hour ?? 0) * 60 + (nowComponents.minute ?? 0)
            
            // If same day, compare by minutes since midnight
            if calendar.isDate(time, inSameDayAs: now) {
                return timeMinutes < nowMinutes
            }
            // Different day - just compare the dates
            return time < now
        }
        
        if isQuickStartEndFixed {
            // Finish by: check that end time is not in the past
            // AND that start time (end - duration) is also not in the past
            let durationInterval = TimeInterval(selectedDurationMinutes * 60)
            let requiredStartTime = constrainedTime.addingTimeInterval(-durationInterval)
            
            if isTimeInPast(constrainedTime) || isTimeInPast(requiredStartTime) {
                errorAlertTitle = L10n.text("scheduler.error_past_time_title")
                errorAlertMessage = L10n.text("scheduler.error_past_time_message")
                showingErrorAlert = true
                return (start: nil, end: nil, isValid: false)
            }
            
            // Finish by: return end time constraint
            return (start: nil, end: constrainedTime, isValid: true)
        } else {
            // Start at: check that start time is not in the past (comparing hour:minute only)
            if isTimeInPast(constrainedTime) {
                errorAlertTitle = L10n.text("scheduler.error_past_time_title")
                errorAlertMessage = L10n.text("scheduler.error_past_time_message")
                showingErrorAlert = true
                return (start: nil, end: nil, isValid: false)
            }
            
            // Start at: return start time constraint
            return (start: constrainedTime, end: nil, isValid: true)
        }
    }
    
    func findCheapestWindow(entriesProvider: () -> [SpotPrice], preferredStartTime: Date? = nil, preferredEndTime: Date? = nil) {
        let allEntries = entriesProvider()
        guard !allEntries.isEmpty else { return }
        guard selectedDurationMinutes > 0 else { return }
        
        // Validate that the requested window fits within available data
        let calendar = Calendar.current
        let durationInterval = TimeInterval(selectedDurationMinutes * 60)
        
        if let startTime = preferredStartTime {
            let requiredEndTime = startTime.addingTimeInterval(durationInterval)
            // Check if we have data covering the full duration from start time
            if let lastEntry = allEntries.last, requiredEndTime > lastEntry.intervalEnd {
                errorAlertTitle = L10n.text("scheduler.error_outside_data_range_title")
                errorAlertMessage = L10n.text("scheduler.error_outside_data_range_message")
                showingErrorAlert = true
                return
            }
        }
        
        if let endTime = preferredEndTime {
            let requiredStartTime = endTime.addingTimeInterval(-durationInterval)
            // Check if we have data covering the full duration ending at end time
            if let firstEntry = allEntries.first, requiredStartTime < firstEntry.timestamp {
                errorAlertTitle = L10n.text("scheduler.error_outside_data_range_title")
                errorAlertMessage = L10n.text("scheduler.error_outside_data_range_message")
                showingErrorAlert = true
                return
            }
        }
        
        var entries = allEntries
        
        // Filter entries by comparing actual timestamps, not just hour/minute
        // This ensures proper handling when tomorrow's data is available
        if let startTime = preferredStartTime {
            entries = entries.filter { $0.timestamp >= startTime }
        }
        
        if let endTime = preferredEndTime {
            entries = entries.filter { $0.timestamp <= endTime }
        }
        
        guard !entries.isEmpty else {
            errorAlertTitle = L10n.text("scheduler.error_outside_data_range_title")
            errorAlertMessage = L10n.text("scheduler.error_outside_data_range_message")
            showingErrorAlert = true
            cheapestWindow = nil
            return
        }
        
        isSearching = true
        let durationSlots = max(1, selectedDurationMinutes / 15)
        
        var bestWindow: CheapestWindow?
        var bestAverage = Double.infinity
        
        for i in 0..<(max(0, entries.count - durationSlots + 1)) {
            let endIndex = min(i + durationSlots, entries.count)
            let windowEntries = Array(entries[i..<endIndex])
            let average = windowEntries.reduce(0.0) { $0 + $1.pricePerKWh } / Double(windowEntries.count)
            
            if average < bestAverage {
                bestAverage = average
                bestWindow = CheapestWindow(
                    startTime: windowEntries.first!.timestamp,
                    endTime: windowEntries.last!.intervalEnd,
                    entries: windowEntries
                )
            }
        }
        
        cheapestWindow = bestWindow
        isSearching = false
        if bestWindow != nil {
            showingResultSheet = true
        }
    }
    
    func saveShortcut(_ shortcut: ApplianceShortcut) {
        if let index = shortcuts.firstIndex(where: { $0.id == shortcut.id }) {
            shortcuts[index] = shortcut
        } else {
            shortcuts.append(shortcut)
        }
        saveShortcuts()
    }
    
    func deleteShortcut(_ shortcut: ApplianceShortcut) {
        shortcuts.removeAll { $0.id == shortcut.id }
        saveShortcuts()
    }
    
    private func loadShortcuts() {
        guard let data = userDefaults.data(forKey: shortcutsKey),
              let decoded = try? JSONDecoder().decode([ApplianceShortcut].self, from: data) else {
            return
        }
        shortcuts = decoded
    }
    
    private func saveShortcuts() {
        guard let encoded = try? JSONEncoder().encode(shortcuts) else { return }
        userDefaults.set(encoded, forKey: shortcutsKey)
    }
}
