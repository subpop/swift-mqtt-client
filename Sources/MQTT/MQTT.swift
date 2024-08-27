//
//  MQTT.swift
//
//
//  Created by Link Dupont on 8/27/24.
//

import ArgumentParser
import Logging
import MQTTNIO
import NIOSSL

@main
struct MQTT: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "An MQTT publish/subscribe client",
                                                    subcommands: [Publish.self, Subscribe.self])
    
    struct Options: ParsableArguments {
        @Option(name: [.long, .customShort("H")], help: "MQTT broker hostname")
        var host: String
        
        @Option(name: .shortAndLong, help: "MQTT broker port")
        var port: Int = 1883

        @Option(name: .shortAndLong, help: "MQTT client ID")
        var clientID: String = RandomClientID(length: 23)

        @Option(name: .shortAndLong, help: "Authenticate with a username")
        var username: String?

        @Option(name: [.long, .customShort("P")], help: "Authenticate with a password")
        var password: String?
        
        @Option(name: .long, help: "Authenticate with a certificate")
        var CertFile: String?
        
        @Option(name: .long, help: "Authenticate with a private key")
        var KeyFile: String?
        
        @Option(name: .long, help: "Path to a file containing additional CA roots")
        var CARoot: String?

        @Option(name: .shortAndLong, help: "Publish to topic")
        var topic: [String]
        
        @Option(name: .shortAndLong, help: "QoS level for messages")
        var qos: UInt8 = 0
        
        @Flag(name: .long, help: "Increase output verbosity")
        var verbose: Bool = false
    }
}

/// RandomClientID creates and returns a randomly generated string suitable for
/// use as an MQTT client ID.
///
/// - Parameter n: Length of the resulting client ID
/// - Returns: A string
func RandomClientID(length: Int = 6) -> String {
    let letters = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    return String((0..<length).map { _ in letters.randomElement()!})
}

func NewMQTTClient(options: MQTT.Options) throws -> MQTTClient {
    let useWebSockets = switch options.port {
    case 443, 80:
        true
    default:
        false
    }
    
    let useSSL = switch options.port {
    case 443, 8884:
        true
    default:
        false
    }
    
    var tlsConfiguration = TLSConfiguration.makeClientConfiguration()
    if let CARoot = options.CARoot {
        tlsConfiguration.additionalTrustRoots.append(.file(CARoot))
    }
    
    if let certFile = options.CertFile, let keyFile = options.KeyFile {
        let certificate = try NIOSSLCertificate(file: certFile, format: .pem)
        let key = try NIOSSLPrivateKey(file: keyFile, format: .pem)

        tlsConfiguration.certificateChain = [.certificate(certificate)]        
        tlsConfiguration.privateKey = .privateKey(key)
    }
    
    let configuration = MQTTClient.Configuration(userName: options.username,
                                                 password: options.password,
                                                   useSSL: useSSL,
                                            useWebSockets: useWebSockets,
                                         tlsConfiguration: .niossl(tlsConfiguration))
    
    let client = MQTTClient(host: options.host,
                            port: options.port,
                      identifier: options.clientID,
          eventLoopGroupProvider: .createNew,
                   configuration: configuration)
    
    return client
}

func NewLogger(label: String, options: MQTT.Options) -> Logger {
    var logger = Logger(label: label)
    
    logger.logLevel = if options.verbose {
        Logger.Level.info
    } else {
        Logger.Level.notice
    }
    
    return logger
}
