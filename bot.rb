# frozen_string_literal: true

require 'json'
require 'dotenv/load'
require 'discordrb'
require_relative 'chat'

RESP_CH_PATH = File.join(__dir__, 'respCh.json')

def get_resp_ch
  return {} unless File.exist?(RESP_CH_PATH)
  content = File.read(RESP_CH_PATH)
  content.strip.empty? ? {} : JSON.parse(content)
end

resp_ch = get_resp_ch

bot = Discordrb::Bot.new(
  token: ENV['DISCORD_BOT_TOKEN'],
  intents: [:servers, :server_messages]
)

bot.ready do |event|
  puts "Bot is ready!"
end

bot.register_application_command(
  'set_channel',
  'おはなしする場所を決めるよ🐇',
)

bot.application_command(:set_channel) do |event|
  unless event.server_id
    event.respond(ephemeral: true) do |builder|
      builder.add_embed do |embed|
        embed.description = 'サーバーのチャンネルで実行してね🐇💦'
        embed.color = 0xff9900
      end
    end
    next
  end

  resp_ch[event.server_id.to_s] = event.channel.id.to_s
  File.open(RESP_CH_PATH, "w") do |f|
    f.write(JSON.generate(resp_ch))
  end

  event.respond(ephemeral: false) do |builder|
    builder.add_embed do |embed|
      embed.title = "おはなしする場所ここにするね👋✨"
      embed.description = "これからは <##{event.channel.id}> でおはなしするよ💭🎶"
      embed.color = 0x00ff00
    end
  end
end

bot.message do |event|
  next if event.author.bot_account?
  next unless event.server
  next unless resp_ch[event.server.id.to_s].to_s == event.channel.id.to_s

  event.channel.start_typing

  typing_thread = Thread.new do
    loop do
      sleep 5
      event.channel.start_typing
    end
  end

  message_content = []

  begin
    channel = bot.channel(event.channel.id)
    channel.history(10).reverse_each do |message|
      member = event.server.member(message.author.id)
      message_content << {
        author_id: message.author.id,
        author_name: member&.display_name || message.author.username,
        content: message.content
      }
    end
    ai_respond = chat(event.content, message_content)
  ensure
    typing_thread.kill
    typing_thread.join
  end

  # 2000字に制限する
  ai_respond.scan(/.{1,2000}/m).each do |part|
    event.message.reply! part
  end
end

bot.run
