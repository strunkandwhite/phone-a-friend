import AppKit
import FriendQueue

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var state: AppState
    @Published private(set) var names: [String] = []
    @Published private(set) var errorLine: String?
    @Published private(set) var openAtLogin: Bool
    @Published private(set) var openAtLoginFailed = false

    let store: StateStore
    private var loader = FriendListLoader()
    private var startupError: String?
    private var saveFailed = false
    private var observers: [NSObjectProtocol] = []
    private var timer: Timer?

    init(store: StateStore = StateStore(directory: StateStore.defaultDirectory())) {
        self.store = store
        var startupError: String?
        do {
            try store.ensureFriendListExists()
        } catch {
            startupError = "Couldn't create friends.txt."
        }
        switch store.loadState() {
        case .fresh:
            state = AppState()
        case .loaded(let loaded):
            state = loaded
        case .recovered(let fresh, let backupURL):
            state = fresh
            startupError = backupURL == store.stateURL
                ? "State file was unreadable and couldn't be set aside."
                : "State file was unreadable — saved a copy as \(backupURL.lastPathComponent)."
        }
        self.startupError = startupError
        openAtLogin = LoginItem.isEnabled

        initializeLoginItemOnFirstLaunch()
        refresh()
        observeDayChanges()
    }

    var today: DayKey { DayKey(Date()) }

    var sortedNames: [String] {
        names.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    var loggedToday: Set<String> { state.loggedToday(today) }

    func searchResults(for query: String) -> [String] {
        FriendSearch.results(query: query, names: names)
    }

    func refresh() {
        let before = state
        let loaded = loader.reload(from: store)
        // Without any successfully read list, refreshing would treat every friend as removed
        // and discard today's pick, so leave the state alone until the file can be read.
        if let loaded {
            names = loaded
            var generator = SystemRandomNumberGenerator()
            state.refresh(names: names, today: today, using: &generator)
        }
        // A failed save is retried on every refresh until one succeeds.
        if state != before || saveFailed {
            save()
        } else {
            updateErrorLine()
        }
    }

    func answer(_ answer: Answer?) {
        state.setAnswer(answer, today: today)
        save()
    }

    func toggleLog(_ name: String) {
        state.toggleLog(name, today: today)
        save()
    }

    /// Returns false when the friend was already marked contacted today.
    func markContacted(_ name: String) -> Bool {
        let marked = state.markContacted(name, today: today)
        if marked {
            save()
        }
        return marked
    }

    func openFriendList() {
        NSWorkspace.shared.open(store.friendsURL)
    }

    func setOpenAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try LoginItem.register()
            } else {
                try LoginItem.unregister()
            }
        } catch {
            // Reflected below through the service's actual status.
        }
        openAtLogin = LoginItem.isEnabled
        openAtLoginFailed = enabled && !openAtLogin
    }

    private func initializeLoginItemOnFirstLaunch() {
        guard !state.loginItemInitialized else { return }
        setOpenAtLogin(true)
        state.loginItemInitialized = true
        save()
    }

    private func save() {
        do {
            try store.save(state)
            saveFailed = false
        } catch {
            saveFailed = true
        }
        updateErrorLine()
    }

    // A save failure outranks other errors and stays visible until a save succeeds.
    private func updateErrorLine() {
        errorLine = saveFailed ? "Couldn't save changes — retrying." : (loader.error ?? startupError)
    }

    // The panel refreshes when it opens; these keep the icon's color right while it's closed.
    private func observeDayChanges() {
        observers.append(NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: .NSSystemTimeZoneDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            // Darwin caches the system time zone; reset it so "today" follows travel.
            NSTimeZone.resetSystemTimeZone()
            Task { @MainActor in self?.refresh() }
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        })

        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        timer.tolerance = 10
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}
