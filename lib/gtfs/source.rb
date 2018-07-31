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

    DEFAULT_OPTIONS = {
      strict: true,
      auto_detect_root: false,
      use_symbols: false
    }

    attr_accessor :source, :archive, :path, :options

    def initialize(source, opts={})
      raise 'Source cannot be nil' if source.nil?
      # Cache
      @cache = {}
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

    def source_filenames
      Dir.entries(@path).select{ |f| File.file?(File.join(@path, f)) }
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
      self.load_shape_lines if @shape_lines.empty?
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
      fail Exception.new('agency.txt: no default agency') if default_agency.nil?

      # Load Routes; link to agencies
      self.routes.each do |e|
        # if route.agency_id is present but no agency exists, should raise a warning.
        (self.agency(e.agency_id) || default_agency).pclink(e)
        count += 1
        progress_block.call(count, total, e)
      end

      # Load Trips; link to routes
      self.trips.each do |e|
        route = self.route(e.route_id)
        if route.nil?
          puts "trips.txt: route not found: #{e.route_id}"
          next
        end
        route.pclink(e)
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
        if trip.nil?
          puts "stop_times.txt: trip not found: #{stop_time.trip_id}"
          next
        end
        if stop.nil?
          puts "stop_times.txt: stop not found: #{stop_time.stop_id}"
          next
        end
        trip_stop_sequence[trip] ||= []
        trip_stop_sequence[trip] << [stop_time.stop_sequence.to_i, stop_time.shape_dist_traveled, stop]
        count += 1
        progress_block.call(count, total, nil)
      end
      trip_stop_sequence.each do |trip, seq|
        seq = seq.sort
        trip.shape_dist_traveled = seq.map { |i| i[1] }
        trip.stop_sequence = seq.map { |i| i[2] }
      end
    end

    def load_shape_lines
      # Merge shapes
      @shape_lines.clear
      self.each_shape_line do |e|
        @shape_lines[e.shape_id] = e
      end
      @shape_lines
    end
    alias :load_shapes :load_shape_lines

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

    def load_trip_counter
      # Count StopTimes by Trip
      counter = Hash.new { |h,k| h[k] = 0 }
      self.each_stop_time do |stop_time|
        counter[stop_time.trip_id] += 1
      end
      counter
    end

    def load_shape_counter
      counter = Hash.new { |h,k| h[k] = 0 }
      self.each_shape do |e|
        counter[e.shape_id] += 1
      end
      counter
    end

    def shape_id_chunks(batchsize=1_000_000)
      yield_chunks(load_shape_counter, batchsize) { |i| yield i }
    end

    def trip_id_chunks(batchsize=1_000_000)
      yield_chunks(load_trip_counter, batchsize) { |i| yield i }
    end

    def trip_chunks(batchsize=1_000_000)
      counter = {}
      load_trip_counter.each do |k,v|
        counter[self.trip(k)] = v
      end
      yield_chunks(counter, batchsize) { |i| yield i }
    end

    def each_shape_line(shape_ids=nil)
      # Return if missing shapes.txt
      return unless file_present?(GTFS::Shape.filename)
      filter_ids = shape_ids.nil? ? nil : Set.new(shape_ids)
      groups = Hash.new { |h,k| h[k] = [] }
      self.each_shape do |e|
        next if (filter_ids && !filter_ids.include?(e.shape_id))
        groups[e.shape_id] << e
      end
      groups.each do |k,v|
        yield ShapeLine.from_shapes(v)
      end
    end

    def each_trip_stop_times(trip_ids=nil, filter_empty=false)
      filter_ids = trip_ids.nil? ? nil : Set.new(trip_ids)
      groups = Hash.new {|h,k| h[k] = []}
      self.each_stop_time do |e|
        next if (filter_ids && !filter_ids.include?(e.trip_id))
        groups[e.trip_id] << e
      end
      groups.each do |k,v|
        next if (filter_empty && v.size < 2)
        yield k, v.sort_by { |e| e.stop_sequence.to_i }
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

    def yield_chunks(counter, batchsize)
      chunk = []
      current = 0
      order = counter.sort_by { |k,v| -v }
      order.each do |k,v|
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
