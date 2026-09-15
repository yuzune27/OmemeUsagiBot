# frozen_string_literal: true

require 'json'
require 'thread'

class ResetState
  def initialize(path)
    @path = path
    @boundaries = File.exist?(path) ? JSON.parse(File.read(path)) : {}
    @mutex = Mutex.new
  end

  def snapshot(channel_id)
    @mutex.synchronize { @boundaries.fetch(channel_id.to_s, '0').to_i }
  end

  def reset(channel_id)
    @mutex.synchronize do
      boundary = yield
      updated = @boundaries.merge(channel_id.to_s => boundary.to_s)
      temporary_path = "#{@path}.tmp"
      begin
        File.write(temporary_path, JSON.generate(updated))
        File.rename(temporary_path, @path)
      ensure
        File.delete(temporary_path) if File.exist?(temporary_path)
      end
      @boundaries = updated
    end
  end

  # Keep the check and send together so reset cannot finish between them.
  def if_current(channel_id, boundary)
    @mutex.synchronize do
      yield if @boundaries.fetch(channel_id.to_s, '0').to_i == boundary
    end
  end
end
