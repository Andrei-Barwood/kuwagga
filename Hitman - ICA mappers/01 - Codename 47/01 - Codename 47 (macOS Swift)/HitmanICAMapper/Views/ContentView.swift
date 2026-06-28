import SwiftUI
import GameController
import ApplicationServices   // For AXIsProcessTrustedWithOptions (Accessibility permission)

struct ContentView: View {
    @State private var mapper = ControllerMapper()
    @State private var selectedMission: Mission = missions[0]
    @State private var settings = MapperSettings()
    @State private var showingPermissionAlert = false
    @State private var permissionMessage = ""

    // Live remapping state (synced to mapper)
    @State private var controllerMappings: [ControllerInput: String] = defaultMappings

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            // Main content
            HStack(alignment: .top, spacing: 12) {
                // LEFT COLUMN - Mission selector + Briefing
                leftColumn
                    .frame(minWidth: 340, idealWidth: 400, maxWidth: .infinity)
                    .layoutPriority(1)

                // RIGHT COLUMN - Mappings + Settings + Controls
                rightColumn
                    .frame(minWidth: 400, idealWidth: 460, maxWidth: .infinity)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Footer tip
            Text("Consejo de la Agencia: Selecciona la misión → Lee el briefing → Ajusta sensibilidad → Inicia el mapper antes de lanzar el juego.")
                .font(.caption)
                .foregroundStyle(Theme.gold)
                .padding(.bottom, 8)
        }
        .frame(minWidth: 860, minHeight: 620)
        .background(Theme.darkBG)
        .onAppear {
            setupControllerObservation()
            checkPermissionsOnLaunch()
            // Load current mappings from mapper
            controllerMappings = mapper.activeMappings.isEmpty ? defaultMappings : mapper.activeMappings
        }
        .onDisappear {
            mapper.stopAndCleanup()
        }
        .alert("Permisos necesarios", isPresented: $showingPermissionAlert) {
            Button("Abrir Accesibilidad") {
                openPrivacySettings()
            }
            Button("Abrir Input Monitoring") {
                openInputMonitoringSettings()
            }
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(permissionMessage)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 2) {
            Text("AGENT 47  •  ICA CONTROLLER BRIEFING")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.gold)

            Text("Hitman: Codename 47  •  Mapeo responsive por misión")
                .font(.system(size: 11))
                .foregroundStyle(Theme.lightGold)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Theme.darkBG)
    }

    // MARK: - Left Column

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SELECCIONA MISIÓN")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.lightBG)
                .padding(.horizontal, 4)

            Picker("", selection: $selectedMission) {
                ForEach(missions) { mission in
                    Text("\(mission.title) — \(mission.location)")
                        .tag(mission)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)
            .tint(Theme.primaryBlue)

            HStack {
                Text("BRIEFING DE LA AGENCIA")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.lightGold)
                Spacer()
                Text(selectedMission.location)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.top, 6)
            .padding(.horizontal, 4)

            ScrollView {
                Text(selectedMission.briefing)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(minHeight: 120, maxHeight: .infinity)
            .background(Theme.darkBG)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Playstyle
            HStack(spacing: 6) {
                Text("Estilo recomendado:")
                    .foregroundStyle(Theme.lightGold)
                    .font(.system(size: 11, weight: .medium))
                Text(selectedMission.playstyle)
                    .foregroundStyle(Theme.gold)
                    .font(.system(size: 11, weight: .semibold))
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 4)
        }
        .padding(12)
        .background(Theme.mediumGray)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Right Column

    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header for controls
            HStack {
                Text("CONFIGURACIÓN DE CONTROLES")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.lightBG)
                Spacer()
                Button("Restablecer") {
                    controllerMappings = defaultMappings
                }
                .font(.caption)
            }
            .padding(.horizontal, 4)

            // Scrollable flexible area: summary + remapper + settings
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    // Quick summary of current mapping (compact)
                    VStack(alignment: .leading, spacing: 1) {
                        ForEach(Array(controllerMappings.keys.sorted { $0.rawValue < $1.rawValue }.prefix(6)), id: \.self) { input in
                            if let actionId = controllerMappings[input], let action = GameAction.action(for: actionId) {
                                HStack {
                                    Text(input.displayName)
                                        .font(.caption)
                                        .foregroundStyle(Theme.gold)
                                        .frame(minWidth: 85, alignment: .leading)
                                    Text("→ \(action.displayName)")
                                        .font(.caption2)
                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding(6)
                    .background(Theme.darkBG)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                    // Remapper - flexible inside the ScrollView
                    RemappingView(mappings: $controllerMappings)

                    // Settings
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SENSIBILIDAD RATÓN")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.lightBG)
                        Slider(value: $settings.sensitivity, in: 10...50, step: 1)
                            .tint(Theme.primaryBlue)

                        Text("DEADZONE MOVIMIENTO")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.lightBG)
                            .padding(.top, 4)
                        Slider(value: $settings.deadzone, in: 0.05...0.40, step: 0.01)
                            .tint(Theme.primaryBlue)

                        Text("DEADZONE MIRA (anti-drift)")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.lightBG)
                            .padding(.top, 4)
                        Slider(value: $settings.lookDeadzone, in: 0.08...0.45, step: 0.01)
                            .tint(Theme.primaryBlue)

                        Text("UMBRAL CORRER (Shift)")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.lightBG)
                            .padding(.top, 4)
                        Slider(value: $settings.runThreshold, in: 0.60...0.95, step: 0.01)
                            .tint(Theme.primaryBlue)
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 6)
                }
            }
            .frame(maxHeight: .infinity)

            // Buttons and status - stay visible
            VStack(spacing: 6) {
                Button {
                    startMapper()
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("INICIAR MAPPER")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.primaryBlue)
                .controlSize(.large)
                .disabled(mapper.isRunning)

                Button {
                    mapper.stop()
                } label: {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("DETENER MAPPER")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
                .controlSize(.regular)
                .disabled(!mapper.isRunning)

                Button("Recalibrar Stick Derecho") {
                    mapper.recalibrateRightStick()
                }
                .font(.caption)
                .foregroundStyle(Theme.lightGold)
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)

            Text(mapper.statusMessage)
                .font(.system(size: 11))
                .foregroundStyle(Theme.lightGold)
                .padding(.top, 4)
                .padding(.horizontal, 4)
        }
        .padding(12)
        .background(Theme.mediumGray)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onChange(of: settings) { _, newValue in
            mapper.updateSettings(newValue)
        }
        .onChange(of: controllerMappings) { _, newValue in
            mapper.activeMappings = newValue
        }
    }

    // MARK: - Actions

    private func startMapper() {
        // Sync everything
        mapper.updateSettings(settings)
        mapper.activeMappings = controllerMappings

        // Check permissions before starting
        if !hasAccessibilityPermission() {
            // Try to trigger the official system prompt for Accessibility
            _ = requestAccessibilityPermission()

            // Re-check after prompt attempt
            if !hasAccessibilityPermission() {
                permissionMessage = "Necesitas conceder permisos de «Accesibilidad» e «Input Monitoring».\n\n1. En la ventana que apareció, permite el acceso.\n2. También ve a «Monitorización de entrada» (Input Monitoring) y actívalo para esta app.\n3. IMPORTANTE: Cierra completamente esta app (Cmd+Q o clic derecho en el Dock → Salir) y vuelve a abrirla."
                showingPermissionAlert = true
                return
            }
        }

        mapper.start()
    }

    private func setupControllerObservation() {
        // Listen for controller connections
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { notification in
            if let controller = notification.object as? GCController {
                // If we didn't have a controller assigned yet, assign this one
                if mapper.connectedControllerName == nil && !mapper.isRunning {
                    // We don't call setup here — the mapper will pick it on start
                }
                mapper.connectedControllerName = controller.vendorName ?? controller.productCategory
                if !mapper.isRunning {
                    mapper.statusMessage = "Mando conectado: \(mapper.connectedControllerName ?? "Desconocido"). Pulsa INICIAR MAPPER."
                }
            }
        }

        NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: .main
        ) { _ in
            if !mapper.isRunning {
                mapper.statusMessage = "Mando desconectado"
            }
        }
    }

    private func checkPermissionsOnLaunch() {
        if !hasAccessibilityPermission() {
            mapper.statusMessage = "⚠️ Accesibilidad + Input Monitoring requeridos. Pulsa INICIAR MAPPER para guiar."
        }
    }

    private func hasAccessibilityPermission() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Calls with prompt:true so the system shows the official Accessibility permission dialog.
    @discardableResult
    private func requestAccessibilityPermission() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options)
    }

    private func openPrivacySettings() {
        // Opens the main Privacy & Security panel (user can then choose Accessibility or Input Monitoring)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openInputMonitoringSettings() {
        // Specific deep link for Input Monitoring (ListenEvent)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        } else if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

#Preview {
    ContentView()
}
