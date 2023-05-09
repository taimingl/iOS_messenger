//
//  ProfileViewModel.swift
//  iOS_messenger
//
//  Created by Taiming Liu on 5/8/23.
//

import Foundation

enum ProfileViewModelType {
    case info
    case logout
}

struct ProfileViewModel {
    let viewModelType: ProfileViewModelType
    let title: String
    let handler: (() -> Void)? // handling when user taps the cell
}
