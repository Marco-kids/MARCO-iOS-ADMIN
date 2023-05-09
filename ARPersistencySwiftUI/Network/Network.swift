//
//  Network.swift
//  ARPersistencySwiftUI
//
//  Created by Jose Castillo on 2/14/23.
//

import UIKit
import Alamofire

//let headers: HTTPHeaders = ["Authorization": "Bearer \(accessToken)"]
let headers: HTTPHeaders = []

class Network {
    
    static let shared = Network()
    var downloadedData: [Data] = []
    var locations: [ARLocation] = []
    weak var delegateARVC: EditorViewControllerDelegate?
    
    init() {
        self.getLocations()
    }
    
    func uploadLocation(name: String, image1: UIImage, arWorldMap: Data) {
        let url = Params.createLocationURL
        let parameters: [String: String] = ["nombre": name]
        AF.upload(multipartFormData: { multipartFormData in
            for (key, value) in parameters {
                multipartFormData.append(value.data(using: .utf8)!, withName: key)
            }
            if let imageData1 = image1.jpegData(compressionQuality: 0.8) {
                multipartFormData.append(imageData1, withName: "screenshot", fileName: "image1.jpg", mimeType: "image/jpeg")
            }
            multipartFormData.append(arWorldMap, withName: "ARWorldMap", fileName: "worldMap.arworldmap", mimeType: "application/octet-stream")
        }, to: url, method: .post, headers: headers).responseJSON { response in
            switch response.result {
            case .success(let value):
                // Handle response here
                print("Success", value)
            case .failure(let error):
                // Handle error here
                print(error)
            }
        }
    }
    
    func getLocations() {
        let url = Params.locationsURL
        AF.request(url).responseJSON { [self] response in
            switch response.result {
            case .success(let value):
                do {
                    let arLocation = try JSONDecoder().decode([ARLocation].self, from: response.data!)
                    self.locations = arLocation
                    guard let delegateEditor = delegateARVC else { return }
                    delegateEditor.loadedData(locations: arLocation)
                    for item in arLocation {
                        self.getARWordlMap(location: item)
                    }
                } catch {
                    print("Error decoding JSON: \(error)")
                }
            case .failure(let error):
                print("Error: \(error)")
            }
        }
    }
    
    func getARWordlMap(location: ARLocation) {
        let fileName = location.ARWorldMap.components(separatedBy: "/").last
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filePathToSearch = documentsURL.relativePath + "/" + fileName!
        let filePathToSearchURL = URL(string: "file://" + filePathToSearch)
        if fileManager.fileExists(atPath: filePathToSearch) {
            for i in self.locations.indices {
                if self.locations[i].nombre == location.nombre {
                    self.locations[i].locationPath = filePathToSearchURL
                    guard let delegateEditor = delegateARVC else { return }
                    delegateEditor.loadedData(locations: self.locations)
                }
            }
        } else {
            downloadARWorldMap(location: location)
        }
    }
    
    func downloadARWorldMap(location: ARLocation) {
        let destination = DownloadRequest.suggestedDownloadDestination(for: .documentDirectory)
        AF.download(Params.baseURL + location.ARWorldMap, to: destination).responseData { response in
            if let error = response.error {
                print("Error downloading file: \(error)")
            } else if let data = response.value {
                self.downloadedData.append(data)
                for i in self.locations.indices {
                    if self.locations[i].nombre == location.nombre {
                        self.locations[i].locationPath = response.fileURL
                        guard let delegateEditor = self.delegateARVC else { return }
                        delegateEditor.loadedData(locations: self.locations)
                    }
                }
            }
        }
    }
    
}
