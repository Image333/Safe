//
//  Contact.swift
//  Safe

import Foundation

struct Contact: Identifiable, Codable {
    let id: Int
    let email: String?
    let userRef: String?
    let contactName: String
    let phoneNumber: String
    let contactType: String?
    let priorityOrder: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case userRef = "user_ref"
        case contactName = "contact_name"
        case phoneNumber = "phone_number"
        case contactType = "contact_type"
        case priorityOrder = "priority_order"
    }
    
    var name: String { contactName }
    var phone: String { phoneNumber }
}

// Structure pour créer un nouveau contact
struct ContactInput: Codable {
    let email: String?
    let contactName: String
    let phoneNumber: String
    let contactType: String?
    let priorityOrder: Int
    
    enum CodingKeys: String, CodingKey {
        case email
        case contactName = "contact_name"
        case phoneNumber = "phone_number"
        case contactType = "contact_type"
        case priorityOrder = "priority_order"
    }
}
