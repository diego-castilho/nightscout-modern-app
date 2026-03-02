import SwiftUI

struct SettingsView: View {
    @Environment(AuthStore.self) private var authStore
    @Environment(DashboardStore.self) private var store
    @State private var isSaving = false
    @State private var saveMessage: String?

    var body: some View {
        @Bindable var store = store

        Form {
            // Section 1: Display
            displaySection

            // Section 2: Thresholds
            thresholdsSection

            // Section 3: Device Ages
            deviceAgesSection

            // Section 4: Insulin Pump
            pumpSection

            // Section 5: Bolus Calculator
            bolusCalcSection

            // Section 6: Alarms
            alarmsSection

            // Section 7: Save
            saveSection
        }
        .navigationTitle("Configurações")
    }

    // MARK: - Display Section

    private var displaySection: some View {
        @Bindable var store = store

        return Section("Exibição") {
            TextField("Nome do paciente", text: $store.patientName)

            Picker("Unidade de glicose", selection: $store.unit) {
                ForEach(GlucoseUnit.allCases) { unit in
                    Text(unit.label).tag(unit)
                }
            }

            Picker("Atualização automática", selection: $store.refreshInterval) {
                ForEach([1, 2, 5, 10, 15, 30], id: \.self) { min in
                    Text("\(min) min").tag(min)
                }
            }

            Picker("DIA (Duração da Insulina)", selection: diaBinding) {
                ForEach([2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 6.0], id: \.self) { h in
                    Text("\(String(format: "%.1f", h))h").tag(h)
                }
            }

            Picker("Absorção de carboidratos", selection: carbRateBinding) {
                ForEach(stride(from: 10, through: 50, by: 5).map { $0 }, id: \.self) { rate in
                    Text("\(rate) g/h").tag(Double(rate))
                }
            }

            Toggle("AR2 ativo por padrão", isOn: $store.predictionsDefault)

            Picker("Tema", selection: $store.appTheme) {
                ForEach(AppTheme.allCases) { theme in
                    Label(theme.label, systemImage: theme.icon).tag(theme)
                }
            }
        }
    }

    // MARK: - Thresholds Section

    private var thresholdsSection: some View {
        let ul = store.unit.label

        return Section("Faixas Limites (\(ul))") {
            thresholdRow("Muito baixo", mgdlBinding: thresholdBinding(\.veryLow), color: GlucoseColors.veryLow)
            thresholdRow("Baixo", mgdlBinding: thresholdBinding(\.low), color: GlucoseColors.low)
            thresholdRow("Alto", mgdlBinding: thresholdBinding(\.high), color: GlucoseColors.high)
            thresholdRow("Muito alto", mgdlBinding: thresholdBinding(\.veryHigh), color: GlucoseColors.veryHigh)

            // Threshold preview bar
            thresholdPreview
        }
    }

    /// Creates a Binding<Double> that reads/writes an Int threshold in the current display unit.
    /// Internal storage is always mg/dL; the binding converts to/from the selected unit.
    /// Values are clamped to 40–400 mg/dL.
    private func thresholdBinding(_ keyPath: WritableKeyPath<AlarmThresholds, Int>) -> Binding<Double> {
        Binding(
            get: {
                GlucoseUnit.toDisplayUnit(Double(store.alarmThresholds[keyPath: keyPath]), unit: store.unit)
            },
            set: { newValue in
                let mgdl = Int(GlucoseUnit.fromDisplayUnit(newValue, unit: store.unit))
                store.alarmThresholds[keyPath: keyPath] = min(400, max(40, mgdl))
            }
        )
    }

    private func thresholdRow(_ label: String, mgdlBinding: Binding<Double>, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
            Spacer()
            if store.unit == .mmol {
                TextField("", value: mgdlBinding, format: .number.precision(.fractionLength(1)))
                    .frame(width: 70)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
            } else {
                TextField("", value: mgdlBinding, format: .number.precision(.fractionLength(0)))
                    .frame(width: 70)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
            }
        }
    }

    private var thresholdPreview: some View {
        let t = store.alarmThresholds
        let total: Double = 400

        return GeometryReader { geo in
            HStack(spacing: 0) {
                Rectangle().fill(GlucoseColors.veryLow)
                    .frame(width: geo.size.width * Double(t.veryLow) / total)
                Rectangle().fill(GlucoseColors.low)
                    .frame(width: geo.size.width * Double(t.low - t.veryLow) / total)
                Rectangle().fill(GlucoseColors.inRange)
                    .frame(width: geo.size.width * Double(t.high - t.low) / total)
                Rectangle().fill(GlucoseColors.high)
                    .frame(width: geo.size.width * Double(t.veryHigh - t.high) / total)
                Rectangle().fill(GlucoseColors.veryHigh)
                    .frame(width: geo.size.width * Double(400 - t.veryHigh) / total)
            }
        }
        .frame(height: 12)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Device Ages Section

    private var deviceAgesSection: some View {
        @Bindable var store = store

        return Section("Idade dos Dispositivos") {
            Picker("SAGE Alerta (dias)", selection: $store.deviceAgeThresholds.sageWarnD) {
                ForEach([7, 10, 12, 14, 15], id: \.self) { Text("\($0)d").tag($0) }
            }
            Picker("SAGE Urgente (dias)", selection: $store.deviceAgeThresholds.sageUrgentD) {
                ForEach([10, 12, 14, 15, 21], id: \.self) { Text("\($0)d").tag($0) }
            }
            Picker("CAGE Alerta (horas)", selection: $store.deviceAgeThresholds.cageWarnH) {
                ForEach([24, 36, 48, 60, 72, 96], id: \.self) { Text("\($0)h").tag($0) }
            }
            Picker("CAGE Urgente (horas)", selection: $store.deviceAgeThresholds.cageUrgentH) {
                ForEach([48, 60, 72, 84, 96, 120], id: \.self) { Text("\($0)h").tag($0) }
            }
            Picker("Pen/IAGE Alerta (dias)", selection: $store.deviceAgeThresholds.penWarnD) {
                ForEach([14, 20, 21, 25, 28, 35], id: \.self) { Text("\($0)d").tag($0) }
            }
            Picker("Pen/IAGE Urgente (dias)", selection: $store.deviceAgeThresholds.penUrgentD) {
                ForEach([21, 25, 28, 35, 42], id: \.self) { Text("\($0)d").tag($0) }
            }
        }
    }

    // MARK: - Pump Section

    private var pumpSection: some View {
        @Bindable var store = store

        return Section("Bomba de Insulina") {
            HStack {
                Text("Taxa basal programada")
                Spacer()
                TextField("0.00", value: $store.scheduledBasalRate, format: .number.precision(.fractionLength(2)))
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                Text("U/h")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Bolus Calculator Section

    private var bolusCalcSection: some View {
        @Bindable var store = store
        let ul = store.unit.label

        return Section("Calculadora de Bolus") {
            HStack {
                Text("ISF")
                Spacer()
                if store.unit == .mmol {
                    TextField("2.8", value: isfDisplayBinding, format: .number.precision(.fractionLength(1)))
                        .frame(width: 70)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                } else {
                    TextField("50", value: isfDisplayBinding, format: .number.precision(.fractionLength(0)))
                        .frame(width: 70)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                }
                Text("\(ul)/U")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("ICR")
                Spacer()
                TextField("15", value: $store.icr, format: .number)
                    .frame(width: 70)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                Text("g/U")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Alvo mínimo")
                Spacer()
                if store.unit == .mmol {
                    TextField("5.6", value: targetBGDisplayBinding, format: .number.precision(.fractionLength(1)))
                        .frame(width: 70)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                } else {
                    TextField("100", value: targetBGDisplayBinding, format: .number.precision(.fractionLength(0)))
                        .frame(width: 70)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                }
                Text(ul)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Alvo máximo")
                Spacer()
                if store.unit == .mmol {
                    TextField("6.7", value: targetBGHighDisplayBinding, format: .number.precision(.fractionLength(1)))
                        .frame(width: 70)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                } else {
                    TextField("120", value: targetBGHighDisplayBinding, format: .number.precision(.fractionLength(0)))
                        .frame(width: 70)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                }
                Text(ul)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Picker("Incremento caneta rápida", selection: $store.rapidPenStep) {
                Text("1 U").tag(1.0)
                Text("0.5 U").tag(0.5)
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Alarms Section

    private var alarmsSection: some View {
        @Bindable var store = store

        return Section("Alarmes") {
            Toggle("Alarmes ativados", isOn: $store.alarmConfig.enabled)

            if store.alarmConfig.enabled {
                Toggle("Muito baixo", isOn: $store.alarmConfig.veryLow)
                Toggle("Baixo", isOn: $store.alarmConfig.low)
                Toggle("Alto", isOn: $store.alarmConfig.high)
                Toggle("Muito alto", isOn: $store.alarmConfig.veryHigh)
                Toggle("Preditivo AR2", isOn: $store.alarmConfig.predictive)
                Toggle("Variação rápida", isOn: $store.alarmConfig.rapidChange)
                Toggle("Dados desatualizados", isOn: $store.alarmConfig.stale)

                if store.alarmConfig.stale {
                    Stepper("Minutos: \(store.alarmConfig.staleMins)", value: $store.alarmConfig.staleMins, in: 5...60, step: 5)
                }
            }
        }
    }

    // MARK: - Save Section

    private var saveSection: some View {
        Section {
            Button {
                Task { await saveSettings() }
            } label: {
                HStack {
                    Spacer()
                    if isSaving {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text("Salvar Configurações")
                        .font(.headline)
                    Spacer()
                }
            }
            .disabled(isSaving)

            if let message = saveMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(message.contains("Erro") ? .red : Color(hex: "#22c55e"))
            }
        }
    }

    // MARK: - Helpers

    private var diaBinding: Binding<Double> {
        Binding(
            get: { store.dia },
            set: { store.dia = $0 }
        )
    }

    private var carbRateBinding: Binding<Double> {
        Binding(
            get: { store.carbAbsorptionRate },
            set: { store.carbAbsorptionRate = $0 }
        )
    }

    /// Creates bindings that read/write Double properties (stored in mg/dL) in the current display unit.
    private var isfDisplayBinding: Binding<Double> {
        Binding(
            get: { GlucoseUnit.toDisplayUnit(store.isf, unit: store.unit) },
            set: { store.isf = GlucoseUnit.fromDisplayUnit($0, unit: store.unit) }
        )
    }
    private var targetBGDisplayBinding: Binding<Double> {
        Binding(
            get: { GlucoseUnit.toDisplayUnit(store.targetBG, unit: store.unit) },
            set: { store.targetBG = GlucoseUnit.fromDisplayUnit($0, unit: store.unit) }
        )
    }
    private var targetBGHighDisplayBinding: Binding<Double> {
        Binding(
            get: { GlucoseUnit.toDisplayUnit(store.targetBGHigh, unit: store.unit) },
            set: { store.targetBGHigh = GlucoseUnit.fromDisplayUnit($0, unit: store.unit) }
        )
    }

    private func saveSettings() async {
        guard let client = authStore.apiClient else { return }
        isSaving = true
        saveMessage = nil

        let settings = AppSettings(
            unit: store.unit.rawValue,
            patientName: store.patientName,
            refreshInterval: store.refreshInterval,
            alarmThresholds: store.alarmThresholds,
            dia: store.dia,
            carbAbsorptionRate: store.carbAbsorptionRate,
            scheduledBasalRate: store.scheduledBasalRate,
            isf: store.isf,
            icr: store.icr,
            targetBG: store.targetBG,
            targetBGHigh: store.targetBGHigh,
            rapidPenStep: store.rapidPenStep,
            predictionsDefault: store.predictionsDefault,
            alarmConfig: store.alarmConfig,
            deviceAgeThresholds: store.deviceAgeThresholds
        )

        do {
            try await client.saveSettings(settings)
            saveMessage = "Configurações salvas com sucesso"
        } catch {
            saveMessage = "Erro ao salvar: \(error.localizedDescription)"
        }

        isSaving = false
    }
}
