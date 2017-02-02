require 'net/http'
require 'uri'

module GTFS
  module Fetch
    def self.download(url, filename, maxsize: nil, progress: nil)
      request(
        url,
        max_size: maxsize,
        progress_proc: progress
      ) { |io|
        FileUtils.copy_stream(io, filename)
      }
      filename
    end

    private

    def self.request(url, limit: 10, timeout: 60, max_size: nil, progress_proc: nil, &block)
      total = nil
      progress_proc ||= lambda { |count, total| }
      uri = URI.parse(url)
      io = nil
      begin
        io = uri.open(
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
