import UIKit
import RoomPlan
import SceneKit
import SceneKit.ModelIO

private enum SelectionState {
    case `none`
    case surface(SCNNode)
}

class PreviewViewController: UIViewController {
    
    private lazy var sceneView = setupSceneView()
    private lazy var activity = setupActivity()
    private lazy var slidingGesture = setupSlidingGesture()
    private lazy var toolTipView = setupToolTipView()
    
    private var currentAngleY: Float = 0.0
    private let modelLoader = ModelLoader()
    private var selectionState: SelectionState = .none
    
    let textView = UITextView(frame: CGRect.zero)
    private var isAnyModelLoaded = false {
        didSet {
            updateRightNavigationItems()
        }
    }
    
    private var shouldDrawFurnitures = true {
        didSet {
            toggleFurnitures()
        }
    }
    
    private var spaceNode: SCNNode? {
        sceneView.scene?.rootNode.childNodes.first(where: \.isSpaceNode)
    }
    
    private var isSceneSetup: Bool {
        view.subviews.contains(sceneView)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        loadModel()
    }
    
    func loadModel() {
        Task {
            do {
                startActivity()
                let url = try await modelLoader.showPicker(from: self)
                setupSceneIfNeeded()
                addModel(path: url)
                stopActivity()
                isAnyModelLoaded = true
                
                showToolTip()
            } catch {
                stopActivity()
                showAlert(title: "Error loading model", message: error.localizedDescription)
                updateRightNavigationItems()
                isAnyModelLoaded = false
            }
        }
    }
    
    func addModel(path: URL) {
        startActivity()
        Task {
            let asset = MDLAsset(url: path)
            let scene = SCNScene(mdlAsset: asset)
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                
                scene.rootNode.markAsSpaceNode()
                self.decorateScene(scene)
                
                switch self.sceneView.scene {
                case let .some(existingScene):
                    existingScene.rootNode.addChildNode(scene.rootNode)
                case .none:
                    // Create an empty scene and append our model to it as a child node.
                    
                    // Also prepare a camera node (which will be controlled by SCNCameraController / SCNView's defaultCameraController),
                    // if we do not set this up and let SceneKit add a default camera node, we can't move the camera via defaultCameraController
                    
                    let rootScene = SCNScene()
                    let cameraNode = SCNNode()
                    cameraNode.camera = SCNCamera()
                    cameraNode.position = SCNVector3(x: 0, y: 0, z: 10)
                    rootScene.rootNode.addChildNode(cameraNode)
                    rootScene.rootNode.addChildNode(scene.rootNode)
                    self.sceneView.scene = rootScene
                    self.animateSceneLoad()
                }
                self.stopActivity()
            }
        }
    }
    
    func decorateScene(_ scene: SCNScene) {
        let rootNode = scene.rootNode
        rootNode.enumerateHierarchy { node, _ in
            guard let geometry = node.geometry else { return }
            switch node.type {
            case .door:
                geometry.firstMaterial?.diffuse.contents = UIColor.green.withAlphaComponent(0.75)
            case .floor:
                
                break
                //                    print("Position before rotation:", node.position, "pivot: ", node.pivot)
                //                    geometry.firstMaterial?.diffuse.contents = UIImage(named: "wooden_texture")
            case .furniture:
                geometry.firstMaterial?.diffuse.contents = UIColor.systemGray.withAlphaComponent(0.8)
            case .wall:
                geometry.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(0.8)
                break
            case .opening, .window:
                break
            case .none:
                break
            }
        }
    }
    
}

// MARK: - UI Helpers

private extension PreviewViewController {
    
    func setupView() {
        let gradient = CAGradientLayer()
        gradient.frame = view.bounds
        gradient.colors = [UIColor.black.cgColor, UIColor.black.cgColor]
        view.layer.insertSublayer(gradient, at: 0)
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "xmark"), style: .plain, target: self, action: #selector(closeTapped))
    }
    
    func updateRightNavigationItems() {
        let optionsButton = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"),
            style: .plain,
            target: self,
            action: #selector(showOptions)
        )
        navigationItem.rightBarButtonItem = optionsButton
    }
    
    func startActivity() {
        guard !view.subviews.contains(where: { $0 == activity }) else { return }
        view.addSubview(activity)
        NSLayoutConstraint.activate([
            activity.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            activity.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
        ])
        activity.startAnimating()
    }
    
    func stopActivity() {
        activity.stopAnimating()
        activity.removeFromSuperview()
    }
    
    func setupSceneView() -> SCNView {
        let scnView = SCNView(frame: .zero)
        scnView.backgroundColor = .clear
        scnView.antialiasingMode = .multisampling2X
        scnView.preferredFramesPerSecond = 60
        scnView.rendersContinuously = true
        scnView.showsStatistics = false
        scnView.autoenablesDefaultLighting = true
        scnView.allowsCameraControl = true
        return scnView
    }
    
    func setupActivity() -> UIActivityIndicatorView {
        let activity = UIActivityIndicatorView()
        activity.style = .medium
        activity.translatesAutoresizingMaskIntoConstraints = false
        return activity
    }
    
    func setupSlidingGesture() -> UIPanGestureRecognizer {
        let slidingGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(sender:)))
        slidingGesture.minimumNumberOfTouches = 1
        slidingGesture.maximumNumberOfTouches = 2
        slidingGesture.isEnabled = false
        return slidingGesture
    }
    
    func setupToolTipView() -> UIView {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 300, height: 60))
        view.backgroundColor = .systemGray.withAlphaComponent(0.6)
        view.clipsToBounds = true
        view.layer.cornerRadius = 20
        let label = UILabel(frame: view.bounds.insetBy(dx: 8, dy: 8))
        view.addSubview(label)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = "Click on the furniture and start tagging"
        return view
    }
    
    func setupSceneIfNeeded() {
        if isSceneSetup { return }
        view.addSubview(sceneView)
        setupLayouts()
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapInScene(sender:)))
        sceneView.addGestureRecognizer(tapGesture)
        sceneView.addGestureRecognizer(slidingGesture)
    }
    
    func animateSceneLoad() {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 1
        let cameraController = sceneView.defaultCameraController
        let rotation = (Float.pi / 4) * 50
        cameraController.rotateBy(x: rotation, y: -rotation)
        SCNTransaction.commit()
    }
    
    func showToolTip() {
        toolTipView.alpha = 0
        toolTipView.center.x = view.center.x
        toolTipView.frame.origin.y = 0//view.bounds.height
        
        view.addSubview(toolTipView)
        view.bringSubviewToFront(toolTipView)
        
        UIView.animate(withDuration: 1.0, animations: {
            self.toolTipView.frame.origin.y = 50//self.view.bounds.height - self.toolTipView.frame.height - 100
            self.toolTipView.alpha = 1
        }) { _ in
            self.scheduleToolTipDismissal()
        }
    }
    
    func scheduleToolTipDismissal() {
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { timer in
            timer.invalidate()
            UIView.animate(withDuration: 0.4) {
                self.toolTipView.frame.origin.y = 0//self.view.bounds.height
                self.toolTipView.alpha = 0
            }
        }
    }
    
    func setupLayouts() {
        sceneView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            sceneView.topAnchor.constraint(equalTo: view.topAnchor),
            sceneView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sceneView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sceneView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
    
}

// MARK: - Logic Helpers

private extension PreviewViewController {
    
    func exportScene() {
        guard let scene = sceneView.scene else { return }
        let exportPath = FileManager.default.temporaryDirectory.appending(path: "Scene_\(UUID().uuidString).usdz")
        let exportSuccess = scene.write(
            to: exportPath,
            options: nil,
            delegate: nil,
            progressHandler: { progress, error, _ in
                debugPrint("[] Progress exporting: \(progress), error: \(String(describing: error))")
            }
        )
        
        guard exportSuccess else {
            showAlert(title: nil, message: "Could not save model")
            return
        }
        showActivitySheet(activityItems: [exportPath])
    }
    
    func toggleFurnitures() {
        
        guard let spaceNode = spaceNode else { return }
        spaceNode.enumerateHierarchy { node, _ in
            guard node.type == .furniture else { return }
            
            
            node.isHidden = !shouldDrawFurnitures
        }
    }
    
}

// MARK: - Event Handlers

private extension PreviewViewController {
    
    @objc func showModelPicker() {
        loadModel()
    }
    
    @objc func closeTapped() {
        dismiss(animated: true)
    }
    
    @objc func showOptions() {
        let actionSheet = UIAlertController(title: nil, message: "Options", preferredStyle: .actionSheet)
        actionSheet.addAction(.init(title: "Toggle furnitures", style: .default) { [weak self] _ in
            self?.shouldDrawFurnitures.toggle()
        })
        actionSheet.addAction(.init(title: "Save", style: .default) { [weak self] _ in
            self?.exportScene()
        })
        actionSheet.addAction(.init(title: "Cancel", style: .cancel))
        present(actionSheet, animated: true)
    }
    
    @objc func handlePanGesture(sender: UIPanGestureRecognizer) {
        guard case let SelectionState.surface(selectedNode) = selectionState else { return }
        
        let translation = sender.translation(in: sender.view)
        var newAngleY = (Float)(translation.x)*(Float)(Double.pi)/180.0
        newAngleY += currentAngleY
        
        selectedNode.eulerAngles.y = newAngleY
        
        if sender.state == .ended {
            currentAngleY = newAngleY
        }
    }
    
    @objc func handleTapInScene(sender: UITapGestureRecognizer) {
        let location = sender.location(in: sceneView)
        let node = sceneView.hitTest(
            location,
            options: [.boundingBoxOnly: false, .searchMode: SCNHitTestSearchMode.all.rawValue]
        ).map(\.node)
            .first(where: { $0.type != nil })
        
        guard let selectedNode = node, selectedNode.type == .furniture else {
            return
        }
        
        var selectedMsg = ""
        
            if selectedNode.geometry?.firstMaterial?.diffuse.contents as! NSObject == UIColor.systemRed.withAlphaComponent(0.8) {
                
                selectedMsg = "Important furniture"
            } else if selectedNode.geometry?.firstMaterial?.diffuse.contents as! NSObject == UIColor(red: 75/255, green: 145/255, blue: 250/255, alpha: 1) {
                
                selectedMsg = "Useful furniture"
            } else if selectedNode.geometry?.firstMaterial?.diffuse.contents as! NSObject == UIColor.systemGreen.withAlphaComponent(0.8) {
                
                selectedMsg = "Medicine box"
            }
            
            else if selectedNode.accessibilityValue == nil{
                selectedMsg = "Tag your funuture"
            }
        
        if selectedNode.accessibilityValue != nil{
            selectedMsg += "\n\n"+selectedNode.accessibilityValue!
        }
        
        let objectmenu = UIAlertController(title: nil, message: selectedMsg, preferredStyle: .actionSheet)
        
        if selectedNode.geometry?.firstMaterial?.diffuse.contents as! NSObject == UIColor.systemGray.withAlphaComponent(0.8){
            
            
            objectmenu.addAction(.init(title: "Mark text", style: .default) { [weak self] _ in
                self?.markalert(selectedNode: selectedNode)
            })
            objectmenu.addAction(.init(title: "Tag as Important (RED)", style: .default) { [weak self] _ in
                self?.selectionState = .surface(selectedNode)
                selectedNode.geometry?.firstMaterial?.diffuse.contents = UIColor.systemRed.withAlphaComponent(0.8)
                
                
            })
            objectmenu.addAction(.init(title: "Tag as Useful (Blue)", style: .default) { [weak self] _ in
                
                self?.selectionState = .surface(selectedNode)
                selectedNode.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 75/255, green: 145/255, blue: 250/255, alpha: 1)
                
            })
            objectmenu.addAction(.init(title: "Tag as Medicine box (Green)", style: .default) { [weak self] _ in
                
                self?.selectionState = .surface(selectedNode)
                selectedNode.geometry?.firstMaterial?.diffuse.contents = UIColor.systemGreen.withAlphaComponent(0.8)
                
            })
            
            objectmenu.addAction(.init(title: "Cancel", style: .cancel))
            present(objectmenu, animated: true)
        } else {
            objectmenu.addAction(.init(title: "Mark text", style: .default) { [weak self] _ in
                
                self?.markalert(selectedNode: selectedNode)
                
            })
            objectmenu.addAction(.init(title: "UnTag", style: .default) { [weak self] _ in
                self?.selectionState = .none
                selectedNode.geometry?.firstMaterial?.diffuse.contents = UIColor.systemGray.withAlphaComponent(0.8)
            })
            objectmenu.addAction(.init(title: "Cancel", style: .cancel))
            present(objectmenu, animated: true)
            
            slidingGesture.isEnabled = false
        }
        
    }

    func markalert(selectedNode: SCNNode) -> SCNNode{
        let alertController = UIAlertController(title: "Mark text \n\n\n", message: nil, preferredStyle: .alert)

        let cancelAction = UIAlertAction.init(title: "Cancel", style: .cancel) { (action) in
            alertController.view.removeObserver(self, forKeyPath: "bounds")
        }
        alertController.addAction(cancelAction)

        let saveAction = UIAlertAction(title: "Confirm", style: .default) { (action) in
            let enteredText = self.textView.text
            selectedNode.accessibilityValue = enteredText
            alertController.view.removeObserver(self, forKeyPath: "bounds")
        }
        alertController.addAction(saveAction)

        alertController.view.addObserver(self, forKeyPath: "bounds", options: NSKeyValueObservingOptions.new, context: nil)
        textView.layer.cornerRadius = 5
        textView.layer.borderColor = UIColor.gray.withAlphaComponent(0.5).cgColor
        textView.layer.borderWidth = 0.5
        textView.clipsToBounds = true
        textView.textContainerInset = UIEdgeInsets.init(top: 8, left: 5, bottom: 8, right: 5)
        
        alertController.view.addSubview(self.textView)

        self.present(alertController, animated: true, completion: nil)
        self.textView.text = nil
        return selectedNode
    }

    internal override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "bounds"{
            if let rect = (change?[NSKeyValueChangeKey.newKey] as? NSValue)?.cgRectValue {
                let margin: CGFloat = 20
                let xPos = rect.origin.x + margin
                let yPos = rect.origin.y + 54
                let width = rect.width - 2 * margin
                let height: CGFloat = 50

                textView.frame = CGRect.init(x: xPos, y: yPos, width: width, height: height)
            }
        }
    }


}
