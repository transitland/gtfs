require 'tmpdir'
require 'fileutils'
require 'zip'

module GTFS
  class Source

    ENTITIES = [
      GTFS::Agency,
      GTFS::Stop,
      GTFS::Route,
      GTFS::Trip,
      GTFS::StopTime,
      GTFS::Calendar,
      GTFS::CalendarDate,
      GTFS::Shape,
      GTFS::FareAttribute,
      GTFS::FareRule,
      GTFS::Frequency,
      GTFS::Transfer,
      GTFS::FeedInfo
    ]
    SOURCE_FILES = Hash[ENTITIES.map { |e| [e.filename, e] }]
    DEFAULT_OPTIONS = {strict: true}

    attr_accessor :source, :archive, :options

    def initialize(source, opts={})
      raise 'Source cannot be nil' if source.nil?
      # Cache
      @cache = {}
      # Parents/children
      @parents = Hash.new { |h,k| h[k] = Set.new }
      @children = Hash.new { |h,k| h[k] = Set.new }
      # Trip counter
      @trip_counter = Hash.new { |h,k| h[k] = 0 }
      # Merged calendars
      @service_periods = {}
      # Shape lines
      @shape_lines = {}
      # Temporary directory
      @tmp_dir = Dir.mktmpdir
      ObjectSpace.define_finalizer(self, self.class.finalize(@tmp_dir))
      # Load options
      @options = DEFAULT_OPTIONS.merge(opts)
      # Unzip to temporary directory
      @source = source
      load_archive(@source)
    end

    def self.find_nested_gtfs(filename)
      dirs = find_nested_archives(filename)
        .select { |dir, files| required_files_present_two?(files) }
        .keys
    end

    def self.find_nested_archives(filename, basepath=nil, limit=1000, count=0)
      dirs = {}
      Zip::File.open(filename) do |zip|
        zip.entries.each do |entry|
          raise Exception.new("Too many files") if count > limit
          count += 1
          entry_dir, entry_name = File.split(entry.name)
          entry_dir = File.join(basepath, entry_dir) if basepath
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
                basepath=entry.name,
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

    def file_present?(filename)
      File.exists?(file_path(filename))
    end

    def row_count(filename)
      raise ArgumentError.new('File does not exist') unless file_present?(filename)
      IO.popen(["wc","-l",file_path(filename)]) { |io| io.read.strip.split(" ").first.to_i - 1 }
    end

    def self.required_files_present_two?(files)
      # Spec is ambiguous
      required = [
        GTFS::Agency,
        GTFS::Stop,
        GTFS::Route,
        GTFS::Trip,
        GTFS::StopTime
      ].map { |cls| files.include?(cls.filename) }
      # Either/both: calendar.txt, calendar_dates.txt
      calendar = [
        GTFS::Calendar,
        GTFS::CalendarDate
      ].map { |cls| files.include?(cls.filename) }
      # All required files, and either calendar file
      required.all? && calendar.any?
    end

    def required_files_present?
      # Spec is ambiguous
      required = [
        GTFS::Agency,
        GTFS::Stop,
        GTFS::Route,
        GTFS::Trip,
        GTFS::StopTime
      ].map { |cls| file_present?(cls.filename) }
      # Either/both: calendar.txt, calendar_dates.txt
      calendar = [
        GTFS::Calendar,
        GTFS::CalendarDate
      ].map { |cls| file_present?(cls.filename) }
      # All required files, and either calendar file
      required.all? && calendar.any?
    end

    ##### Relationships #####

    def pclink(parent, child)
      @parents[child] << parent
      @children[parent] << child
    end

    def parents(entity)
      @parents[entity]
    end

    def children(entity)
      @children[entity]
    end

    ##### Cache #####

    def cache(filename, &block)
      # Read entities, cache by ID.
      cls = SOURCE_FILES[filename]
      if @cache[cls]
        @cache[cls].values.each(&block)
      else
        @cache[cls] = {}
        cls.each(file_path(filename), options, self) do |model|
          @cache[cls][model.id || model] = model
          block.call model
        end
      end
    end

    ##### Access methods #####

    # Define model access methods, e.g. feed.each_stop
    ENTITIES.each do |cls|
      # feed.<entities>
      define_method cls.name.to_sym do
        ret = []
        self.cache(cls.filename) { |model| ret << model }
        ret
      end

      # feed.<entity>
      define_method cls.singular_name.to_sym do |key|
        @cache[cls][key]
      end

      # feed.each_<entity>
      define_method "each_#{cls.singular_name}".to_sym do |&block|
        cls.each(file_path(cls.filename), options, self, &block)
      end
    end

    def shape_line(shape_id)
      self.load_shapes if @shape_lines.empty?
      @shape_lines[shape_id]
    end

    def service_period(service_id)
      self.load_service_periods if @service_periods.empty?
      @service_periods[service_id]
    end

    def service_period_range
      self.load_service_periods if @service_periods.empty?
      start_dates = @service_periods.values.map(&:start_date)
      end_dates = @service_periods.values.map(&:end_date)
      [start_dates.min, end_dates.max]
    end

    ##### Load graph, shapes, calendars, etc. #####

    def load_graph(&progress_block)
      # Progress callback
      progress_block ||= Proc.new { |count, total, entity| }
      # Clear
      @cache.clear
      @parents.clear
      @children.clear
      @trip_counter.clear
      # Row count for progress bar...
      count = 0
      total = 0
      [GTFS::Agency, GTFS::Route, GTFS::Trip, GTFS::Stop, GTFS::StopTime].each do |e|
        total += row_count(e.filename)
      end
      # Load Agencies
      default_agency = nil
      self.agencies.each do |e|
        default_agency = e
        count += 1
        progress_block.call(count, total, e)
      end
      # Load Routes; link to agencies
      self.routes.each do |e|
        self.pclink(self.agency(e.agency_id) || default_agency, e)
        count += 1
        progress_block.call(count, total, e)
      end
      # Load Trips; link to routes
      self.trips.each do |e|
        self.pclink(self.route(e.route_id), e)
        count += 1
        progress_block.call(count, total, e)
      end
      # Load Stops
      self.stops.each do |e|
        count += 1
        progress_block.call(count, total, e)
      end
      # Count StopTimes by Trip; link Stops to Trips
      self.each_stop_time do |e|
        trip = self.trip(e.trip_id)
        stop = self.stop(e.stop_id)
        self.pclink(trip, stop)
        @trip_counter[trip] += 1
        count += 1
        progress_block.call(count, total, e)
      end
    end

    def load_shapes
      # Merge shapes
      @shape_lines.clear
      # Return if missing shapes.txt
      return unless file_present?(GTFS::Shape.filename)
      shapes_merge = Hash.new { |h,k| h[k] = [] }
      self.each_shape { |e| shapes_merge[e.shape_id] << e }
      shapes_merge.each do |k,v|
        @shape_lines[k] = v
          .sort_by { |i| i.shape_pt_sequence.to_i }
          .map { |i| [i.shape_pt_lon.to_f, i.shape_pt_lat.to_f] }
      end
      @shape_lines
    end

    def load_service_periods
      @service_periods.clear
      # Load calendar
      if file_present?(GTFS::Calendar.filename)
        self.each_calendar do |e|
          service_period = ServicePeriod.from_calendar(e)
          @service_periods[service_period.id] = service_period
        end
      end
      # Load calendar_date exceptions
      if file_present?(GTFS::CalendarDate.filename)
        self.each_calendar_date do |e|
          service_period = @service_periods[e.service_id] || ServicePeriod.new(service_id: e.service_id)
          if e.exception_type.to_i == 1
            service_period.add_date(e.date)
          else
            service_period.except_date(e.date)
          end
          @service_periods[service_period.id] = service_period
        end
      end
      # Expand service range
      @service_periods.values.each(&:expand_service_range)
      @service_periods
    end

  ##### Incremental processing #####

    def trip_chunks(batchsize=1_000_000)
      # Return chunks of trips containing approx. batchsize stop_times.
      # Reverse sort trips
      trips = @trip_counter.sort_by { |k,v| -v }
      chunk = []
      current = 0
      trips.each do |k,v|
        if (current + v) > batchsize
          yield chunk
          chunk = []
          current = 0
        end
        chunk << k
        current += v
      end
      yield chunk
    end

    def trip_stop_times(trips=nil)
      # Return all the stop time pairs for a set of trips.
      # Trip IDs
      trips ||= self.trips
      trip_ids = Set.new trips.map(&:id)
      # Subgraph mapping trip IDs to stop_times
      trip_ids_stop_times = Hash.new {|h,k| h[k] = []}
      self.each_stop_time do |stop_time|
        next unless trip_ids.include?(stop_time.trip_id)
        trip_ids_stop_times[stop_time.trip_id] << stop_time
      end
      # Process each trip
      trips.each do |trip|
        stop_times = trip_ids_stop_times[trip.trip_id]
        stop_times = stop_times.sort_by { |st| st.stop_sequence.to_i }
        yield trip, stop_times
      end
    end

    def stop_time_pairs(trips=nil)
      self.trip_stop_times(trips) do |trip,stop_times|
        route = self.route(trip.route_id)
        stop_times[0..-2].zip(stop_times[1..-1]).each do |origin,destination|
          yield route, trip, origin, destination
        end
      end
    end

    private

    def self.finalize(directory)
      proc {FileUtils.rm_rf(directory)}
    end

    def self.build(data_root, opts={})
      if File.exists?(data_root)
        src = LocalSource.new(data_root, opts)
      else
        src = URLSource.new(data_root, opts)
      end
    end

    def extract_to_cache(source_path)
      Zip::File.open(source_path) do |zip|
        zip.entries.each do |entry|
          next unless SOURCE_FILES.key?(entry.name)
          zip.extract(entry.name, file_path(entry.name))
        end
      end
    end

    def load_archive(source)
      raise 'Cannot directly instantiate base GTFS::Source'
    end

    def file_path(filename)
      File.join(@tmp_dir, filename)
    end

    def parse_file(filename)
      raise_if_missing_source filename
      open file_path(filename), 'r:bom|utf-8' do |f|
        files[filename] ||= yield f
      end
    end
  end
end
