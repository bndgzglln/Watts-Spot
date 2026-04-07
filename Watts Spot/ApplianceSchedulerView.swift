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
                        resultSection
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
            .sheet(isPresented: $viewModel.showingShortcutEditor) {
                ShortcutEditorView(shortcut: viewModel.editingShortcut) { shortcut in
                    viewModel.saveShortcut(shortcut)
                }
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
                    HStack {
                        Text(L10n.text("scheduler.search_range"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Picker("", selection: $viewModel.selectedDayFilter) {
                            Text(L10n.text("scheduler.all_days")).tag(DayFilter.all)
                            Text(L10n.text("price.today")).tag(DayFilter.today)
                            Text(L10n.text("price.day_ahead")).tag(DayFilter.tomorrow)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 280)
                    }
                    
                    if viewModel.selectedDayFilter != .today && priceViewModel.tomorrowEntries.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.orange)
                            Text(L10n.text("scheduler.tomorrow_not_available"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Button {
                    viewModel.findCheapestWindow {
                        priceViewModel.entries(for: viewModel.selectedDayFilter)
                    }
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
                            viewModel.findCheapestWindow {
                                priceViewModel.entries(for: viewModel.selectedDayFilter)
                            }
                        }
                        .contextMenu {
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
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(L10n.text("scheduler.cheapest_window"))
                        .font(.headline)
                    
                    Spacer()
                    
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(L10n.text("scheduler.start_time"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(window.startTimeFormatted)
                                .font(.title2.weight(.bold))
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
                            durationMinutes: durationMinutes
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
    
    func findCheapestWindow(entriesProvider: () -> [SpotPrice]) {
        let entries = entriesProvider()
        guard !entries.isEmpty else { return }
        guard selectedDurationMinutes > 0 else { return }
        
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
