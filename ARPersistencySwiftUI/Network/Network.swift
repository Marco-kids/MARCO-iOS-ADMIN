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
        self.getARWorldMap()
    }
    
    func uploadImage(image1: UIImage, arWorldMap: Data) {
        let url = Params.createLocationURL
        let parameters: [String: String] = ["nombre": "test"]
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
    
    func getARWorldMap() {
        let url = Params.locationsURL
        AF.request(url).responseJSON { [self] response in
            switch response.result {
            case .success(let value):
                do {
                    print("Success dowloading intial data")
                    let arLocation = try JSONDecoder().decode([ARLocation].self, from: response.data!)
                    self.locations = arLocation
                    guard let delegateEditor = delegateARVC else { return }
                    delegateEditor.loadedData(locations: arLocation)
                    self.downloadFile(url: self.locations.first!.ARWorldMap)
                } catch {
                    print("Error decoding JSON: \(error)")
                }
            case .failure(let error):
                print("Error: \(error)")
            }
        }
    }
    
    func downloadFile(url: String) {
        let destination = DownloadRequest.suggestedDownloadDestination(for: .documentDirectory)
        AF.download(Params.baseURL + url, to: destination).responseData { response in
            if let error = response.error {
                print("Error downloading file: \(error)")
            } else if let data = response.value {
                self.downloadedData.append(data)
                print("File downloaded to: \(response.fileURL?.path ?? "")")
            }
        }
    }
}
