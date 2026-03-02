import SwiftUI

struct BolusCalculatorView: View {
    @Environment(AuthStore.self) private var authStore
    @Environment(DashboardStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var currentBG = ""
    @State private var carbsInput = ""
    @State private var localISF = ""
    @State private var localICR = ""
    @State private var localTargetLow = ""
    @State private var localTargetHigh = ""

    var body: some View {
        NavigationStack {
            Form {
                inputSection
                breakdownSection
                actionsSection
            }
            .navigationTitle("Calculadora de Bolus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
            }
            .onAppear { populateDefaults() }
        }
    }

    // MARK: - Inputs

    private var inputSection: some View {
        let ul = store.unit.label

        return Section("Dados") {
            HStack {
                Text("Glicose atual")
                Spacer()
                TextField("---", text: $currentBG)
                    .frame(width: 70)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                Text(ul)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Carboidratos")
                Spacer()
                TextField("0", text: $carbsInput)
                    .frame(width: 70)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.numberPad)
                Text("g")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("IOB atual")
                Spacer()
                Text(String(format: "%.2f U", store.iob))
                    .foregroundStyle(Color(hex: "#3b82f6"))
                    .monospacedDigit()
            }

            DisclosureGroup("Parâmetros") {
                paramField("ISF", text: $localISF, suffix: "\(ul)/U")
                paramField("ICR", text: $localICR, suffix: "g/U")
                paramField("Alvo mín.", text: $localTargetLow, suffix: ul)
                paramField("Alvo máx.", text: $localTargetHigh, suffix: ul)
            }
        }
    }

    private func paramField(_ label: String, text: Binding<String>, suffix: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            TextField("", text: text)
                .frame(width: 60)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
            Text(suffix)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)
        }
    }

    // MARK: - Breakdown

    private var breakdownSection: some View {
        let result = computeResult()

        return Section("Resultado") {
            if let r = result {
                // Projected BG
                HStack {
                    Text("Glicose projetada (após IOB)")
                        .font(.subheadline)
                    Spacer()
                    Text(GlucoseUnit.formatGlucose(r.projectedBG, unit: store.unit) + " " + store.unit.label)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                }

                // Food dose
                HStack {
                    Text("Carbos")
                        .font(.subheadline)
                    Spacer()
                    Text(String(format: "%+.2f U", r.foodDose))
                        .font(.subheadline.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(Color(hex: "#f97316"))
                }

                // Correction
                HStack {
                    Text("Correção")
                        .font(.subheadline)
                    Spacer()
                    if abs(r.correctionDose) < 0.01 {
                        Text("dentro do alvo")
                            .font(.caption)
                            .foregroundStyle(Color(hex: "#22c55e"))
                    } else {
                        Text(String(format: "%+.2f U", r.correctionDose))
                            .font(.subheadline.weight(.medium))
                            .monospacedDigit()
                            .foregroundStyle(r.correctionDose > 0 ? Color(hex: "#ef4444") : Color(hex: "#22c55e"))
                    }
                }

                Divider()

                // Suggested (raw)
                HStack {
                    Text("Calculado")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(String(format: "%.2f U", r.suggested))
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(r.suggested < 0 ? Color(hex: "#f59e0b") : .primary)
                }

                // Warning if negative
                if r.suggested < 0, r.carbEquivalent > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color(hex: "#f59e0b"))
                        Text("Excesso de insulina ativa. Considere \(r.carbEquivalent)g de carbos.")
                            .font(.caption)
                            .foregroundStyle(Color(hex: "#f59e0b"))
                    }
                    .padding(.vertical, 4)
                }

                // Rounded dose
                if r.suggested > 0 {
                    Divider()
                    HStack {
                        Text("Dose sugerida")
                            .font(.headline)
                        Spacer()
                        Text(String(format: "%.1f U", roundedDose(r.suggested)))
                            .font(.title2.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(Color(hex: "#22c55e"))
                    }
                }

                // Temp basal alternative
                if let tb30 = r.tempBasal30min, (0...200).contains(tb30) {
                    HStack {
                        Text("Alt. Temp Basal 30min")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(tb30)%")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                    }
                }
                if let tb60 = r.tempBasal1h, (0...200).contains(tb60) {
                    HStack {
                        Text("Alt. Temp Basal 1h")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(tb60)%")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                    }
                }
            } else {
                Text("Insira glicose atual para calcular")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        let result = computeResult()
        let dose = result.map { roundedDose($0.suggested) } ?? 0
        let hasCarbs = (Double(carbsInput) ?? 0) > 0

        return Section {
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button("Registrar Meal Bolus") {
                registerTreatment(eventType: "Meal Bolus", dose: dose)
            }
            .disabled((dose <= 0 && !hasCarbs) || isSaving)

            Button("Registrar Correction Bolus") {
                registerTreatment(eventType: "Correction Bolus", dose: dose)
            }
            .disabled(dose <= 0 || isSaving)
        }
    }

    // MARK: - Computation

    private func computeResult() -> BolusBreakdown? {
        guard let bg = Double(currentBG), bg > 0 else { return nil }

        let isf = Double(localISF) ?? store.isf
        let icr = Double(localICR) ?? store.icr
        let targetLow = Double(localTargetLow) ?? store.targetBG
        let targetHigh = Double(localTargetHigh) ?? store.targetBGHigh
        let carbs = Double(carbsInput) ?? 0

        // Convert from display unit to mg/dL if needed
        let bgMgdl = GlucoseUnit.fromDisplayUnit(bg, unit: store.unit)
        let isfMgdl = store.unit == .mmol ? isf * GlucoseUnit.mmolFactor : isf
        let targetLowMgdl = GlucoseUnit.fromDisplayUnit(targetLow, unit: store.unit)
        let targetHighMgdl = GlucoseUnit.fromDisplayUnit(targetHigh, unit: store.unit)

        return BolusCalculator.calculate(
            currentBG: bgMgdl,
            targetLow: targetLowMgdl,
            targetHigh: targetHighMgdl,
            isf: isfMgdl,
            icr: icr,
            carbs: carbs,
            iob: store.iob,
            basalRate: store.scheduledBasalRate
        )
    }

    private func roundedDose(_ dose: Double) -> Double {
        let step = store.rapidPenStep
        return max(0, (dose / step).rounded() * step)
    }

    private func populateDefaults() {
        if let latest = store.latest {
            let val = GlucoseUnit.toDisplayUnit(Double(latest.sgv), unit: store.unit)
            currentBG = store.unit == .mmol ? String(format: "%.1f", val) : "\(latest.sgv)"
        }

        if store.unit == .mmol {
            localISF = String(format: "%.1f", store.isf / GlucoseUnit.mmolFactor)
            localTargetLow = String(format: "%.1f", store.targetBG / GlucoseUnit.mmolFactor)
            localTargetHigh = String(format: "%.1f", store.targetBGHigh / GlucoseUnit.mmolFactor)
        } else {
            localISF = String(format: "%.0f", store.isf)
            localTargetLow = String(format: "%.0f", store.targetBG)
            localTargetHigh = String(format: "%.0f", store.targetBGHigh)
        }
        localICR = String(format: "%.1f", store.icr)
    }

    @State private var isSaving = false
    @State private var errorMessage: String?

    private func registerTreatment(eventType: String, dose: Double) {
        guard let client = authStore.apiClient else {
            errorMessage = "Não conectado ao servidor"
            return
        }

        isSaving = true
        errorMessage = nil

        let formatter = ISO8601DateFormatter()
        var body: [String: Any] = [
            "eventType": eventType,
            "created_at": formatter.string(from: Date()),
            "enteredBy": "nightscout-app",
            "units": store.unit.rawValue,
        ]

        if dose > 0 { body["insulin"] = dose }
        if let carbs = Double(carbsInput), carbs > 0 { body["carbs"] = carbs }
        if let bg = Double(currentBG), bg > 0 {
            let bgMgdl = GlucoseUnit.fromDisplayUnit(bg, unit: store.unit)
            body["glucose"] = bgMgdl
            body["glucoseType"] = "Sensor"
        }

        Task {
            do {
                let _: Treatment = try await client.createTreatment(body: body)
                await store.refreshIOBCOB()
                dismiss()
            } catch {
                errorMessage = "Erro ao salvar: \(error.localizedDescription)"
            }
            isSaving = false
        }
    }
}
