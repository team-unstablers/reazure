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

    /// Whether `accountId` authored this post *or* boosted it — a block has to
    /// hide both, since a boost row is shown on behalf of the booster.
    func involves(accountId: String) -> Bool {
        return account.id == accountId || canonical.account.id == accountId
    }
}
