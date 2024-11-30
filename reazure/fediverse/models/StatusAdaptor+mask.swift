//
//  StatusAdaptor+mask.swift
//  reazure
//
//  Created by Gyuhwan Park on 11/30/24.
//


extension StatusAdaptor {
    func mask(favourited: Bool? = nil, reblogged: Bool? = nil, deleted: Bool? = nil) -> MaskedStatusAdaptor {
        // check instance of MaskedStatusAdaptor
        if let masked = self as? MaskedStatusAdaptor {
            let favourited = favourited ?? masked.favourited
            let reblogged = reblogged ?? masked.reblogged
            let deleted = deleted ?? masked.deleted
            
            return MaskedStatusAdaptor(status: masked.status, favourited: favourited, reblogged: reblogged, deleted: deleted)
        }
        
        return MaskedStatusAdaptor(status: self, favourited: favourited, reblogged: reblogged, deleted: deleted)
    }
}

