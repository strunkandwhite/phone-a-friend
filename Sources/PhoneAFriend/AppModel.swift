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
        case .recovered(let fresh, _):
            state = fresh
            startupError = "State file was unreadable — saved a copy as state.corrupt.json."
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

    func refresh() {
        let before = state
        names = loader.reload(from: store)
        var generator = SystemRandomNumberGenerator()
        state.refresh(names: names, today: today, using: &generator)
        errorLine = loader.error ?? startupError
        if state != before {
            save()
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
        } catch {
            errorLine = "Couldn't save state."
        }
    }

    // MenuBarExtra's menu style has no reliable "menu opened" hook, so a one-minute timer
    // stands in for re-reading the list on open, alongside day-change and wake events.
    private func observeDayChanges() {
        observers.append(NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged, object: nil, queue: .main
        ) { [weak self] _ in
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
