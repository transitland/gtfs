module GTFS

  class ServicePeriod

    ISO_DAYS_OF_WEEK = [
      :monday,
      :tuesday,
      :wednesday,
      :thursday,
      :friday,
      :saturday,
      :sunday
    ]

    attr_accessor :service_id,
                  :start_date,
                  :end_date,
                  :added_dates,
                  :except_dates,
                  :monday,
                  :tuesday,
                  :wednesday,
                  :thursday,
                  :friday,
                  :saturday,
                  :sunday

    def self.to_date(date)
      begin
        date.is_a?(Date) ? date : Date.parse(date)
      rescue StandardError => e
        nil
      end
    end

    def self.from_calendar(calendar)
      attrs = {
          service_id: calendar.service_id,
          start_date: to_date(calendar.start_date),
          end_date: to_date(calendar.end_date),
      }
      ISO_DAYS_OF_WEEK.each { |i| attrs[i] = (calendar.send(i).to_i > 0) }
      self.new(attrs)
    end

    def initialize(attrs=nil)
      @added_dates = Set.new
      @except_dates = Set.new
      attrs ||= {}
      attrs.each do |key, val|
        instance_variable_set("@#{key}", val)
      end
    end

    def id
      self.service_id
    end

    def service_on_date?(date)
      date.between?(start_date, end_date) && (iso_service_weekdays[date.cwday-1] == true || added_dates.include?(date)) && (!except_dates.include?(date))
    end

    def iso_service_weekdays
      # Export as a true/false boolean, not true/false/nil.
      ISO_DAYS_OF_WEEK.map { |i| self.send(i) == true }
    end

    def add_date(date)
      date = ServicePeriod.to_date(date)
      (self.added_dates << date) if date
    end

    def except_date(date)
      date = ServicePeriod.to_date(date)
      (self.except_dates << date) if date
    end

    def expand_service_range
      range = added_dates + except_dates
      range << start_date if start_date
      range << end_date if end_date
      self.start_date = range.min
      self.end_date = range.max
    end
  end
end
