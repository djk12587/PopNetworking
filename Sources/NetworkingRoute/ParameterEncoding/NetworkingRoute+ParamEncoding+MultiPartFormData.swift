//
//  File.swift
//  
//
//  Created by Dan_Koza on 4/2/22.
//

import Foundation

// Thanks to Orestis Papadopoulos for the following MultiPartFormData encoding
// https://orjpap.github.io/swift/http/ios/urlsession/2021/04/26/Multipart-Form-Requests.html
// This code was tweaked from the original blog post
public struct MultipartFormDataEncoder {

    private let boundary: String = UUID().uuidString
    private var httpBody = NSMutableData()

    func encode(textFields: [TextField],
                dataFields: [DataField],
                into urlRequest: inout URLRequest) {

        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        textFields.forEach {
            httpBody.append(textFormField(named: $0.name,
                                          value: $0.value))
        }

        dataFields.forEach {
            httpBody.append(dataFormField(named: $0.name,
                                          data: $0.data,
                                          filename: $0.filename,
                                          mimeType: $0.mimeType))
        }

        httpBody.append("--\(boundary)--")

        urlRequest.httpBody = httpBody as Data
    }
}

extension MultipartFormDataEncoder {

    public struct DataField {

        let name: String
        let data: Data
        let filename: String?
        let mimeType: String

        public init(name: String, data: Data, filename: String? = nil, mimeType: String) {
            self.name = name
            self.data = data
            self.filename = filename
            self.mimeType = mimeType
        }
    }

    public struct TextField {

        let name: String
        let value: String

        public init(name: String, value: String) {
            self.name = name
            self.value = value
        }
    }
}

private extension MultipartFormDataEncoder {

    func textFormField(named name: String, value: String) -> String {
        var fieldString = "--\(boundary)\r\n"
        fieldString += "Content-Disposition: form-data; name=\"\(name)\"\r\n"
        fieldString += "Content-Type: text/plain; charset=ISO-8859-1\r\n"
        fieldString += "Content-Transfer-Encoding: 8bit\r\n"
        fieldString += "\r\n"
        fieldString += "\(value)\r\n"

        return fieldString
    }

    func dataFormField(named name: String,
                       data: Data,
                       filename: String? = nil,
                       mimeType: String) -> Data {
        let fieldData = NSMutableData()

        fieldData.append("--\(boundary)\r\n")
        fieldData.append("Content-Disposition: form-data; name=\"\(name)\"")
        if let filename = filename {
            fieldData.append("; filename=\"\(filename)\"")
        }
        fieldData.append("\r\n")
        fieldData.append("Content-Type: \(mimeType)\r\n")
        fieldData.append("\r\n")
        fieldData.append(data)
        fieldData.append("\r\n")

        return fieldData as Data
    }
}

extension NSMutableData {
    func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            self.append(data)
        }
    }
}
