import SwiftUI

struct OfferDetailSheet: View {
    @ObservedObject var store: OfferTrackerStore
    let property: Property
    let isPremium: Bool
    let onRequireUpgrade: () -> Void
    let onTrackEvent: (AnalyticsEvent, [String: String]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showCreateOfferSheet = false
    @State private var showRevisionSheet = false
    @State private var commentDraft = ""
    @State private var isSaving = false
    @State private var localError: String?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    headerSection
                    if let error = localError ?? store.errorMessage {
                        Text(error)
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let offer = store.selectedOffer {
                        currentOfferSummary(offer)
                        quickActions(offer)
                        termsSection(offer)
                        deadlinesSection
                        clientReviewSection(offer)
                        historySection
                    } else {
                        emptyState
                    }
                }
                .padding(24)
            }
            .background(
                ZStack {
                    CanvasBackground()
                        .ignoresSafeArea()
                }
            )
            .navigationTitle("Offer Tracker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showCreateOfferSheet) {
                OfferRevisionEditorView(
                    title: nextOfferTitle,
                    draft: OfferRevisionDraft.from(property: property),
                    confirmTitle: "Create Offer"
                ) { title, draft in
                    await createOffer(named: title, draft: draft)
                }
            }
            .sheet(isPresented: $showRevisionSheet) {
                OfferRevisionEditorView(
                    title: store.selectedOffer?.title ?? "Offer",
                    draft: store.currentRevision.map(OfferRevisionDraft.init) ?? OfferRevisionDraft.from(property: property),
                    confirmTitle: "Save Revision",
                    isEditingExistingOffer: true
                ) { _, draft in
                    await createRevision(draft)
                }
            }
        }
        .onAppear {
            onTrackEvent(.offerTrackerOpened, ["property_id": property.id ?? "unsaved"])
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            offerIdentityChip

            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(headerAccent.opacity(0.16))
                        .frame(width: 48, height: 48)

                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(headerAccent)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("Offer Command Center")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.richBlack)

                    Text(property.address)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.richBlack)
                        .lineLimit(2)

                    Text(headerSubtitle)
                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                        .foregroundStyle(Color.richBlack.opacity(0.62))
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                headerStatusBadge
            }

            HStack(spacing: 10) {
                headerMetricTile(
                    title: "Amount",
                    value: currency(store.currentRevision?.purchasePrice ?? property.purchasePrice),
                    tint: headerAccent
                )
                headerMetricTile(
                    title: "Client",
                    value: store.selectedOffer?.clientDecision.title ?? "Pending",
                    tint: Color.richBlack.opacity(0.7)
                )
                headerMetricTile(
                    title: "Next",
                    value: nextDeadlineDisplay,
                    tint: nextDeadlineColor
                )
            }

            Capsule(style: .continuous)
                .fill(headerAccent)
                .frame(width: 60, height: 5)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(headerAccent.opacity(0.18), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [headerAccent.opacity(0.15), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .shadow(color: headerAccent.opacity(0.14), radius: 16, x: 0, y: 8)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var offerIdentityChip: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(headerAccent)
                .padding(7)
                .background(
                    Circle()
                        .fill(headerAccent.opacity(0.14))
                )

            Text("Offer")
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(Color.richBlack)

            if let offer = store.selectedOffer {
                Circle()
                    .fill(statusStrongColor(for: offer.status))
                    .frame(width: 6, height: 6)

                Text(offer.status.title)
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .foregroundStyle(statusStrongColor(for: offer.status))
            } else {
                Text("Draft Ready")
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.richBlack.opacity(0.62))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(Color.cardSurface)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(headerAccent.opacity(0.22), lineWidth: 1)
                )
        )
    }

    private func currentOfferSummary(_ offer: PropertyOffer) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Live Snapshot")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.richBlack.opacity(0.55))
                    Text(offer.title)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.richBlack)
                }
                Spacer()
                statusPill(offer.status)
            }

            HStack(spacing: 10) {
                statPill("Amount", currency(store.currentRevision?.purchasePrice ?? property.purchasePrice))
                statPill("Revision", "#\(store.currentRevision?.revisionNumber ?? 1)")
                statPill("Client", offer.clientDecision.title)
            }
        }
        .cardStyle()
    }

    private var headerStatusBadge: some View {
        VStack(alignment: .trailing, spacing: 8) {
            statusPill(store.selectedOffer?.status ?? .draft)

            if let revision = store.currentRevision {
                Text("R\(revision.revisionNumber)")
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.richBlack.opacity(0.72))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.softGray)
                    )
            }
        }
    }

    private var headerSubtitle: String {
        if let offer = store.selectedOffer {
            if offer.isTerminal {
                return "Review the latest terms, history, and client direction."
            }
            return "Track counters, deadlines, and client direction in one place."
        }
        return "Start a draft, pressure-test terms, and keep the client aligned."
    }

    private var headerAccent: Color {
        guard let status = store.selectedOffer?.status else { return Color.primaryYellow }
        return statusStrongColor(for: status)
    }

    private var nextDeadlineDisplay: String {
        guard let nextDeadlineItem else { return "No date" }
        return nextDeadlineItem.shortLabel
    }

    private var nextDeadlineColor: Color {
        guard let nextDeadlineItem else { return Color.richBlack.opacity(0.7) }
        return accentColor(for: nextDeadlineItem.date)
    }

    private var nextDeadlineItem: OfferDeadlineItem? {
        var items: [OfferDeadlineItem] = []
        if let revision = store.currentRevision {
            items.append(contentsOf: deadlineItems(from: revision))
        }
        if let expiresAt = store.selectedOffer?.expiresAt {
            items.append(OfferDeadlineItem(title: "Expires", date: expiresAt))
        }
        return items
            .filter { $0.date.timeIntervalSinceNow > 0 }
            .sorted { $0.date < $1.date }
            .first
            ?? items.sorted { $0.date < $1.date }.first
    }

    private func headerMetricTile(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(.caption2, design: .rounded).weight(.bold))
                .foregroundStyle(Color.richBlack.opacity(0.52))
            Text(value)
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(Color.richBlack)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.softGray)
                .overlay(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(tint.opacity(0.18), lineWidth: 1)
                }
        )
    }

    private func quickActions(_ offer: PropertyOffer) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack)

            HStack(spacing: 10) {
                Button("New Offer") {
                    if !store.canCreateOffer {
                        onTrackEvent(.offerLimitHitFree, ["property_id": property.id ?? ""]) 
                        onTrackEvent(.paywallOpenedFromOfferTracker, ["property_id": property.id ?? ""]) 
                        onRequireUpgrade()
                    } else {
                        localError = nil
                        showCreateOfferSheet = true
                    }
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("Revise") {
                    guard !offer.isTerminal else {
                        localError = "Terminal offers cannot be revised. Create a new offer instead."
                        return
                    }
                    if !isPremium {
                        onTrackEvent(.paywallOpenedFromOfferTracker, ["property_id": property.id ?? ""]) 
                        onRequireUpgrade()
                        return
                    }
                    localError = nil
                    showRevisionSheet = true
                }
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(Color.richBlack)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.softGray)
                )
                .buttonStyle(.plain)
            }

            Menu {
                ForEach(OfferStatus.allCases) { status in
                    Button(status.title) {
                        Task { await updateStatus(offer, status: status) }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.branch")
                    Text("Change Status")
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                }
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(Color.richBlack)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.softGray)
                )
            }
            .buttonStyle(.plain)
        }
        .cardStyle()
    }

    private func termsSection(_ offer: PropertyOffer) -> some View {
        let revision = store.currentRevision
        return VStack(alignment: .leading, spacing: 12) {
            Text("Terms")
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack)

            if let revision {
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        statPill("Offer", currency(revision.purchasePrice))
                        statPill("Earnest", currency(revision.earnestMoney ?? 0, zeroAsDash: true))
                        statPill("Down", percent(revision.downPaymentPercent))
                    }
                    HStack(spacing: 10) {
                        statPill("Credit", currency(revision.closingCostCredit ?? 0, zeroAsDash: true))
                        statPill("Concessions", currency(revision.sellerConcessions ?? 0, zeroAsDash: true))
                        statPill("Appraisal", revision.appraisalContingency ? "Yes" : "No")
                    }
                    if let notes = revision.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(Color.richBlack.opacity(0.68))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } else {
                Text("Create an offer to start tracking terms.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.richBlack.opacity(0.6))
            }

            if let updatedAt = offer.updatedAt {
                Text("Updated \(RelativeDateTimeFormatter().localizedString(for: updatedAt, relativeTo: Date()))")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack.opacity(0.52))
            }
        }
        .cardStyle()
    }

    private var deadlinesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Deadlines")
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack)

            if let revision = store.currentRevision {
                let deadlinePills = deadlineItems(from: revision)
                if deadlinePills.isEmpty {
                    Text("No deadlines set yet.")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(Color.richBlack.opacity(0.6))
                } else {
                    OfferDeadlinePillView(items: deadlinePills)
                }
            } else {
                Text("Add terms first to track option, inspection, and financing windows.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.richBlack.opacity(0.6))
            }
        }
        .cardStyle()
    }

    private func clientReviewSection(_ offer: PropertyOffer) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Client Review")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack)
                Spacer()
                if !isPremium {
                    Button {
                        onTrackEvent(.paywallOpenedFromOfferTracker, ["property_id": property.id ?? ""]) 
                        onRequireUpgrade()
                    } label: {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.richBlack)
                            .padding(8)
                            .background(Circle().fill(Color.primaryYellow))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                ForEach(OfferClientDecision.allCases) { decision in
                    Button {
                        if !isPremium {
                            onTrackEvent(.paywallOpenedFromOfferTracker, ["property_id": property.id ?? ""]) 
                            onRequireUpgrade()
                            return
                        }
                        Task { await updateClientDecision(offer, decision: decision) }
                    } label: {
                        Text(decision.title)
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .foregroundStyle(offer.clientDecision == decision ? Color.richBlack : Color.richBlack.opacity(0.65))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(offer.clientDecision == decision ? Color.primaryYellow : Color.softGray)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            if !isPremium {
                Text("Client recommendations and comments unlock with Pro.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.richBlack.opacity(0.58))
            } else {
                VStack(spacing: 10) {
                    ForEach(store.comments) { comment in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(Color.primaryYellow.opacity(0.8))
                                .frame(width: 8, height: 8)
                                .padding(.top, 5)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(comment.body)
                                    .font(.system(.footnote, design: .rounded))
                                    .foregroundStyle(Color.richBlack)
                                if let createdAt = comment.createdAt {
                                    Text(RelativeDateTimeFormatter().localizedString(for: createdAt, relativeTo: Date()))
                                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                                        .foregroundStyle(Color.richBlack.opacity(0.55))
                                }
                            }
                            Spacer()
                            let currentUser = store.selectedOffer?.ownerUserId
                            if comment.authorUserId == currentUser {
                                Button(role: .destructive) {
                                    Task { await deleteComment(comment) }
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                HStack(spacing: 10) {
                    TextField("Add a note", text: $commentDraft, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                    Button("Add") {
                        Task { await addComment(to: offer) }
                    }
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.richBlack)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.primaryYellow)
                    )
                    .buttonStyle(.plain)
                    .disabled(commentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
        }
        .cardStyle()
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("History")
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.richBlack)
                Spacer()
                if !isPremium {
                    Text("Pro")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.richBlack)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.primaryYellow)
                        )
                }
            }

            if !isPremium {
                Text("Revision history and full timeline unlock with Pro.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.richBlack.opacity(0.6))
            } else {
                if store.revisions.isEmpty {
                    Text("No revisions yet.")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(Color.richBlack.opacity(0.6))
                } else {
                    VStack(spacing: 10) {
                        ForEach(store.revisions) { revision in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Revision #\(revision.revisionNumber)")
                                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                                        .foregroundStyle(Color.richBlack)
                                    Spacer()
                                    Text(currency(revision.purchasePrice))
                                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                                        .foregroundStyle(Color.richBlack)
                                }
                                if let createdAt = revision.createdAt {
                                    Text(RelativeDateTimeFormatter().localizedString(for: createdAt, relativeTo: Date()))
                                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                                        .foregroundStyle(Color.richBlack.opacity(0.55))
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.softGray)
                            )
                        }
                    }
                }

                if !store.activity.isEmpty {
                    OfferStatusTimelineView(activity: store.activity)
                }
            }
        }
        .cardStyle()
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("No offers yet")
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(Color.richBlack)
            Text("Create the first offer for this property. Multi-offer workflows and collaboration unlock with Pro.")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(Color.richBlack.opacity(0.6))
            Button("Create Offer") {
                if !store.canCreateOffer {
                    onTrackEvent(.offerLimitHitFree, ["property_id": property.id ?? ""]) 
                    onTrackEvent(.paywallOpenedFromOfferTracker, ["property_id": property.id ?? ""]) 
                    onRequireUpgrade()
                } else {
                    localError = nil
                    showCreateOfferSheet = true
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .cardStyle()
    }

    private var nextOfferTitle: String {
        "Offer \(store.offers.count + 1)"
    }

    private func deadlineItems(from revision: OfferRevision) -> [OfferDeadlineItem] {
        var items: [OfferDeadlineItem] = []
        let now = Date()
        if let days = revision.optionPeriodDays,
           let date = Calendar.current.date(byAdding: .day, value: days, to: revision.createdAt ?? now) {
            items.append(OfferDeadlineItem(title: "Option", date: date))
        }
        if let days = revision.inspectionPeriodDays,
           let date = Calendar.current.date(byAdding: .day, value: days, to: revision.createdAt ?? now) {
            items.append(OfferDeadlineItem(title: "Inspection", date: date))
        }
        if let days = revision.financingContingencyDays,
           let date = Calendar.current.date(byAdding: .day, value: days, to: revision.createdAt ?? now) {
            items.append(OfferDeadlineItem(title: "Financing", date: date))
        }
        if let date = revision.estimatedCloseDate {
            items.append(OfferDeadlineItem(title: "Close", date: date))
        }
        return items.sorted { $0.date < $1.date }
    }

    private func createOffer(named title: String, draft: OfferRevisionDraft) async {
        await withSavingState {
            do {
                try await store.createOffer(title: title, draft: draft)
                if let offer = store.selectedOffer {
                    onTrackEvent(.offerCreated, [
                        "property_id": property.id ?? "",
                        "offer_id": offer.id ?? "",
                        "status": offer.status.rawValue
                    ])
                }
                showCreateOfferSheet = false
            } catch let error as OfferTrackerError {
                localError = error.localizedDescription
                onTrackEvent(.offerLimitHitFree, ["property_id": property.id ?? ""]) 
                onTrackEvent(.paywallOpenedFromOfferTracker, ["property_id": property.id ?? ""]) 
                onRequireUpgrade()
            } catch {
                localError = error.localizedDescription
            }
        }
    }

    private func createRevision(_ draft: OfferRevisionDraft) async {
        guard let offer = store.selectedOffer else { return }
        await withSavingState {
            do {
                try await store.createRevision(for: offer, draft: draft)
                onTrackEvent(.offerRevisionCreated, [
                    "property_id": property.id ?? "",
                    "offer_id": offer.id ?? ""
                ])
                showRevisionSheet = false
            } catch {
                localError = error.localizedDescription
            }
        }
    }

    private func updateStatus(_ offer: PropertyOffer, status: OfferStatus) async {
        await withSavingState {
            do {
                try await store.updateStatus(for: offer, status: status)
                onTrackEvent(.offerStatusChanged, [
                    "property_id": property.id ?? "",
                    "offer_id": offer.id ?? "",
                    "status": status.rawValue
                ])
            } catch {
                localError = error.localizedDescription
            }
        }
    }

    private func updateClientDecision(_ offer: PropertyOffer, decision: OfferClientDecision) async {
        await withSavingState {
            do {
                try await store.updateClientDecision(for: offer, decision: decision)
                onTrackEvent(.offerClientDecisionChanged, [
                    "property_id": property.id ?? "",
                    "offer_id": offer.id ?? "",
                    "decision": decision.rawValue
                ])
            } catch {
                localError = error.localizedDescription
            }
        }
    }

    private func addComment(to offer: PropertyOffer) async {
        let body = commentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        await withSavingState {
            do {
                try await store.addComment(for: offer, body: body)
                commentDraft = ""
                onTrackEvent(.offerCommentCreated, [
                    "property_id": property.id ?? "",
                    "offer_id": offer.id ?? ""
                ])
            } catch {
                localError = error.localizedDescription
            }
        }
    }

    private func deleteComment(_ comment: OfferComment) async {
        await withSavingState {
            do {
                try await store.deleteComment(comment)
            } catch {
                localError = error.localizedDescription
            }
        }
    }

    private func withSavingState(_ work: @escaping () async -> Void) async {
        isSaving = true
        defer { isSaving = false }
        await work()
    }

    private func statusPill(_ status: OfferStatus) -> some View {
        Text(status.title)
            .font(.system(.caption, design: .rounded).weight(.bold))
            .foregroundStyle(Color.richBlack)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(statusColor(for: status))
            )
    }

    private func statPill(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(.caption2, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.richBlack.opacity(0.58))
            Text(value)
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(Color.richBlack)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.softGray)
        )
    }

    private func statusColor(for status: OfferStatus) -> Color {
        switch status {
        case .draft, .readyToSubmit:
            return Color.primaryYellow
        case .submitted, .counterReceived:
            return Color.blue.opacity(0.2)
        case .accepted:
            return Color.green.opacity(0.2)
        case .rejected, .withdrawn, .expired:
            return Color.red.opacity(0.18)
        }
    }

    private func statusStrongColor(for status: OfferStatus) -> Color {
        switch status {
        case .draft, .readyToSubmit:
            return Color.primaryYellow
        case .submitted, .counterReceived:
            return Color.blue.opacity(0.78)
        case .accepted:
            return Color.green.opacity(0.78)
        case .rejected, .withdrawn, .expired:
            return Color.red.opacity(0.78)
        }
    }

    private func accentColor(for date: Date) -> Color {
        let hours = date.timeIntervalSinceNow / 3600
        if hours < 0 { return .red.opacity(0.8) }
        if hours <= 24 { return Color.primaryYellow }
        return .green.opacity(0.7)
    }

    private func currency(_ value: Double, zeroAsDash: Bool = false) -> String {
        if zeroAsDash, abs(value) < 0.0001 {
            return "-"
        }
        return Formatters.currency.string(from: NSNumber(value: value)) ?? "$0"
    }

    private func percent(_ value: Double?) -> String {
        guard let value else { return "-" }
        return String(format: "%.0f%%", value)
    }
}

struct OfferDeadlineItem: Identifiable {
    let id = UUID()
    let title: String
    let date: Date

    var shortLabel: String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter.string(from: date)
    }
}

struct OfferDeadlinePillView: View {
    let items: [OfferDeadlineItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items) { item in
                HStack(spacing: 10) {
                    Circle()
                        .fill(accentColor(for: item.date))
                        .frame(width: 10, height: 10)
                    Text(item.title)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.richBlack)
                    Spacer()
                    Text(dateLabel(item.date))
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.richBlack.opacity(0.72))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.softGray)
                )
            }
        }
    }

    private func accentColor(for date: Date) -> Color {
        let hours = date.timeIntervalSinceNow / 3600
        if hours < 0 { return .red.opacity(0.8) }
        if hours <= 24 { return Color.primaryYellow }
        return .green.opacity(0.7)
    }

    private func dateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct OfferStatusTimelineView: View {
    let activity: [OfferActivityEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Activity")
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(Color.richBlack)

            ForEach(activity) { event in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(Color.primaryYellow.opacity(0.9))
                        .frame(width: 8, height: 8)
                        .padding(.top, 5)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.displayTitle)
                            .font(.system(.footnote, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color.richBlack)
                        if let createdAt = event.createdAt {
                            Text(RelativeDateTimeFormatter().localizedString(for: createdAt, relativeTo: Date()))
                                .font(.system(.caption2, design: .rounded).weight(.semibold))
                                .foregroundStyle(Color.richBlack.opacity(0.55))
                        }
                    }
                    Spacer()
                }
            }
        }
    }
}

struct OfferRevisionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var purchasePrice: String
    @State private var earnestMoney: String
    @State private var downPaymentPercent: String
    @State private var closingCostCredit: String
    @State private var optionPeriodDays: String
    @State private var inspectionPeriodDays: String
    @State private var financingContingencyDays: String
    @State private var appraisalContingency: Bool
    @State private var sellerConcessions: String
    @State private var estimatedCloseDate: Date
    @State private var includeCloseDate: Bool
    @State private var notes: String
    @State private var isSubmitting = false
    let confirmTitle: String
    let isEditingExistingOffer: Bool
    let onConfirm: (String, OfferRevisionDraft) async -> Void

    init(
        title: String,
        draft: OfferRevisionDraft,
        confirmTitle: String,
        isEditingExistingOffer: Bool = false,
        onConfirm: @escaping (String, OfferRevisionDraft) async -> Void
    ) {
        _title = State(initialValue: title)
        _purchasePrice = State(initialValue: Formatters.currencyTwo.string(from: NSNumber(value: draft.purchasePrice)) ?? String(draft.purchasePrice))
        _earnestMoney = State(initialValue: draft.earnestMoney.map { Formatters.currencyTwo.string(from: NSNumber(value: $0)) ?? String($0) } ?? "")
        _downPaymentPercent = State(initialValue: draft.downPaymentPercent.map { String(format: "%.0f", $0) } ?? "")
        _closingCostCredit = State(initialValue: draft.closingCostCredit.map { Formatters.currencyTwo.string(from: NSNumber(value: $0)) ?? String($0) } ?? "")
        _optionPeriodDays = State(initialValue: draft.optionPeriodDays.map(String.init) ?? "")
        _inspectionPeriodDays = State(initialValue: draft.inspectionPeriodDays.map(String.init) ?? "")
        _financingContingencyDays = State(initialValue: draft.financingContingencyDays.map(String.init) ?? "")
        _appraisalContingency = State(initialValue: draft.appraisalContingency)
        _sellerConcessions = State(initialValue: draft.sellerConcessions.map { Formatters.currencyTwo.string(from: NSNumber(value: $0)) ?? String($0) } ?? "")
        _estimatedCloseDate = State(initialValue: draft.estimatedCloseDate ?? Date())
        _includeCloseDate = State(initialValue: draft.estimatedCloseDate != nil)
        _notes = State(initialValue: draft.notes ?? "")
        self.confirmTitle = confirmTitle
        self.isEditingExistingOffer = isEditingExistingOffer
        self.onConfirm = onConfirm
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    if !isEditingExistingOffer {
                        LabeledTextField(title: "Offer Title", text: $title, keyboard: .default)
                    }
                    LabeledTextField(title: "Purchase Price", text: $purchasePrice, keyboard: .decimalPad)
                        .onChange(of: purchasePrice) { _, newValue in
                            purchasePrice = InputFormatters.formatCurrencyLive(newValue)
                        }
                    LabeledTextField(title: "Earnest Money", text: $earnestMoney, keyboard: .decimalPad)
                        .onChange(of: earnestMoney) { _, newValue in
                            earnestMoney = InputFormatters.formatCurrencyLive(newValue)
                        }
                    HStack(spacing: 10) {
                        LabeledTextField(title: "Down %", text: $downPaymentPercent, keyboard: .decimalPad)
                        LabeledTextField(title: "Closing Credit", text: $closingCostCredit, keyboard: .decimalPad)
                            .onChange(of: closingCostCredit) { _, newValue in
                                closingCostCredit = InputFormatters.formatCurrencyLive(newValue)
                            }
                    }
                    HStack(spacing: 10) {
                        LabeledTextField(title: "Option Days", text: $optionPeriodDays, keyboard: .numberPad)
                        LabeledTextField(title: "Inspection Days", text: $inspectionPeriodDays, keyboard: .numberPad)
                        LabeledTextField(title: "Financing Days", text: $financingContingencyDays, keyboard: .numberPad)
                    }
                    Toggle("Appraisal Contingency", isOn: $appraisalContingency)
                        .toggleStyle(SwitchToggleStyle(tint: Color.primaryYellow))
                        .padding(.horizontal, 4)
                    LabeledTextField(title: "Seller Concessions", text: $sellerConcessions, keyboard: .decimalPad)
                        .onChange(of: sellerConcessions) { _, newValue in
                            sellerConcessions = InputFormatters.formatCurrencyLive(newValue)
                        }

                    Toggle("Include Close Date", isOn: $includeCloseDate)
                        .toggleStyle(SwitchToggleStyle(tint: Color.primaryYellow))
                        .padding(.horizontal, 4)
                    if includeCloseDate {
                        DatePicker("Estimated Close", selection: $estimatedCloseDate, displayedComponents: .date)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color.richBlack)
                        TextField("Optional notes", text: $notes, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                    }

                    Button(isSubmitting ? "Saving..." : confirmTitle) {
                        Task { await submit() }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isSubmitting)
                }
                .padding(24)
            }
            .background(
                CanvasBackground()
                    .ignoresSafeArea()
            )
            .navigationTitle(confirmTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func submit() async {
        guard let purchaseValue = InputFormatters.parseCurrency(purchasePrice) else { return }
        isSubmitting = true
        let draft = OfferRevisionDraft(
            purchasePrice: purchaseValue,
            earnestMoney: InputFormatters.parseCurrency(earnestMoney),
            downPaymentPercent: Double(downPaymentPercent),
            closingCostCredit: InputFormatters.parseCurrency(closingCostCredit),
            optionPeriodDays: Int(optionPeriodDays),
            inspectionPeriodDays: Int(inspectionPeriodDays),
            financingContingencyDays: Int(financingContingencyDays),
            appraisalContingency: appraisalContingency,
            sellerConcessions: InputFormatters.parseCurrency(sellerConcessions),
            estimatedCloseDate: includeCloseDate ? estimatedCloseDate : nil,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        await onConfirm(title, draft)
        isSubmitting = false
        dismiss()
    }
}

extension OfferRevisionDraft {
    init(_ revision: OfferRevision) {
        self.init(
            purchasePrice: revision.purchasePrice,
            earnestMoney: revision.earnestMoney,
            downPaymentPercent: revision.downPaymentPercent,
            closingCostCredit: revision.closingCostCredit,
            optionPeriodDays: revision.optionPeriodDays,
            inspectionPeriodDays: revision.inspectionPeriodDays,
            financingContingencyDays: revision.financingContingencyDays,
            appraisalContingency: revision.appraisalContingency,
            sellerConcessions: revision.sellerConcessions,
            estimatedCloseDate: revision.estimatedCloseDate,
            notes: revision.notes
        )
    }
}
