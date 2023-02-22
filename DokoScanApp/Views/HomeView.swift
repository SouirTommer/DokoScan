

import ARKit
import SwiftUI

struct HomeView: View {

    @State var showRoomCaptureView = false
    @State var showPreview = false
    @State var isImageAnimating = false

    var isRoomCaptureSupported: Bool {
        ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    }

    var infoText: String {
        isRoomCaptureSupported
        ? "掃描你的房間，將你的設備對准你空間裡的所有牆壁、窗戶、門和家具。完成後，你可以在已掃描的物體上添加標記，以幫助老年人更快找到它們。"
        : "Device not supported. Space scanning requires a LiDAR enabled device."
    }

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                Image(systemName: "viewfinder.circle")
                    .imageScale(.large)
                    .foregroundColor(.accentColor)
                    .font(.largeTitle)
                    .scaleEffect(isImageAnimating ? 0.8 : 1.1)
                    .onAppear {
                        withAnimation(Animation.linear(duration: 0.8).repeatForever()) {
                            isImageAnimating = true
                        }
                    }
                
                Spacer().frame(height: 20)
                Text("Doko Scanning").font(.title)
                Text(infoText)
                    .padding()
                    .multilineTextAlignment(.center)
                Button {
                    withAnimation { showPreview.toggle() }
                } label: {
                    Text("View Scanned Room")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!isRoomCaptureSupported)
                .opacity(isRoomCaptureSupported ? 1 : 0.5)

                Spacer()
                
                Button {
                    withAnimation { showRoomCaptureView.toggle() }
                } label: {
                    Text("haven't scan? begin scan")
                }
            }
            .padding()
            .fullScreenCover(isPresented: $showRoomCaptureView) {
                Scanner()
            }
            .fullScreenCover(isPresented: $showPreview) {
                PreviewView()
            }
            .toolbarBackground(.hidden, for: .automatic)
        }

    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
