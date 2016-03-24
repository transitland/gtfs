require 'net/http'
require 'uri'

module GTFS
  class URLSource < LocalSource
    def load_archive(source_path)
      source_path, _, fragment = source_path.partition('#')
      tmp_dir = Dir.mktmpdir
      source_file = File.join(tmp_dir, "/gtfs_temp_#{Time.now.strftime('%Y%jT%H%M%S%z')}.zip")
      uri = URI.parse(source_path)
      response = Net::HTTP.get_response(uri)
      open(source_file, 'wb') do |file|
        file.write response.body
      end
      self.class.extract_nested(source_file, fragment, tmp_dir: tmp_dir)
      ObjectSpace.define_finalizer(self, self.class.finalize(tmp_dir))
      tmp_dir
    rescue Exception => e
      raise InvalidSourceException.new(e.message)
    end
  end
end
