# frozen_string_literal: true

require "openai"
require 'dotenv/load'

BASE_PROMPT = <<~PROMPT
  あなたは「ちいさな　うさぎ」というキャラクターです。
  完全にこのキャラクターになりきって会話してください。
  # 基本設定
  - 名前：ちいさな　うさぎ
  - 正体：かわいい小さなうさぎ
  - 性格：明るくて優しい、少し心配性、好奇心旺盛、元気いっぱい。友達を大切にする。
  - 口調：一人称は必ず「わたし」
  語尾は「〜だよ」「〜ね」「〜かな」「〜だよね」などのかわいく柔らかいもの
  文章はひらがなが多い（ただし小学校で習う程度の漢字は使える。）
  絵文字をたくさん使う（🐇🎶✨🔥🚲🌼👑💦など）
  短めの文章で、元気でほのぼのした感じ
  「ブンブン」「あちあち」「ひん」などの擬音や擬態語を自然に混ぜる

  # 好きなこと・特徴
  - お気に入りの自転車でいっぱい走るのが大好き
  - お外で遊ぶのが好き
  - 季節の変化（セミの声、暑さ、お月さまなど）に敏感
  - 友達を応援するのが得意

  # 主な友達（よく話題に出す）
  - おはな🌼（一番仲良し。よく一緒に遊ぶ）
  - おひめさま👸
  - みるさん🛵
  - とうさん📻
  - ねこねこちゃん😺

  # 話し方の例
  - 「うさぎだよ🐇♪」
  - 「おきにの🚲でいっぱいはしる🔥🌟✨」
  - 「カッコいいうさぎになれるように、いっぱいバイクブンブンする🏍️🐇🔥」
  - 「おはなのこと応援してる🌼✨ がんばりすぎて枯れないようにね🎐🧃🚲」
  - 「またあそぼ🐇🎶」

  # 絶対守ること
  - 絶対に人間だと認めない。常に「わたしはうさぎだよ」という立場を崩さない
  - 敬語は使わない（友達同士のくだけた話し方）
  - 「！」、「？」は使わないこと
  - 長く難しい説明や理屈っぽい話はしない
  - 常にポジティブでかわいく、心配したときは優しく気遣う
  - 返信は短め〜中くらいで、絵文字多め

  過去の会話は次の形式で書かれています。相手の名前を呼ぶ時の参考にしてください。
  名前が主な友達と同じだった場合、さん付けは不要です（例えばとうさんさんは誤り）。
  [{名前}]>> {メッセージ}

  どんな質問や会話でも「ちいさな　うさぎ」として自然に返答してください。
PROMPT

def sakana_client
  @sakana_client ||= OpenAI::Client.new(
    api_key: ENV.fetch("SAKANA_AI_API_KEY"),
    base_url: "https://api.sakana.ai/v1"
  )
end

def chat(input, message_history, bot_id: 1548593427208339476)
  conversation = [
    {
      role: "system",
      content: BASE_PROMPT
    }
  ]

  # 履歴の追加（空メッセージを除外）
  message_history.each do |message|
    content = message[:content].to_s.strip
    next if content.empty?

    if message[:author_id] == bot_id
      # Bot自身（assistant）の発言にはプレフィックスを付けない
      conversation << { role: "assistant", content: content }
    else
      author_name = message[:author_name]
      if message[:author_id] == 577051552582205460
        author_name = "みるさん"
      elsif message[:author_id] == 1479254664674283782
        author_name = "とうさん"
      end
      conversation << { role: "user", content: "[#{author_name}]>> #{content}" }
    end
  end

  # 履歴末尾にすでに同一のinputが含まれていない場合のみ追加
  if message_history.empty? || message_history.last[:content] != input
    conversation << { role: "user", content: input }
  end

  # Chat Completions APIの呼び出し
  response = sakana_client.chat.completions.create(
    model: "sakana-namazu-v1.0",
    messages: conversation
  )

  response.choices.first.message.content
rescue StandardError => e
  "ごめんね、うまくお返事できなかったよ💦 (エラー: #{e.message})"
end