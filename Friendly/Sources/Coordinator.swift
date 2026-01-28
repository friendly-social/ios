// import Foundation
//
// /// Used to propagate commands from parent views to children views
// @MainActor
// class Coordinator {
//     private var pending: [Command] = []
//     private var listeners: [UUID: Listener] = [:]
//
//     func execute(command: Command) {
//     }
//
//     /// return Bool from action to indicate that command was handled
//     func on(action: @escaping (Any) -> Bool) -> Cancellation {
//         let listener = Listener(action: action)
//         listeners[listener.id] = listener
//         guard pending.isEmpty else {
//             handle(listener)
//         }
//         return Cancellation(cancel: { [weak self] in
//             self?.listeners[listener.id] = nil
//         })
//     }
//
//     @discardableResult
//     private func handle(_ listener: Listener) -> Bool {
//         let pending = pending[0]
//         return listener.action(pending)
//     }
//
//     struct Command: Identifiable {
//         let id = UUID()
//         let data: Any
//     }
//
//     /// return Bool from action to indicate that command was handled
//     struct Listener: Identifiable {
//         let id = UUID()
//         let action: (Any) -> Bool
//     }
//
//     struct Cancellation {
//         let cancel: () -> Void
//     }
// }
