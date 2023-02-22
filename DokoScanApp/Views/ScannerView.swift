
import SwiftUI
import Lottie

struct Scanner: UIViewControllerRepresentable {

    func makeUIViewController(context: Context) -> UINavigationController {
        UINavigationController(rootViewController: RoomCaptureViewController())
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {

    }

}

struct PreviewView: UIViewControllerRepresentable {

    func makeUIViewController(context: Context) -> UINavigationController {
        UINavigationController(rootViewController: PreviewViewController())
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {

    }

}

