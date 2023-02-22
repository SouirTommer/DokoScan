import SwiftUI

struct TestView: View {
    var body: some View {
        NavigationStack {
            
                VStack {
                    NavigationLink {
                        HomeView()
                    } label: {
                        Text("Start")
                    }.buttonStyle(PrimaryButtonStyle())
                }
                .navigationTitle("Doko Scanning")
            }
    }
}

struct TestView_Previews: PreviewProvider {
    static var previews: some View {
        TestView()
    }
}
