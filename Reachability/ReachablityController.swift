import Foundation
import SystemConfiguration
import ReactiveSwift
import Result

public enum ReachabilityStatus {
    public enum ReachableType {
        case wiFi, cellular
    }
    
    case unreachable, reachable(type: ReachableType)
    
    public var isReachable: Bool {
        if case .reachable(_) = self {
            return true
        }
        return false
    }
}

private extension Reachability.NetworkStatus {
    func toReachabilityStatus() -> ReachabilityStatus {
        switch self {
        case .reachableViaWiFi: return .reachable(type: .wiFi)
        case .reachableViaWWAN: return .reachable(type: .cellular)
        case .notReachable: return .unreachable
        }
    }
}

public class ReachabilityController {

    public let signal: Signal<ReachabilityStatus, NoError>
    public let reachable: Property<Bool>

    public var currentStatus: ReachabilityStatus {
        return self.reachability.currentReachabilityStatus.toReachabilityStatus()
    }

    public var isReachable: Bool {
        if case .reachable(_) = currentStatus {
            return true
        } else {
            return false
        }
    }
    
    private let observer: Signal<ReachabilityStatus, NoError>.Observer
    private let reachability: Reachability
    
    public init() {
        (signal, observer) = Signal<ReachabilityStatus, NoError>.pipe()
        
        reachability = try! Reachability.reachabilityForInternetConnection()
        reachable = Property<Bool>(initial: reachability.isReachable(),
                                   then: signal.map { $0.isReachable }.skipRepeats())
        
        reachability.whenReachable = { [unowned self] r in
            let status: ReachabilityStatus
            if r.isReachableViaWiFi() {
                status = ReachabilityStatus.reachable(type: .wiFi)
            } else {
                status = ReachabilityStatus.reachable(type: .cellular)
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
