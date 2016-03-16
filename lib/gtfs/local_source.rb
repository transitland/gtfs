module GTFS
  class LocalSource < Source
    def load_archive(source_path)
      extract_to_cache(source_path)
    rescue Exception => e
      raise InvalidSourceException.new(e.message)
    end

    def extract_to_cache(source_path)
      # Temporary directory
      @tmp_dir = Dir.mktmpdir
      @path = @tmp_dir
      ObjectSpace.define_finalizer(self, self.class.finalize(@tmp_dir))
      # Extract
      Zip::File.open(source_path) do |zip|
        zip.entries.each do |entry|
          next unless SOURCE_FILES.key?(entry.name)
          entry.extract(file_path(entry.name))
        end
      end
      @path
    end

    def self.finalize(directory)
      proc {FileUtils.rm_rf(directory)}
    end
  end
end
