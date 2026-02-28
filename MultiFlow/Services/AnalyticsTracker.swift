import Foundation

enum AnalyticsEvent: String {
    case shareDealOpened = "share_deal_opened"
    case shareLinkCreated = "share_link_created"
    case shareLinkCopied = "share_link_copied"
    case collabPanelViewed = "collab_panel_viewed"
    case collabNoteAddAttempted = "collab_note_add_attempted"
    case checklistItemAdded = "checklist_item_added"
    case paywallOpenedFromCollab = "paywall_opened_from_collab"
    case proUpgradeSuccessFromCollab = "pro_upgrade_success_from_collab"
    case scenarioCompareOpened = "scenario_compare_opened"
    case scenarioSaved = "scenario_saved"
    case scenarioApplied = "scenario_applied"
    case scenarioDeleted = "scenario_deleted"
    case scenarioLimitHitFree = "scenario_limit_hit_free"
    case paywallOpenedFromScenarioCompare = "paywall_opened_from_scenario_compare"
    case proUpgradeSuccessFromScenarioCompare = "pro_upgrade_success_from_scenario_compare"
    case offerChipTapped = "offer_chip_tapped"
    case offerTrackerOpened = "offer_tracker_opened"
    case offerCreated = "offer_created"
    case offerRevisionCreated = "offer_revision_created"
    case offerStatusChanged = "offer_status_changed"
    case offerClientDecisionChanged = "offer_client_decision_changed"
    case offerCommentCreated = "offer_comment_created"
    case offerLimitHitFree = "offer_limit_hit_free"
    case paywallOpenedFromOfferTracker = "paywall_opened_from_offer_tracker"
    case proUpgradeSuccessFromOfferTracker = "pro_upgrade_success_from_offer_tracker"
    case dealRoomOpened = "deal_room_opened"
    case dealRoomCreated = "deal_room_created"
    case dealRoomJoinedByCode = "deal_room_joined_by_code"
    case dealRoomStageChanged = "deal_room_stage_changed"
    case dealRoomNoteCreated = "deal_room_note_created"
    case dealRoomChecklistToggled = "deal_room_checklist_toggled"
    case dealRoomLimitHitFree = "deal_room_limit_hit_free"
    case paywallOpenedFromDealRoom = "paywall_opened_from_deal_room"
    case proUpgradeSuccessFromDealRoom = "pro_upgrade_success_from_deal_room"
}

enum AnalyticsTracker {
    static func track(_ event: AnalyticsEvent, metadata: [String: String] = [:]) {
        #if DEBUG
        let metadataString = metadata.isEmpty ? "" : " \(metadata)"
        print("[Analytics] \(event.rawValue)\(metadataString)")
        #endif
    }
}
