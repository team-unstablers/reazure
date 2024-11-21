//
//  BuildInfoBase.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/22/24.
//

struct BuildInfo {
    var debug: Bool
    
    var gitBranch: String?
    var gitCommitId: String
    var gitIsDirty: Bool
    
    var buildDate: String
}

extension BuildInfo {
    var gitShortCommitId: String {
        return String(gitCommitId.prefix(7))
    }
    
    var displayVersion: String {
        if debug {
            return "\(gitBranch ?? "unknown")@\(gitShortCommitId)" + (gitIsDirty ? "-dirty" : "")
        }
        
        
        // 그 외의 경우 tag를 버전으로 사용함
        return gitBranch ?? "unknown"
    }
}
