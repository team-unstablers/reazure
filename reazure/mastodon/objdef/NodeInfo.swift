//
//  NodeInfo.swift
//  reazure
//
//  Created by cheesekun on 11/3/24.
//

struct NodeInfo: Codable {
    let software: NodeInfoSoftware
}


struct NodeInfoSoftware: Codable {
    let name: String
    let version: String
}

