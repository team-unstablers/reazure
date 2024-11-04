//
//  TimelineView.swift
//  reazure
//
//  Created by cheesekun on 11/2/24.
//

import SwiftUI

enum TimelineType {
    case home
    case local
    case federated
}

fileprivate class TimelineViewModel: ObservableObject {
    var sharedClient: SharedClient!
    
    @Published
    var statuses: [Status] = []
    
    func setup(sharedClient: SharedClient) {
        self.sharedClient = sharedClient
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.fetchStatuses()
        }
    }
    
    func fetchStatuses() {
        Task {
            do {
                guard let statuses = try await sharedClient.client?.homeTimeline() else {
                    return
                }
                
                DispatchQueue.main.async {
                    self.statuses = statuses
                }
            } catch {
                print(error)
            }
        }
    }
    
}

struct TimelineView: View {
    @FocusState
    var selectedPost: String?
    
    var type: TimelineType
    
    @EnvironmentObject
    var sharedClient: SharedClient

    @StateObject
    private var viewModel = TimelineViewModel()
    
    var body: some View {
        List {
            ForEach(viewModel.statuses) { status in
                PostItem(status: status)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .focusable()
                    .focused($selectedPost, equals: status.id)
                    .onTapGesture {
                        selectedPost = status.id
                    }
                    .background {
                        if selectedPost == status.id {
                            Color.red
                        } else {
                            Color.clear
                        }
                    }
            }
        }
        .listStyle(.plain)
        .padding(0)
        .onAppear {
            viewModel.setup(sharedClient: sharedClient)
        }
    }
}

