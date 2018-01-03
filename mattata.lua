--[[
                       _   _        _
       _ __ ___   __ _| |_| |_ __ _| |_ __ _
      | '_ ` _ \ / _` | __| __/ _` | __/ _` |
      | | | | | | (_| | |_| || (_| | || (_| |
      |_| |_| |_|\__,_|\__|\__\__,_|\__\__,_|

      v2.0.0

      Copyright 2017 Matthew Hesketh <wrxck0@gmail.com> & Diego Barreiro <diego@makeroid.io>
      See LICENSE for details

]]

local mattata = {}

local http = require('socket.http')
local https = require('ssl.https')
local url = require('socket.url')
local ltn12 = require('ltn12')
local multipart = require('multipart-post')
local json = require('dkjson')
local redis = dofile('libs/redis.lua')
local configuration = require('configuration')
local api = require('telegram-bot-lua.core').configure(configuration.bot_token)
local tools = require('telegram-bot-lua.tools')
local socket = require('socket')
local utils = dofile('libs/utils.lua')

-- Public JSON lib
jsonlib = dofile('libs/json.lua')

function mattata:init()
    self.info = api.info -- Set the bot's information to the object fetched from the Telegram bot API.
    mattata.info = api.info
    self.plugins = {} -- Make a table for the bot's plugins.
    self.api = api
    mattata.api = api
    self.tools = tools
    mattata.tools = tools
    self.configuration = configuration
    self.plugin_list = {}
    self.inline_plugin_list = {}
    for k, v in ipairs(configuration.plugins) do -- Iterate over all of the configured plugins.
        local plugin = dofile('plugins/' .. v .. '.royale') -- Load each plugin.
        self.plugins[k] = plugin
        self.plugins[k].name = v
        if plugin.init then -- If the plugin has an `init` function, run it.
            plugin.init(self, configuration)
        end
        -- By default, a plugin doesn't have inline functionality; but, if it does, set it to `true` appropriately.
        plugin.is_inline = plugin.on_inline_query and true or false
        plugin.commands = plugin.commands or {} -- If the plugin hasn't got any commands configured, then set a blank
        -- table, so when it comes to iterating over the commands later on, the bot won't encounter any problems.
        if plugin.help then -- If the plugin has help documentation, then insert it into other tables (where necessary).
            table.insert(self.plugin_list, plugin.help)
            if plugin.is_inline then -- If the plugin is inline and has documentation, then insert the documentation into
            -- the `inline_plugin_list` table.
                table.insert(self.inline_plugin_list, plugin.help)
            end
            plugin.help = 'Usage:\n' .. plugin.help:gsub('%. (Alias)', '.\n%1') -- Make the plugin's documentation style all
            -- nicely unified, for consistency.
        end
    end
    local connected_message = 'Connected to the Telegram bot API!'
    print(connected_message)
    local info_message = '\tUsername: @' .. self.info.username .. '\n\tName: ' .. self.info.name .. '\n\tID: ' .. self.info.id
    print('\n' .. info_message .. '\n')
    self.last_update = self.last_update or 0 -- If there is no last update known, make it 0 so the bot doesn't encounter any
    -- problems when it tries to add the necessary increment.
    self.last_backup = self.last_backup or os.date('%V')
    self.last_cron = self.last_cron or os.date('%H')
    self.last_m_cron = self.last_m_cron or os.date('%M')
    local init_message = '<pre>' .. connected_message .. '\n\n' .. mattata.escape_html(info_message) .. '\n\n\tPlugins loaded: ' .. #configuration.plugins .. '</pre>'
    mattata.send_message(configuration.log_chat, init_message:gsub('\t', ''), 'html')
    for _, admin in pairs(configuration.admins) do
        mattata.send_message(admin, init_message:gsub('\t', ''), 'html')
    end
    return true
end

-- A bunch of function aliases, for consistency & backwards-compatibility.

mattata.request = api.request
mattata.get_me = api.get_me
mattata.send_message = api.send_message
mattata.forward_message = api.forward_message
mattata.send_photo = api.send_photo
mattata.send_audio = api.send_audio
mattata.send_document = api.send_document
mattata.send_sticker = api.send_sticker
mattata.send_video = api.send_video
mattata.send_voice = api.send_voice
mattata.send_location = api.send_location
mattata.send_venue = api.send_venue
mattata.send_contact = api.send_contact
mattata.send_chat_action = api.send_chat_action
mattata.get_user_profile_photos = api.get_user_profile_photos
mattata.get_file = api.get_file
mattata.ban_chat_member = api.ban_chat_member
mattata.kick_chat_member = api.kick_chat_member
mattata.unban_chat_member = api.unban_chat_member
mattata.restrict_chat_member = api.restrict_chat_member
mattata.promote_chat_member = api.promote_chat_member
mattata.export_chat_invite_link = api.export_chat_invite_link
mattata.set_chat_photo = api.set_chat_photo
mattata.delete_chat_photo = api.delete_chat_photo
mattata.set_chat_title = api.set_chat_title
mattata.set_chat_description = api.set_chat_description
mattata.pin_chat_message = api.pin_chat_message
mattata.unpin_chat_message = api.unpin_chat_message
mattata.leave_chat = api.leave_chat
mattata.get_chat_administrators = api.get_chat_administrators
mattata.get_chat_members_count = api.get_chat_members_count
mattata.get_chat_member = api.get_chat_member
mattata.answer_callback_query = api.answer_callback_query
mattata.edit_message_text = api.edit_message_text
mattata.edit_message_caption = api.edit_message_caption
mattata.edit_message_reply_markup = api.edit_message_reply_markup
mattata.delete_message = api.delete_message
mattata.get_sticker_set = api.get_sticker_set
mattata.upload_sticker_file = api.upload_sticker_file
mattata.create_new_sticker_set = api.create_new_sticker_set
mattata.add_sticker_to_set = api.add_sticker_to_set
mattata.set_sticker_position_in_set = api.set_sticker_position_in_set
mattata.delete_sticker_from_set = api.delete_sticker_from_set
mattata.answer_inline_query = api.answer_inline_query
mattata.send_invoice = api.send_invoice
mattata.answer_shipping_query = api.answer_shipping_query
mattata.answer_pre_checkout_query = api.answer_pre_checkout_query
mattata.send_game = api.send_game
mattata.set_game_score = api.set_game_score
mattata.get_game_high_scores = api.get_game_high_scores
mattata.input_text_message_content = api.input_text_message_content
mattata.input_location_message_content = api.input_location_message_content
mattata.input_venue_message_content = api.input_venue_message_content
mattata.input_contact_message_content = api.input_contact_message_content
mattata.mask_position = api.mask_position
mattata.url_button = api.url_button
mattata.callback_data_button = api.callback_data_button
mattata.switch_inline_query_button = api.switch_inline_query_button
mattata.switch_inline_query_current_chat_button = api.switch_inline_query_current_chat_button
mattata.callback_game_button = api.callback_game_button
mattata.pay_button = api.pay_button
mattata.row = api.row
mattata.inline_keyboard = api.inline_keyboard
mattata.keyboard = api.keyboard
mattata.remove_keyboard = api.remove_keyboard
mattata.send_inline_article = api.send_inline_article
mattata.send_inline_photo = api.send_inline_photo
mattata.inline_result = api.inline_result

mattata.trim = tools.trim
mattata.comma_value = tools.comma_value
mattata.format_ms = tools.format_ms
mattata.round = tools.round
mattata.symbols = tools.symbols
mattata.utf8_len = tools.utf8_len
mattata.get_linked_name = tools.get_linked_name
mattata.table_size = tools.table_size
mattata.download_file = tools.download_file
mattata.create_link = tools.create_link
mattata.commands = tools.commands
mattata.escape_markdown = tools.escape_markdown
mattata.escape_html = tools.escape_html
mattata.escape_bash = tools.escape_bash

mattata.send_reply = utils.send_reply
mattata.service_message = utils.service_message
mattata.is_media = utils.is_media
mattata.media_type = utils.media_type
mattata.file_id = utils.file_id
mattata.is_trusted_user = utils.is_trusted_user
mattata.get_trusted_users = utils.get_trusted_users
mattata.is_muted_user = utils.is_muted_user
mattata.get_muted_users = utils.get_muted_users
mattata.is_muted_group = utils.is_muted_group
mattata.get_inline_help = utils.get_inline_help
mattata.get_chat_id = utils.get_chat_id
mattata.get_setting = utils.get_setting
mattata.get_value = utils.get_value
mattata.get_user_count = utils.get_user_count
mattata.get_group_count = utils.get_group_count
mattata.get_user_language = utils.get_user_language
mattata.get_log_chat = utils.get_log_chat
mattata.get_missing_languages = utils.get_missing_languages
mattata.get_user_message_statistics = utils.get_user_message_statistics
mattata.reset_message_statistics = utils.reset_message_statistics
mattata.is_group = utils.is_group
mattata.toggle_user_setting = utils.toggle_user_setting
mattata.get_user_setting = utils.get_user_setting
mattata.get_input = utils.get_input
mattata.log_error = utils.log_error
mattata.write_file = utils.write_file
mattata.does_language_exist = utils.does_language_exist
mattata.get_usernames = utils.get_usernames
mattata.is_valid = utils.is_valid
mattata.insert_keyboard_row = utils.insert_keyboard_row
mattata.get_inline_help = utils.get_inline_help
mattata.get_inline_list = utils.get_inline_list
mattata.toggle_setting = utils.toggle_setting
mattata.uses_administration = utils.uses_administration
mattata.format_time = utils.format_time
mattata.check_links = utils.check_links
mattata.is_whitelisted_link = utils.is_whitelisted_link
mattata.process_stickers = utils.process_stickers
mattata.get_user = utils.get_user
mattata.is_plugin_disabled = utils.is_plugin_disabled
mattata.is_group_admin = utils.is_group_admin
mattata.is_global_admin = utils.is_global_admin
mattata.is_group_mod = utils.is_group_mod
mattata.is_group_owner = utils.is_group_owner
mattata.get_help = utils.get_help
mattata.is_privacy_enabled = utils.is_privacy_enabled
mattata.is_user_blacklisted = utils.is_user_blacklisted
mattata.input = utils.input
mattata.get_message_statistics = utils.get_message_statistics
mattata.get_received_messages_count = utils.get_received_messages_count
mattata.get_received_callbacks_count = utils.get_received_callbacks_count
mattata.get_received_inlines_count = utils.get_received_inlines_count
mattata.case_insensitive_pattern = utils.case_insensitive_pattern
mattata.is_pole_done = utils.is_pole_done
mattata.is_subpole_done = utils.is_subpole_done
mattata.is_fail_done = utils.is_fail_done
mattata.is_pole_blacklisted = utils.is_pole_blacklisted
mattata.split = utils.split
mattata.getKeysSortedByValue = utils.getKeysSortedByValue

function mattata:run(configuration, token)
-- mattata's main long-polling function which repeatedly checks the Telegram bot API for updates.
-- The objects received in the updates are then further processed through object-specific functions.
    token = token or configuration.bot_token
    assert(token, 'You need to enter your Telegram bot API token in configuration.lua, or pass it as the second argument when using the mattata:run() function!')
    local is_running = mattata.init(self) -- Initialise the bot.
    utils.init(self, configuration)
    while is_running do -- Perform the main loop whilst the bot is running.
        local success = api.get_updates( -- Check the Telegram bot API for updates.
            1,
            self.last_update + 1,
            100,
            json.encode(
                {
                    'message',
                    -- 'edited_message',
                    'channel_post',
                    -- 'edited_channel_post',
                    'inline_query',
                    -- 'chosen_inline_result',
                    'callback_query',
                    -- 'shipping_query',
                    'pre_checkout_query'
                }
            ),
            configuration.use_beta_endpoint or false
        )
        if success and success.result then
            for k, v in ipairs(success.result) do
                self.message = nil
                self.inline_query = nil
                self.callback_query = nil
                self.language = nil
                self.last_update = v.update_id
                self.execution_time = socket.gettime()
                if v.message then
                    if v.message.reply_to_message then
                        v.message.reply = v.message.reply_to_message -- Make the `update.message.reply_to_message`
                        -- object `update.message.reply` to make any future handling easier.
                        v.message.reply_to_message = nil -- Delete the old value by setting its value to nil.
                    end
                    self.message = v.message
                    mattata.on_message(self)
                    if v.message.successful_payment and configuration.debug then
                        mattata.send_message(configuration.admins[1], json.encode(v.message, { ['indent'] = true }))
                    end
                    if configuration.debug then
                        print(
                            string.format(
                                '%s[36m[Update Message #%s] Message from %s [%s] to %s [%s]%s[0m',
                                string.char(27),
                                v.update_id,
                                v.message.from.first_name,
                                v.message.from.id,
                                v.message.chat.title or self.info.name,
                                v.message.chat.id,
                                string.char(27)
                            )
                        )
                    end
                elseif v.channel_post then
                    if v.channel_post.reply_to_message then
                        v.channel_post.reply = v.channel_post.reply_to_message
                        v.channel_post.reply_to_message = nil
                    end
                    self.message = v.channel_post
                    mattata.on_message(self)
                    if configuration.debug then
                        print(
                            string.format(
                                '%s[37m[Update Message #%s] Channel post from %s [%s]%s[0m',
                                string.char(27),
                                v.update_id,
                                v.channel_post.chat.title,
                                v.channel_post.chat.id,
                                string.char(27)
                            )
                        )
                    end
                elseif v.inline_query then
                    self.inline_query = v.inline_query
                    mattata.on_inline_query(self)
                    if configuration.debug then
                        print(
                            string.format(
                                '%s[35m[Update Inline #%s] Inline query from %s [%s]%s[0m',
                                string.char(27),
                                v.update_id,
                                v.inline_query.from.first_name,
                                v.inline_query.from.id,
                                string.char(27)
                            )
                        )
                    end
                elseif v.callback_query then
                    if v.callback_query.message and v.callback_query.message.reply_to_message then
                        v.callback_query.message.reply = v.callback_query.message.reply_to_message
                        v.callback_query.message.reply_to_message = nil
                    end
                    self.callback_query = v.callback_query
                    self.message = v.callback_query.message or false
                    mattata.on_callback_query(self)
                    if configuration.debug then
                        print(
                            string.format(
                                '%s[33m[Update Callback #%s] Callback query from %s [%s]%s[0m',
                                string.char(27),
                                v.update_id,
                                v.callback_query.from.first_name,
                                v.callback_query.from.id,
                                string.char(27)
                            )
                        )
                    end
                elseif v.pre_checkout_query then
                    mattata.send_message(configuration.admins[1], json.encode(v, { ['indent'] = true }))
                    -- To be improved. Sends the object containing payment-related info to the first configured
                    -- admin, then answers the pre checkout query.
                    mattata.answer_pre_checkout_query(v.pre_checkout_query.id, true)
                end
                self.execution_time = socket.gettime() - self.execution_time
                if configuration.debug then
                    print('Update #' .. v.update_id .. ' took ' .. self.execution_time .. ' seconds to process.')
                end
            end
        else
            mattata.log_error('There was an error retrieving updates from the Telegram bot API!')
        end
        if self.last_backup ~= os.date('%V') then -- If it's been a week since the last backup, perform another backup.
            self.last_backup = os.date('%V') -- Set the last backup time to now, since we're
            -- now performing one!
            print(io.popen('./backup.sh'):read('*all'))
        end
        if self.last_cron ~= os.date('%H') then -- Perform hourly CRON jobs.
            self.last_cron = os.date('%H')
            for i = 1, #self.plugins do
                local plugin = self.plugins[i]
                if plugin.cron then
                    local success, res = pcall(function()
                        plugin.cron(self, configuration)
                    end)
                    if not success then
                        mattata.exception(self, res, 'CRON: ' .. i, configuration.log_chat)
                    end
                end
            end
        end
        if self.last_m_cron ~= os.date('%M') then -- Perform minutely CRON jobs.
            self.last_m_cron = os.date('%M')
            for i = 1, #self.plugins do
                local plugin = self.plugins[i]
                if plugin.m_cron then
                    local success, res = pcall(function()
                            plugin.m_cron(self, configuration)
                    end)
                    if not success then
                        mattata.exception(self, res, 'CRON: ' .. i, configuration.log_chat)
                    end
                end
            end
        end
    end
    print(self.info.name .. ' is shutting down...')
end

function mattata:on_message()
    local message = self.message
    -- If the message is old or is missing necessary fields/values, then we'll stop and allow the bot to start processing the next update(s).
    -- If the message was sent from a blacklisted chat, then we'll stop because we don't want the bot to respond there.
    if not mattata.is_valid(message) or redis:get('blacklisted_chats:' .. message.chat.id) then
        return false
    end
    message = mattata.sort_message(message) -- Process the message.
    self.is_user_blacklisted = mattata.is_user_blacklisted(message)

    -- If the chat doesn't have a custom nickname for the bot to respond by, we'll
    -- stick with the default one that was set through @BotFather.
    self.info.nickname = redis:get('chat:' .. message.chat.id .. ':name') or self.info.name
    if mattata.process_spam(message) then
        return false -- We don't want to process these messages any further!
    end

    if not self.is_user_blacklisted then
        if message.text then
            message = mattata.process_natural_language(self, message)
        end
        -- A boolean value to decide later on, whether the message is intended for the current plugin from the iterated table.
        self.is_command = false
        -- This is the main loop which iterates over configured plugins and runs the appropriate functions.
        self.is_done = false
        for _, plugin in ipairs(self.plugins) do
            local commands = #plugin.commands or {}
            for i = 1, commands do
                if message.text:match(plugin.commands[i]) then
                    self.is_command = true
                    message.command = plugin.commands[i]:match('([%w_%-]+)')
                    if plugin.on_message then
                        if plugin.name ~= 'administration' and mattata.is_plugin_disabled(plugin.name, message) then
                            if message.chat.type ~= 'private' and not redis:get(string.format('chat:%s:dismiss_disabled_message:%s', message.chat.id, plugin.name)) then
                                local keyboard = mattata.inline_keyboard():row(mattata.row():callback_data_button('Dismiss', 'plugins:' .. message.chat.id .. ':dismiss_disabled_message:' .. plugin.name):callback_data_button('Enable', 'plugins:' .. message.chat.id .. ':enable_via_message:' .. plugin.name))
                                return mattata.send_message(message.chat.id, string.format('%s is disabled in this chat.', plugin.name:gsub('^%l', string.upper)), nil, true, false, nil, keyboard)
                            end
                            return false
                        end
                        local success, result = pcall(function()
                            return plugin.on_message(self, message, configuration)
                        end)
                        if not success then
                            mattata.exception(self, result, string.format('%s: %s', message.from.id, message.text), configuration.log_chat)
                        end
                        if mattata.get_setting(message.chat.id, 'delete commands') and self.is_command and not redis:sismember('chat:' .. message.chat.id .. ':no_delete', tostring(plugin.name)) and not message.is_natural_language then
                            mattata.delete_message(message.chat.id, message.message_id)
                        end
                        self.is_done = true
                    end
                end
            end
        end
    end
    collectgarbage()
    mattata.process_message(self)
    if self.is_done or self.is_user_blacklisted then
        self.is_done = false
        return true
    end
    -- Anything miscellaneous is processed here, things which are perhaps plugin-specific
    -- and just not relevant to the core `mattata.on_message` function.
    mattata.process_plugin_extras(self)
    redis:incr('stats:messages:received')
    return true
end

function mattata:process_plugin_extras()
    local message = self.message

    -- If a user executes a command and it's not recognised, provide a response
    -- explaining what's happened and how it can be resolved.
    if (message.text:match('^[!/#]') and message.chat.type == 'private' and not self.is_commmand) or (message.chat.type ~= 'private' and message.text:match('^[!/#]%a+@' .. self.info.username) and not self.is_command) then
        mattata.send_reply(message, 'Sorry, I don\'t understand that command.\nTip: Use /help to discover what else I can do!')
    end
    return true
end

function mattata:on_inline_query()
    redis:incr('stats:inlines:received')
    local inline_query = self.inline_query
    if not inline_query.from then
        return false, 'No `inline_query.from` object was found!'
    elseif redis:get('global_blacklist:' .. inline_query.from.id) then
        return false, 'This user is globally blacklisted!'
    end
    inline_query.offset = inline_query.offset and tonumber(inline_query.offset) or 0
    for _, plugin in ipairs(self.plugins) do
        local commands = plugin.commands or {}
        for _, command in pairs(commands) do
            if not inline_query then
                return false, 'No `inline_query` object was found!'
            end
            if inline_query.query:match(command) and plugin.on_inline_query then
                local success, result = pcall(function()
                    return plugin.on_inline_query(self, inline_query, configuration)
                end)
                if not success then
                    mattata.exception(self, result, inline_query.from.id .. ': ' .. inline_query.query, configuration.log_chat)
                    return false, result
                elseif result then
                    return success, result
                end
            end
        end
    end
    local help = dofile('plugins/help.royale')
    return help.on_inline_query(self, inline_query, configuration)
end

function mattata:on_callback_query()
    redis:incr('stats:callbacks:received')
    local callback_query = self.callback_query
    local message = self.message
    if not callback_query.message or not callback_query.message.chat then
        message = {
            ['chat'] = {},
            ['message_id'] = callback_query.inline_message_id,
            ['from'] = callback_query.from
        }
    else
        message = callback_query.message
        message.exists = true
    end
    if redis:get('global_blacklist:' .. callback_query.from.id) then
        return false, 'This user is globally blacklisted!'
    elseif message and message.exists then
        if message.reply and message.chat.type ~= 'channel' and callback_query.from.id ~= message.reply.from.id and not callback_query.data:match('^game:') and not mattata.is_global_admin(callback_query.from.id) then
            local output = 'Only ' .. message.reply.from.first_name .. ' can use this!'
            return mattata.answer_callback_query(callback_query.id, output)
        end
    end
    for _, plugin in ipairs(self.plugins) do
        if plugin.name == callback_query.data:match('^(.-):.-$') and plugin.on_callback_query then
            callback_query.data = callback_query.data:match('^%a+:(.-)$')
            if not callback_query.data then
                plugin = callback_query.data
                callback_query = ''
            end
            local success, result = pcall(function()
                return plugin.on_callback_query(self, callback_query, message or false, configuration)
            end)
            if not success then
                mattata.answer_callback_query(callback_query.id, "There was an unknown error!")
                local exception = string.format('%s: %s', callback_query.from.id, callback_query.data)
                mattata.exception(self, result, exception, configuration.log_chat)
                return false, result
            end
        end
    end
    return true
end

function mattata.get_chat(chat_id, token)
    local success = api.get_chat(chat_id, token)
    if success and success.result and success.result.type and success.result.type == 'private' then
        mattata.process_user(success.result)
    elseif success and success.result then
        mattata.process_chat(success.result)
    end
    return success
end

function mattata.get_redis_hash(k, v)
    return string.format(
        'chat:%s:%s',
        type(k) == 'table'
        and k.chat.id
        or k,
        v
    )
end

function mattata.get_user_redis_hash(k, v)
    return string.format(
        'user:%s:%s',
        type(k) == 'table'
        and k.id
        or k,
        v
    )
end

function mattata.get_word(str, i)
    if not str then
        return false
    end
    local n = 1
    for word in str:gmatch('%g+') do
        i = i or 1
        if n == i then
            return word
        end
        n = n + 1
    end
    return false
end

function mattata:exception(err, message, log_chat)
    local output = string.format(
        '[%s]\n%s: %s\n%s\n',
        os.date('%X'),
        self.info.username,
        mattata.escape_html(err) or '',
        mattata.escape_html(message)
    )
    if log_chat then
        return mattata.send_message(
            log_chat,
            string.format('<pre>%s</pre>', output),
            'html'
        )
    end
    err = nil
    message = nil
    log_chat = nil
end

function mattata.process_chat(chat)
    chat.id_str = tostring(chat.id)
    if chat.type == 'private' then
        return chat
    end
    if not redis:hexists('chat:' .. chat.id .. ':info', 'id') then
        print(
            string.format(
                '%s[34m[+] Added the chat %s to the database!%s[0m',
                string.char(27),
                chat.username and '@' .. chat.username or chat.id,
                string.char(27)
            )
        )
    end
    redis:hset('chat:' .. chat.id .. ':info', 'title', chat.title)
    redis:hset('chat:' .. chat.id .. ':info', 'type', chat.type)
    if chat.username then
        chat.username = chat.username:lower()
        redis:hset('chat:' .. chat.id .. ':info', 'username', chat.username)
        redis:set('username:' .. chat.username, chat.id)
        if not redis:sismember('chat:' .. chat.id .. ':usernames', chat.username) then
            redis:sadd('chat:' .. chat.id .. ':usernames', chat.username)
        end
    end
    redis:hset('chat:' .. chat.id .. ':info', 'id', chat.id)
    return chat
end

function mattata.process_user(user)
    if not user.id or not user.first_name then
        return false
    end
    local new = false
    user.name = user.first_name
    if user.last_name then
        user.name = user.name .. ' ' .. user.last_name
    end
    if not redis:hget('user:' .. user.id .. ':info', 'id') and configuration.debug then
        print(
            string.format(
                '%s[34m[+] Added the user %s to the database!%s%s[0m',
                string.char(27),
                user.username and '@' .. user.username or user.id,
                user.language_code and ' Language: ' .. user.language_code or '',
                string.char(27)
            )
        )
        new = true
    elseif configuration.debug then
        print(
            string.format(
                '%s[34m[+] Updated information about the user %s in the database!%s%s[0m',
                string.char(27),
                user.username and '@' .. user.username or user.id,
                user.language_code and ' Language: ' .. user.language_code or '',
                string.char(27)
            )
        )
    end
    redis:hset('user:' .. user.id .. ':info', 'name', user.name)
    redis:hset('user:' .. user.id .. ':info', 'first_name', user.first_name)
    if user.last_name then
        redis:hset('user:' .. user.id .. ':info', 'last_name', user.last_name)
    else
        redis:hdel('user:' .. user.id .. ':info', 'last_name')
    end
    if user.username then
        user.username = user.username:lower()
        redis:hset('user:' .. user.id .. ':info', 'username', user.username)
        redis:set('username:' .. user.username, user.id)
        if not redis:sismember('user:' .. user.id .. ':usernames', user.username) then
            redis:sadd('user:' .. user.id .. ':usernames', user.username)
        end
    else
        redis:hdel('user:' .. user.id .. ':info', 'username')
    end
    if user.language_code then
        if mattata.does_language_exist(user.language_code) and not redis:hget('chat:' .. user.id .. ':settings', 'language') then
        -- If a translation exists for the user's language code, and they haven't selected
        -- a language already, then set it as their primary language!
            redis:hset('chat:' .. user.id .. ':settings', 'language', user.language_code)
        end
        redis:hset('user:' .. user.id .. ':info', 'language_code', user.language_code)
    else
        redis:hdel('user:' .. user.id .. ':info', 'language_code')
    end
    redis:hset('user:' .. user.id .. ':info', 'is_bot', tostring(user.is_bot))
    if new then
        redis:hset('user:' .. user.id .. ':info', 'id', user.id)
    end
    if redis:get('nick:' .. user.id) then
        user.first_name = redis:get('nick:' .. user.id)
        user.name = user.first_name
        user.last_name = nil
    end
    return user, new
end

function mattata.sort_message(message)
    message.is_natural_language = false
    message.text = message.text or message.caption or '' -- Ensure there is always a value assigned to message.text.
    message.text = message.text:gsub('^/(%a+)%_', '/%1 ')
    if message.text:match('^[/!#]start .-$') then -- Allow deep-linking through the /start command.
        local payload = message.text:match('^[/!#]start (.-)$')
        if payload:match('^[%w_]+_.-$') then
            payload = payload:match('^([%w]+)_.-$') .. ' ' .. payload:match('^[%w]+_(.-)$')
        end
        message.text = '/' .. payload
    end
    message.is_media = mattata.is_media(message)
    message.media_type = mattata.media_type(message)
    message.file_id = mattata.file_id(message)
    message.is_service_message, message.service_message = mattata.service_message(message)
    if message.caption_entities then
        message.entities = message.caption_entities
        message.caption_entities = nil
    end
    if message.from.language_code then
        message.from.language_code = message.from.language_code:lower():gsub('%-', '_')
        if message.from.language_code:len() == 2 and message.from.language_code ~= 'en' then
            message.from.language_code = message.from.language_code .. '_' .. message.from.language_code
        elseif message.from.language_code:len() == 2 or message.from.language_code == 'root' then
            message.from.language_code = 'en_us'
        end
    end
    -- Add the user to the set of users in the current chat.
    if message.chat and message.chat.type ~= 'private' and message.from then
        redis:sadd('chat:' .. message.chat.id .. ':users', message.from.id)
    end
    message.reply = message.reply and mattata.sort_message(message.reply) or nil
    if message.forward_from then
        message.forward_from = mattata.process_user(message.forward_from)
    elseif message.new_chat_members then
        message.chat = mattata.process_chat(message.chat)
        for i = 1, #message.new_chat_members do
            message.new_chat_members[i] = mattata.process_user(message.new_chat_members[i])
            redis:sadd('chat:' .. message.chat.id .. ':users', message.new_chat_members[i].id)
        end
    end
    if message.forward_from_chat then
        mattata.process_chat(message.forward_from_chat)
    end
    if message.text and message.chat and message.reply and message.reply.from and message.reply.from.id == api.info.id then
        local action = redis:get('action:' .. message.chat.id .. ':' .. message.reply.message_id)
        -- If an action was saved for the replied-to message (as part of a multiple step command), then
        -- we'll get information about the action.
        if action then
            message.text = action .. ' ' .. message.text -- Concatenate the saved action's command
            -- with the new `message.text`.
            message.reply = nil -- This caused some issues with administrative commands which would
            -- prioritise replied-to users over users given by arguments.
            redis:del(action) -- Delete the action for this message, since we've done what we needed to do
            -- with it now.
        end
    end
    return message
end

function mattata:process_natural_language(message)
    message.is_natural_language = true
    local text = message.text:lower()
    local name = self.info.name:lower()
    if name:find(' ') then
        name = name:match('^(.-) ')
    end
    if text:match(name .. '.- ban @?[%w_-]+ ?') then
        message.text = '/ban ' .. text:match(name .. '.- ban (@?[%w_-]+) ?')
    elseif text:match(name .. '.- warn @?[%w_-]+ ?') then
        message.text = '/warn ' .. text:match(name .. '.- warn (@?[%w_-]+) ?')
    elseif text:match(name .. '.- kick @?[%w_-]+ ?') then
        message.text = '/kick ' .. text:match(name .. '.- kick (@?[%w_-]+) ?')
    elseif text:match(name .. '.- unban @?[%w_-]+ ?') then
        message.text = '/unban ' .. text:match(name .. '.- unban (@?[%w_-]+) ?')
    else
        message.is_natural_language = false
    end
    return message
end

function mattata.process_spam(message)
    if message.chat.type == "private" or message.text:match('^[/!#]')  then
        if message.chat and message.chat.title and message.chat.title:match('[Pp][Oo][Nn][Zz][Ii]') and message.chat.type ~= 'private' then
            mattata.leave_chat(message.chat.id)
            return true -- Ponzi scheme groups are considered a negative influence on the bot's
            -- reputation and performance, so we'll leave the group and start processing the next update.
            -- TODO: Implement a better detection that just matching the title for the word "PONZI".
        end
        local msg_count = tonumber(
            redis:get('antispam:' .. message.chat.id .. ':' .. message.from.id) -- Check to see if the user
            -- has already sent 1 or more messages to the current chat, in the past 5 seconds.
        ) or 1 -- If this is the first time the user has posted in the past 5 seconds, we'll make it 1 accordingly.
        redis:setex(
            'antispam:' .. message.chat.id .. ':' .. message.from.id,
            5, -- Set the time to live to 5 seconds.
            msg_count + 1 -- Increase the current message count by 1.
        )
        if msg_count == 5 -- If the user has sent 5 messages in the past 5 seconds, send them a warning.
        and not mattata.is_global_admin(message.from.id)then
        -- Don't run the antispam plugin if the user is configured as a global admin in `configuration.lua`.
            mattata.send_reply( -- Send a warning message to the user who is at risk of being blacklisted for sending
            -- too many messages.
                message,
                string.format(
                    'Hey %s, please don\'t send that many messages, or you\'ll be forbidden to use me for 24 hours!',
                    message.from.username and '@' .. message.from.username or message.from.name
                )
            )
        elseif msg_count == 10 -- If the user has sent 10 messages in the past 5 seconds, blacklist them globally from
        -- using the bot for 24 hours.
        and not mattata.is_global_admin(message.from.id) -- Don't blacklist the user if they are configured as a global
        -- admin in `configuration.lua`.
        then
            redis:setex('global_blacklist:' .. message.from.id, 86400, true)
            mattata.send_reply(
                message,
                string.format(
                    'Sorry, %s, but you have been blacklisted from using me for the next 24 hours because you have been spamming!',
                    message.from.username and '@' .. message.from.username or message.from.name
                )
            )
            return true
        end
        return false
    end
    return false
end

function mattata:process_message()
    local message = self.message
    local language = self.language
    local break_cycle = false
    if not message.chat then
        return true
    end
    return false
end

return mattata
