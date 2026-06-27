import SwiftUI

/// UI to show available game controls + let the user assign controller inputs to them.
struct RemappingView: View {
    @Binding var mappings: [ControllerInput: String]   // input rawValue -> action id
    @State private var selectedCategory: GameAction.ActionCategory? = nil

    private var filteredActions: [GameAction] {
        if let cat = selectedCategory {
            return availableGameActions.filter { $0.category == cat }
        }
        return availableGameActions
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CONTROLES DISPONIBLES DEL JUEGO")
                .font(.headline)
                .foregroundStyle(Theme.gold)

            Text("Estos son los controles principales de Hitman: Codename 47 (basado en keybindings_WASD.pdf + manual.pdf del juego instalado). Puedes reasignar cualquier acción a los botones que te sobren (incluyendo usar D-Pad para el puntero).")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)

            // Game actions reference list (grouped) - flexible
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 3) {
                    ForEach(GameAction.ActionCategory.allCases, id: \.self) { category in
                        let actionsInCat = availableGameActions.filter { $0.category == category }
                        if !actionsInCat.isEmpty {
                            Text(category.rawValue.uppercased())
                                .font(.caption.bold())
                                .foregroundStyle(Theme.lightGold)
                                .padding(.top, 4)

                            ForEach(actionsInCat) { action in
                                HStack(spacing: 6) {
                                    Text(action.displayName)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Theme.textPrimary)
                                    Spacer()
                                    Text(action.description)
                                        .font(.caption2)
                                        .foregroundStyle(Theme.textSecondary)
                                        .lineLimit(1)
                                }
                                .padding(.vertical, 1)
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            .frame(minHeight: 90, maxHeight: 160)
            .background(Theme.darkBG)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Divider()

            Text("ASIGNAR BOTONES DEL MANDO")
                .font(.headline)
                .foregroundStyle(Theme.gold)
                .padding(.top, 4)

            Text("Elige qué acción del juego quieres que haga cada botón de tu mando. Tienes botones de sobra (puedes poner flechas, mapa, etc.).")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)

            // Editable mapping list - fully responsive
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(ControllerInput.allCases) { input in
                        HStack(spacing: 8) {
                            Label {
                                Text(input.displayName)
                                    .font(.system(size: 12, weight: .semibold))
                            } icon: {
                                Image(systemName: iconFor(input))
                            }
                            .foregroundStyle(Theme.gold)
                            .frame(minWidth: 120, idealWidth: 140, alignment: .leading)

                            Picker("", selection: binding(for: input)) {
                                Text("— Sin asignar —").tag(Optional<String>.none)
                                ForEach(availableGameActions) { action in
                                    Text(action.displayName).tag(Optional(action.id))
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity)

                            if let currentId = mappings[input], let act = GameAction.action(for: currentId) {
                                Text(act.category.rawValue)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 70, alignment: .trailing)
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                }
            }
            .frame(minHeight: 120)

            HStack {
                Button("Restablecer predeterminados") {
                    mappings = defaultMappings
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Text("Sticks y gatillos usan comportamientos especiales.")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            .padding(.top, 4)
        }
        .padding(10)
        .background(Theme.mediumGray)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func binding(for input: ControllerInput) -> Binding<String?> {
        Binding(
            get: { mappings[input] },
            set: { newValue in
                if let val = newValue {
                    mappings[input] = val
                } else {
                    mappings.removeValue(forKey: input)
                }
            }
        )
    }

    private func iconFor(_ input: ControllerInput) -> String {
        switch input {
        case .buttonA: return "a.circle"
        case .buttonB: return "b.circle"
        case .buttonX, .buttonY: return "xmark.circle"
        case .leftShoulder, .rightShoulder: return "l.rectangle.roundedbottom"
        case .buttonOptions, .buttonMenu: return "menubar.arrow.up.rectangle"
        case .leftTrigger, .rightTrigger: return "arrow.down.to.line"
        case .dpadUp, .dpadDown, .dpadLeft, .dpadRight: return "dpad"
        case .leftStick, .leftStickClick: return "l.joystick"
        case .rightStick, .rightStickClick: return "r.joystick"
        }
    }
}

#Preview {
    RemappingView(mappings: .constant(defaultMappings))
        .frame(width: 620, height: 640)
}
