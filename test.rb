#encoding=utf-8

load './time.rb'
begin
  t = TimeConverter.new
  [
    "today",
    "next sun",
    "last sat",
    "昨日",
    "明日",
    "あさって",
    "次の火曜",
    "次の月曜",
    "前の木曜",
    "先週の水曜",
    "来週の1日",
    "先月の30",
    "来月の1日",
    "3時間後",
    "1時間後",
    "3日後",
    "3週間後",
    "1318996912", # unix time stamp
    "20141229",
    "next sun"
  ].each do |str|
    puts "#{str} => #{t.str_to_time(str).strftime('%Y-%m-%d(_dow_) %T')}"
  end
rescue => e
  TimeConverter.print_error_item(e.message, $@)
end
