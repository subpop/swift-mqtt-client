//
//  Subscribe.swift
//  
//
//  Created by Link Dupont on 8/27/24.
//

import ArgumentParser
import Logging
import MQTTNIO
import NIOCore

extension MQTT {
    struct Subscribe: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Subscribe to an MQTT topic")
        
        @OptionGroup var options: MQTT.Options
        
        mutating func run() async throws {
            let client = try NewMQTTClient(options: self.options)
            try await client.connect()
            
            let logger = NewLogger(label: "SUB", options: self.options)
            
            logger.info("connected", metadata: ["host": .string(self.options.host)])

            let subscriptions = self.options.topic.map { topic in
                MQTTSubscribeInfo(topicFilter: topic, qos: MQTTQoS(rawValue: self.options.qos) ?? .atMostOnce)
            }
            _ = try await client.subscribe(to: subscriptions)

            logger.info("subscribed", metadata: ["topic": .array(self.options.topic.map({ .string($0) }))])
            let listener = client.createPublishListener()
            for await result in listener {
                switch result {
                    case .success(let packet):
                        var buffer = packet.payload
                        let content = buffer.readString(length: buffer.readableBytes)?.trimmingCharacters(in: .whitespacesAndNewlines)
                        logger.notice("message received",
                                      metadata: ["topic": .string(packet.topicName), "content": .string(content!)])
                    case .failure(let error):
                        logger.error("failed to receive PUBLISH", metadata: ["error": .string("\(error)")])
                }
            }
        }
    }
}
