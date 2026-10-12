//
//  SceneDelegate.swift
//  FaceShy
//
//  单窗口场景：根控制器为「首页」。
//

import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.tintColor = Theme.brand
        window.rootViewController = AppNavigationController(rootViewController: HomeViewController())
        window.makeKeyAndVisible()
        self.window = window
    }
}
