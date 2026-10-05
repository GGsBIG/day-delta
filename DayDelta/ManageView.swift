import SwiftUI

/// The Money tab's Edit screen: a segmented switch between the category and
/// account managers.
struct ManageView: View {
    @Binding var categories: [Category]
    @Binding var accounts: [Account]
    @State private var tab = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    Text("Categories").tag(0)
                    Text("Accounts").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                if tab == 0 {
                    CategoryManagerView(categories: $categories)
                } else {
                    AccountManagerView(accounts: $accounts)
                }
            }
            .background(GrainientBackground())
        }
        .preferredColorScheme(.dark)
        .tint(.white)
    }
}
