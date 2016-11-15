
import Foundation
import SystemConfiguration
import ReactiveSwift
import Result

public enum ReachabilityStatus {
    public enum ReachableType {
        case wiFi, cellular
    }
    
    case unreachable, reachable(ReachableType)
}

private extension Reachability.NetworkStatus {
    func toReachabilityStatus() -> ReachabilityStatus {
        switch self {
        case .reachableViaWiFi: return .reachable(.wiFi)
        case .reachableViaWWAN: return .reachable(.cellular)
        case .notReachable: return .unreachable
        }
    }
}

public class ReachabilityController {
    public let signal: Signal<ReachabilityStatus, NoError>

    public var currentStatus: ReachabilityStatus {
        return self.reachability.currentReachabilityStatus.toReachabilityStatus()
    }
    
    public let reachable: Property<Bool>

    
    public var isReachable: Bool {
        if case .reachable(_) = currentStatus {
            return true
        } else {
            return false
        }
    }
    
    private let observer: (Observer<ReachabilityStatus, NoError>)
    private let reachability: Reachability
    
    public init() {
        reachability = try! Reachability.reachabilityForInternetConnection()
        (signal, observer) = Signal<ReachabilityStatus, NoError>.pipe()
        
        reachable = Property<Bool>(initial: reachability.isReachable(), then: signal.map {
            if case .reachable = $0 {
                return true
            }
            return false
        }.skipRepeats())
        
        reachability.whenReachable = { [unowned self] r in
            let status: ReachabilityStatus
            if r.isReachableViaWiFi() {
                status = ReachabilityStatus.reachable(.wiFi)
            } else {
                status = ReachabilityStatus.reachable(.cellular)
            }
            self.observer.send(value: status)
        }
        
        reachability.whenUnreachable = { [unowned self] r in
            let status = ReachabilityStatus.unreachable
            self.observer.send(value: status)
        }
        
        
        try! reachability.startNotifier()
    }
    
    deinit {
        reachability.stopNotifier()
    }
}
