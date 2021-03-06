/*
 Copyright 2021 The Fuel Rats Mischief

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

class ShortenURLCommands: IRCBotModule {
    var name: String = "Shorten URL Commands"

    @BotCommand(
        ["shorten", "short", "shortener"],
        [.param("url", "https://www.youtube.com/watch?v=dQw4w9WgXcQ"), .param("custom link", "importantinfo", .standard, .optional)],
        category: .utility,
        description: "Create a t.fuelr.at short url to another url, optionally set a custom url rather than a random.",
        permission: .RescueWriteOwn,
        allowedDestinations: .PrivateMessage
    )
    var didReceiveShortenURLCommand = { (command: IRCBotCommand) in
        var keyword: String?
        if command.parameters.count > 1 {
            keyword = command.parameters[1].lowercased()
        }

        guard let url = URL(string: command.parameters[0]) else {
            command.message.error(key: "shorten.invalidurl", fromCommand: command)
            return
        }

        URLShortener.shorten(url: url, keyword: keyword, complete: { response in
            command.message.reply(key: "shorten.shortened", fromCommand: command, map: [
                "url": response.shorturl,
                "title": response.title
            ])
        }, error: { _ in
            command.message.error(key: "shorten.error", fromCommand: command)
        })
    }

    required init(_ moduleManager: IRCBotModuleManager) {
        moduleManager.register(module: self)
    }
}
