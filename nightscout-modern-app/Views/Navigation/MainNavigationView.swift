import SwiftUI

enum NavigationItem: String, CaseIterable, Identifiable {
    case dashboard
    case treatments
    case settings

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dashboard:  "Dashboard"
        case .treatments: "Tratamentos"
        case .settings:   "Configurações"
        }
    }

    var icon: String {
        switch self {
        case .dashboard:  "heart.text.square"
        case .treatments: "syringe"
        case .settings:   "gear"
        }
    }
}

struct MainNavigationView: View {
    @Environment(AuthStore.self) private var authStore
    @Environment(DashboardStore.self) private var store
    @State private var selectedItem: NavigationItem? = .dashboard
    @State private var showTreatmentForm = false
    @State private var showBolusCalculator = false

    var body: some View {
        mainContent
            .sheet(isPresented: $showTreatmentForm) {
                TreatmentFormView()
            }
            .sheet(isPresented: $showBolusCalculator) {
                BolusCalculatorView()
            }
    }

    @ViewBuilder
    private var mainContent: some View {
        #if os(macOS)
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
        }
        #else
        if UIDevice.current.userInterfaceIdiom == .pad {
            NavigationSplitView {
                sidebar
            } detail: {
                detailView
            }
        } else {
            NavigationStack {
                detailView
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Menu {
                                ForEach(NavigationItem.allCases) { item in
                                    Button {
                                        selectedItem = item
                                    } label: {
                                        Label(item.label, systemImage: item.icon)
                                    }
                                }

                                Divider()

                                Button {
                                    showTreatmentForm = true
                                } label: {
                                    Label("Novo Tratamento", systemImage: "plus")
                                }

                                Button {
                                    showBolusCalculator = true
                                } label: {
                                    Label("Calculadora de Bolus", systemImage: "square.grid.3x3.square")
                                }

                                Divider()

                                Button(role: .destructive) {
                                    authStore.logout()
                                } label: {
                                    Label("Sair", systemImage: "rectangle.portrait.and.arrow.right")
                                }
                            } label: {
                                Image(systemName: "line.3.horizontal")
                                    .font(.title3)
                            }
                        }

                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showTreatmentForm = true
                            } label: {
                                Image(systemName: "plus")
                            }
                        }

                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showBolusCalculator = true
                            } label: {
                                Image(systemName: "square.grid.3x3.square")
                            }
                        }
                    }
            }
        }
        #endif
    }

    private var sidebar: some View {
        List(selection: $selectedItem) {
            Section("Principal") {
                ForEach([NavigationItem.dashboard]) { item in
                    NavigationLink(value: item) {
                        Label(item.label, systemImage: item.icon)
                    }
                }
            }

            Section("Careportal") {
                Button {
                    showTreatmentForm = true
                } label: {
                    Label("Novo Tratamento", systemImage: "plus")
                }

                Button {
                    showBolusCalculator = true
                } label: {
                    Label("Calculadora de Bolus", systemImage: "square.grid.3x3.square")
                }

                NavigationLink(value: NavigationItem.treatments) {
                    Label("Tratamentos", systemImage: "syringe")
                }
            }

            Section {
                NavigationLink(value: NavigationItem.settings) {
                    Label("Configurações", systemImage: "gear")
                }
            }

            Section {
                Button(role: .destructive) {
                    authStore.logout()
                } label: {
                    Label("Sair", systemImage: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("DCGlyco")
        #if os(macOS)
        .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        #endif
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedItem {
        case .dashboard, .none:
            DashboardView()
        case .treatments:
            TreatmentListView()
        case .settings:
            SettingsView()
        }
    }
}

// MARK: - Treatment List (placeholder for now, will be expanded in Etapa 6)

struct TreatmentListView: View {
    @Environment(DashboardStore.self) private var store

    var body: some View {
        List {
            if store.treatments.isEmpty {
                ContentUnavailableView(
                    "Sem tratamentos",
                    systemImage: "syringe",
                    description: Text("Nenhum tratamento registrado no período.")
                )
            } else {
                ForEach(store.treatments, id: \.id) { treatment in
                    treatmentRow(treatment)
                }
            }
        }
        .navigationTitle("Tratamentos")
    }

    private func treatmentRow(_ t: Treatment) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(t.eventType)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(t.createdAtDate, format: .dateTime.month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                if let insulin = t.insulin, insulin > 0 {
                    Label(String(format: "%.1fU", insulin), systemImage: "syringe")
                        .font(.caption)
                        .foregroundStyle(Color(hex: "#3b82f6"))
                }
                if let carbs = t.carbs, carbs > 0 {
                    Label("\(Int(carbs))g", systemImage: "fork.knife")
                        .font(.caption)
                        .foregroundStyle(Color(hex: "#f97316"))
                }
                if let glucose = t.glucose, glucose > 0 {
                    Label("\(Int(glucose))", systemImage: "drop.fill")
                        .font(.caption)
                        .foregroundStyle(Color(hex: "#22c55e"))
                }
            }

            if let notes = t.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }
}
