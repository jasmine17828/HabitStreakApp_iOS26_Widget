import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            TasksView()
                .tabItem { Label("Tasks", systemImage: "checklist") }
        }
    }
}

#Preview {
    MainTabView()
}
