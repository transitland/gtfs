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

    attr_accessor :source, :archive, :path, :options

    def initialize(source, opts={})
      raise 'Source cannot be nil' if source.nil?
      # Cache
      @cache = {}
      # Trip counter
      @trip_counter = Hash.new { |h,k| h[k] = 0 }
      # Merged calendars
      @service_periods = {}
      # Shape lines
      @shape_lines = {}
      # Load options
      @options = DEFAULT_OPTIONS.merge(opts)
      # Load
      @source = source
      @path, @archive = load_archive(@source)
      raise GTFS::InvalidSourceException unless valid?
    end

    def self.required_files_present?(files)
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

    def file_present?(filename)
      File.exists?(file_path(filename))
    end

    def valid?
      return false unless File.exists?(@path)
      self.class.required_files_present?(Dir.entries(@path))
    end

    def row_count(filename)
      raise ArgumentError.new('File does not exist') unless file_present?(filename)
      IO.popen(["wc","-l",file_path(filename)]) { |io| io.read.strip.split(" ").first.to_i - 1 }
    end

    def inspect
      "#<%s:0x%x @source=%s>" % [self.class, object_id, @source]
    end

    ##### Relationships #####

    def parents(entity)
      entity.parents
    end

    def children(entity)
      entity.children
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
      progress_block ||= options[:progress_graph]
      progress_block ||= Proc.new { |count, total, entity| }
      # Clear
      @cache.clear
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
        (self.agency(e.agency_id) || default_agency).pclink(e)
        count += 1
        progress_block.call(count, total, e)
      end
      # Load Trips; link to routes
      self.trips.each do |e|
        self.route(e.route_id).pclink(e)
        count += 1
        progress_block.call(count, total, e)
      end
      # Load Stops
      self.stops.each do |e|
        count += 1
        progress_block.call(count, total, e)
      end
      # Count StopTimes by Trip; link Stops to Trips
      trip_stop_sequence = {}
      self.each_stop_time do |stop_time|
        trip = self.trip(stop_time.trip_id)
        stop = self.stop(stop_time.stop_id)
        trip_stop_sequence[trip] ||= []
        trip_stop_sequence[trip] << [stop_time.stop_sequence.to_i, stop, stop_time.shape_dist_traveled]
        @trip_counter[trip] += 1
        count += 1
        progress_block.call(count, total, nil)
      end
      trip_stop_sequence.each do |trip, seq|
        seq = seq.sort
        trip.stop_sequence = seq.map { |i| i[1] }
        trip.shape_dist_traveled = seq.map { |i| i[2] }
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
        @shape_lines[k] = ShapeLine.from_shapes(v)
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

    def trip_stop_times(trips=nil, filter_empty=false)
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
        next if (filter_empty && stop_times.size < 2)
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

    def create_archive(filename)
      # Create a new GTFS archive.
      raise 'File exists' if File.exists?(filename)
      Zip::File.open(filename, Zip::File::CREATE) do |zipfile|
        self.class::ENTITIES.each do |cls|
          next unless file_present?(cls.filename)
          zipfile.add(cls.filename, file_path(cls.filename))
        end
      end
    end

    def self.build(source, opts={})
      raise 'source required' unless source
      source = source.to_s
      if Source.exists?(source)
        Source.new(source, opts)
      elsif ZipSource.exists?(source)
        ZipSource.new(source, opts)
      elsif URLSource.exists?(source)
        URLSource.new(source, opts)
      else
        raise 'No handler for source'
      end
    end

    def self.exists?(source)
      File.directory?(source)
    end

    private

    def create_tmpdir
      if !@tmpdir
        @tmpdir = Dir.mktmpdir("gtfs", options[:tmpdir_basepath])
        ObjectSpace.define_finalizer(self, self.class.finalize_tmpdir(@tmpdir))
      end
      @tmpdir
    end

    def self.finalize_tmpdir(directory)
      proc {FileUtils.rm_rf(directory)}
    end

    def load_archive(source)
      # Return directory with GTFS CSV files
      source
    end

    def file_path(filename)
      File.join(@path, filename)
    end

    def parse_file(filename)
      raise_if_missing_source filename
      open file_path(filename), 'r:bom|utf-8' do |f|
        files[filename] ||= yield f
      end
    end
  end
end
