import SwiftUI

struct GradeProfilesView: View {
    @EnvironmentObject var gradeProfileStore: GradeProfileStore
    @EnvironmentObject var propertyStore: PropertyStore
    @State private var showCreateSheet = false
    @State private var editingProfile: GradeProfile?
    @State private var isSavingDefault = false
    @State private var showApplyConfirm = false
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
        .alert("Apply Profile to All Properties?", isPresented: $showApplyConfirm) {
            Button("Apply", role: .destructive) {
                if let profile = pendingApplyProfile {
                    Task { await applyToAll(profile) }
                }
                pendingApplyProfile = nil
            }
            Button("Cancel", role: .cancel) {
                pendingApplyProfile = nil
            }
        } message: {
            Text("This will override every property’s grade profile.")
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
                Text("Weights that match your strategy.")
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

            ProfileWeightBar(title: "Cash-on-Cash", value: profile.weightCashOnCash)
            ProfileWeightBar(title: "DCR", value: profile.weightDcr)
            ProfileWeightBar(title: "Cap Rate", value: profile.weightCapRate)
            ProfileWeightBar(title: "Cash Flow", value: profile.weightCashFlow)
            ProfileWeightBar(title: "Equity Gain", value: profile.weightEquityGain)

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
                    showApplyConfirm = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Apply to All")
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

    private func applyToAll(_ profile: GradeProfile) async {
        for index in propertyStore.properties.indices {
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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack.opacity(0.7))
                Spacer()
                Text(String(format: "%.0f%%", value))
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack.opacity(0.7))
            }
            GeometryReader { proxy in
                let width = proxy.size.width
                let filled = max(min(value / 100.0, 1), 0) * width
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.softGray)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primaryYellow)
                        .frame(width: filled)
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
    @State private var color: Color = .yellow

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

                    weightSlider(title: "Cash-on-Cash", value: $weightCashOnCash)
                    weightSlider(title: "DCR", value: $weightDcr)
                    weightSlider(title: "Cap Rate", value: $weightCapRate)
                    weightSlider(title: "Cash Flow", value: $weightCashFlow)
                    weightSlider(title: "Equity Gain", value: $weightEquityGain)

                    HStack {
                        Text("Profile Color")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color.richBlack)
                        Spacer()
                        ColorPicker("", selection: $color, supportsOpacity: true)
                            .labelsHidden()
                    }
                    .cardStyle()

                    let total = weightCashOnCash + weightDcr + weightCapRate + weightCashFlow + weightEquityGain
                    HStack {
                        Text("Total Weight")
                            .font(.system(.footnote, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color.richBlack.opacity(0.7))
                        Spacer()
                        Text(String(format: "%.0f%%", total))
                            .font(.system(.footnote, design: .rounded).weight(.bold))
                            .foregroundStyle(Color.richBlack)
                    }
                    .padding(.top, 6)
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
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { hydrate() }
        }
    }

    private func weightSlider(title: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack)
                Spacer()
                Text(String(format: "%.0f%%", value.wrappedValue))
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack.opacity(0.7))
            }
            Slider(value: value, in: 0...100, step: 1)
                .tint(Color.primaryYellow)
        }
        .cardStyle()
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
        color = Color(hex: profile.colorHex)
    }

    private func save() async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let newProfile = GradeProfile(
            id: profile?.id,
            name: trimmed,
            weightCashOnCash: weightCashOnCash,
            weightDcr: weightDcr,
            weightCapRate: weightCapRate,
            weightCashFlow: weightCashFlow,
            weightEquityGain: weightEquityGain,
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
            dismiss()
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

