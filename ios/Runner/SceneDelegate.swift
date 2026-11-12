import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    receive(connectionOptions.urlContexts)
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    // Keep plugin handling for other schemes without letting Flutter interpret PDF
    // file URLs as application routes.
    let other = Set(URLContexts.filter { !$0.url.isFileURL })
    if !other.isEmpty { super.scene(scene, openURLContexts: other) }
    receive(URLContexts)
  }

  private func receive(_ contexts: Set<UIOpenURLContext>) {
    guard let app = UIApplication.shared.delegate as? AppDelegate else { return }
    for context in contexts.sorted(by: { $0.url.absoluteString < $1.url.absoluteString }) {
      app.documents.accept(context.url)
    }
  }
}
