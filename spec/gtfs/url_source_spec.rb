require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe GTFS::URLSource do

  context '#load_archive' do
    let(:source_path) {'http://dl.dropbox.com/u/416235/work/valid_gtfs.zip'}
    it 'downloads' do
      feed = nil
      VCR.use_cassette('valid_gtfs_uri') do
        feed = GTFS::URLSource.new(source_path)
      end
      feed.valid?.should be true
    end

    it 'sets @archive to downloaded temporary file' do
      feed = nil
      VCR.use_cassette('valid_gtfs_uri') do
        feed = GTFS::URLSource.new(source_path)
      end
      File.exists?(feed.archive).should be true
    end
  end

  context 'with a URI to a valid source zip' do
    let(:source_path) {'http://dl.dropbox.com/u/416235/work/valid_gtfs.zip'}
    it 'should create a new source successfully' do
      VCR.use_cassette('valid_gtfs_uri') do
        lambda {GTFS::URLSource.new(source_path, {})}.should_not raise_error(GTFS::InvalidSourceException)
      end
    end
  end

  context 'with a non-existent URI' do
    let(:source_path) {'http://www.edschmalzle.com/gtfs.zip'}
    it 'should raise an exception' do
      VCR.use_cassette('invalid_gtfs_uri') do
        lambda {GTFS::URLSource.new(source_path, {})}.should raise_error(GTFS::InvalidSourceException)
      end
    end
  end

  context 'progress callback' do
    let(:source_path) {'http://dl.dropbox.com/u/416235/work/valid_gtfs.zip'}
    it 'reports download progress' do
      processed = 0
      progress = lambda { |count, total| processed = count }
      VCR.use_cassette('valid_gtfs_uri') do
        GTFS::URLSource.new(source_path, {progress_download: progress})
      end
      processed.should eq 4147
    end
  end

end
