import WidgetKit
import AppIntents

struct WidgetConfigIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choose Event"
    static var description = IntentDescription("Set the title and date to count.")

    @Parameter(title: "Title", default: "Event")
    var title: String

    @Parameter(title: "Date")
    var date: Date?

    @Parameter(title: "Label")
    var label: String?

    @Parameter(title: "Icon", default: IconChoice.none)
    var icon: IconChoice

    @Parameter(title: "Count", default: .auto)
    var mode: CountMode

    @Parameter(title: "Repeat", default: Recurrence.none)
    var recurrence: Recurrence
}
