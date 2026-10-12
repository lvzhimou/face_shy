//
//  AppNavigationController.swift
//  FaceShy
//
//  全局导航控制器：竖屏锁定 + 状态栏颜色随深浅色模式切换。
//

import UIKit

final class AppNavigationController: UINavigationController {

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        traitCollection.userInterfaceStyle == .dark ? .lightContent : .darkContent
    }
}
