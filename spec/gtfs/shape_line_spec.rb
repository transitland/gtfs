require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe GTFS::ShapeLine do
  let(:valid_local_source) do
    File.expand_path(File.dirname(__FILE__) + '/../fixtures/valid_gtfs.zip')
  end

  describe 'test' do
    let(:data_source) {valid_local_source}
    let(:opts) {{}}

    it 'has a ShapeLine' do

    end
  end
end
