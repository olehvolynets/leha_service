require 'sinatra'
require 'pry'
require 'csv'

get '/' do
  erb :index
end

preprocessor = proc do |(model, date, _currency, amount)|
  [
    model.split(' ').first.downcase.tr('аоуесрхі', 'aoyecpxi'),
    date,
    amount.to_f
  ]
end

post '/process' do
  file = params.dig(:file, :tempfile)
  parsed_file =
    CSV.parse(file.read, liberal_parsing: true)[1..]
    .map!(&preprocessor)
    .group_by { |(model, _date, _amount)| model }
    .transform_values do |records_by_model|
      records_by_model
        .group_by { |(_model, date, _amount)| date }
        .transform_values do |records_by_date|
          records_by_date
            .sum { |(_model, _date, amount)| amount }
            .ceil(2)
        end
    end

  csv_ready = parsed_file.flat_map do |model, sum_by_date|
    sum_by_date.to_a.each { _1.unshift(model) }
  end

  out_content = CSV.generate do |csv|
    csv << ['Model', 'Date', 'Spent (USD)']

    csv_ready.each { csv << _1 }
  end

  content_type 'application/csv'
  attachment "PROCESSED #{params.dig(:file, :filename)}"
  out_content
end
