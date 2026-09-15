# frozen_string_literal: true

require 'json'
require 'dotenv/load'
require 'discordrb'
require_relative 'chat'
require_relative 'reset_state'

RESP_CH_PATH = File.join(__dir__, 'respCh.json')

def get_resp_ch
  return {} unless File.exist?(RESP_CH_PATH)
  content = File.read(RESP_CH_PATH)
  content.strip.empty? ? {} : JSON.parse(content)
end

resp_ch = get_resp_ch
reset_state = ResetState.new(File.join(__dir__, 'reset_state.json'))

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

# /set_channel
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

# /reset
bot.register_application_command('reset', 'これまでのおはなしを忘れるよ👋')

bot.application_command(:reset) do |event|
  unless event.server_id && resp_ch[event.server_id.to_s] == event.channel.id.to_s
    event.respond(ephemeral: true) do |builder|
      builder.add_embed do |embed|
        embed.description = 'サーバーのおはなし用チャンネルで実行してね🐇💦'
        embed.color = 0xff9900
      end
    end
    next
  end

  view = Discordrb::Components::View.new do |builder|
    builder.row do |row|
      row.button(
        style: :primary,
        label: 'うん',
        custom_id: 'reset_confirm'
      )

      row.button(
        style: :secondary,
        label: 'また今度',
        custom_id: 'reset_cancel'
      )
    end
  end

  event.respond(ephemeral: true, components: view) do |builder|
    builder.add_embed do |embed|
      embed.title = "かくにん📝"
      embed.description = "ほんとに忘れていい？👀"
      embed.color = 0xff9900
    end
  end
end

# リセット確認Yesイベント
bot.button(custom_id: 'reset_confirm') do |event|
  event.defer_update
  begin
    reset_state.reset(event.channel.id) do
      event.channel.history(1).first&.id.to_i
    end
  rescue StandardError => e
    warn "Reset failed: #{e.class}: #{e.message}"
    event.edit_response(content: 'ごめんね、おはなしをリセットできなかったよ。もう一度ためしてね🐇💦')
    next
  end

  updated_embed = Discordrb::Webhooks::Embed.new(
    title: 'おはなし忘れたよ🐇❓',
    description: 'これまでのおはなしを忘れて、ここからまたおはなしするね💬✨',
    color: 0x00ff00
  )

  updated_view = Discordrb::Components::View.new do |builder|
    builder.row do |row|
      row.button(
        style: :primary,
        label: 'うん',
        custom_id: 'reset_confirm',
        disabled: true
      )
    end
  end

  event.edit_response(
    embeds: [updated_embed],
    components: updated_view
  )
end

# リセット確認Noイベント
bot.button(custom_id: 'reset_cancel') do |event|
  updated_embed = Discordrb::Webhooks::Embed.new(
    title: 'またこんど、分かった✨',
    description: 'これまでのことは覚えたままおはなしするね💬🎶',
    color: 0x00ff00
  )

  updated_view = Discordrb::Components::View.new do |builder|
    builder.row do |row|
      row.button(
        style: :secondary,
        label: 'また今度',
        custom_id: 'reset_cancel',
        disabled: true
      )
    end
  end

  event.update_message(
    embeds: [updated_embed],
    components: updated_view
  )
end

# 通常メッセージ応答
bot.message do |event|
  next if event.author.bot_account?
  next unless event.server
  next unless resp_ch[event.server.id.to_s].to_s == event.channel.id.to_s
  reset_boundary = reset_state.snapshot(event.channel.id)
  next if event.message.id.to_i <= reset_boundary

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
    channel.history(20).reverse_each do |message|
      next if message.id.to_i <= reset_boundary
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
  reset_state.if_current(event.channel.id, reset_boundary) do
    ai_respond.scan(/.{1,2000}/m).each do |part|
      event.message.reply! part
    end
  end
end

bot.run
