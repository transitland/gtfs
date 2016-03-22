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

    def self.extract_nested(filename, path)

    end

    def self.find_nested_gtfs(filename)
      dirs = find_nested_archives(filename)
        .select { |dir, files| required_files_present?(files) }
        .keys
    end

    def self.find_nested_archives(filename, basepath=nil, limit=1000, count=0)
      basepath ||= "/"
      dirs = {}
      Zip::File.open(filename) do |zip|
        zip.entries.each do |entry|
          raise Exception.new("Too many files") if count > limit
          count += 1
          entry_dir, entry_name = File.split(entry.name)
          entry_dir = "" if entry_dir == "."
          entry_dir = File.join(basepath, entry_dir)
          entry_ext = File.extname(entry_name)
          dirs[entry_dir] ||= Set.new
          if entry_ext == '.zip'
            tmpfile = Tempfile.open(entry_name)
            Tempfile.open(entry_name) do |tmpfile|
              tmpfile.binmode
              tmpfile.write(entry.get_input_stream.read)
              tmpfile.close
              result = find_nested_archives(
                tmpfile.path,
                basepath=File.join(entry_dir, entry_name),
                limit=limit,
                count=count
              )
              dirs = dirs.merge(result)
              tmpfile.unlink
            end
          else
            dirs[entry_dir] << entry_name
          end
        end
      end
      dirs
    end
  end
end
