/*
 Copyright 2020 The Fuel Rats Mischief

 Redistribution and use in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice,
 this list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following
 disclaimer in the documentation and/or other materials provided with the distribution.

 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote
 products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
 INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation
import IRCKit

protocol IRCBotModule {
    var name: String { get }

    init (_ moduleManager: IRCBotModuleManager)
}

enum AllowedCommandDestination {
    case Channel
    case PrivateMessage
    case All
}

typealias BotCommandFunction = (IRCBotCommand) -> Void
@propertyWrapper struct BotCommand {
    var wrappedValue: BotCommandFunction

    init <T: AnyRange> (
        wrappedValue value: @escaping BotCommandFunction,
        _ commands: [String],
        parameters: T,
        lastParameterIsContinous: Bool = false,
        options: OrderedSet<Character> = [],
        namedOptions: OrderedSet<String> = [],
        category: HelpCategory?,
        description: String,
        paramText: String? = nil,
        example: String? = nil,
        permission: AccountPermission? = nil,
        allowedDestinations: AllowedCommandDestination = .All
    ) {
        self.wrappedValue = value

        let declaration = IRCBotCommandDeclaration(
            commands: commands,
            minParameters: parameters.lower as? Int ?? 0,
            onCommand: self.wrappedValue,
            maxParameters: parameters.upper as? Int,
            lastParameterIsContinous: lastParameterIsContinous,
            options: options,
            namedOptions: namedOptions,
            category: category,
            description: description,
            paramText: paramText,
            example: example,
            permission: permission,
            allowedDestinations: allowedDestinations
        )

        MechaSqueak.commands.append(declaration)
    }
}

struct IRCBotCommandDeclaration {
    let commands: [String]
    let minimumParameters: Int
    let maximumParameters: Int?
    let options: OrderedSet<Character>
    let namedOptions: OrderedSet<String>
    let permission: AccountPermission?
    let lastParameterIsContinous: Bool
    let allowedDestinations: AllowedCommandDestination
    let category: HelpCategory?
    let description: String
    var paramText: String?
    var example: String?

    var onCommand: BotCommandFunction?

    init (
        commands: [String],
        minParameters: Int,
        onCommand: BotCommandFunction?,
        maxParameters: Int? = nil,
        lastParameterIsContinous: Bool = false,
        options: OrderedSet<Character> = [],
        namedOptions: OrderedSet<String> = [],
        category: HelpCategory?,
        description: String,
        paramText: String? = nil,
        example: String? = nil,
        permission: AccountPermission? = nil,
        allowedDestinations: AllowedCommandDestination = .All) {

        self.commands = commands
        self.minimumParameters = minParameters
        self.maximumParameters = maxParameters
        self.options = options
        self.namedOptions = namedOptions
        self.lastParameterIsContinous = lastParameterIsContinous
        self.permission = permission
        self.onCommand = onCommand
        self.allowedDestinations = allowedDestinations
        self.category = category
        self.description = description
        self.paramText = paramText
        self.example = example
    }

    func usageDescription (command: IRCBotCommand?) -> String {
        var usage = command?.command ?? self.commands[0]

        if self.options.count > 0 {
            usage += "[-\(String(self.options))]"
        }

        if self.namedOptions.count > 0 {
            usage += " " + Array(self.namedOptions).map({ "[--\($0)]" }).joined(separator: " ")
        }

        if let paramText = self.paramText {
            usage += " \(paramText)"
        }
        return usage
    }

    func exampleDescription (command: IRCBotCommand?) -> String {
        return "\(command?.command ?? self.commands[0]) \(self.example ?? "")"
    }

    var isDispatchingCommand: Bool {
        return self.category == .board && (self.permission == .RescueWrite || self.permission == .RescueWriteOwn)
    }
}

class IRCBotModuleManager {
    private var registeredModules: [IRCBotModule] = []
    static var blacklist = configuration.general.dispatchBlacklist

    func register (module: IRCBotModule) {
        self.registeredModules.append(module)
    }

    func register (command: IRCBotCommandDeclaration) {
        MechaSqueak.commands.append(command)
    }

    @IRCListener<IRCChannelMessageNotification>
    var onChannelMessage = { channelMessage in
        guard let ircBotCommand = IRCBotCommand(from: channelMessage) else {
            return
        }

        handleIncomingCommand(ircBotCommand: ircBotCommand)
    }


    @IRCListener<IRCPrivateMessageNotification>
    var onPrivateMessage = { privateMessage in
        guard let ircBotCommand = IRCBotCommand(from: privateMessage) else {
            return
        }

        handleIncomingCommand(ircBotCommand: ircBotCommand)
    }

    static func handleIncomingCommand (ircBotCommand: IRCBotCommand) {
        var ircBotCommand = ircBotCommand
        let message = ircBotCommand.message

        guard message.raw.messageTags["batch"] == nil else {
            // Do not interpret commands from playback of old messages
            return
        }

        guard let command = MechaSqueak.commands.first(where: {
            $0.commands.contains(ircBotCommand.command)
        }) else {
            return
        }

        if ircBotCommand.options.contains("h") {
            var helpCommand = ircBotCommand
            helpCommand.command = "!help"
            helpCommand.parameters = ["!\(ircBotCommand.command)"]
            mecha.helpModule.didReceiveHelpCommand(helpCommand)
            return
        }

        let illegalNamedOptions = ircBotCommand.namedOptions.subtracting(command.namedOptions)
        if illegalNamedOptions.count > 0 {
            message.error(key: "command.illegalnamedoptions", fromCommand: ircBotCommand, map: [
                "options": Array(illegalNamedOptions).englishList,
                "command": ircBotCommand.command,
                "usage": "Usage: \(command.usageDescription(command: ircBotCommand)).",
                "example": "Example: \(command.exampleDescription(command: ircBotCommand))."
            ])
            return
        }

        let illegalOptions = ircBotCommand.options.subtracting(command.options)
        if illegalOptions.count > 0 {
            message.error(key: "command.illegaloptions", fromCommand: ircBotCommand, map: [
                "options": String(illegalOptions),
                "command": ircBotCommand.command,
                "usage": "Usage: \(command.usageDescription(command: ircBotCommand)).",
                "example": "Example: \(command.exampleDescription(command: ircBotCommand))."
            ])
            return
        }

        if message.user.hasPermission(permission: .RescueWrite) == false && message.destination.isPrivateMessage && command.allowedDestinations == .Channel {
            message.error(key: "command.publiconly", fromCommand: ircBotCommand, map: [
                "command": ircBotCommand.command
            ])
            return
        }

        if message.user.hasPermission(permission: .RescueWrite) == false && message.destination.isPrivateMessage == false && command.allowedDestinations == .PrivateMessage {
            message.error(key: "command.privateonly", fromCommand: ircBotCommand, map: [
                "command": ircBotCommand.command
            ])
             return
        }

        guard command.minimumParameters <= ircBotCommand.parameters.count else {
            message.error(key: "command.toofewparams", fromCommand: ircBotCommand, map: [
                "command": ircBotCommand.command,
                "usage": "Usage: \(command.usageDescription(command: ircBotCommand)).",
                "example": "Example: \(command.exampleDescription(command: ircBotCommand))."
            ])
            return
        }

        if
            let maxParameters = command.maximumParameters,
            command.lastParameterIsContinous == true,
            ircBotCommand.parameters.count > 1
        {
            var parameters: [String] = []
            var paramIndex = 0

            while paramIndex < maxParameters && paramIndex < ircBotCommand.parameters.count {
                if paramIndex == maxParameters - 1 {
                    let remainderComponents = ircBotCommand.parameters[paramIndex..<ircBotCommand.parameters.endIndex]
                    let remainder = remainderComponents.joined(separator: " ")
                    parameters.append(remainder)
                    break
                } else {
                    parameters.append(ircBotCommand.parameters[paramIndex])
                }
                paramIndex += 1
            }
            ircBotCommand.parameters = Array(parameters)
        }

        if let maxParameters = command.maximumParameters, ircBotCommand.parameters.count > maxParameters {
            message.error(key: "command.toomanyparams", fromCommand: ircBotCommand, map: [
                "command": ircBotCommand.command,
                "usage": "Usage: \(command.usageDescription(command: ircBotCommand)).",
                "example": "Example: \(command.exampleDescription(command: ircBotCommand))."
            ])
            return
        }

        if let permission = command.permission {
            guard message.user.hasPermission(permission: permission) else {
                message.error(key: "board.nopermission", fromCommand: ircBotCommand)
                return
            }
        }
        if command.isDispatchingCommand && blacklist.contains(where: {
            message.user.nickname.lowercased().contains($0.lowercased()) || message.user.account?.lowercased() == $0.lowercased()
        }) {
            message.client.sendMessage(toChannelName: "#doersofstuff", withKey: "command.blacklist", mapping: [
                "command": ircBotCommand.command,
                "nick": message.user.nickname
            ])
        }

        command.onCommand?(ircBotCommand)
    }
}

@propertyWrapper struct IRCListener<T: NotificationDescriptor> {
    var wrappedValue: (T.Payload) -> Void
    let token: NotificationToken

    init (wrappedValue value: @escaping (T.Payload) -> Void) {
        self.wrappedValue = value
        self.token = NotificationCenter.default.addObserver(descriptor: T(), using: self.wrappedValue)
    }
}
