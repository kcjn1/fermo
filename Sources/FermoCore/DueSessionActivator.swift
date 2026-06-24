import Foundation

public struct DueSessionActivationResult: Equatable, Sendable {
    public var policy: FermoPolicy
    public var didChange: Bool

    public init(policy: FermoPolicy, didChange: Bool) {
        self.policy = policy
        self.didChange = didChange
    }
}

public struct DueSessionActivator: Sendable {
    public init() {}

    public func activatingDueSessions(
        in policy: FermoPolicy,
        at date: Date = Date()
    ) -> DueSessionActivationResult {
        var nextPolicy = policy
        var didChange = false

        nextPolicy.sessions = policy.sessions.map { session in
            guard session.state == .scheduled else {
                return session
            }

            if session.startsAt <= date && date < session.endsAt {
                didChange = true
                return session.activated()
            }

            if date >= session.endsAt {
                var cancelled = session
                cancelled.state = .cancelled
                didChange = true
                return cancelled
            }

            return session
        }

        return DueSessionActivationResult(policy: nextPolicy, didChange: didChange)
    }
}
