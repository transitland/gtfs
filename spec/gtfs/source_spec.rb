require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe GTFS::Source do
  let(:valid_local_source) do
    File.expand_path(File.dirname(__FILE__) + '/../fixtures/valid_gtfs.zip')
  end

  let(:source_missing_required_files) do
    File.expand_path(File.dirname(__FILE__) + '/../fixtures/missing_files.zip')
  end

  describe '#build' do
    let(:opts) {{}}
    let(:data_source) {valid_local_source}
    subject {GTFS::Source.build(data_source, opts)}

    context 'with a url as a data root' do
      use_vcr_cassette('valid_gtfs_uri')
      let(:data_source) {'http://dl.dropbox.com/u/416235/work/valid_gtfs.zip'}

      it {should be_instance_of GTFS::URLSource}
      its(:options) {should == GTFS::Source::DEFAULT_OPTIONS}
    end

    context 'with a file path as a data root' do
      let(:data_source) {valid_local_source}

      it {should be_instance_of GTFS::LocalSource}
      its(:options) {should == GTFS::Source::DEFAULT_OPTIONS}
    end

    context 'with a file object as a data root' do
      let(:data_source) {File.open(valid_local_source)}

      it {should be_instance_of GTFS::LocalSource}
      its(:options) {should == GTFS::Source::DEFAULT_OPTIONS}
    end

    context 'with options to disable strict checks' do
      let(:opts) {{strict: false}}

      its(:options) {should == {strict: false}}
    end
  end

  describe '#new(source)' do
    it 'should not allow a base GTFS::Source to be initialized' do
      lambda {GTFS::Source.new(valid_local_source)}.should raise_exception
    end
  end

  describe '#file_present?' do
    let(:source) {GTFS::Source.build(valid_local_source)}
    it 'should return true if file is present' do
      source.file_present?('agency.txt').should be true
    end
    it 'should return false if a file is not present' do
      source.file_present?('missing.txt').should be false
    end
  end

  describe '#required_files_present?' do
    it 'should be true when all required files present' do
      source = GTFS::Source.build(valid_local_source)
      source.required_files_present?.should be true
    end
    it 'should be false when missing required files' do
      source = GTFS::Source.build(source_missing_required_files)
      source.required_files_present?.should be false
    end
    it 'should accept either calendar.txt or calendar_dates.txt' do
      source = GTFS::Source.build(valid_local_source)
      source.required_files_present?.should be true
      # ... still valid without calendar.txt
      File.unlink(source.send(:file_path, 'calendar.txt'))
      source.required_files_present?.should be true
      # ... but invalid when missing calendar.txt & calendar_dates.txt
      File.unlink(source.send(:file_path, 'calendar_dates.txt'))
      source.required_files_present?.should be false
    end
  end

  describe '#load_shapes' do
    let(:source) {GTFS::Source.build(valid_local_source)}
    it 'should load shapes when file present' do
      shapes = source.load_shapes
      shapes.size.should > 0
    end
    it 'should return nil when file not present' do
      File.unlink(source.send(:file_path, 'shapes.txt'))
      shapes = source.load_shapes
      shapes.should be nil
    end
    it '#shape_line should returns array of points' do
      source.shape_line('63542').size.should be 9
    end
  end

  describe '#load_service_periods' do
    let(:source) {GTFS::Source.build(valid_local_source)}
    it 'should return ServicePeriods' do
      source.load_service_periods.size.should > 0
    end
    it 'should handle missing calendar/calendar_dates' do
      File.unlink(source.send(:file_path, 'calendar.txt'))
      source.load_service_periods.size.should > 0
    end
    it '#service_period returns ServicePeriod' do
      source.service_period('1').class.should be GTFS::ServicePeriod
    end
  end

  describe '#service_period_range' do
    let(:source) {GTFS::Source.build(valid_local_source)}
    it 'calculates min and max service dates using both calendars' do
      start_date, end_date = source.service_period_range
      start_date.should eq Date.parse('2012-01-29')
      end_date.should eq Date.parse('2012-06-16')
    end
  end

  describe '#agencies' do
    subject {source.agencies}

    context 'when the source has agencies' do
      let(:source) {GTFS::Source.build(valid_local_source)}

      it {should_not be_empty}
      its(:first) {should be_an_instance_of(GTFS::Agency)}
    end
  end

  describe '#stops' do
  end

  describe '#routes' do
    context 'when the source is missing routes' do
      let(:source) { GTFS::Source.build source_missing_required_files }

      it do
        expect { source.routes }.to raise_exception GTFS::InvalidSourceException
      end
    end
  end

  describe '#trips' do
  end

  describe '#stop_times' do
  end
end
