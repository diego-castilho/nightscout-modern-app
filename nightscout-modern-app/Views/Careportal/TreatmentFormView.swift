import SwiftUI

struct TreatmentFormView: View {
    @Environment(AuthStore.self) private var authStore
    @Environment(DashboardStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var eventType = "Meal Bolus"
    @State private var createdAt = Date()
    @State private var insulin = ""
    @State private var carbs = ""
    @State private var glucose = ""
    @State private var protein = ""
    @State private var fat = ""
    @State private var notes = ""
    @State private var duration = ""
    @State private var rate = ""
    @State private var immediateInsulin = ""
    @State private var extendedInsulin = ""
    @State private var preBolus = "0"
    @State private var exerciseType = "aerobico"
    @State private var intensity = "moderada"
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let eventTypes = [
        "Meal Bolus", "Snack Bolus", "Correction Bolus", "Combo Bolus",
        "Carb Correction", "BG Check", "Note", "Temp Basal",
        "Sensor Change", "Site Change", "Insulin Change",
        "Basal Pen Change", "Rapid Pen Change", "Exercise", "Basal Insulin"
    ]

    private let eventLabels: [String: String] = [
        "Meal Bolus": "Refeição + Bolus",
        "Snack Bolus": "Lanche + Bolus",
        "Correction Bolus": "Bolus de Correção",
        "Combo Bolus": "Combo Bolus",
        "Carb Correction": "Correção de Carbos",
        "BG Check": "Leitura de Glicose",
        "Note": "Anotação",
        "Temp Basal": "Basal Temporária",
        "Sensor Change": "Troca de Sensor",
        "Site Change": "Troca de Site",
        "Insulin Change": "Troca de Insulina",
        "Basal Pen Change": "Nova Caneta Basal",
        "Rapid Pen Change": "Nova Caneta Rápida",
        "Exercise": "Exercício",
        "Basal Insulin": "Insulina Basal"
    ]

    var body: some View {
        NavigationStack {
            Form {
                // Event type
                Section {
                    Picker("Tipo", selection: $eventType) {
                        ForEach(eventTypes, id: \.self) { type in
                            Text(eventLabels[type] ?? type).tag(type)
                        }
                    }

                    DatePicker("Data / Hora", selection: $createdAt)
                }

                // Dynamic fields
                Section {
                    dynamicFields
                }

                // Notes (always shown)
                Section {
                    TextField("Notas", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }

                // Error
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Novo Tratamento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        Task { await saveTreatment() }
                    }
                    .disabled(isSaving)
                }
            }
        }
        .onAppear {
            // Pre-fill glucose from latest reading
            if let latest = store.latest {
                glucose = "\(latest.sgv)"
            }
        }
    }

    // MARK: - Dynamic Fields

    @ViewBuilder
    private var dynamicFields: some View {
        switch eventType {
        case "Meal Bolus", "Snack Bolus":
            numberField("Insulina", text: $insulin, suffix: "U")
            numberField("Carboidratos", text: $carbs, suffix: "g")
            numberField("Proteínas", text: $protein, suffix: "g")
            numberField("Gorduras", text: $fat, suffix: "g")
            numberField("Glicose", text: $glucose, suffix: store.unit.label)
            preBolusPicker

        case "Correction Bolus":
            numberField("Insulina", text: $insulin, suffix: "U")
            numberField("Glicose", text: $glucose, suffix: store.unit.label)

        case "Combo Bolus":
            numberField("Insulina imediata", text: $immediateInsulin, suffix: "U")
            numberField("Insulina estendida", text: $extendedInsulin, suffix: "U")
            numberField("Duração", text: $duration, suffix: "min")
            numberField("Carboidratos", text: $carbs, suffix: "g")
            numberField("Glicose", text: $glucose, suffix: store.unit.label)

        case "Carb Correction":
            numberField("Carboidratos", text: $carbs, suffix: "g")
            numberField("Proteínas", text: $protein, suffix: "g")
            numberField("Gorduras", text: $fat, suffix: "g")
            numberField("Glicose", text: $glucose, suffix: store.unit.label)

        case "BG Check":
            numberField("Glicose", text: $glucose, suffix: store.unit.label)

        case "Temp Basal":
            numberField("Taxa", text: $rate, suffix: "U/h")
            numberField("Duração", text: $duration, suffix: "min")

        case "Exercise":
            numberField("Duração", text: $duration, suffix: "min")
            Picker("Tipo", selection: $exerciseType) {
                Text("Aeróbico").tag("aerobico")
                Text("Anaeróbico").tag("anaerobico")
                Text("Misto").tag("misto")
            }
            .pickerStyle(.segmented)
            Picker("Intensidade", selection: $intensity) {
                Text("Leve").tag("leve")
                Text("Moderada").tag("moderada")
                Text("Intensa").tag("intensa")
            }
            .pickerStyle(.segmented)

        case "Basal Insulin":
            numberField("Insulina", text: $insulin, suffix: "U")

        default:
            EmptyView()
        }
    }

    private func numberField(_ label: String, text: Binding<String>, suffix: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: text)
                .frame(width: 80)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
            Text(suffix)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .leading)
        }
    }

    private var preBolusPicker: some View {
        Picker("Pré-bolus", selection: $preBolus) {
            Text("-60 min").tag("-60")
            Text("-30 min").tag("-30")
            Text("-15 min").tag("-15")
            Text("Agora").tag("0")
            Text("+15 min").tag("15")
            Text("+30 min").tag("30")
            Text("+60 min").tag("60")
        }
    }

    // MARK: - Save

    private func saveTreatment() async {
        guard let client = authStore.apiClient else {
            errorMessage = "Não conectado ao servidor"
            return
        }

        isSaving = true
        errorMessage = nil

        // Adjust date for pre-bolus
        var adjustedDate = createdAt
        if let preBolusMins = Double(preBolus), preBolusMins != 0 {
            adjustedDate = createdAt.addingTimeInterval(preBolusMins * 60)
        }

        let formatter = ISO8601DateFormatter()
        var body: [String: Any] = [
            "eventType": eventType,
            "created_at": formatter.string(from: adjustedDate),
            "enteredBy": "dcglyco-app",
            "units": store.unit.rawValue
        ]

        if let v = Double(insulin), v > 0 { body["insulin"] = v }
        if let v = Double(carbs), v > 0 { body["carbs"] = v }
        if let v = Double(glucose), v > 0 { body["glucose"] = v; body["glucoseType"] = "Sensor" }
        if let v = Double(protein), v > 0 { body["protein"] = v }
        if let v = Double(fat), v > 0 { body["fat"] = v }
        if let v = Double(duration), v > 0 { body["duration"] = v }
        if let v = Double(rate), v > 0 { body["rate"] = v }
        if let v = Double(immediateInsulin), v > 0 { body["immediateInsulin"] = v }
        if let v = Double(extendedInsulin), v > 0 { body["extendedInsulin"] = v }
        if !notes.isEmpty { body["notes"] = notes }
        if exerciseType != "aerobico" { body["exerciseType"] = exerciseType }
        if intensity != "moderada" { body["intensity"] = intensity }

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
