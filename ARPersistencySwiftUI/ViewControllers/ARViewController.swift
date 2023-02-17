//
//  ARViewController.swift
//  ARPersistencySwiftUI
//
//  Created by Jose Castillo on 2/8/23.
//

import UIKit
import ARKit
import RealityKit
import Combine
import CoreData

#if !targetEnvironment(simulator)
class ARViewController: UIViewController, ARSessionDelegate {
    
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var sessionInfoLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet var arView: ARView!
    
    var model = Entity()
    var flagLoading: Bool?
    var location: ARLocation?
    let network = Network.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // RealityKit Config
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        arView.session.run(config)
        arView.debugOptions = [ .showFeaturePoints ]
        arView.session.delegate = self
        // Loads sample model (USDZ)
        self.model = try! Entity.load(named: "toy_drummer")
        // Gesture recognizer config
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        arView.addGestureRecognizer(tapGesture)
        // Style buttons
        saveButton.layer.cornerRadius = saveButton.layer.frame.height / 2
        saveButton.clipsToBounds = true
        saveButton.isEnabled = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if (location != nil) {
            self.saveButton.isEnabled = false
            self.load()
        }
    }

    // MARK: - Add AnchorEntity to arView
    
    @objc func handleTap(gesture: UITapGestureRecognizer) {
        guard let query = arView.makeRaycastQuery(from: gesture.location(in: self.arView), allowing: .existingPlaneInfinite, alignment: .any)
        else { return }
        
        guard let result = arView.session.raycast(query).first
                
        else { return }
        
        let newModel = model.clone(recursive: true)
        let raycastAnchor = AnchorEntity(world: result.worldTransform)
        raycastAnchor.addChild(newModel)
        arView.scene.addAnchor(raycastAnchor)
    }
    
    // MARK: - Persistence: Saving and Loading
    
    private func load() {
        let urlS = Params.baseURL + self.location!.screenshot
        let url = URL(string: urlS)
        let dataImage = try? Data(contentsOf: url!) //make sure your image in this url does exist, otherwise unwrap in a if let check / try-catch
        imageView.image = UIImage(data: dataImage!)
        imageView.isHidden = false

        var data = Data()
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        do {
            data = try Data(contentsOf: (location?.locationPath!)!)
        } catch {
            print("Error while enumerating files \(documentsURL.path): \(error.localizedDescription)")
        }
        
        let worldMap: ARWorldMap = {
            do {
                guard let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data)
                else { fatalError("No ARWorldMap in archive.") }
                return worldMap
            } catch {
                fatalError("Can't unarchive ARWorldMap from file data: \(error)")
            }
        }()

        let configuration = self.defaultConfiguration // this app's standard world tracking settings
        configuration.initialWorldMap = worldMap
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        self.isRelocalizingMap = true
    }
    
    @IBAction func saveButton(_ sender: Any) {
        // Display alert
        self.nameLocationAlert()
    }
    
    func saveToServer(name: String) {
        // Deactivate save button
        self.saveButton.isEnabled = false
        // Save screenshot
        arView.snapshot(saveToHDR: false) { image in
            let param1 = image
            // Save world map
            self.arView.session.getCurrentWorldMap { worldMap, error in
                guard let map = worldMap
                    else { self.showAlert(title: "Can't get current world map", message: error!.localizedDescription); return }
                do {
                    let data = try NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
                    try data.write(to: self.mapSaveURL, options: [.atomic])
                    self.network.uploadLocation(name: name, image1: param1!, arWorldMap: data)
                    DispatchQueue.main.async {
                        self.navigationController?.popViewController(animated: true)
                        self.dismiss(animated: true, completion: nil)
                    }
                } catch {
                    fatalError("Can't save map: \(error.localizedDescription)")
                }
            }
        }
    }
    
    lazy var mapSaveURL: URL = {
        do {
            return try FileManager.default
                .url(for: .documentDirectory,
                     in: .userDomainMask,
                     appropriateFor: nil,
                     create: true)
                .appendingPathComponent("map.arexperience")
        } catch {
            fatalError("Can't get file save URL: \(error.localizedDescription)")
        }
    }()
    
    // MARK: - ARSessionDelegate
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        updateSessionInfoLabel(for: session.currentFrame!, trackingState: camera.trackingState)
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        updateSessionInfoLabel(for: frame, trackingState: frame.camera.trackingState)
    }
    
    // MARK: - AR session managment
    
    var isRelocalizingMap = false
    
    var defaultConfiguration: ARWorldTrackingConfiguration {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        configuration.environmentTexturing = .automatic
        return configuration
    }
    
    var prevState: Bool?
    
    // This switch can be modified to just detect the space in MARCO KIDS main app
    private func updateSessionInfoLabel(for frame: ARFrame, trackingState: ARCamera.TrackingState) {
        // Update the UI to provide feedback on the state of the AR experience.
        let message: String
        imageView.isHidden = true
        if (prevState == true && trackingState == .normal) {
            locationDetectedAlert()
        }
        switch (trackingState, frame.worldMappingStatus) {
        case (.normal, .mapped),
             (.normal, .extending):
            message = "Tap 'Save Experience' to save the current map."
            self.saveButton.isEnabled = true
            prevState = false
        case (.normal, _) where flagLoading != nil && !isRelocalizingMap:
            message = "Move around to map the environment or tap 'Load Experience' to load a saved experience."
            prevState = false
        case (.normal, _) where flagLoading == nil:
            message = "Move around to map the environment."
            prevState = false
        case (.limited(.relocalizing), _) where isRelocalizingMap:
            message = "Move your device to the location shown in the image."
            imageView.isHidden = false
            prevState = true
        default:
            message = trackingState.localizedFeedback
            prevState = false
        }
        sessionInfoLabel.text = message
    }
    
    // MARK: Alerts
    
    func nameLocationAlert() {
        let alertController = UIAlertController(title: "Agrega un nombre a la ubicación agregada", message: "", preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Guardar", style: .default, handler: { alert -> Void in
            let textField = alertController.textFields![0] as UITextField
            self.saveToServer(name: textField.text ?? "Default Name")
        }))
        alertController.addAction(UIAlertAction(title: "Cancelar", style: .cancel, handler: nil))
        alertController.addTextField(configurationHandler: {(textField : UITextField!) -> Void in
            textField.placeholder = "Escribe el nombre aquí"
        })
        self.present(alertController, animated: true, completion: nil)
    }
    
    func locationDetectedAlert() {
        let alertController = UIAlertController(title: "Zona detectada correctamente.", message: "", preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
        self.present(alertController, animated: true, completion: nil)
    }

}

#endif
