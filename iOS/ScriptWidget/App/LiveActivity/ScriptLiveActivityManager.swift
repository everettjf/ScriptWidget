import Foundation
import ActivityKit
import UIKit
import Combine
import SwiftUI

struct ScriptLiveActivityRow: Identifiable, Equatable, Sendable {
    let id: String
    let attributes: ScriptLiveActivityAttributes
    let state: ScriptLiveActivityAttributes.ContentState
    let status: String
    let staleDate: Date?
    var isRunning: Bool { ["pending","active","stale"].contains(status) }
}

@available(iOS 16.2,*)
@MainActor
struct ScriptLiveActivityClient {
    var supported: @MainActor () -> Bool
    var enabled: @MainActor () -> Bool
    var foreground: @MainActor () -> Bool
    var list: @MainActor () -> [ScriptLiveActivityRow]
    var request: @MainActor (ScriptLiveActivityAttributes,ScriptLiveActivityAttributes.ContentState,Date?) throws -> String
    var update: @MainActor (String,ScriptLiveActivityAttributes.ContentState,Date?) async -> Void
    var end: @MainActor (String,ScriptLiveActivityAttributes.ContentState?,ActivityUIDismissalPolicy) async -> Void

    static var system: Self {
        #if DEBUG
        if ScriptWidgetApplicationTestHost.isActive && ProcessInfo.processInfo.environment["SCRIPTWIDGET_ACTIVITYKIT_SMOKE"] != "1" {
            return .init(supported:{false},enabled:{false},foreground:{false},list:{[]},request:{_,_,_ in throw ScriptLiveActivityFailure.unsupported},update:{_,_,_ in},end:{_,_,_ in})
        }
        #endif
        return .init(supported:{ if #available(iOS 16.2,*) { return true };return false },
              enabled:{ if #available(iOS 16.2,*) { return ActivityAuthorizationInfo().areActivitiesEnabled };return false },
              foreground:{ UIApplication.shared.applicationState == .active },
              list:{
                  guard #available(iOS 16.2,*) else { return [] }
                  return Activity<ScriptLiveActivityAttributes>.activities.map { item in
                      let status:String
                      switch item.activityState { case .pending:status="pending";case .active:status="active";case .stale:status="stale";case .ended:status="ended";case .dismissed:status="dismissed";@unknown default:status="unknown" }
                      return .init(id:item.id,attributes:item.attributes,state:item.content.state,status:status,staleDate:item.content.staleDate)
                  }
              },request:{ attributes,state,staleDate in
                  guard #available(iOS 16.2,*) else { throw ScriptLiveActivityFailure.unsupported }
                  return try Activity.request(attributes:attributes,content:ActivityContent(state:state,staleDate:staleDate),pushType:nil).id
              },update:{ id,state,staleDate in
                  guard #available(iOS 16.2,*),let activity=Activity<ScriptLiveActivityAttributes>.activities.first(where:{$0.id==id}) else { return }
                  await activity.update(ActivityContent(state:state,staleDate:staleDate))
              },end:{ id,state,policy in
                  guard #available(iOS 16.2,*),let activity=Activity<ScriptLiveActivityAttributes>.activities.first(where:{$0.id==id}) else { return }
                  let content=state.map{ActivityContent(state:$0,staleDate:nil)}
                  await activity.end(content,dismissalPolicy:policy)
              })
    }
}

enum ScriptLiveActivityFailure: LocalizedError, Equatable {
    case unsupported,disabled,foregroundRequired,tooLarge,limit,duplicate,notFound,busy,systemRefused,changed
    var errorDescription: String? {
        switch self {
        case .unsupported:return "Local Live Activities require iOS 16.2 or later on a supported device."
        case .disabled:return "Live Activities are unavailable or disabled. Check device support and ScriptWidget Settings."
        case .foregroundRequired:return "Open ScriptWidget in the foreground to start a Live Activity."
        case .tooLarge:return "The encoded activity data is too large or invalid. Static attributes and state share a 4 KiB budget."
        case .limit:return "Four local activities are already running. End one before starting another."
        case .duplicate:return "An identical activity is already running. Update it, or explicitly start another copy."
        case .changed:return "The activity changed after you opened this draft. Reload its current state and review your update."
        case .notFound:return "This Live Activity has ended or is no longer available."
        case .busy:return "Another activity operation is in progress. Try again when it finishes."
        case .systemRefused:return "The system could not start this Live Activity. Check device support, settings and available activity slots."
        }
    }
}

@available(iOS 16.2,*)
@MainActor
final class ScriptLiveActivityManager: ObservableObject {
    static let maximumStateBytes=4096
    static let maximumActivities=4
    @Published private(set) var activities:[ScriptLiveActivityRow]=[]
    @Published private(set) var isWorking=false
    @Published private(set) var message:String?
    @Published private(set) var isError=false
    private let client:ScriptLiveActivityClient
    private let prepare:@MainActor (String)throws->(ScriptWidgetLiveActivityBinding,String)
    private let currentName:@MainActor (ScriptWidgetLiveActivityBinding)throws->String
    private let now:@MainActor ()->Date
    private var removalObserver:NSObjectProtocol?
    private var activeObserver:NSObjectProtocol?
    private var needsReconcile=false

    init(client:ScriptLiveActivityClient? = nil,
         prepare:@escaping @MainActor (String)throws->(ScriptWidgetLiveActivityBinding,String) = { name in
             let (binding,execution)=try ScriptWidgetLiveActivityBinding.capture(name:name)
             return (binding,execution.snapshot?.binding.name ?? name)
         },currentName:@escaping @MainActor (ScriptWidgetLiveActivityBinding)throws->String = { try $0.currentName() },
         now:@escaping @MainActor ()->Date = { Date() },observeSystem:Bool = true) {
        self.client=client ?? .system;self.prepare=prepare;self.currentName=currentName;self.now=now
        if observeSystem {
            removalObserver=NotificationCenter.default.addObserver(forName:ScriptManager.packageRemovedNotification,object:nil,queue:.main){ [weak self] notification in
                let name=notification.object as? String
                Task { @MainActor [weak self] in await self?.reconcile(removedName:name) }
            }
            activeObserver=NotificationCenter.default.addObserver(forName:UIApplication.didBecomeActiveNotification,object:nil,queue:.main){ [weak self] _ in
                Task { @MainActor [weak self] in await self?.reconcile() }
            }
        }
        refresh()
    }
    deinit {
        if let removalObserver { NotificationCenter.default.removeObserver(removalObserver) }
        if let activeObserver { NotificationCenter.default.removeObserver(activeObserver) }
    }
    var isSupported:Bool { client.supported() }
    var areActivitiesEnabled:Bool { client.enabled() }
    func refresh() { activities=client.list().filter(\.isRunning).sorted{$0.id<$1.id} }
    func displayName(_ row:ScriptLiveActivityRow)->String { (try? row.attributes.binding.map(currentName)) ?? row.attributes.scriptName }
    func bindingMessage(_ row:ScriptLiveActivityRow)->String? {
        guard let binding=row.attributes.binding else { return ScriptWidgetLiveActivityBindingError.invalidBinding.localizedDescription }
        do { _=try currentName(binding);return nil } catch { return error.localizedDescription }
    }
    private func failure(_ error:Error) { message=error.localizedDescription;isError=true }
    private func finishOperation() {
        isWorking=false;refresh()
        if needsReconcile { needsReconcile=false;Task { await self.reconcile() } }
    }
    private func begin() throws {
        guard !isWorking else { throw ScriptLiveActivityFailure.busy }
        guard client.supported() else { throw ScriptLiveActivityFailure.unsupported }
        isWorking=true;message=nil;isError=false
    }
    static func isValidState(_ state:String)->Bool { state.utf8.count<=maximumStateBytes }

    @discardableResult
    func create(scriptName:String,scriptParameter:String,initialState:String="",staleDate:Date?=nil,allowDuplicate:Bool=false,expectedBinding:ScriptWidgetLiveActivityBinding?=nil)->String? {
        do {
            try begin();defer{finishOperation()}
            guard client.enabled() else { throw ScriptLiveActivityFailure.disabled }
            guard client.foreground() else { throw ScriptLiveActivityFailure.foregroundRequired }
            guard Self.isValidState(initialState),scriptParameter.utf8.count<=4096,staleDate?.timeIntervalSince1970.isFinite ?? true else { throw ScriptLiveActivityFailure.tooLarge }
            let (binding,name)=try prepare(scriptName)
            if let expectedBinding,expectedBinding != binding { throw ScriptWidgetLiveActivityBindingError.invalidBinding }
            guard binding.isValid else { throw ScriptWidgetLiveActivityBindingError.invalidBinding }
            let attributes=ScriptLiveActivityAttributes(scriptName:name,scriptParameter:scriptParameter,binding:binding)
            let state=ScriptLiveActivityAttributes.ContentState(scriptState:initialState,updatedAt:now())
            guard ScriptLiveActivityAttributes.fits(attributes:attributes,state:state) else { throw ScriptLiveActivityFailure.tooLarge }
            let running=client.list().filter(\.isRunning)
            guard running.count<Self.maximumActivities else { throw ScriptLiveActivityFailure.limit }
            if !allowDuplicate && running.contains(where:{$0.attributes.binding==binding && $0.attributes.scriptParameter==scriptParameter && $0.state.scriptState==initialState}) { throw ScriptLiveActivityFailure.duplicate }
            let id:String
            do { id=try client.request(attributes,state,staleDate) } catch { throw ScriptLiveActivityFailure.systemRefused }
            do { _=try currentName(binding) } catch {
                Task { await client.end(id,nil,.immediate) }
                throw error
            }
            message="Live Activity requested. The system controls its presentation.";return id
        } catch { failure(error);return nil }
    }

    @discardableResult
    func update(activityID:String,state:String,staleDate:Date?=nil,expectedState:ScriptLiveActivityAttributes.ContentState?=nil) async->Bool {
        do {
            try begin();defer{finishOperation()}
            guard let row=client.list().first(where:{$0.id==activityID && $0.isRunning}) else { throw ScriptLiveActivityFailure.notFound }
            if let expectedState,expectedState != row.state { throw ScriptLiveActivityFailure.changed }
            guard let binding=row.attributes.binding else { throw ScriptWidgetLiveActivityBindingError.invalidBinding }
            _=try currentName(binding)
            let content=ScriptLiveActivityAttributes.ContentState(scriptState:state,updatedAt:now())
            guard ScriptLiveActivityAttributes.fits(attributes:row.attributes,state:content),staleDate?.timeIntervalSince1970.isFinite ?? true else { throw ScriptLiveActivityFailure.tooLarge }
            await client.update(activityID,content,staleDate)
            guard client.list().contains(where:{$0.id==activityID && $0.isRunning}) else { throw ScriptLiveActivityFailure.notFound }
            _=try currentName(binding)
            message="Update requested. Lock-screen and Island rendering are scheduled by the system.";return true
        } catch { failure(error);return false }
    }

    @discardableResult
    func end(activityID:String,finalState:String, dismissalPolicy:ActivityUIDismissalPolicy = .default) async->Bool {
        await finish(activityID:activityID,finalState:finalState,policy:dismissalPolicy)
    }
    @discardableResult
    func dismiss(activityID:String) async->Bool { await finish(activityID:activityID,finalState:nil,policy:.immediate) }
    private func finish(activityID:String,finalState:String?,policy:ActivityUIDismissalPolicy) async->Bool {
        do {
            try begin();defer{finishOperation()}
            guard let row=client.list().first(where:{$0.id==activityID && $0.isRunning}) else { throw ScriptLiveActivityFailure.notFound }
            let content=finalState.map{ScriptLiveActivityAttributes.ContentState(scriptState:$0,updatedAt:now())}
            if let content,!ScriptLiveActivityAttributes.fits(attributes:row.attributes,state:content) { throw ScriptLiveActivityFailure.tooLarge }
            await client.end(activityID,content,policy)
            message="Live Activity end requested.";return true
        } catch { failure(error);return false }
    }
    func endAll(finalState:String="") async {
        for row in client.list().filter(\.isRunning) { _=await end(activityID:row.id,finalState:finalState) }
    }
    func reconcile(removedName:String?=nil) async {
        guard !isWorking else { needsReconcile=true;return }
        guard client.supported() else { refresh();return }
        isWorking=true;defer{finishOperation()}
        for row in client.list().filter(\.isRunning) {
            var shouldEnd=row.attributes.binding==nil || row.attributes.scriptName==removedName
            if let binding=row.attributes.binding {
                do { _=try currentName(binding) }
                catch let error as ScriptWidgetLiveActivityBindingError { shouldEnd = shouldEnd || [.invalidBinding,.differentLibrary,.installationRetired].contains(error) }
                catch { /* A temporarily unavailable library is not deletion. */ }
            }
            if shouldEnd { await client.end(row.id,nil,.immediate) }
        }
    }
}

@available(iOS 16.2,*)
@MainActor let sharedLiveActivityManager=ScriptLiveActivityManager()

@available(iOS 16.2,*)
@MainActor
struct ScriptLiveActivityManagementView: View {
    @ObservedObject private var manager:ScriptLiveActivityManager
    private let availableNames:@MainActor ()throws->[String]
    @State private var names:[String]=[]
    @State private var selection=""
    @State private var parameter=""
    @State private var state=""
    @State private var markStale=false
    @State private var staleDate=Date().addingTimeInterval(15*60)
    @State private var duplicate=false
    @State private var preparing=false
    @State private var localMessage:String?

    init(manager:ScriptLiveActivityManager?=nil,availableNames:@escaping @MainActor ()throws->[String]={try ScriptWidgetHostExecution.availableNames()}) {
        self.manager=manager ?? sharedLiveActivityManager;self.availableNames=availableNames
    }
    var body:some View {
        Form {
            Section("Start a local activity") {
                if !manager.isSupported { Text(ScriptLiveActivityFailure.unsupported.localizedDescription) }
                else {
                    if !manager.areActivitiesEnabled { Text(ScriptLiveActivityFailure.disabled.localizedDescription).foregroundStyle(.secondary) }
                    Picker("Widget",selection:$selection) {
                        Text("Choose a widget").tag("")
                        ForEach(names,id:\.self){Text($0).tag($0)}
                    }
                    TextField("Widget parameter (optional)",text:$parameter).autocorrectionDisabled()
                    Text("Initial state").font(.caption).foregroundStyle(.secondary)
                    TextEditor(text:$state).frame(minHeight:100).autocorrectionDisabled().textInputAutocapitalization(.never).accessibilityLabel("Initial Live Activity state")
                    Text("State text: \(state.utf8.count) bytes. Attributes and encoded state share a 4 KB limit.").font(.caption).foregroundStyle(.secondary)
                    Button("Use a 25-minute focus state") { focusPreset() }
                    Toggle("Mark data stale at a chosen time",isOn:$markStale)
                    if markStale { DatePicker("Stale time",selection:$staleDate) }
                    Toggle("Allow another identical copy",isOn:$duplicate)
                    Button { start() } label: {
                        if preparing { ProgressView("Preparing activity…") } else { Label("Start Live Activity",systemImage:"lock.rectangle") }
                    }.disabled(selection.isEmpty || preparing || manager.isWorking || !manager.areActivitiesEnabled)
                }
            }.disabled(preparing || manager.isWorking)
            if let localMessage { Section { Text(localMessage).foregroundStyle(.red) } }
            if let message=manager.message { Section { Text(message).foregroundStyle(manager.isError ? .red : .secondary) } }
            Section("Running activities (\(manager.activities.count))") {
                if manager.activities.isEmpty { Text("No running activities. Reopening this screen reads the system's activity list.").foregroundStyle(.secondary) }
                ForEach(manager.activities) { row in
                    NavigationLink { ScriptLiveActivityDetailView(manager:manager,activityID:row.id) } label: {
                        VStack(alignment:.leading,spacing:4) {
                            Text(manager.displayName(row))
                            Text(row.status.capitalized).font(.caption).foregroundStyle(.secondary)
                            if let warning=manager.bindingMessage(row) { Text(warning).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }
                if !manager.activities.isEmpty { Button("End All Activities",role:.destructive){Task{await manager.endAll()}}.disabled(manager.isWorking) }
            }
            Section {
                Text("Use a script with lock-screen and Dynamic Island layouts, such as Live Activity Demo. Updates are local app requests; no background polling or remote push is configured. The system controls display, staleness and removal.").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Live Activities")
        .toolbar { Button { reloadNames();Task{await manager.reconcile()} } label:{Label("Refresh",systemImage:"arrow.clockwise")} }
        .task { reloadNames();await manager.reconcile() }
    }
    private func reloadNames() {
        do { names=try availableNames();if !names.contains(selection){selection=names.first ?? ""} }
        catch { localMessage=error.localizedDescription }
    }
    private func focusPreset() {
        let end=Date().addingTimeInterval(25*60)
        let data=try? JSONSerialization.data(withJSONObject:["title":"Focus session","detail":"Time to concentrate","endsAt":ISO8601DateFormatter().string(from:end)],options:[.sortedKeys])
        state=data.map{String(decoding:$0,as:UTF8.self)} ?? "";markStale=true;staleDate=end
    }
    private func start() {
        let name=selection,input=parameter,initial=state,date=markStale ? staleDate : nil,another=duplicate
        preparing=true;localMessage=nil
        let package=sharedScriptManager.getScriptPackage(packageName:name)
        Task {
            defer{preparing=false}
            do {
                let expected=try await Task.detached(priority:.userInitiated) {
                    try package.managedScope?.validate(name:name)
                    let (binding,execution)=try ScriptWidgetLiveActivityBinding.capture(name:name,cacheOnly:false)
                    guard binding.ownerID==package.managedScope?.binding?.ownerID,
                          execution.snapshot?.context.libraryRoot==package.managedScope?.context.libraryRoot else { throw ScriptWidgetLiveActivityBindingError.invalidBinding }
                    let result=sharedScriptManager.buildScriptPackage(package:package,requireSharedContainer:true)
                    guard result.0 else { throw ScriptWidgetHostReadError(message:result.1) }
                    try package.managedScope?.validate(name:name)
                    return binding
                }.value
                _=manager.create(scriptName:name,scriptParameter:input,initialState:initial,staleDate:date,allowDuplicate:another,expectedBinding:expected)
            } catch { localMessage=error.localizedDescription }
        }
    }
}

@available(iOS 16.2,*)
@MainActor
private struct ScriptLiveActivityDetailView:View {
    @ObservedObject var manager:ScriptLiveActivityManager
    let activityID:String
    @State private var draft=""
    @State private var baseline:ScriptLiveActivityAttributes.ContentState?
    @State private var markStale=false
    @State private var staleDate=Date().addingTimeInterval(15*60)
    private var row:ScriptLiveActivityRow? { manager.activities.first{$0.id==activityID} }
    var body:some View {
        Form {
            if let row {
                Section {
                    Text(manager.displayName(row)).font(.headline)
                    Text(row.status.capitalized)
                    if row.state.updatedAt.timeIntervalSince1970>0 { Text("Updated \(row.state.updatedAt.formatted())").font(.caption) }
                    if let warning=manager.bindingMessage(row) { Text(warning).foregroundStyle(.secondary) }
                }
                Section("State draft") {
                    TextEditor(text:$draft).frame(minHeight:160).autocorrectionDisabled().textInputAutocapitalization(.never).accessibilityLabel("Live Activity state draft")
                    Toggle("Mark data stale at a chosen time",isOn:$markStale)
                    if markStale { DatePicker("Stale time",selection:$staleDate) }
                    Button("Update State") { Task { if await manager.update(activityID:activityID,state:draft,staleDate:markStale ? staleDate : nil,expectedState:baseline) { baseline=self.row?.state } } }.disabled(manager.bindingMessage(row) != nil)
                    Button("End with This Final State",role:.destructive) { Task { _=await manager.end(activityID:activityID,finalState:draft) } }
                    Button("End and Remove Immediately",role:.destructive) { Task { _=await manager.dismiss(activityID:activityID) } }
                }.disabled(manager.isWorking)
            } else { Text("This activity has ended or was dismissed by the system.") }
            if let message=manager.message { Text(message).foregroundStyle(manager.isError ? .red : .secondary) }
        }
        .navigationTitle("Activity State")
        .toolbar { Button("Reload Current State"){reload()} }
        .onAppear{reload()}
    }
    private func reload() {
        manager.refresh();guard let row else { return }
        draft=row.state.scriptState;baseline=row.state;markStale=row.staleDate != nil;staleDate=row.staleDate ?? Date().addingTimeInterval(15*60)
    }
}
