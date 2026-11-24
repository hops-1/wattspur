import CarPlay
import WattspurCore

/// Wattspur in CarPlay (B-327), a Driving Task app (V-20): start, pause and end a recording, pick
/// the vehicle, and one panel with speed, time, distance and the lateral acceleration (car) or lean
/// angle (motorcycle). No map, no ride list. It is the same recorder as on the iPhone, so an end on
/// the iPhone ends here too and the other way round. The panel is written at most every 5 s
/// (`DrivingPanel`); a new state shows at once.
@MainActor
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    /// Set by the app at launch: the one recorder of the app.
    static weak var recorder: Recorder?

    private var interfaceController: CPInterfaceController?
    private var panelTemplate: CPInformationTemplate?
    private var timer: Timer?
    private var shown: DrivingPanel?
    private var shownAt: Date?
    /// The vehicle picked in CarPlay for the next start; else the one the iPhone would take.
    private var chosen: RecordingDevice?

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        let template = CPInformationTemplate(title: "Wattspur", layout: .twoColumn, items: [], actions: [])
        panelTemplate = template
        refresh(force: true)
        interfaceController.setRootTemplate(template, animated: false, completion: nil)
        // Checks every second; `DrivingPanel` decides whether the panel is written anew.
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        timer?.invalidate()
        timer = nil
        self.interfaceController = nil
        panelTemplate = nil
        shown = nil
        shownAt = nil
    }

    // MARK: - Opened from the Live Activity

    /// A tap on the Live Activity in the CarPlay dashboard opens this scene with `RecordingLink`
    /// (B-379): back to the panel, whatever list or question was open.
    func scene(_ scene: UIScene, openURLContexts urlContexts: Set<UIOpenURLContext>) {
        guard urlContexts.contains(where: { RecordingLink.isRecordingURL($0.url) }) else { return }
        showPanel()
    }

    /// The same when the system passes the Live Activity as a user activity instead of the link.
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        showPanel()
    }

    private func showPanel() {
        guard let interfaceController else { return }
        if interfaceController.presentedTemplate != nil {
            interfaceController.dismissTemplate(animated: false, completion: nil)
        }
        interfaceController.popToRootTemplate(animated: false, completion: nil)
        refresh(force: true)
    }

    // MARK: - Panel

    private var devices: [RideExchange.Bike] { RecordingChoice.cachedDevices }

    /// The vehicle for the next start: the one picked here, or the iPhone's next one in “Vehicles”.
    private var nextVehicle: RecordingDevice {
        if let chosen { return chosen }
        let next = RecordingChoice.next(for: .vehicle, devices: devices, activeID: nil, lastRideDeviceID: nil)
        return next.kind.sport == .vehicle ? next : .without(.car)
    }

    private func refresh(force: Bool = false) {
        guard let panelTemplate else { return }
        let now = Date.now
        let panel = DrivingPanel(recording: Self.recorder?.recording, at: now)
        guard force || panel.needsRefresh(since: shown, shownAt: shownAt, at: now) else { return }
        shown = panel
        shownAt = now
        panelTemplate.items = items(panel)
        panelTemplate.actions = actions(panel)
    }

    private func items(_ panel: DrivingPanel) -> [CPInformationItem] {
        switch panel.state {
        case .idle:
            return [CPInformationItem(title: String(localized: "Vehicle"), detail: nextVehicle.name(in: devices))]
        case .ready:
            return [CPInformationItem(title: String(localized: "Ready"), detail: String(localized: "Waiting for the vehicle to move"))]
        case .recording, .paused:
            var items = [
                CPInformationItem(title: String(localized: "Speed"), detail: RideFormat.speed(panel.speed)),
                CPInformationItem(title: String(localized: "Time"),
                                  detail: Duration.seconds(panel.elapsed).formatted(.time(pattern: .hourMinuteSecond))),
                CPInformationItem(title: String(localized: "Distance"), detail: RideFormat.distance(panel.distance)),
            ]
            if let measure = panel.sideMeasure {
                let title = measure == .lateralAcceleration ? String(localized: "Lateral Acceleration") : String(localized: "Lean Angle")
                items.append(CPInformationItem(title: title, detail: panel.lean.map { measure.text(lean: $0) } ?? "–"))
            }
            if panel.state == .paused { items.insert(CPInformationItem(title: String(localized: "Pause"), detail: nil), at: 0) }
            return items
        }
    }

    private func actions(_ panel: DrivingPanel) -> [CPTextButton] {
        switch panel.state {
        case .idle:
            return [
                CPTextButton(title: String(localized: "Start Ride"), textStyle: .confirm) { [weak self] _ in
                    guard let self else { return }
                    Self.recorder?.start(device: self.nextVehicle)
                    self.refresh(force: true)
                },
                CPTextButton(title: String(localized: "Change Vehicle"), textStyle: .normal) { [weak self] _ in
                    self?.showVehicles()
                },
            ]
        case .ready:
            return [CPTextButton(title: String(localized: "Cancel"), textStyle: .cancel) { [weak self] _ in
                Self.recorder?.cancelReady()
                self?.refresh(force: true)
            }]
        case .recording, .paused:
            let paused = panel.state == .paused
            return [
                CPTextButton(title: paused ? String(localized: "Resume") : String(localized: "Pause"), textStyle: .normal) { [weak self] _ in
                    if paused { Self.recorder?.resume() } else { Self.recorder?.pause() }
                    self?.refresh(force: true)
                },
                CPTextButton(title: String(localized: "End"), textStyle: .cancel) { [weak self] _ in
                    self?.confirmEnd()
                },
            ]
        }
    }

    // MARK: - Vehicle and end

    private func showVehicles() {
        let items = DrivingPanel.vehicles(from: devices).map { vehicle in
            let item = CPListItem(text: vehicle.name(in: devices),
                                  detailText: vehicle.bikeID == nil ? nil : vehicle.kind.localizedName,
                                  image: UIImage(systemName: vehicle.symbol))
            item.handler = { [weak self] _, completion in
                self?.chosen = vehicle
                self?.refresh(force: true)
                self?.interfaceController?.popTemplate(animated: true, completion: nil)
                completion()
            }
            return item
        }
        let list = CPListTemplate(title: String(localized: "Vehicle"), sections: [CPListSection(items: items)])
        interfaceController?.pushTemplate(list, animated: true, completion: nil)
    }

    /// One more tap, so a brush against the screen does not end the ride; it is saved without the
    /// sheet, with the places at start and end as its name, like an automatic end (B-339).
    private func confirmEnd() {
        let alert = CPAlertTemplate(titleVariants: [String(localized: "End and save the ride?")], actions: [
            CPAlertAction(title: String(localized: "Save"), style: .default) { [weak self] _ in
                self?.interfaceController?.dismissTemplate(animated: true, completion: nil)
                Task { @MainActor in
                    await Self.recorder?.endAndSave()
                    self?.refresh(force: true)
                }
            },
            CPAlertAction(title: String(localized: "Cancel"), style: .cancel) { [weak self] _ in
                self?.interfaceController?.dismissTemplate(animated: true, completion: nil)
            },
        ])
        interfaceController?.presentTemplate(alert, animated: true, completion: nil)
    }
}
