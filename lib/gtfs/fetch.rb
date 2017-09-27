require 'net/http'
require 'uri'

module GTFS
  module Fetch
    def self.download(url, filename, maxsize: nil, ssl_verify: true, progress: nil)
      request(
        url,
        ssl_verify: ssl_verify,
        max_size: maxsize,
        progress_proc: progress
      ) { |io|
        FileUtils.copy_stream(io, filename)
      }
      filename
    end

    private

    def self.request(url, limit: 10, timeout: 60, max_size: nil, ssl_verify: true, progress_proc: nil, &block)
      total = nil
      ssl_verify_mode = nil
      if ssl_verify == false
        ssl_verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      progress_proc ||= lambda { |count, total| }
      uri = URI.parse(url)
      io = nil
      begin
        io = uri.open(
          ssl_verify_mode: ssl_verify_mode,
          redirect: false,
          read_timeout: timeout,
          content_length_proc: ->(size) {
            raise IOError.new('Exceeds maximum file size') if (size && max_size && size > max_size)
            total = size
          },
          progress_proc: ->(size) {
            raise IOError.new('Exceeds maximum file size') if (size && max_size && size > max_size)
            progress_proc.call(size, total)
          }
        )
      rescue OpenURI::HTTPRedirect => redirect
        uri = redirect.uri # from Location
        retry if (limit -= 1) > 0
        raise ArgumentError.new('Too many redirects')
      end
      yield io
    end
  end
end
