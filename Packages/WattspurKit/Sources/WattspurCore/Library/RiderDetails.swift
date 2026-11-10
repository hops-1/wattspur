import Foundation

/// The rider as the iPhone shows it at the top of “More” (B-298): name, photo and the body data
/// for the calories. Read only; editing comes with the profile on the iPhone (B-299).
public struct RiderDetails: Sendable, Equatable {
    public var name: String
    public var photoData: Data?
    public var body: BodyProfile

    public init(name: String = "", photoData: Data? = nil, body: BodyProfile = BodyProfile()) {
        self.name = name
        self.photoData = photoData
        self.body = body
    }

    /// The first letter of the name for the avatar without a photo; `nil` without a name.
    public var initial: String? {
        name.trimmingCharacters(in: .whitespacesAndNewlines).first.map { String($0).uppercased() }
    }

}
