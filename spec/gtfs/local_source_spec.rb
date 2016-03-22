require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe GTFS::LocalSource do
  let(:source_root) { File.join(File.expand_path(File.dirname(__FILE__)), '..') }
  let(:source_valid_zip) { File.join(source_root, 'fixtures', 'example.zip') }
  let(:source_nested_zip) { File.join(source_root, 'fixtures', 'example_nested.zip') }

  describe '.find_nested_gtfs' do
    it 'finds root sources' do
      GTFS::LocalSource.find_nested_gtfs(source_valid_zip).should =~ ["/"]
    end

    it 'finds nested sources' do
      GTFS::LocalSource.find_nested_gtfs(source_nested_zip).should =~ ["/example_nested/example", "/example_nested/nested/example.zip/"]
    end
  end
end
