require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe GTFS::ServicePeriod do
  let(:valid_local_source) do
    File.expand_path(File.dirname(__FILE__) + '/../fixtures/valid_gtfs.zip')
  end

  describe 'test' do
    let(:data_source) {valid_local_source}
    let(:opts) {{}}

    it 'has a service_period' do
      source = GTFS::ZipSource.new(data_source, opts)
      source.load_service_periods
      sp = source.service_period('1')
    end
  end

  context '.to_date' do
    it 'handles date' do
      date = GTFS::ServicePeriod.to_date(Date.parse('2016-01-01'))
      date.should eq Date.parse('2016-01-01')
    end

    it 'handles strings' do
      date = GTFS::ServicePeriod.to_date('2016-01-01')
      date.should eq Date.parse('2016-01-01')
    end

    it 'handles invalid dates' do
      date = GTFS::ServicePeriod.to_date('0')
      date.should eq nil
    end
  end

  context '#add_date' do
    it 'adds valid date' do
      date = Date.parse('2016-01-01')
      sp = GTFS::ServicePeriod.new
      sp.add_date(date)
      sp.added_dates.size.should eq 1
      sp.added_dates.should include date
    end

    it 'ignores invalid date' do
      sp = GTFS::ServicePeriod.new
      sp.add_date(nil)
      sp.added_dates.size.should eq 0
    end
  end

  context '#except_date' do
    it 'adds valid date' do
      date = Date.parse('2016-01-01')
      sp = GTFS::ServicePeriod.new
      sp.except_date(date)
      sp.except_dates.size.should eq 1
      sp.except_dates.should include date
    end

    it 'ignores invalid date' do
      sp = GTFS::ServicePeriod.new
      sp.except_date(nil)
      sp.except_dates.size.should eq 0
    end
  end

  context '#service_on_date?' do
    let(:sunday) { Date.parse('2016-05-29')}
    let(:other_sunday) { Date.parse('2016-06-05') }
    let(:monday) { Date.parse('2016-05-30') }
    let(:tuesday) { Date.parse('2016-05-31') }
    let(:service_period) {
      GTFS::ServicePeriod.new(
        start_date: Date.parse('2016-01-01'),
        end_date: Date.parse('2017-01-01'),
        added_dates: [sunday],
        except_dates: [tuesday],
        sunday: false,
        monday: true,
        tuesday: true
      )
    }

    it 'true if day of week' do
      service_period.service_on_date?(monday).should be true
    end

    it 'true if added_dates' do
      service_period.service_on_date?(sunday).should be true
    end

    it 'false if not day of week' do
      service_period.service_on_date?(other_sunday).should be false
    end

    it 'false if except_dates' do
      service_period.service_on_date?(tuesday).should be false
    end
  end
end
