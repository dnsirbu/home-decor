// Main view controller for the AR experience

import ARKit
import SceneKit
import UIKit

class ViewController: UIViewController {
    
    // IBOutlets
    
    @IBOutlet var sceneView: VirtualObjectARView!
    
    @IBOutlet weak var addObjectButton: UIButton!
    
    @IBOutlet weak var takePhoto: UIButton!
    
    @IBOutlet weak var loginButton: UIButton!
    
    @IBOutlet weak var blurView: UIVisualEffectView!
    
    @IBOutlet weak var spinner: UIActivityIndicatorView!

    // UI Elements
    
    var focusSquare = FocusSquare()
    
    // The view controller that displays the status and "restart experience" UI
    lazy var statusViewController: StatusViewController = {
        return childViewControllers.lazy.flatMap({ $0 as? StatusViewController }).first!
    }()
	
	// The view controller that displays the virtual object selection menu
	var objectsViewController: VirtualObjectSelectionViewController?
    
    // ARKit Configuration Properties
    
    // A type which manages gesture manipulation of virtual content in the scene
    lazy var virtualObjectInteraction = VirtualObjectInteraction(sceneView: sceneView)
    
    // Coordinates the loading and unloading of reference nodes for virtual objects
    let virtualObjectLoader = VirtualObjectLoader()
    
    // Marks if the AR experience is available for restart.
    var isRestartAvailable = true
    
    // A serial queue used to coordinate adding or removing nodes from the scene.
    let updateQueue = DispatchQueue(label: "arkitproject.serialSceneKitQueue")
    
    var screenCenter: CGPoint {
        let bounds = sceneView.bounds
        return CGPoint(x: bounds.midX, y: bounds.midY)
    }
    
    // Convenience accessor for the session owned by ARSCNView
    var session: ARSession {
        return sceneView.session
    }
    
    // View Controller Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        sceneView.session.delegate = self

        // Set up scene content
        setupCamera()
        sceneView.scene.rootNode.addChildNode(focusSquare)

        // Allows arkitscene to add some default lighting to the whole scene
        sceneView.autoenablesDefaultLighting = true

        // Hook up status view controller callback(s)
        statusViewController.restartExperienceHandler = { [unowned self] in
            self.restartExperience()
        }
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(showVirtualObjectSelectionViewController))
        // Set the delegate to ensure this gesture is only used when there are no virtual objects in the scene
        tapGesture.delegate = self
        sceneView.addGestureRecognizer(tapGesture)

    }

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		
		// Prevent the screen from being dimmed to avoid interuppting the AR experience
		UIApplication.shared.isIdleTimerDisabled = true

        // Start the `ARSession`
        resetTracking()
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)

        session.pause()
	}

    // Scene content setup

    func setupCamera() {
        guard let camera = sceneView.pointOfView?.camera else {
            fatalError("Expected a valid `pointOfView` from the scene.")
        }

        /*
         Enable HDR camera settings for the most realistic appearance
         with environmental lighting and physically based materials.
         */
        camera.wantsHDR = true
        camera.exposureOffset = -1
        camera.minimumExposure = -1
        camera.maximumExposure = 3
    }

    // Session management
    
    // Creates a new AR configuration to run on the `session`
	func resetTracking() {
		virtualObjectInteraction.selectedObject = nil
		
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
		session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

        statusViewController.scheduleMessage("FIND A SURFACE TO PLACE AN OBJECT", inSeconds: 7.5, messageType: .planeEstimation)
	}

	func updateFocusSquare() {
        let isObjectVisible = virtualObjectLoader.loadedObjects.contains { object in
            return sceneView.isNode(object, insideFrustumOf: sceneView.pointOfView!)
        }
        
        if isObjectVisible {
            focusSquare.hide()
        } else {
            focusSquare.unhide()
            statusViewController.scheduleMessage("TRY MOVING LEFT OR RIGHT", inSeconds: 5.0, messageType: .focusSquare)
        }
		
        // Perform hit testing only when ARKit tracking is in a good state
        if let camera = session.currentFrame?.camera, case .normal = camera.trackingState,
            let result = self.sceneView.smartHitTest(screenCenter) {
            updateQueue.async {
                self.sceneView.scene.rootNode.addChildNode(self.focusSquare)
                self.focusSquare.state = .detecting(hitTestResult: result, camera: camera)
            }
            addObjectButton.isHidden = false
            statusViewController.cancelScheduledMessage(for: .focusSquare)
        } else {
            updateQueue.async {
                self.focusSquare.state = .initializing
                self.sceneView.pointOfView?.addChildNode(self.focusSquare)
            }
            addObjectButton.isHidden = true
        }
	}
    
	// Error handling
    
    func displayErrorMessage(title: String, message: String) {
        // Blur the background
        blurView.isHidden = false
        
        // Present an alert informing about the error that has occurred
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
            alertController.dismiss(animated: true, completion: nil)
            self.blurView.isHidden = true
            self.resetTracking()
        }
        alertController.addAction(restartAction)
        present(alertController, animated: true, completion: nil)
    }
    
    // Take photo
    @IBAction func takePhoto(_ sender: UIButton) {
        //take photo
        let imageshot = sceneView.snapshot()
        
        // Save image to library
        UIImageWriteToSavedPhotosAlbum(imageshot, self, nil, nil)
    }
    
    @IBAction func openLoginView(_ sender: UIButton) {
        //let loginViewController = LoginViewController()
        //self.present(loginViewController, animated: true, completion: nil)
        performSegue(withIdentifier: "loginSegueIdentifier", sender: self)
    }

}
