import SwiftUI

private enum GradeProfileApplyScope: String, CaseIterable, Identifiable {
    case allProperties
    case provisionalOnly
    case defaultInheritedOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .allProperties: return "All Properties"
        case .provisionalOnly: return "Provisional Only"
        case .defaultInheritedOnly: return "Using Default Only"
        }
    }

    var description: String {
        switch self {
        case .allProperties:
            return "Apply this profile to every property in your portfolio."
        case .provisionalOnly:
            return "Apply only to properties currently marked as estimate/provisional."
        case .defaultInheritedOnly:
            return "Apply only to properties inheriting the default profile (no explicit override)."
        }
    }
}

struct GradeProfilesView: View {
    @EnvironmentObject var gradeProfileStore: GradeProfileStore
    @EnvironmentObject var propertyStore: PropertyStore
    @State private var showCreateSheet = false
    @State private var editingProfile: GradeProfile?
    @State private var isSavingDefault = false
    @State private var showApplyScopeDialog = false
    @State private var pendingApplyProfile: GradeProfile?

    var body: some View {
        ZStack {
            CanvasBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    header

                    if gradeProfileStore.profiles.isEmpty {
                        emptyState
                    } else {
                        ForEach(gradeProfileStore.profiles, id: \.id) { profile in
                            profileCard(profile)
                        }
                    }
                }
                .padding(24)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button {
                showCreateSheet = true
            } label: {
                Image(systemName: "plus")
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            GradeProfileEditorSheet(profile: nil)
                .environmentObject(gradeProfileStore)
        }
        .sheet(item: $editingProfile) { profile in
            GradeProfileEditorSheet(profile: profile)
                .environmentObject(gradeProfileStore)
        }
        .confirmationDialog(
            "Apply Profile",
            isPresented: $showApplyScopeDialog,
            titleVisibility: .visible
        ) {
            ForEach(GradeProfileApplyScope.allCases) { scope in
                Button(scope.title) {
                    if let profile = pendingApplyProfile {
                        Task { await apply(profile, scope: scope) }
                    }
                    pendingApplyProfile = nil
                }
            }
            Button("Cancel", role: .cancel) {
                pendingApplyProfile = nil
            }
        } message: {
            if let profile = pendingApplyProfile {
                Text("Apply \(profile.name) to which properties?")
            }
        }
        .onAppear {
            gradeProfileStore.listen()
            ensureDefaultIfNeeded()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Grade Profiles")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Color.richBlack)

            Text("Customize how your deals are graded.")
                .font(.system(.title3, design: .rounded).weight(.medium))
                .foregroundStyle(Color.richBlack.opacity(0.7))

            HStack(spacing: 10) {
                Capsule()
                    .fill(Color.primaryYellow)
                    .frame(width: 36, height: 6)
                Text("Weights + criteria toggles per strategy.")
                    .font(.system(.footnote, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Text("No profiles yet")
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack)
            Text("Create a profile to start grading deals your way.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Color.richBlack.opacity(0.7))
                .multilineTextAlignment(.center)
            Button("Create Profile") {
                editingProfile = nil
                showCreateSheet = true
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 28)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.cardSurface)
                .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 10)
        )
    }

    private func profileCard(_ profile: GradeProfile) -> some View {
        let isDefault = profile.id == gradeProfileStore.defaultProfileId
        let usageCount = propertyUsageCount(for: profile)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(Color(hex: profile.colorHex))
                    .frame(width: 10, height: 10)
                Text(profile.name)
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack)
                Spacer()
                if isDefault {
                    Text("Default")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(Color.primaryYellow.opacity(0.8))
                        )
                }
            }

            Text("\(profile.enabledCriteriaCount) of 6 active")
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack.opacity(0.65))

            ProfileWeightBar(title: "Cash-on-Cash", value: profile.weightCashOnCash, isEnabled: profile.enabledCashOnCash)
            ProfileWeightBar(title: "DCR", value: profile.weightDcr, isEnabled: profile.enabledDcr)
            ProfileWeightBar(title: "Cap Rate", value: profile.weightCapRate, isEnabled: profile.enabledCapRate)
            ProfileWeightBar(title: "Cash Flow", value: profile.weightCashFlow, isEnabled: profile.enabledCashFlow)
            ProfileWeightBar(title: "Equity Gain", value: profile.weightEquityGain, isEnabled: profile.enabledEquityGain)
            ProfileWeightBar(title: "NOI", value: profile.weightNoi, isEnabled: profile.enabledNoi)

            Text(usageCount)
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack.opacity(0.6))

            HStack(spacing: 10) {
                Button(action: {
                    Task { await setDefault(profile) }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: isDefault ? "checkmark.seal.fill" : "star.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text(isDefault ? "Default" : "Set Default")
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                    }
                    .foregroundStyle(Color.richBlack)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(isDefault ? Color.primaryYellow.opacity(0.85) : Color.softGray)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isSavingDefault)

                Button {
                    pendingApplyProfile = profile
                    showApplyScopeDialog = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Apply")
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                    }
                    .foregroundStyle(Color.richBlack)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.primaryYellow.opacity(0.25))
                    )
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    editingProfile = profile
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.richBlack.opacity(0.7))
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle().stroke(Color.richBlack.opacity(0.35), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    Task { await deleteProfile(profile) }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.red)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle().stroke(Color.red.opacity(0.8), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.cardSurface)
        )
    }

    private func setDefault(_ profile: GradeProfile) async {
        isSavingDefault = true
        do {
            try await gradeProfileStore.setDefaultProfile(profile)
        } catch { }
        isSavingDefault = false
    }

    private func deleteProfile(_ profile: GradeProfile) async {
        do {
            try await gradeProfileStore.deleteProfile(profile)
            let affected = propertyStore.properties.filter { $0.gradeProfileId == profile.id }
            for var item in affected {
                item.gradeProfileId = nil
                try? await propertyStore.updateProperty(item)
            }
        } catch { }
    }

    private func apply(_ profile: GradeProfile, scope: GradeProfileApplyScope) async {
        let targetIndices: [Int] = propertyStore.properties.indices.filter { index in
            let item = propertyStore.properties[index]
            switch scope {
            case .allProperties:
                return true
            case .provisionalOnly:
                return item.isProvisionalEstimate
            case .defaultInheritedOnly:
                return item.gradeProfileId == nil
            }
        }

        for index in targetIndices {
            var item = propertyStore.properties[index]
            item.gradeProfileId = profile.id
            propertyStore.properties[index] = item
            try? await propertyStore.updateProperty(item)
        }
    }

    private func ensureDefaultIfNeeded() {
        guard gradeProfileStore.defaultProfileId == nil,
              let first = gradeProfileStore.profiles.first else { return }
        Task { try? await gradeProfileStore.setDefaultProfile(first) }
    }

    private func propertyUsageCount(for profile: GradeProfile) -> String {
        let properties = propertyStore.properties
        let profileKey = profile.id ?? profile.name
        let count = properties.filter {
            let effective = gradeProfileStore.effectiveProfile(for: $0)
            return (effective.id ?? effective.name) == profileKey
        }.count
        return "Used by \(count) properties"
    }
}

struct ProfileWeightBar: View {
    let title: String
    let value: Double
    var isEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack.opacity(isEnabled ? 0.7 : 0.45))
                Spacer()
                Text(isEnabled ? String(format: "%.0f%%", value) : "Off")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack.opacity(isEnabled ? 0.7 : 0.45))
            }
            GeometryReader { proxy in
                let width = proxy.size.width
                let filled = max(min(value / 100.0, 1), 0) * width
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.softGray)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isEnabled ? Color.primaryYellow : Color.richBlack.opacity(0.2))
                        .frame(width: isEnabled ? filled : 0)
                }
            }
            .frame(height: 8)
        }
    }
}

struct GradeProfileEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var gradeProfileStore: GradeProfileStore

    let profile: GradeProfile?

    @State private var name = ""
    @State private var weightCashOnCash: Double = 30
    @State private var weightDcr: Double = 25
    @State private var weightCapRate: Double = 20
    @State private var weightCashFlow: Double = 15
    @State private var weightEquityGain: Double = 10
    @State private var weightNoi: Double = 10
    @State private var enabledCashOnCash = true
    @State private var enabledDcr = true
    @State private var enabledCapRate = true
    @State private var enabledCashFlow = true
    @State private var enabledEquityGain = true
    @State private var enabledNoi = true
    @State private var color: Color = .yellow
    @State private var formError: String?

    private enum Criterion {
        case cashOnCash
        case dcr
        case capRate
        case cashFlow
        case equityGain
        case noi
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    if profile != nil {
                        Text("Editing Profile")
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color.richBlack.opacity(0.6))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    LabeledTextField(title: "Profile Name", text: $name, keyboard: .default)

                    criteriaRow(
                        criterion: .cashOnCash,
                        title: "Cash-on-Cash",
                        subtitle: "Annual cash flow vs cash invested",
                        isOn: $enabledCashOnCash,
                        value: $weightCashOnCash
                    )
                    criteriaRow(
                        criterion: .dcr,
                        title: "DCR",
                        subtitle: "NOI coverage of annual debt service",
                        isOn: $enabledDcr,
                        value: $weightDcr
                    )
                    criteriaRow(
                        criterion: .capRate,
                        title: "Cap Rate",
                        subtitle: "NOI yield relative to purchase price",
                        isOn: $enabledCapRate,
                        value: $weightCapRate
                    )
                    criteriaRow(
                        criterion: .cashFlow,
                        title: "Cash Flow",
                        subtitle: "Annual cash flow after debt service",
                        isOn: $enabledCashFlow,
                        value: $weightCashFlow
                    )
                    criteriaRow(
                        criterion: .equityGain,
                        title: "Equity Gain",
                        subtitle: "Principal paydown + appreciation",
                        isOn: $enabledEquityGain,
                        value: $weightEquityGain
                    )
                    criteriaRow(
                        criterion: .noi,
                        title: "NOI",
                        subtitle: "Annual NOI per unit",
                        isOn: $enabledNoi,
                        value: $weightNoi
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Profile Color")
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(Color.richBlack)
                            Spacer()
                            ColorPicker("", selection: $color, supportsOpacity: true)
                                .labelsHidden()
                        }

                        Text("Only enabled criteria affect grade. Active weights are normalized automatically.")
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color.richBlack.opacity(0.6))
                    }
                    .cardStyle()

                    let activeTotal = activeWeightTotal
                    HStack {
                        Text("Active Weight Total")
                            .font(.system(.footnote, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color.richBlack.opacity(0.7))
                        Spacer()
                        Text(String(format: "%.0f%%", activeTotal))
                            .font(.system(.footnote, design: .rounded).weight(.bold))
                            .foregroundStyle(Color.richBlack)
                    }
                    .padding(.top, 6)

                    if let formError {
                        Text(formError)
                            .font(.system(.footnote, design: .rounded).weight(.semibold))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(24)
            }
            .navigationTitle(profile == nil ? "New Profile" : "Edit Profile")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { Task { await save() } }
                        .disabled(!canSave)
                }
            }
            .onAppear { hydrate() }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && hasAtLeastOneEnabledCriterion
    }

    private var hasAtLeastOneEnabledCriterion: Bool {
        enabledCashOnCash || enabledDcr || enabledCapRate || enabledCashFlow || enabledEquityGain || enabledNoi
    }

    private var activeWeightTotal: Double {
        (enabledCashOnCash ? weightCashOnCash : 0)
            + (enabledDcr ? weightDcr : 0)
            + (enabledCapRate ? weightCapRate : 0)
            + (enabledCashFlow ? weightCashFlow : 0)
            + (enabledEquityGain ? weightEquityGain : 0)
            + (enabledNoi ? weightNoi : 0)
    }

    private func criteriaRow(
        criterion: Criterion,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>,
        value: Binding<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack)
                    Text(subtitle)
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack.opacity(0.6))
                }
                Spacer()
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: Color.primaryYellow))
                    .onChange(of: isOn.wrappedValue) { _, _ in
                        value.wrappedValue = clampedWeight(value.wrappedValue, for: criterion)
                    }
            }

            HStack {
                Text(isOn.wrappedValue ? String(format: "%.0f%%", value.wrappedValue) : "Off")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack.opacity(0.7))
                Spacer()
            }

            Slider(value: sliderBinding(for: criterion, value: value), in: 0...100, step: 1)
                .tint(Color.primaryYellow)
                .disabled(!isOn.wrappedValue)
                .opacity(isOn.wrappedValue ? 1 : 0.45)
        }
        .cardStyle()
    }

    private func sliderBinding(for criterion: Criterion, value: Binding<Double>) -> Binding<Double> {
        Binding<Double>(
            get: { value.wrappedValue },
            set: { newValue in
                value.wrappedValue = clampedWeight(newValue, for: criterion)
            }
        )
    }

    private func clampedWeight(_ proposed: Double, for criterion: Criterion) -> Double {
        let capped = max(0, proposed)
        let maxAllowed = max(0, 100 - otherActiveWeightTotal(excluding: criterion))
        return min(capped, maxAllowed)
    }

    private func otherActiveWeightTotal(excluding criterion: Criterion) -> Double {
        var total = 0.0
        if criterion != .cashOnCash, enabledCashOnCash { total += weightCashOnCash }
        if criterion != .dcr, enabledDcr { total += weightDcr }
        if criterion != .capRate, enabledCapRate { total += weightCapRate }
        if criterion != .cashFlow, enabledCashFlow { total += weightCashFlow }
        if criterion != .equityGain, enabledEquityGain { total += weightEquityGain }
        if criterion != .noi, enabledNoi { total += weightNoi }
        return total
    }

    private func hydrate() {
        guard let profile else {
            name = "Balanced"
            color = Color(hex: GradeProfile.defaultProfile.colorHex)
            return
        }
        name = profile.name
        weightCashOnCash = profile.weightCashOnCash
        weightDcr = profile.weightDcr
        weightCapRate = profile.weightCapRate
        weightCashFlow = profile.weightCashFlow
        weightEquityGain = profile.weightEquityGain
        weightNoi = profile.weightNoi
        enabledCashOnCash = profile.enabledCashOnCash
        enabledDcr = profile.enabledDcr
        enabledCapRate = profile.enabledCapRate
        enabledCashFlow = profile.enabledCashFlow
        enabledEquityGain = profile.enabledEquityGain
        enabledNoi = profile.enabledNoi
        color = Color(hex: profile.colorHex)
    }

    private func save() async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard hasAtLeastOneEnabledCriterion else {
            formError = "Enable at least one criterion to save this profile."
            return
        }

        formError = nil
        let newProfile = GradeProfile(
            id: profile?.id,
            name: trimmed,
            weightCashOnCash: weightCashOnCash,
            weightDcr: weightDcr,
            weightCapRate: weightCapRate,
            weightCashFlow: weightCashFlow,
            weightEquityGain: weightEquityGain,
            weightNoi: weightNoi,
            enabledCashOnCash: enabledCashOnCash,
            enabledDcr: enabledDcr,
            enabledCapRate: enabledCapRate,
            enabledCashFlow: enabledCashFlow,
            enabledEquityGain: enabledEquityGain,
            enabledNoi: enabledNoi,
            colorHex: UIColor(color).hexString
        )

        do {
            if profile == nil {
                try await gradeProfileStore.addProfile(newProfile)
            } else {
                try await gradeProfileStore.updateProfile(newProfile)
            }
            dismiss()
        } catch {
            formError = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        GradeProfilesView()
            .environmentObject(GradeProfileStore())
            .environmentObject(PropertyStore())
    }
}
