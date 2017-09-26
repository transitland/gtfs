module GTFS
  class URLSource < ZipSource
    def load_archive(source)
      source_url, _, fragment = source.partition('#')
      tmpdir = create_tmpdir
      source_file = File.join(tmpdir, "gtfs_temp_#{Time.now.strftime('%Y%jT%H%M%S%z')}.zip")
      GTFS::Fetch.download(source_url, source_file, ssl_verify: options[:ssl_verify], progress: options[:progress_download])
      @source_filenames = self.class.extract_nested(source_file, fragment, tmpdir, options)
      # Return unzipped path and source zip file
      return tmpdir, source_file
    rescue SocketError => e
      raise InvalidURLException.new(e.message)
    rescue OpenURI::HTTPError => e
      response_code = nil
      begin
        response_code = e.io.status.first
      rescue
      end
      raise InvalidResponseException.new(e.message, response_code=response_code)
    rescue Net::FTPError => e
      raise InvalidResponseException.new(e.message)
    rescue Zip::Error => e
      raise InvalidZipException.new(e.message)
    rescue StandardError => e
      raise InvalidSourceException.new(e.message)
    end

    def self.exists?(source)
      ["http", "https", "ftp"].include?(URI.parse(source).scheme)
    end
  end
end
