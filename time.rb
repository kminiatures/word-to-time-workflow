#!/usr/bin/env ruby
# fileencoding=utf-8
require 'time'

class Time
  MIN  = 60
  HOUR = MIN * 60
  DAY  = HOUR * 24
  WEEK = DAY * 7

  def day_of_week
    self.strftime("%w").to_i
  end
  alias dow day_of_week

  def beginning_of_week
    self - self.dow * DAY
  end

  def last_week
    self - WEEK
  end

  def end_of_week
    self + (7 - self.dow) * DAY
  end
end

class TimeConverter
  module Formats
    HMS  = '%H:%M:%S'
    HMSj = '%H時%M分%S秒'
    YMD  = '%Y/%m/%d'
    MD   = '%m/%d'
    YMDj = '%Y年%m月%d日'
    YMDh = '%Y-%m-%d'
    DOW  = '( _dow_ )'
    DOWe = '( %a )'
  end

  def date_and_time_format
    [
      "#{YMD} #{HMS}",
      "#{YMD} #{DOW} #{HMS}",
      "#{YMDh} %H:%M:%S",
      "%Y%m%d%H%M%S",
      "#{YMDj}#{HMSj}",
      '_unix_time_stamp_',
    ]
  end

  def date_format
    [
      YMD,
      YMDh,
      "%Y%m%d",
      "#{MD}",
      "#{MD} #{DOWe}",
      "#{YMD} #{DOW}",
      "%b/%d/%Y #{DOWe}",
      "%b-%d-%Y",
      YMDj,
      "#{YMDj} #{DOW}",
    ]
  end

  def time_format
    [
      HMS,
      "%H:%M",
      HMS,
      "%H時%M分",
    ]
  end

  def formats(arg)
    case arg.strip
    when "time", "t"
      time_format
    when "now", "n"
      date_and_time_format + time_format + date_format
    when "date", "d"
      date_format + date_and_time_format
    else
      date_format + date_and_time_format
    end
  end
end

module TimeConverter::ClassMethods
  def print_error_item(error, exeption_object = nil)
    trace = []
    if exeption_object
      6.times.each do
        trace << "#{exeption_object.shift}"
      end
    end
    print_item('error', "Error: #{error}", trace.join("\n"))
  end

  def print_item(uid, title, subtitle)
    puts <<-XML
    <item arg="#{title}" autocomplete="#{title}">
      <title>#{title}</title>
      <subtitle>#{subtitle}</subtitle>
    </item>
    XML
  end
end

class TimeConverter
  include TimeConverter::Formats
  extend TimeConverter::ClassMethods

  def initialize
    @force_format = nil
    @day_of_weeks = {
        0 => '日', 1 => '月', 2 => '火', 3 => '水',
        4 => '木', 5 => '金', 6 => '土',
    }
    @day_of_weeks_en = {
        0 => 'sun', 1 => 'mon', 2 => 'tue', 3 => 'wed',
        4 => 'thu', 5 => 'fri', 6 => 'sat',
    }
    @day_of_week_options    = "(#{@day_of_weeks.map{   |k,v| v}.join("|")})"
    @day_of_week_options_en = "(#{@day_of_weeks_en.map{|k,v| v}.join("|")})"
  end

  def run(arg = nil)
    dump_xml do
      begin
        arg = ARGV[0] unless arg
        time,formats = time_and_formats(arg.strip)
        formats.each do |format|
          uid = format
          str_date = time.strftime(format)
            .sub('_dow_', day_of_week_str(time))
            .sub('_unix_time_stamp_', time.to_i.to_s)
          TimeConverter.print_item(uid, str_date, "#{time} => #{format}")
        end
      rescue => e
        TimeConverter.print_error_item e.message, $@
      end
    end
  end

  def str_to_time(arg)
    now = Time.now
    regex_day = "([0-9]{1,2})"
    case arg
    when "昨日", "きのう", /yes/
      now - Time::DAY
    when "明日", "あした", /tom/
      now + Time::DAY
    when "明後日", "あさって", "dat"
      now + Time::DAY * 2
    when /次の#{@day_of_week_options}曜?日?/, /next #{@day_of_week_options_en}/,
         /^(#{@day_of_week_options})曜?$/, /^(#{@day_of_week_options_en})$/
      next_day_of_week find_day_of_week($1)
    when /前の#{@day_of_week_options}曜?日?/, /last #{@day_of_week_options_en}/
      prev_day_of_week find_day_of_week($1)
    when /先週の?#{@day_of_week_options}曜?日?/, /last week #{@day_of_week_options_en}/
      now.last_week.beginning_of_week + find_day_of_week($1) * Time::DAY
    when /来週の?#{@day_of_week_options}曜?日?/, /next week #{@day_of_week_options_en}/
      (now + Time::WEEK).beginning_of_week + find_day_of_week($1) * Time::DAY
    when /先月の#{regex_day}日?/, /last month #{regex_day}/
      prev_month = now.month == 1 ? 12 : now.month - 1
      month_and_day(now, prev_month, $1)
    when /来月の#{regex_day}日?/, /next month #{regex_day}/
      next_month =  now.month == 1 ? 12 : now.month + 1
      month_and_day(now, next_month, $1)
    when /([0-9]{1,3})(週|日|時|分)間?後/, /([0-9]{1,3}) (week|day|hour|min|minute)s? since/
      now + $1.to_i * time_by_unit($2)
    when /([0-9]{1,3})(週|日|時|分)間?前/, /([0-9]{1,3}) (week|day|hour|min|minute)s? ago/
      now - $1.to_i * time_by_unit($2)
    when "週末", "weekend"
      @format = :day
      now.end_of_week - Time::DAY
    when /[0-9]{10}/ # timestamp
      Time.strptime(arg,'%s')
    else
      begin
        Time.parse(arg)
      rescue
        now
      end
    end
  end

  private

  def dump_xml
    puts '<?xml version="1.0"?><items>'
    yield
    puts '</items>'
  end

  def time_and_formats(arg)
    [str_to_time(arg), formats(arg)]
  end

  def time_by_unit(unit_str)
    case unit_str
    when '週', 'week';          Time::WEEK
    when '日', 'day';           Time::DAY
    when '時', 'hour';          Time::HOUR
    when '分', 'min', 'minute'; Time::MIN
    end
  end

  def day_of_week_str(time)
    @day_of_weeks[time.dow]
  end

  def month_and_day(now, month, day)
    Time.parse(now.strftime("%Y-#{month}-#{day} %T"))
  end

  def next_day_of_week(dow)
    now = Time.now.dow
    if now < dow
      Time.now + (dow - now) * Time::DAY
    else
      Time.now + (7 - now + dow) * Time::DAY
    end
  end

  def prev_day_of_week(dow)
    now = Time.now.dow
    if now <= dow
      Time.now - (7 - (dow - now)) * Time::DAY
    else
      Time.now - (now - dow) * Time::DAY
    end
  end

  def find_day_of_week(match)
    values = @day_of_weeks.find{|item| item[1] == match} || @day_of_weeks_en.find{|item| item[1] == match}
    values[0].to_i
  end
end
