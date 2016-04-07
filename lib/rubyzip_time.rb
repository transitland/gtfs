# Fix time-related behaviors in rubyzip.
# 1. Read mtime into @time
# 2. Extract writes mtime
# 3. Write mtime *after* file is written

module Zip
  class Entry
    def get_extra_attributes_from_path(path) # :nodoc:
      return if Zip::RUNNING_ON_WINDOWS
      stat        = file_stat(path)
      @unix_uid   = stat.uid
      @unix_gid   = stat.gid
      @unix_perms = stat.mode & 07777
      @time       = Zip::DOSTime.at(stat.mtime)
    end

    def set_unix_times_on_path(dest_path)
      return unless @restore_times
      FileUtils.touch(dest_path, mtime: @time)
    end

    def extract(dest_path = @name, &block)
      block ||= proc { ::Zip.on_exists_proc }
      if directory? || file? || symlink?
        __send__("create_#{@ftype}", dest_path, &block)
      else
        raise "unknown file type #{inspect}"
      end
      set_unix_times_on_path(dest_path)
      self
    end
  end
end
