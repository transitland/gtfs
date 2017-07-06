require 'rcsv'

module GTFS
  module Parse

    def self.parse_filename(filename, **kw, &block)
      File.open(filename, encoding: 'bom|utf-8') do |f|
        parse(f, **kw, &block)
      end
    end

    def self.parse_data(data, **kw, &block)
      parse(StringIO.new(data), **kw, &block)
    end

    def self.parse(fileobj, use_symbols: false, skip_inequal_rows: false)
      header = nil
      fileobj.each do |line|
        row = nil
        begin
          row = Rcsv.parse(line, header: :none, parse_empty_fields_as: :nil).first
        rescue Rcsv::ParseError => e
          begin
            # puts "Parse error, retry without quotes."
            line = line.gsub('"','')
            row = Rcsv.parse(line, header: :none, parse_empty_fields_as: :nil).first
          rescue Rcsv::ParseError => e2
            # puts "Parse error, skipping: #{e2}"
          end
        end

        if row.nil?
          # puts "Row is nil, skipping"
          next
        end

        row = row.map { |i| i.nil? ? nil : i.to_sym } if use_symbols

        if header.nil?
          header = row
          next
        end

        if (row.size != header.size) && skip_inequal_rows
          # puts "Unequal size, skipping: #{row.size} row != #{header.size} header"
          next
        end

        yield Hash[header.zip(row)]
      end
    end
  end
end
