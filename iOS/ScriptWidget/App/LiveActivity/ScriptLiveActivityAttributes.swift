import Foundation
import ActivityKit

struct ScriptLiveActivityAttributes: ActivityAttributes, Equatable, Sendable {
    typealias ScriptLiveActivityState = ContentState
    struct ContentState: Codable, Hashable, Sendable {
        var scriptState: String
        var updatedAt: Date
        init(scriptState: String = "", updatedAt: Date = Date()) { self.scriptState=scriptState;self.updatedAt=updatedAt }
        private enum CodingKeys: String, CodingKey { case scriptState,updatedAt }
        init(from decoder: Decoder) throws {
            let values=try decoder.container(keyedBy:CodingKeys.self)
            scriptState=try values.decode(String.self,forKey:.scriptState)
            updatedAt=try values.decodeIfPresent(Date.self,forKey:.updatedAt) ?? Date(timeIntervalSince1970:0)
        }
    }
    var scriptName: String
    var scriptParameter: String
    var binding: ScriptWidgetLiveActivityBinding? = nil

    static func fits(attributes: Self, state: ContentState) -> Bool {
        guard ScriptWidgetPackageName.isValid(attributes.scriptName),attributes.scriptParameter.utf8.count<=4096,
              state.scriptState.utf8.count<=4096,state.updatedAt.timeIntervalSince1970.isFinite else { return false }
        struct Payload: Encodable { let attributes: ScriptLiveActivityAttributes;let state: ContentState }
        // Reserve space for ActivityKit's envelope, rather than treating a 4-KiB string as a 4-KiB activity.
        guard let data=try? JSONEncoder().encode(Payload(attributes:attributes,state:state)) else { return false }
        return data.count+128<=4096
    }
}
