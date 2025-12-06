//
//  NetworkState.swift
//  ToyVideoStreamingPlayer
//
//  Created by 이상진 on 12/5/25.
//

import Foundation
import Network

struct NetworkState {
    let isConnected: Bool
    let connectionType: NWInterface.InterfaceType?
    let estimatedBandwidth: Double  // Mbps
    
    enum Quality {
        case poor       // < 1 Mbps
        case fair       // 1-5 Mbps
        case good       // 5-10 Mbps
        case excellent  // 10+ Mbps
    }
    
    var quality: Quality {
        switch estimatedBandwidth {
        case 0..<1:
            return .poor
        case 1..<5:
            return .fair
        case 5..<10:
            return .good
        default:
            return .excellent
        }
    }
    
    var displayText: String {
        guard isConnected else { return "연결 끊김" }
        
        switch connectionType {
        case .wifi:
            return "Wi-Fi"
        case .cellular:
            return "셀룰러"
        case .wiredEthernet:
            return "유선"
        default:
            return "연결됨"
        }
    }
    
    // 초기 상태
    static var unknown: NetworkState {
        NetworkState(
            isConnected: false,
            connectionType: nil,
            estimatedBandwidth: 0
        )
    }
}
