//
//  FediverseAPIError.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/20/24.
//

import Foundation

enum FediverseAPIError: LocalizedError {
    case notImplemented
    
    case operationNotSupported
    case unsupportedServerSoftware
    
    case serverError(originError: Error? = nil)
    case unknownError(originError: Error? = nil)
    
    var errorDescription: String? {
        switch self {
        case .notImplemented:
            return NSLocalizedString("FEDI_API_ERROR_NOT_IMPLEMENTED", comment: "")
        case .operationNotSupported:
            return NSLocalizedString("FEDI_API_ERROR_OPERATION_NOT_SUPPORTED", comment: "")
        case .unsupportedServerSoftware:
            return NSLocalizedString("FEDI_API_ERROR_UNSUPPORTED_SERVER_SOFTWARE", comment: "")
        case .serverError(let originError):
            return NSLocalizedString("FEDI_API_ERROR_SERVER_ERROR", comment: "") + " (" + (originError?.localizedDescription ?? "") + ")"
        case .unknownError(let originError):
            return NSLocalizedString("FEDI_API_ERROR_UNKNOWN_ERROR", comment: "") + " (" + (originError?.localizedDescription ?? "") + ")"
        }
    }
}
