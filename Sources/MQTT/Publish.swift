//
//  Publish.swift
//
//
//  Created by Link Dupont on 8/27/24.
//

import ArgumentParser
import MQTTNIO
import NIOCore

extension MQTT {
    struct Publish: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Publish data to an MQTT topic"
        )
        
        @OptionGroup var options: MQTT.Options
        
        @Argument(help: "Read file as message body (use '-' to read from standard input)")
        var message = "-"
        
        mutating func run() async throws {
            let client = try NewMQTTClient(options: self.options)
            try await client.connect()
            
            let logger = NewLogger(label: "PUB", options: self.options)

            var messageContent: String?
            switch message {
            case "-":
                messageContent = readLine(strippingNewline: true)
            default:
                messageContent = try String(contentsOfFile: message, encoding: .utf8)
            }

            guard let messageContent = messageContent else {
                logger.error("message body cannot be empty")
                throw ExitCode(1)
            }

            for topic in self.options.topic {
                _ = try await client.publish(to: topic,
                                             payload: ByteBuffer(string: messageContent),
                                             qos: MQTTQoS(rawValue: self.options.qos) ?? .atMostOnce
                )
            }
        }
    }
}
