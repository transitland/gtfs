require 'net/http'
require 'uri'

module GTFS
  class URLSource < ZipSource
    def load_archive(source)
      source, _, fragment = source.partition('#')
      tmp_dir = Dir.mktmpdir
      source_file = File.join(tmp_dir, "/gtfs_temp_#{Time.now.strftime('%Y%jT%H%M%S%z')}.zip")
      Fetch.download(source, source_file)
      self.class.extract_nested(source_file, fragment, tmp_dir: tmp_dir)
      ObjectSpace.define_finalizer(self, self.class.finalize(tmp_dir))
      tmp_dir
    rescue Exception => e
      raise InvalidSourceException.new(e.message)
    end

    def self.exists?(source)
      source.start_with?('http')
    end
  end
end
