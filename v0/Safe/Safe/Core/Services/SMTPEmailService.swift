//
//  SMTPEmailService.swift
//  Safe
//
//  Service d'envoi automatique d'emails via SMTP avec pièce jointe audio
//

import Foundation
import UIKit
import CoreLocation

/// Configuration SMTP
struct SMTPConfig {
    let host: String
    let port: Int
    let username: String
    let password: String
    let fromEmail: String
    let fromName: String
    
    // Configuration depuis le fichier .env
    static var fromEnvironment: SMTPConfig {
        let env = EnvironmentConfig.shared
        return SMTPConfig(
            host: env.smtpHost,
            port: env.smtpPort,
            username: env.smtpUsername,
            password: env.smtpPassword,
            fromEmail: env.smtpFromEmail,
            fromName: env.smtpFromName
        )
    }
}

/// Service d'envoi d'emails SMTP
class SMTPEmailService {
    
    static let shared = SMTPEmailService()
    
    private var config: SMTPConfig?
    
    /// Configure le service SMTP
    func configure(with config: SMTPConfig) {
        self.config = config
    }
    
    /// Envoie un email avec un enregistrement audio en pièce jointe
    /// - Parameters:
    ///   - recordingURL: URL de l'enregistrement audio
    ///   - contacts: Liste des contacts à qui envoyer
    ///   - keyword: Mot-clé qui a déclenché l'alerte
    ///   - userName: Nom de l'utilisateur qui envoie l'alerte
    ///   - location: Localisation GPS optionnelle
    ///   - completion: Handler de complétion
    func sendEmergencyEmail(
        recordingURL: URL,
        to contacts: [Contact],
        keyword: String,
        userName: String,
        location: CLLocation? = nil,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let config = config else {
            completion(.failure(SMTPError.notConfigured))
            return
        }
        
        // Vérifier que le fichier existe
        guard FileManager.default.fileExists(atPath: recordingURL.path) else {
            completion(.failure(SMTPError.fileNotFound))
            return
        }
        
        // Filtrer les contacts qui ont un email
        let emailContacts = contacts.filter { $0.email != nil && !$0.email!.isEmpty }
        
        guard !emailContacts.isEmpty else {
            completion(.failure(SMTPError.noEmailContacts))
            return
        }
        
        // Pour chaque contact, envoyer l'email
        let group = DispatchGroup()
        var errors: [Error] = []
        
        for contact in emailContacts {
            guard let toEmail = contact.email else { continue }
            
            group.enter()
            
            sendEmail(
                config: config,
                to: toEmail,
                toName: contact.name,
                keyword: keyword,
                userName: userName,
                audioURL: recordingURL,
                location: location
            ) { result in
                if case .failure(let error) = result {
                    errors.append(error)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            if errors.isEmpty {
                completion(.success(()))
            } else {
                completion(.failure(SMTPError.partialFailure(errors)))
            }
        }
    }
    
    /// Envoie un email via SMTP
    private func sendEmail(
        config: SMTPConfig,
        to: String,
        toName: String,
        keyword: String,
        userName: String,
        audioURL: URL,
        location: CLLocation?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // Créer le contenu de l'email
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        formatter.locale = Locale(identifier: "fr_FR")
        
        let subject = "🚨 ALERTE D'URGENCE"
        
        // Gérer la localisation
        var locationHTML = ""
        if let location = location {
            let latitude = location.coordinate.latitude
            let longitude = location.coordinate.longitude
            let googleMapsLink = "https://www.google.com/maps?q=\(latitude),\(longitude)"
            
            locationHTML = """
            
            <div style="background: #e3f2fd; padding: 15px; border-radius: 5px; margin-top: 20px; border-left: 4px solid #2196F3;">
                <p style="margin: 0;"><strong>Localisation GPS :</strong></p>
                <p style="margin: 5px 0;">
                    Latitude : \(String(format: "%.6f", latitude))<br>
                    Longitude : \(String(format: "%.6f", longitude))
                </p>
                <p style="margin: 10px 0 0 0;">
                    <a href="\(googleMapsLink)" style="color: #2196F3; text-decoration: none;">Ouvrir dans Google Maps</a>
                </p>
            </div>
            """
        }
        
        let body = """
        <html>
        <body style="font-family: Arial, sans-serif; padding: 20px;">
            <div style="background: #ff4444; color: white; padding: 20px; border-radius: 10px; margin-bottom: 20px;">
                <h1 style="margin: 0;">ALERTE D'URGENCE</h1>
            </div>
            
            <p>\(userName) ne se sent pas en sécurité.</p>
            <p>\(userName) vous a envoyé un enregistrement audio via son application Safe.</p>
            
            <p><strong>Date et heure :</strong> \(formatter.string(from: Date()))</p>
            \(locationHTML)
            
            <div style="background: #f5f5f5; padding: 15px; border-radius: 5px; margin-top: 20px;">
                <p style="margin: 0;"><strong>Enregistrement audio en pièce jointe</strong></p>
                <p style="margin: 5px 0 0 0; font-size: 12px; color: #666;">
                    Téléchargez et écoutez l'enregistrement pour plus de détails.
                </p>
            </div>
            
            <p style="margin-top: 30px; font-size: 12px; color: #999;">
                Cet email a été envoyé automatiquement par l'application Safe.
            </p>
        </body>
        </html>
        """
        
        // Charger les données audio
        guard let audioData = try? Data(contentsOf: audioURL) else {
            completion(.failure(SMTPError.cannotReadFile))
            return
        }
        
        let filename = "urgence_\(keyword)_\(Date().timeIntervalSince1970).m4a"
        
        // Construire l'email avec URLSession (via Mailgun API ou SendGrid)
        // Pour simplifier, on utilise une requête HTTP POST vers une API d'envoi
        sendViaHTTPAPI(
            config: config,
            to: to,
            subject: subject,
            body: body,
            audioData: audioData,
            filename: filename,
            completion: completion
        )
    }
    
    /// Envoie via SMTP natif (POC simplifié)
    private func sendViaHTTPAPI(
        config: SMTPConfig,
        to: String,
        subject: String,
        body: String,
        audioData: Data,
        filename: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Créer la connexion SMTP
                let smtpSession = SimpleSMTPSession(
                    host: config.host,
                    port: config.port,
                    username: config.username,
                    password: config.password
                )
                
                // Créer l'email
                let email = SMTPEmail(
                    from: config.fromEmail,
                    fromName: config.fromName,
                    to: to,
                    subject: subject,
                    bodyHTML: body,
                    attachmentData: audioData,
                    attachmentFilename: filename
                )
                
                // Envoyer
                try smtpSession.send(email: email)
                
                DispatchQueue.main.async {
                    completion(.success(()))
                }
                
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
}

// MARK: - Errors

enum SMTPError: LocalizedError {
    case notConfigured
    case fileNotFound
    case noEmailContacts
    case cannotReadFile
    case partialFailure([Error])
    case sendFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Service SMTP non configuré"
        case .fileNotFound:
            return "Fichier audio introuvable"
        case .noEmailContacts:
            return "Aucun contact avec email configuré"
        case .cannotReadFile:
            return "Impossible de lire le fichier audio"
        case .partialFailure(let errors):
            return "Échec partiel: \(errors.count) email(s) non envoyé(s)"
        case .sendFailed(let reason):
            return "Échec d'envoi: \(reason)"
        }
    }
}

// MARK: - Extension pour SendMode

extension SendMode {
    static let sendViaEmail = SendMode(rawValue: "Envoyer par Email") ?? .sendToContacts
}

// MARK: - Simple SMTP Implementation (POC)

/// Session SMTP simplifiée sans dépendance externe
private class SimpleSMTPSession {
    let host: String
    let port: Int
    let username: String
    let password: String
    
    init(host: String, port: Int, username: String, password: String) {
        self.host = host
        self.port = port
        self.username = username
        self.password = password
    }
    
    func send(email: SMTPEmail) throws {
        // Créer le socket de connexion
        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?
        
        CFStreamCreatePairWithSocketToHost(
            kCFAllocatorDefault,
            host as CFString,
            UInt32(port),
            &readStream,
            &writeStream
        )
        
        guard let inputStream = readStream?.takeRetainedValue(),
              let outputStream = writeStream?.takeRetainedValue() else {
            throw SMTPError.sendFailed("Impossible de créer la connexion")
        }
        
        let inputStreamSwift = inputStream as InputStream
        let outputStreamSwift = outputStream as OutputStream
        
        // Ouvrir les streams AVANT de configurer TLS
        inputStreamSwift.open()
        outputStreamSwift.open()
        
        defer {
            inputStreamSwift.close()
            outputStreamSwift.close()
        }
        
        // Attendre que les streams soient prêts
        var timeout = 0
        while (inputStreamSwift.streamStatus != .open || outputStreamSwift.streamStatus != .open) && timeout < 50 {
            Thread.sleep(forTimeInterval: 0.1)
            timeout += 1
            
            if inputStreamSwift.streamStatus == .error || outputStreamSwift.streamStatus == .error {
                throw SMTPError.sendFailed("Erreur lors de l'ouverture de la connexion")
            }
        }
        
        if timeout >= 50 {
            throw SMTPError.sendFailed("Timeout lors de la connexion")
        }
        
        // Lire le message de bienvenue du serveur
        Thread.sleep(forTimeInterval: 1.0)
        _ = try? readResponse(from: inputStreamSwift)
        
        // Protocole SMTP - EHLO initial
        try sendCommand("EHLO \(host)\r\n", to: outputStreamSwift, from: inputStreamSwift)
        
        // STARTTLS - Initier la négociation TLS
        try sendCommand("STARTTLS\r\n", to: outputStreamSwift, from: inputStreamSwift)
        
        // Activer TLS sur les streams existants
        let tlsSettings: [String: Any] = [
            kCFStreamSSLLevel as String: kCFStreamSocketSecurityLevelNegotiatedSSL,
            kCFStreamSSLValidatesCertificateChain as String: true
        ]
        
        inputStreamSwift.setProperty(tlsSettings as CFTypeRef, forKey: Stream.PropertyKey(rawValue: kCFStreamPropertySSLSettings as String))
        outputStreamSwift.setProperty(tlsSettings as CFTypeRef, forKey: Stream.PropertyKey(rawValue: kCFStreamPropertySSLSettings as String))
        
        // Attendre que le TLS soit établi
        Thread.sleep(forTimeInterval: 2.0)
        
        // EHLO après STARTTLS
        try sendCommand("EHLO \(host)\r\n", to: outputStreamSwift, from: inputStreamSwift)
        
        // Authentification (maintenant sécurisée)
        let authString = "\0\(username)\0\(password)"
        let authData = authString.data(using: .utf8)!
        let authBase64 = authData.base64EncodedString()
        try sendCommand("AUTH PLAIN \(authBase64)\r\n", to: outputStreamSwift, from: inputStreamSwift)
        
        // Expéditeur
        try sendCommand("MAIL FROM:<\(email.from)>\r\n", to: outputStreamSwift, from: inputStreamSwift)
        
        // Destinataire
        try sendCommand("RCPT TO:<\(email.to)>\r\n", to: outputStreamSwift, from: inputStreamSwift)
        
        // Données
        try sendCommand("DATA\r\n", to: outputStreamSwift, from: inputStreamSwift)
        
        // Contenu de l'email avec pièce jointe
        let boundary = "----SafeBoundary\(UUID().uuidString)"
        var emailContent = ""
        
        emailContent += "From: \(email.fromName) <\(email.from)>\r\n"
        emailContent += "To: <\(email.to)>\r\n"
        emailContent += "Subject: \(email.subject)\r\n"
        emailContent += "MIME-Version: 1.0\r\n"
        emailContent += "Content-Type: multipart/mixed; boundary=\"\(boundary)\"\r\n"
        emailContent += "\r\n"
        
        // Corps HTML
        emailContent += "--\(boundary)\r\n"
        emailContent += "Content-Type: text/html; charset=UTF-8\r\n"
        emailContent += "Content-Transfer-Encoding: 7bit\r\n"
        emailContent += "\r\n"
        emailContent += email.bodyHTML
        emailContent += "\r\n\r\n"
        
        // Pièce jointe audio
        emailContent += "--\(boundary)\r\n"
        emailContent += "Content-Type: audio/m4a; name=\"\(email.attachmentFilename)\"\r\n"
        emailContent += "Content-Transfer-Encoding: base64\r\n"
        emailContent += "Content-Disposition: attachment; filename=\"\(email.attachmentFilename)\"\r\n"
        emailContent += "\r\n"
        emailContent += email.attachmentData.base64EncodedString(options: .lineLength64Characters)
        emailContent += "\r\n\r\n"
        
        emailContent += "--\(boundary)--\r\n"
        
        // Envoyer le contenu
        try sendData(emailContent, to: outputStreamSwift)
        
        // Terminer
        try sendCommand("\r\n.\r\n", to: outputStreamSwift, from: inputStreamSwift)
        try sendCommand("QUIT\r\n", to: outputStreamSwift, from: inputStreamSwift)
    }
    
    private func sendCommand(_ command: String, to output: OutputStream, from input: InputStream) throws {
        guard let data = command.data(using: .utf8) else {
            throw SMTPError.sendFailed("Encodage UTF-8 échoué")
        }
        
        // Vérifier que le stream est prêt à écrire
        var waitCount = 0
        while !output.hasSpaceAvailable && waitCount < 10 {
            Thread.sleep(forTimeInterval: 0.1)
            waitCount += 1
        }
        
        if !output.hasSpaceAvailable {
            throw SMTPError.sendFailed("Stream non disponible pour l'écriture")
        }
        
        let written = data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> Int in
            output.write(bytes.bindMemory(to: UInt8.self).baseAddress!, maxLength: data.count)
        }
        
        if written < 0 {
            let error = output.streamError?.localizedDescription ?? "Inconnue"
            throw SMTPError.sendFailed("Écriture échouée: \(error)")
        }
        
        if written != data.count {
            throw SMTPError.sendFailed("Écriture incomplète (\(written)/\(data.count) bytes)")
        }
        
        // Attendre et lire la réponse
        let response = try readResponse(from: input)
        
        // Vérifier les codes d'erreur
        if response.hasPrefix("4") || response.hasPrefix("5") {
            throw SMTPError.sendFailed("Erreur SMTP: \(response)")
        }
    }
    
    private func readResponse(from input: InputStream) throws -> String {
        var attempts = 0
        while !input.hasBytesAvailable && attempts < 20 {
            Thread.sleep(forTimeInterval: 0.1)
            attempts += 1
        }
        
        if !input.hasBytesAvailable {
            throw SMTPError.sendFailed("Pas de réponse du serveur")
        }
        
        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = input.read(&buffer, maxLength: buffer.count)
        
        if bytesRead < 0 {
            let error = input.streamError?.localizedDescription ?? "Inconnue"
            throw SMTPError.sendFailed("Erreur de lecture: \(error)")
        }
        
        if bytesRead == 0 {
            throw SMTPError.sendFailed("Connexion fermée par le serveur")
        }
        
        return String(bytes: buffer[..<bytesRead], encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    
    private func sendData(_ data: String, to output: OutputStream) throws {
        guard let bytes = data.data(using: .utf8) else {
            throw SMTPError.sendFailed("Encodage UTF-8 échoué")
        }
        
        // Envoyer par chunks pour éviter les problèmes de buffer
        let chunkSize = 8192
        var offset = 0
        
        while offset < bytes.count {
            let remainingBytes = bytes.count - offset
            let currentChunkSize = min(chunkSize, remainingBytes)
            
            // Attendre que le stream soit prêt
            var waitCount = 0
            while !output.hasSpaceAvailable && waitCount < 20 {
                Thread.sleep(forTimeInterval: 0.1)
                waitCount += 1
            }
            
            if !output.hasSpaceAvailable {
                throw SMTPError.sendFailed("Stream non disponible - timeout")
            }
            
            let written = bytes.withUnsafeBytes { (rawBuffer: UnsafeRawBufferPointer) -> Int in
                let ptr = rawBuffer.baseAddress!.advanced(by: offset).assumingMemoryBound(to: UInt8.self)
                return output.write(ptr, maxLength: currentChunkSize)
            }
            
            if written < 0 {
                let error = output.streamError?.localizedDescription ?? "Inconnue"
                throw SMTPError.sendFailed("Écriture échouée à l'offset \(offset): \(error)")
            }
            
            offset += written
        }
    }
}

/// Structure d'un email SMTP
private struct SMTPEmail {
    let from: String
    let fromName: String
    let to: String
    let subject: String
    let bodyHTML: String
    let attachmentData: Data
    let attachmentFilename: String
}
