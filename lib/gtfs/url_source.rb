module GTFS
  class URLSource < ZipSource
    def load_archive(source)
      source_url, _, fragment = source.partition('#')
      tmpdir = create_tmpdir
      source_file = File.join(tmpdir, "gtfs_temp_#{Time.now.strftime('%Y%jT%H%M%S%z')}.zip")
      GTFS::Fetch.download(source_url, source_file, progress: options[:progress_download])
      self.class.extract_nested(source_file, fragment, tmpdir)
      # Return unzipped path and source zip file
      return tmpdir, source_file
    rescue SocketError => e
      raise InvalidURLException.new(e.message)
    rescue Net::HTTPServerException => e
      raise InvalidResponseException.new(e.message, response_code=e.response.code)
    rescue Zip::Error => e
      raise InvalidZipException.new(e.message)
    rescue StandardError => e
      raise InvalidSourceException.new(e.message)
    end

    def self.exists?(source)
      ["http", "ftp"].include?(URI.parse(source).scheme)
    end
  end
end
