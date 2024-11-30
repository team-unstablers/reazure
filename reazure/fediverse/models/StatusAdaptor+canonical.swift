//
//  StatusAdaptor+canonical.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/30/24.
//

extension StatusAdaptor {
    var canonical: StatusAdaptor {
        if let reblog = reblog {
            return reblog
        }
        
        return self
    }
}
